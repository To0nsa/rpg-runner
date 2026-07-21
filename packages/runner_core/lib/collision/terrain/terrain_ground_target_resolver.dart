import 'terrain_edge.dart';
import 'terrain_edge_id.dart';
import 'terrain_edge_index.dart';
import 'terrain_geometry.dart';
import 'terrain_numeric.dart';
import 'terrain_polygon.dart';
import 'terrain_query_buffer.dart';
import 'terrain_traversal_profile.dart';

/// Stable reason returned by [TerrainGroundTargetResolver].
enum TerrainGroundTargetValidity {
  valid,
  noWalkableSupport,
  outsideCastRange,
  lineOfSightBlocked,
}

/// Immutable quantized request for a future ground-target ability.
class TerrainGroundTargetRequest {
  factory TerrainGroundTargetRequest({
    required TerrainPoint castOrigin,
    required TerrainDirection aimDirection,
    required int rangeTicks,
    required int maximumDownwardProbeTicks,
  }) {
    if (rangeTicks <= 0 || rangeTicks > terrainMaxAbsPhysicsTicks) {
      throw RangeError.range(
        rangeTicks,
        1,
        terrainMaxAbsPhysicsTicks,
        'rangeTicks',
      );
    }
    if (maximumDownwardProbeTicks < 0 ||
        maximumDownwardProbeTicks > terrainMaxAbsPhysicsTicks) {
      throw RangeError.range(
        maximumDownwardProbeTicks,
        0,
        terrainMaxAbsPhysicsTicks,
        'maximumDownwardProbeTicks',
      );
    }
    return TerrainGroundTargetRequest._(
      castOrigin: castOrigin,
      aimDirection: aimDirection,
      rangeTicks: rangeTicks,
      maximumDownwardProbeTicks: maximumDownwardProbeTicks,
    );
  }

  const TerrainGroundTargetRequest._({
    required this.castOrigin,
    required this.aimDirection,
    required this.rangeTicks,
    required this.maximumDownwardProbeTicks,
  });

  final TerrainPoint castOrigin;
  final TerrainDirection aimDirection;
  final int rangeTicks;
  final int maximumDownwardProbeTicks;
}

/// Immutable output suitable for preview and commit revalidation.
class TerrainGroundTargetResult {
  const TerrainGroundTargetResult({
    required this.desiredPoint,
    required this.resolvedPoint,
    required this.supportEdgeId,
    required this.geometryVersion,
    required this.validity,
    required this.blockerEdgeId,
  });

  final TerrainPoint desiredPoint;
  final TerrainPoint? resolvedPoint;
  final TerrainEdgeId? supportEdgeId;
  final int geometryVersion;
  final TerrainGroundTargetValidity validity;
  final TerrainEdgeId? blockerEdgeId;

  bool get isValid => validity == TerrainGroundTargetValidity.valid;
}

/// Pure Core resolver for a future player ground-target ability.
///
/// The resolver owns one reusable query buffer. Geometry and traversal policy
/// are immutable, all ordering follows canonical edge IDs, and every public
/// coordinate uses 1/1024-world-unit physics ticks.
class TerrainGroundTargetResolver {
  TerrainGroundTargetResolver({
    required this.geometry,
    required this.index,
    required this.profile,
  }) : _queryBuffer = index.createQueryBuffer() {
    if (geometry.edges.length != index.edges.length) {
      throw ArgumentError('Geometry and index edge counts must match.');
    }
    for (var edgeIndex = 0; edgeIndex < geometry.edges.length; edgeIndex += 1) {
      if (geometry.edges[edgeIndex].id != index.edges[edgeIndex].id) {
        throw ArgumentError(
          'Geometry and index must use the same canonical edge order.',
        );
      }
    }
  }

  final TerrainGeometry geometry;
  final TerrainEdgeIndex index;
  final TerrainTraversalProfile profile;
  final TerrainQueryBuffer _queryBuffer;

