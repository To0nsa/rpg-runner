import 'capsule_segment_kernel.dart';
import 'terrain_edge.dart';
import 'terrain_edge_id.dart';
import 'terrain_geometry.dart';
import 'terrain_numeric.dart';
import 'terrain_polygon.dart';
import 'terrain_traversal_profile.dart';
import 'upright_capsule.dart';

/// Physical role assigned to an accepted terrain contact.
enum TerrainContactKind { ignored, support, wall, ceiling }

/// Caller-owned contact-policy output used by the allocation-free controller.
class TerrainContactDecision {
  TerrainContactKind kind = TerrainContactKind.ignored;
  int normalXTicks = 0;
  int normalYTicks = 0;
  TerrainEdgeId? constraintEdgeId;

  bool get blocks => kind != TerrainContactKind.ignored;

  void reset() {
    kind = TerrainContactKind.ignored;
    normalXTicks = 0;
    normalYTicks = 0;
    constraintEdgeId = null;
  }
}

/// Gameplay filtering and classification layered over compiled terrain.
///
/// This policy owns solid/one-way sidedness, support thresholds, endpoint
/// filtering, and actor side masks. It does not mutate ECS or geometry.
class TerrainContactPolicy {
  const TerrainContactPolicy({required this.geometry, required this.profile});

  final TerrainGeometry geometry;
  final TerrainTraversalProfile profile;

  /// Classifies one successful continuous hit for the supplied tick motion.
  void classifySweep({
    required UprightCapsule tickStartCapsule,
    required int displacementXTicks,
    required int displacementYTicks,
    required TerrainEdge edge,
    required CapsuleSweepHit hit,
    required TerrainContactDecision out,
  }) {
    classifySweepAtCenter(
      tickStartCenterXTicks: tickStartCapsule.center.xTicks,
      tickStartCenterYTicks: tickStartCapsule.center.yTicks,
      radiusTicks: tickStartCapsule.radiusTicks,
      verticalHalfSegmentTicks: tickStartCapsule.verticalHalfSegmentTicks,
      displacementXTicks: displacementXTicks,
      displacementYTicks: displacementYTicks,
      edge: edge,
      hit: hit,
      out: out,
    );
  }

  /// Primitive-center equivalent of [classifySweep] for controller hot loops.
  @pragma('vm:prefer-inline')
  void classifySweepAtCenter({
    required int tickStartCenterXTicks,
    required int tickStartCenterYTicks,
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
    required int displacementXTicks,
    required int displacementYTicks,
    required TerrainEdge edge,
    required CapsuleSweepHit hit,
    required TerrainContactDecision out,
  }) {
    out.reset();
    if (!hit.hit || hit.edgeId != edge.id || hit.startedOverlapping) return;

    if (edge.collisionMode == TerrainCollisionMode.oneWay) {
      _classifyOneWay(
        tickStartCenterXTicks: tickStartCenterXTicks,
        tickStartCenterYTicks: tickStartCenterYTicks,
        radiusTicks: radiusTicks,
        verticalHalfSegmentTicks: verticalHalfSegmentTicks,
        displacementXTicks: displacementXTicks,
        displacementYTicks: displacementYTicks,
        edge: edge,
        hit: hit,
        out: out,
      );
      return;
    }

    var normalX = hit.normalXTicks;
    var normalY = hit.normalYTicks;
    var constraintEdge = edge;
    if (hit.feature != TerrainSegmentFeature.face &&
        _hasCompatibleJoin(edge, hit.feature) &&
        !_isConvexJoin(edge, hit.feature)) {
      final adjacent = _adjacentEdge(edge, hit.feature);
      final faceDot =
          displacementXTicks * edge.outwardNormal.xTicks +
          displacementYTicks * edge.outwardNormal.yTicks;
      final adjacentDot = adjacent == null
          ? 0
          : displacementXTicks * adjacent.outwardNormal.xTicks +
                displacementYTicks * adjacent.outwardNormal.yTicks;
      if (faceDot >= 0 && adjacentDot >= 0) return;

      // Connected vertices are constrained by their actual faces. Using a
      // radial endpoint normal here would create a ghost wall at exact seams.
      if (faceDot < 0) {
        normalX = edge.outwardNormal.xTicks;
        normalY = edge.outwardNormal.yTicks;
      } else if (adjacent != null) {
        normalX = adjacent.outwardNormal.xTicks;
        normalY = adjacent.outwardNormal.yTicks;
        constraintEdge = adjacent;
      }
    }

    final entering =
        displacementXTicks * normalX + displacementYTicks * normalY;
    if (entering >= 0) return;
    _classifyBlockingNormal(normalX, normalY, out);
    if (out.blocks) out.constraintEdgeId = constraintEdge.id;
  }