  TerrainGroundTargetResult resolve(TerrainGroundTargetRequest request) {
    final desired = TerrainPoint(
      request.castOrigin.xTicks +
          _roundedDivide(
            request.aimDirection.xTicks * request.rangeTicks,
            terrainDirectionScale,
          ),
      request.castOrigin.yTicks +
          _roundedDivide(
            request.aimDirection.yTicks * request.rangeTicks,
            terrainDirectionScale,
          ),
    );
    final support = _firstSupportBelow(
      desired,
      request.maximumDownwardProbeTicks,
    );
    if (support == null) {
      return TerrainGroundTargetResult(
        desiredPoint: desired,
        resolvedPoint: null,
        supportEdgeId: null,
        geometryVersion: geometry.version,
        validity: TerrainGroundTargetValidity.noWalkableSupport,
        blockerEdgeId: null,
      );
    }

    final target = TerrainPoint(desired.xTicks, support.yTicks);
    final deltaX = target.xTicks - request.castOrigin.xTicks;
    final deltaY = target.yTicks - request.castOrigin.yTicks;
    if (deltaX * deltaX + deltaY * deltaY >
        request.rangeTicks * request.rangeTicks) {
      return TerrainGroundTargetResult(
        desiredPoint: desired,
        resolvedPoint: target,
        supportEdgeId: support.edge.id,
        geometryVersion: geometry.version,
        validity: TerrainGroundTargetValidity.outsideCastRange,
        blockerEdgeId: null,
      );
    }

    final blocker = _firstLineOfSightBlocker(
      origin: request.castOrigin,
      target: target,
      targetSupport: support.edge,
    );
    return TerrainGroundTargetResult(
      desiredPoint: desired,
      resolvedPoint: target,
      supportEdgeId: support.edge.id,
      geometryVersion: geometry.version,
      validity: blocker == null
          ? TerrainGroundTargetValidity.valid
          : TerrainGroundTargetValidity.lineOfSightBlocked,
      blockerEdgeId: blocker?.id,
    );
  }

  /// Checks whether a preview can be committed without redirecting it.
  ///
  /// A version change always invalidates the preview. Callers may render a new
  /// preview by resolving again, but commit must never substitute that new
  /// result for the originally presented target.
  bool canCommitPreview(TerrainGroundTargetResult preview) {
    if (!preview.isValid || preview.geometryVersion != geometry.version) {
      return false;
    }
    final edgeId = preview.supportEdgeId;
    final point = preview.resolvedPoint;
    if (edgeId == null || point == null) return false;
    final edge = geometry.edgeById[edgeId];
    if (edge == null || !_isEligibleSupport(edge)) return false;
    final expectedY = _edgeYAtX(edge, point.xTicks);
    return expectedY != null && expectedY == point.yTicks;
  }

  _GroundTargetSupport? _firstSupportBelow(
    TerrainPoint desired,
    int maximumProbeTicks,
  ) {
    final maximumY = desired.yTicks + maximumProbeTicks;
    index.query(
      TerrainAabb(
        minX: desired.xTicks - terrainContactEpsilonTicks,
        minY: desired.yTicks,
        maxX: desired.xTicks + terrainContactEpsilonTicks,
        maxY: maximumY,
      ),
      _queryBuffer,
    );
    _GroundTargetSupport? best;
    for (
      var candidateIndex = 0;
      candidateIndex < _queryBuffer.candidateCount;
      candidateIndex += 1
    ) {
      final edge = _queryBuffer.edgeAt(candidateIndex, index.edges);
      if (!_isEligibleSupport(edge)) continue;
      final y = _edgeYAtX(edge, desired.xTicks);
      if (y == null || y < desired.yTicks || y > maximumY) continue;
      final candidate = _GroundTargetSupport(edge, y);
      if (best == null || _compareSupport(candidate, best) < 0) {
        best = candidate;
      }
    }
    return best;
  }

  bool _isEligibleSupport(TerrainEdge edge) {
    if (!profile.isWalkableSupport(edge)) return false;
    return edge.collisionMode == TerrainCollisionMode.solid ||
        (edge.collisionMode == TerrainCollisionMode.oneWay &&
            profile.oneWaySupportEnabled);
  }

  int _compareSupport(_GroundTargetSupport left, _GroundTargetSupport right) {
    final distanceOrder = left.yTicks.compareTo(right.yTicks);
    if (distanceOrder != 0 &&
        (left.yTicks - right.yTicks).abs() > terrainContactEpsilonTicks) {
      return distanceOrder;
    }
    final modeOrder = _supportModePriority(
      left.edge.collisionMode,
    ).compareTo(_supportModePriority(right.edge.collisionMode));
    if (modeOrder != 0) return modeOrder;
    return left.edge.id.compareTo(right.edge.id);
  }

  int _supportModePriority(TerrainCollisionMode mode) =>
      mode == TerrainCollisionMode.solid ? 0 : 1;

  TerrainEdge? _firstLineOfSightBlocker({
    required TerrainPoint origin,
    required TerrainPoint target,
    required TerrainEdge targetSupport,
  }) {
    index.query(
      TerrainAabb(
        minX: origin.xTicks < target.xTicks ? origin.xTicks : target.xTicks,
        minY: origin.yTicks < target.yTicks ? origin.yTicks : target.yTicks,
        maxX: origin.xTicks > target.xTicks ? origin.xTicks : target.xTicks,
        maxY: origin.yTicks > target.yTicks ? origin.yTicks : target.yTicks,
      ).expanded(terrainContactEpsilonTicks),
      _queryBuffer,
    );
    for (
      var candidateIndex = 0;
      candidateIndex < _queryBuffer.candidateCount;
      candidateIndex += 1
    ) {
      final edge = _queryBuffer.edgeAt(candidateIndex, index.edges);
      if (edge.id == targetSupport.id) continue;
      if (edge.collisionMode == TerrainCollisionMode.oneWay &&
          !_oneWayBlocksLine(origin, target, edge)) {
        continue;
      }
      if (_intersectsBeforeTarget(origin, target, edge)) return edge;
    }
    return null;
  }

  bool _oneWayBlocksLine(
    TerrainPoint origin,
    TerrainPoint target,
    TerrainEdge edge,
  ) {
    final startSide =
        (origin.xTicks - edge.start.xTicks) * edge.outwardNormal.xTicks +
        (origin.yTicks - edge.start.yTicks) * edge.outwardNormal.yTicks;
    final directionDot =
        (target.xTicks - origin.xTicks) * edge.outwardNormal.xTicks +
        (target.yTicks - origin.yTicks) * edge.outwardNormal.yTicks;
    return startSide >= -terrainContactEpsilonTicks * terrainDirectionScale &&
        directionDot < 0;
  }

  bool _intersectsBeforeTarget(
    TerrainPoint origin,
    TerrainPoint target,
    TerrainEdge edge,
  ) {
    final rayX = target.xTicks - origin.xTicks;
    final rayY = target.yTicks - origin.yTicks;
    final edgeX = edge.end.xTicks - edge.start.xTicks;
    final edgeY = edge.end.yTicks - edge.start.yTicks;
    var denominator = _cross(rayX, rayY, edgeX, edgeY);
    if (denominator == 0) return false;
    final offsetX = edge.start.xTicks - origin.xTicks;
    final offsetY = edge.start.yTicks - origin.yTicks;
    var rayNumerator = _cross(offsetX, offsetY, edgeX, edgeY);
    var edgeNumerator = _cross(offsetX, offsetY, rayX, rayY);
    if (denominator < 0) {
      denominator = -denominator;
      rayNumerator = -rayNumerator;
      edgeNumerator = -edgeNumerator;
    }
    return rayNumerator > 0 &&
        rayNumerator < denominator &&
        edgeNumerator >= 0 &&
        edgeNumerator <= denominator;
  }

  int? _edgeYAtX(TerrainEdge edge, int xTicks) {
    if (xTicks < edge.bounds.minX || xTicks > edge.bounds.maxX) return null;
    final dx = edge.dxTicks;
    if (dx == 0) return null;
    return edge.start.yTicks +
        _roundedDivide((xTicks - edge.start.xTicks) * edge.dyTicks, dx);
  }
}

class _GroundTargetSupport {
  const _GroundTargetSupport(this.edge, this.yTicks);

  final TerrainEdge edge;
  final int yTicks;
}

int _cross(int leftX, int leftY, int rightX, int rightY) =>
    leftX * rightY - leftY * rightX;

int _roundedDivide(int numerator, int denominator) {
  if (denominator == 0) {
    throw ArgumentError.value(denominator, 'denominator', 'Must not be zero.');
  }
  final negative = (numerator < 0) != (denominator < 0);
  final absoluteNumerator = numerator.abs();
  final absoluteDenominator = denominator.abs();
  final quotient =
      (absoluteNumerator + absoluteDenominator ~/ 2) ~/ absoluteDenominator;
  return negative ? -quotient : quotient;
}