  /// Whether an existing contact can serve as final eligible support.
  bool acceptsSupportContact({
    required UprightCapsule tickStartCapsule,
    required TerrainEdge edge,
    required CapsuleSegmentContact contact,
  }) {
    return acceptsSupportContactAtCenter(
      tickStartCenterXTicks: tickStartCapsule.center.xTicks,
      tickStartCenterYTicks: tickStartCapsule.center.yTicks,
      radiusTicks: tickStartCapsule.radiusTicks,
      verticalHalfSegmentTicks: tickStartCapsule.verticalHalfSegmentTicks,
      edge: edge,
      contact: contact,
    );
  }

  /// Primitive-center equivalent of [acceptsSupportContact].
  @pragma('vm:prefer-inline')
  bool acceptsSupportContactAtCenter({
    required int tickStartCenterXTicks,
    required int tickStartCenterYTicks,
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
    required TerrainEdge edge,
    required CapsuleSegmentContact contact,
  }) {
    if (!profile.isWalkableSupport(edge)) return false;
    if (edge.collisionMode == TerrainCollisionMode.oneWay) {
      if (!profile.oneWaySupportEnabled) return false;
      if (contact.feature != TerrainSegmentFeature.face &&
          !_pointLiesOnFiniteEdge(
            contact.pointXTicks,
            contact.pointYTicks,
            edge,
          )) {
        return false;
      }
      return capsulePlaneClearanceNumeratorAtCenter(
            centerXTicks: tickStartCenterXTicks,
            centerYTicks: tickStartCenterYTicks,
            radiusTicks: radiusTicks,
            verticalHalfSegmentTicks: verticalHalfSegmentTicks,
            edge: edge,
          ) >=
          terrainContactEpsilonTicks * terrainDirectionScale;
    }
    return true;
  }

  /// Signed closest capsule clearance from the directed edge plane.
  ///
  /// Positive values are on the outward/collidable side. The capsule extent
  /// includes its cap radius and the support endpoint of its vertical spine.
  double capsulePlaneClearanceTicks(UprightCapsule capsule, TerrainEdge edge) {
    return capsulePlaneClearanceAtCenterTicks(
      centerXTicks: capsule.center.xTicks,
      centerYTicks: capsule.center.yTicks,
      radiusTicks: capsule.radiusTicks,
      verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
      edge: edge,
    );
  }

  /// Primitive-center signed capsule clearance from a directed edge plane.
  @pragma('vm:prefer-inline')
  double capsulePlaneClearanceAtCenterTicks({
    required int centerXTicks,
    required int centerYTicks,
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
    required TerrainEdge edge,
  }) {
    return capsulePlaneClearanceNumeratorAtCenter(
          centerXTicks: centerXTicks,
          centerYTicks: centerYTicks,
          radiusTicks: radiusTicks,
          verticalHalfSegmentTicks: verticalHalfSegmentTicks,
          edge: edge,
        ) /
        terrainDirectionScale;
  }

  /// Direction-scaled integer numerator of capsule-to-plane clearance.
  @pragma('vm:prefer-inline')
  int capsulePlaneClearanceNumeratorAtCenter({
    required int centerXTicks,
    required int centerYTicks,
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
    required TerrainEdge edge,
  }) {
    final normalX = edge.outwardNormal.xTicks;
    final normalY = edge.outwardNormal.yTicks;
    final centerProjection =
        (centerXTicks - edge.start.xTicks) * normalX +
        (centerYTicks - edge.start.yTicks) * normalY;
    final extentProjection =
        radiusTicks * terrainDirectionScale +
        verticalHalfSegmentTicks * normalY.abs();
    return centerProjection - extentProjection;
  }

  /// Signed capsule-center distance from the edge's directed face plane.
  double capsuleCenterPlaneDistanceTicks(
    UprightCapsule capsule,
    TerrainEdge edge,
  ) {
    return capsuleCenterPlaneDistanceAtCenterTicks(
      centerXTicks: capsule.center.xTicks,
      centerYTicks: capsule.center.yTicks,
      edge: edge,
    );
  }

  /// Primitive-center signed distance from a directed edge face plane.
  @pragma('vm:prefer-inline')
  double capsuleCenterPlaneDistanceAtCenterTicks({
    required int centerXTicks,
    required int centerYTicks,
    required TerrainEdge edge,
  }) {
    return capsuleCenterPlaneDistanceNumeratorAtCenter(
          centerXTicks: centerXTicks,
          centerYTicks: centerYTicks,
          edge: edge,
        ) /
        terrainDirectionScale;
  }

  /// Direction-scaled integer numerator of center-to-plane distance.
  @pragma('vm:prefer-inline')
  int capsuleCenterPlaneDistanceNumeratorAtCenter({
    required int centerXTicks,
    required int centerYTicks,
    required TerrainEdge edge,
  }) {
    return (centerXTicks - edge.start.xTicks) * edge.outwardNormal.xTicks +
        (centerYTicks - edge.start.yTicks) * edge.outwardNormal.yTicks;
  }

  void _classifyOneWay({
    required int tickStartCenterXTicks,
    required int tickStartCenterYTicks,
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
    required int displacementXTicks,
    required int displacementYTicks,
    required TerrainEdge edge,
    required CapsuleSweepHit hit,
    required TerrainContactDecision out,
  }) {
    if (!profile.oneWaySupportEnabled || !profile.isWalkableSupport(edge)) {
      return;
    }
    if (capsulePlaneClearanceNumeratorAtCenter(
          centerXTicks: tickStartCenterXTicks,
          centerYTicks: tickStartCenterYTicks,
          radiusTicks: radiusTicks,
          verticalHalfSegmentTicks: verticalHalfSegmentTicks,
          edge: edge,
        ) <
        terrainContactEpsilonTicks * terrainDirectionScale) {
      return;
    }
    final approach =
        displacementXTicks * edge.outwardNormal.xTicks +
        displacementYTicks * edge.outwardNormal.yTicks;
    if (approach >= 0) return;
    if (!_pointLiesOnFiniteEdge(hit.pointXTicks, hit.pointYTicks, edge)) return;

    out
      ..kind = TerrainContactKind.support
      ..normalXTicks = edge.outwardNormal.xTicks
      ..normalYTicks = edge.outwardNormal.yTicks
      ..constraintEdgeId = edge.id;
  }

  void _classifyBlockingNormal(
    int normalX,
    int normalY,
    TerrainContactDecision out,
  ) {
    if (-normalY >= profile.minimumSupportUpComponent) {
      out
        ..kind = TerrainContactKind.support
        ..normalXTicks = normalX
        ..normalYTicks = normalY;
      return;
    }
    if (normalY > 0 && normalY.abs() >= normalX.abs()) {
      if (!profile.collideCeilings) return;
      out
        ..kind = TerrainContactKind.ceiling
        ..normalXTicks = normalX
        ..normalYTicks = normalY;
      return;
    }
    if (normalX < 0 && !profile.collideRightWalls) return;
    if (normalX > 0 && !profile.collideLeftWalls) return;
    if (normalX == 0) {
      if (!profile.collideCeilings) return;
      out.kind = TerrainContactKind.ceiling;
    } else {
      out.kind = TerrainContactKind.wall;
    }
    out
      ..normalXTicks = normalX
      ..normalYTicks = normalY;
  }

  bool _hasCompatibleJoin(TerrainEdge edge, TerrainSegmentFeature feature) {
    return switch (feature) {
      TerrainSegmentFeature.startEndpoint =>
        edge.startJoin != TerrainVertexJoin.exposed,
      TerrainSegmentFeature.endEndpoint =>
        edge.endJoin != TerrainVertexJoin.exposed,
      TerrainSegmentFeature.face => false,
    };
  }

  TerrainEdge? _adjacentEdge(TerrainEdge edge, TerrainSegmentFeature feature) {
    final adjacentId = switch (feature) {
      TerrainSegmentFeature.startEndpoint => edge.previousId,
      TerrainSegmentFeature.endEndpoint => edge.nextId,
      TerrainSegmentFeature.face => null,
    };
    return adjacentId == null ? null : geometry.edgeById[adjacentId];
  }

  bool _isConvexJoin(TerrainEdge edge, TerrainSegmentFeature feature) {
    final adjacent = _adjacentEdge(edge, feature);
    if (adjacent == null) return false;
    if (!profile.isWalkableSupport(edge) ||
        !profile.isWalkableSupport(adjacent)) {
      return false;
    }
    final incoming = feature == TerrainSegmentFeature.endEndpoint
        ? edge
        : adjacent;
    final outgoing = feature == TerrainSegmentFeature.endEndpoint
        ? adjacent
        : edge;
    final cross =
        incoming.dxTicks * outgoing.dyTicks -
        incoming.dyTicks * outgoing.dxTicks;
    return cross > 0;
  }
}

bool _pointLiesOnFiniteEdge(int xTicks, int yTicks, TerrainEdge edge) {
  final dx = edge.dxTicks;
  final dy = edge.dyTicks;
  final pointDx = xTicks - edge.start.xTicks;
  final pointDy = yTicks - edge.start.yTicks;
  final projection = pointDx * dx + pointDy * dy;
  final lengthSquared = dx * dx + dy * dy;
  final projectionTolerance =
      terrainContactEpsilonTicks * (dx.abs() + dy.abs());
  return projection >= -projectionTolerance &&
      projection <= lengthSquared + projectionTolerance;
}
