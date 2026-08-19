import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_polygon_overlap.dart';

import 'terrain_polygon_interaction.dart';
import 'terrain_source_models.dart';

const int _physicsTicksPerHalfPixel =
    terrainPhysicsTicksPerWorldUnit ~/ terrainSourceTicksPerWorldUnit;

/// One immutable collision loop considered by editor contact constraints.
///
/// Vertices use Core's physics grid so transformed prefab collision can remain
/// exact even when it cannot be represented on the direct half-pixel source
/// grid. [stableKey] resolves otherwise equal snap candidates deterministically.
@immutable
final class TerrainAuthoringCollisionLoop {
  TerrainAuthoringCollisionLoop({
    required this.stableKey,
    required Iterable<TerrainPoint> vertices,
    required this.collisionMode,
  }) : vertices = List<TerrainPoint>.unmodifiable(vertices) {
    if (stableKey.trim().isEmpty || stableKey.trim() != stableKey) {
      throw ArgumentError.value(
        stableKey,
        'stableKey',
        'Must be non-empty and trimmed.',
      );
    }
    if (this.vertices.length < 3) {
      throw ArgumentError.value(
        vertices,
        'vertices',
        'Collision loops require at least three vertices.',
      );
    }
  }

  /// Builds an exact physics-grid loop from direct half-pixel source geometry.
  factory TerrainAuthoringCollisionLoop.fromSourceShape({
    required String stableKey,
    required TerrainSourceShapeDef shape,
  }) => TerrainAuthoringCollisionLoop(
    stableKey: stableKey,
    vertices: shape.vertices.map(
      (vertex) => TerrainPoint(
        vertex.xHalfPixels * _physicsTicksPerHalfPixel,
        vertex.yHalfPixels * _physicsTicksPerHalfPixel,
      ),
    ),
    collisionMode: switch (shape.collisionMode) {
      TerrainSourceCollisionMode.solid => TerrainCollisionMode.solid,
      TerrainSourceCollisionMode.oneWay => TerrainCollisionMode.oneWay,
      // Render-only loops block authored overlap but are not snap targets.
      TerrainSourceCollisionMode.none => TerrainCollisionMode.oneWay,
    },
  );

  final String stableKey;
  final List<TerrainPoint> vertices;
  final TerrainCollisionMode collisionMode;
}

typedef TerrainGesturePreviewBuilder =
    TerrainSourceShapeDef Function(TerrainSourceVertexDef pointer);

/// Resolves Chunk/Prefab polygon input against immutable collision loops.
///
/// Contact snapping is editor-only ergonomics. Free movement stays on the
/// caller's active grid; point gestures may refine boundary contact to a finer
/// caller-supplied source lattice. Accepted commits must continue to pass
/// Core's complete topology and occupied-area validation.
abstract final class TerrainPolygonContactConstraint {
  /// Whether [shape] occupies positive area inside any immutable [target].
  ///
  /// Degenerate previews return false and remain subject to the normal Core
  /// topology review before commit.
  static bool hasOccupiedAreaOverlap({
    required TerrainSourceShapeDef shape,
    required Iterable<TerrainAuthoringCollisionLoop> targets,
  }) => _shapeOverlapsAny(shape, _orderedTargets(targets));

  /// Snaps one source point to nearby solid collision without entering any loop.
  ///
  /// Returns `null` when [desired] is strictly inside occupied collision and no
  /// legal boundary point exists within [snapRadiusHalfPixels]. Exact boundary
  /// contact is legal. Transformed boundaries that miss the source lattice use
  /// the nearest authorable non-overlapping point.
  static TerrainSourceVertexDef? resolvePoint({
    required TerrainSourceVertexDef desired,
    required Iterable<TerrainAuthoringCollisionLoop> targets,
    required int snapStepHalfPixels,
    required double snapRadiusHalfPixels,
    bool Function(TerrainSourceVertexDef point)? isCandidateAllowed,
  }) {
    _validateSnapArguments(
      snapStepHalfPixels: snapStepHalfPixels,
      snapRadiusHalfPixels: snapRadiusHalfPixels,
    );
    final orderedTargets = _orderedTargets(targets);
    final allowed = isCandidateAllowed ?? (_) => true;
    final desiredInside = _pointInsideAny(desired, orderedTargets);
    final candidates =
        _pointSnapCandidates(
          desired: desired,
          targets: orderedTargets,
          snapStepHalfPixels: snapStepHalfPixels,
          snapRadiusHalfPixels: snapRadiusHalfPixels,
        ).where(
          (candidate) =>
              !_pointInsideAny(candidate.point, orderedTargets) &&
              allowed(candidate.point),
        );
    final best = _bestPointCandidate(candidates);
    if (best != null) return best.point;
    if (desiredInside || !allowed(desired)) return null;
    return desired;
  }

  /// Resolves one gesture pointer to a snapped, non-overlapping preview.
  ///
  /// Invalid desired previews are clamped along the authoring grid from the
  /// last accepted preview. Whole-shape translation snaps the moving boundary;
  /// rectangle and vertex gestures snap their active point. One-way loops block
  /// occupied overlap but are never used as removable solid seam targets.
  /// [pointContactStepHalfPixels] lets move/insert gestures reach a legal solid
  /// boundary between optional coarse-grid intersections without changing the
  /// coarse grid used for unconstrained movement. When supplied, it must be a
  /// positive divisor of [snapStepHalfPixels].
  static TerrainSourceVertexDef resolveGesturePointer({
    required TerrainPolygonGesture gesture,
    required TerrainSourceVertexDef desired,
    required Iterable<TerrainAuthoringCollisionLoop> targets,
    required int snapStepHalfPixels,
    int? pointContactStepHalfPixels,
    required double snapRadiusHalfPixels,
    required TerrainGesturePreviewBuilder buildPreview,
    required bool Function(TerrainSourceShapeDef shape) isCandidateInBounds,
  }) {
    _validateSnapArguments(
      snapStepHalfPixels: snapStepHalfPixels,
      snapRadiusHalfPixels: snapRadiusHalfPixels,
    );
    final pointContactStep = pointContactStepHalfPixels ?? snapStepHalfPixels;
    if (pointContactStep <= 0 || snapStepHalfPixels % pointContactStep != 0) {
      throw ArgumentError.value(
        pointContactStepHalfPixels,
        'pointContactStepHalfPixels',
        'Must be a positive divisor of snapStepHalfPixels when supplied.',
      );
    }
    final gestureStep = switch (gesture.kind) {
      TerrainPolygonGestureKind.moveVertex ||
      TerrainPolygonGestureKind.insertVertex => pointContactStep,
      TerrainPolygonGestureKind.createRectangle ||
      TerrainPolygonGestureKind.translateShape => snapStepHalfPixels,
    };
    final orderedTargets = _orderedTargets(targets);
    bool allowed(TerrainSourceVertexDef pointer) {
      final candidate = buildPreview(pointer);
      return isCandidateInBounds(candidate) &&
          !_shapeOverlapsAny(candidate, orderedTargets);
    }

    TerrainSourceVertexDef? snapped(TerrainSourceVertexDef pointer) =>
        gesture.kind == TerrainPolygonGestureKind.translateShape
        ? _resolveTranslationSnap(
            desired: pointer,
            preview: buildPreview(pointer),
            targets: orderedTargets,
            snapStepHalfPixels: snapStepHalfPixels,
            snapRadiusHalfPixels: snapRadiusHalfPixels,
            buildPreview: buildPreview,
            isAllowed: allowed,
          )
        : resolvePoint(
            desired: pointer,
            targets: orderedTargets,
            snapStepHalfPixels: gestureStep,
            snapRadiusHalfPixels: snapRadiusHalfPixels,
            isCandidateAllowed: allowed,
          );

    final previous = _gesturePreviewPointer(gesture);
    var lastAllowed = allowed(previous) ? previous : gesture.startPointer;
    final desiredSnap = snapped(desired);
    final requested = desiredSnap ?? desired;
    lastAllowed = _lastAllowedOnGrid(
      start: lastAllowed,
      end: requested,
      stepHalfPixels: gestureStep,
      isAllowed: allowed,
    );
    if (desiredSnap != null && lastAllowed == requested) return desiredSnap;

    final slideCandidates =
        <TerrainSourceVertexDef>[
              TerrainSourceVertexDef(
                xHalfPixels: lastAllowed.xHalfPixels,
                yHalfPixels: desired.yHalfPixels,
              ),
              TerrainSourceVertexDef(
                xHalfPixels: desired.xHalfPixels,
                yHalfPixels: lastAllowed.yHalfPixels,
              ),
            ]
            .map(
              (candidate) => _lastAllowedOnGrid(
                start: lastAllowed,
                end: candidate,
                stepHalfPixels: gestureStep,
                isAllowed: allowed,
              ),
            )
            .where((candidate) => candidate != lastAllowed)
            .toSet()
            .toList(growable: false)
          ..sort((left, right) {
            final distanceOrder = _sourceDistanceSquared(
              left,
              desired,
            ).compareTo(_sourceDistanceSquared(right, desired));
            if (distanceOrder != 0) return distanceOrder;
            final xOrder = left.xHalfPixels.compareTo(right.xHalfPixels);
            return xOrder != 0
                ? xOrder
                : left.yHalfPixels.compareTo(right.yHalfPixels);
          });
    if (slideCandidates.isNotEmpty) lastAllowed = slideCandidates.first;
    return snapped(lastAllowed) ?? lastAllowed;
  }
}

TerrainSourceVertexDef _lastAllowedOnGrid({
  required TerrainSourceVertexDef start,
  required TerrainSourceVertexDef end,
  required int stepHalfPixels,
  required bool Function(TerrainSourceVertexDef point) isAllowed,
}) {
  var lastAllowed = start;
  for (final point in _gridLine(start, end, stepHalfPixels: stepHalfPixels)) {
    if (!isAllowed(point)) break;
    lastAllowed = point;
  }
  return lastAllowed;
}

TerrainSourceVertexDef? _resolveTranslationSnap({
  required TerrainSourceVertexDef desired,
  required TerrainSourceShapeDef preview,
  required List<TerrainAuthoringCollisionLoop> targets,
  required int snapStepHalfPixels,
  required double snapRadiusHalfPixels,
  required TerrainGesturePreviewBuilder buildPreview,
  required bool Function(TerrainSourceVertexDef point) isAllowed,
}) {
  final solidTargets = targets
      .where((target) => target.collisionMode == TerrainCollisionMode.solid)
      .toList(growable: false);
  final moving = _physicsVertices(preview);
  if (isAllowed(desired) &&
      _minimumSolidBoundaryDistanceSquared(moving, solidTargets) <= 1e-6) {
    return desired;
  }
  final pointers = <TerrainSourceVertexDef>{};
  final radiusPhysics = snapRadiusHalfPixels * _physicsTicksPerHalfPixel;

  void addDeltas(double deltaXHalfPixels, double deltaYHalfPixels) {
    for (final delta in _nearbyGridDeltas(
      deltaXHalfPixels,
      deltaYHalfPixels,
      stepHalfPixels: snapStepHalfPixels,
    )) {
      final distanceSquared = delta.$1 * delta.$1 + delta.$2 * delta.$2;
      if (distanceSquared >
          snapRadiusHalfPixels * snapRadiusHalfPixels + 1e-9) {
        continue;
      }
      pointers.add(
        TerrainSourceVertexDef(
          xHalfPixels: desired.xHalfPixels + delta.$1,
          yHalfPixels: desired.yHalfPixels + delta.$2,
        ),
      );
    }
  }

  for (final target in solidTargets) {
    for (final vertex in moving) {
      for (final edge in _edges(target.vertices)) {
        final closest = _closestPointOnSegment(vertex, edge.$1, edge.$2);
        if (closest.distanceSquared > radiusPhysics * radiusPhysics + 1e-6) {
          continue;
        }
        addDeltas(
          (closest.x - vertex.xTicks) / _physicsTicksPerHalfPixel,
          (closest.y - vertex.yTicks) / _physicsTicksPerHalfPixel,
        );
      }
    }
    for (final targetVertex in target.vertices) {
      for (final edge in _edges(moving)) {
        final closest = _closestPointOnSegment(targetVertex, edge.$1, edge.$2);
        if (closest.distanceSquared > radiusPhysics * radiusPhysics + 1e-6) {
          continue;
        }
        addDeltas(
          (targetVertex.xTicks - closest.x) / _physicsTicksPerHalfPixel,
          (targetVertex.yTicks - closest.y) / _physicsTicksPerHalfPixel,
        );
      }
    }
  }

  _ShapeSnapCandidate? best;
  for (final pointer in pointers) {
    if (pointer == desired || !isAllowed(pointer)) continue;
    final shape = buildPreview(pointer);
    final boundaryDistance = _minimumSolidBoundaryDistanceSquared(
      _physicsVertices(shape),
      solidTargets,
    );
    final pointerDistance = _sourceDistanceSquared(pointer, desired);
    final candidate = _ShapeSnapCandidate(
      point: pointer,
      boundaryDistanceSquared: boundaryDistance,
      pointerDistanceSquared: pointerDistance,
    );
    if (best == null || candidate.compareTo(best) < 0) best = candidate;
  }
  if (best != null) return best.point;
  return isAllowed(desired) ? desired : null;
}

List<_PointSnapCandidate> _pointSnapCandidates({
  required TerrainSourceVertexDef desired,
  required List<TerrainAuthoringCollisionLoop> targets,
  required int snapStepHalfPixels,
  required double snapRadiusHalfPixels,
}) {
  final result = <_PointSnapCandidate>[];
  final desiredPhysics = _physicsPoint(desired);
  final radiusPhysics = snapRadiusHalfPixels * _physicsTicksPerHalfPixel;
  for (final target in targets) {
    if (target.collisionMode != TerrainCollisionMode.solid) continue;
    for (var edgeIndex = 0; edgeIndex < target.vertices.length; edgeIndex++) {
      final start = target.vertices[edgeIndex];
      final end = target.vertices[(edgeIndex + 1) % target.vertices.length];
      final closest = _closestPointOnSegment(desiredPhysics, start, end);
      if (closest.distanceSquared > radiusPhysics * radiusPhysics + 1e-6) {
        continue;
      }
      final desiredEdgeDistance = closest.distanceSquared;
      final xValues = _nearbyGridCoordinates(
        closest.x / _physicsTicksPerHalfPixel,
        desired.xHalfPixels,
        snapStepHalfPixels,
      );
      final yValues = _nearbyGridCoordinates(
        closest.y / _physicsTicksPerHalfPixel,
        desired.yHalfPixels,
        snapStepHalfPixels,
      );
      for (final x in xValues) {
        for (final y in yValues) {
          final point = TerrainSourceVertexDef(xHalfPixels: x, yHalfPixels: y);
          final pointerDistance = _sourceDistanceSquared(point, desired);
          if (pointerDistance >
              snapRadiusHalfPixels * snapRadiusHalfPixels + 1e-9) {
            continue;
          }
          final candidatePhysics = _physicsPoint(point);
          final edgeDistance = _closestPointOnSegment(
            candidatePhysics,
            start,
            end,
          ).distanceSquared;
          if (edgeDistance > desiredEdgeDistance + 1e-6) continue;
          if (point == desired && edgeDistance > 1e-6) continue;
          result.add(
            _PointSnapCandidate(
              point: point,
              edgeDistanceSquared: edgeDistance,
              pointerDistanceSquared: pointerDistance,
              targetKey: target.stableKey,
              edgeIndex: edgeIndex,
            ),
          );
        }
      }
    }
  }
  return result;
}

_PointSnapCandidate? _bestPointCandidate(
  Iterable<_PointSnapCandidate> candidates,
) {
  _PointSnapCandidate? best;
  for (final candidate in candidates) {
    if (best == null || candidate.compareTo(best) < 0) best = candidate;
  }
  return best;
}

bool _shapeOverlapsAny(
  TerrainSourceShapeDef shape,
  List<TerrainAuthoringCollisionLoop> targets,
) {
  if (shape.vertices.length < 3) return false;
  final vertices = _physicsVertices(shape);
  if (_signedDoubledArea(vertices) == BigInt.zero) return false;
  final bounds = _bounds(vertices);
  for (final target in targets) {
    if (!_aabbsIntersect(bounds, _bounds(target.vertices))) continue;
    if (TerrainPolygonOverlap.physicsLoops(vertices, target.vertices)) {
      return true;
    }
  }
  return false;
}

bool _pointInsideAny(
  TerrainSourceVertexDef point,
  List<TerrainAuthoringCollisionLoop> targets,
) {
  final physicsPoint = _physicsPoint(point);
  for (final target in targets) {
    final bounds = _bounds(target.vertices);
    if (physicsPoint.xTicks < bounds.$1 ||
        physicsPoint.xTicks > bounds.$3 ||
        physicsPoint.yTicks < bounds.$2 ||
        physicsPoint.yTicks > bounds.$4) {
      continue;
    }
    if (TerrainPolygonOverlap.physicsLoopContainsPointStrictly(
      target.vertices,
      physicsPoint,
    )) {
      return true;
    }
  }
  return false;
}

TerrainSourceVertexDef _gesturePreviewPointer(TerrainPolygonGesture gesture) {
  switch (gesture.kind) {
    case TerrainPolygonGestureKind.createRectangle:
      return gesture.previewShape.vertices.length >= 3
          ? gesture.previewShape.vertices[2]
          : gesture.startPointer;
    case TerrainPolygonGestureKind.moveVertex:
    case TerrainPolygonGestureKind.insertVertex:
      return gesture.previewShape.vertices[gesture.activeVertexIndex!];
    case TerrainPolygonGestureKind.translateShape:
      final original = gesture.originalShape.vertices.first;
      final preview = gesture.previewShape.vertices.first;
      return TerrainSourceVertexDef(
        xHalfPixels:
            gesture.startPointer.xHalfPixels +
            preview.xHalfPixels -
            original.xHalfPixels,
        yHalfPixels:
            gesture.startPointer.yHalfPixels +
            preview.yHalfPixels -
            original.yHalfPixels,
      );
  }
}

Iterable<TerrainSourceVertexDef> _gridLine(
  TerrainSourceVertexDef start,
  TerrainSourceVertexDef end, {
  required int stepHalfPixels,
}) sync* {
  final startX = start.xHalfPixels ~/ stepHalfPixels;
  final startY = start.yHalfPixels ~/ stepHalfPixels;
  final deltaX = end.xHalfPixels ~/ stepHalfPixels - startX;
  final deltaY = end.yHalfPixels ~/ stepHalfPixels - startY;
  final steps = math.max(deltaX.abs(), deltaY.abs());
  if (steps == 0) return;
  TerrainSourceVertexDef? previous;
  for (var index = 1; index <= steps; index++) {
    final point = TerrainSourceVertexDef(
      xHalfPixels:
          (startX + _roundRatioAwayFromZero(deltaX * index, steps)) *
          stepHalfPixels,
      yHalfPixels:
          (startY + _roundRatioAwayFromZero(deltaY * index, steps)) *
          stepHalfPixels,
    );
    if (point == previous) continue;
    previous = point;
    yield point;
  }
}

List<TerrainAuthoringCollisionLoop> _orderedTargets(
  Iterable<TerrainAuthoringCollisionLoop> targets,
) =>
    List<TerrainAuthoringCollisionLoop>.of(targets)
      ..sort((left, right) => left.stableKey.compareTo(right.stableKey));

List<int> _nearbyGridCoordinates(double value, int desired, int step) {
  final floor = (value / step).floor() * step;
  final ceil = (value / step).ceil() * step;
  final rounded = _roundDoubleAwayFromZero(value / step) * step;
  final result = <int>{desired, floor, ceil, rounded};
  for (final coordinate in <int>[floor, ceil, rounded]) {
    result
      ..add(coordinate - step)
      ..add(coordinate + step);
  }
  final sorted = result.toList()..sort();
  return sorted;
}

List<(int, int)> _nearbyGridDeltas(
  double x,
  double y, {
  required int stepHalfPixels,
}) {
  final xValues = _nearbyGridCoordinates(x, 0, stepHalfPixels);
  final yValues = _nearbyGridCoordinates(y, 0, stepHalfPixels);
  return <(int, int)>[
    for (final dx in xValues)
      for (final dy in yValues) (dx, dy),
  ];
}

Iterable<(TerrainPoint, TerrainPoint)> _edges(
  List<TerrainPoint> vertices,
) sync* {
  for (var index = 0; index < vertices.length; index++) {
    yield (vertices[index], vertices[(index + 1) % vertices.length]);
  }
}

({double x, double y, double distanceSquared}) _closestPointOnSegment(
  TerrainPoint point,
  TerrainPoint start,
  TerrainPoint end,
) {
  final dx = (end.xTicks - start.xTicks).toDouble();
  final dy = (end.yTicks - start.yTicks).toDouble();
  final lengthSquared = dx * dx + dy * dy;
  final rawT = lengthSquared == 0
      ? 0.0
      : ((point.xTicks - start.xTicks) * dx +
                (point.yTicks - start.yTicks) * dy) /
            lengthSquared;
  final t = rawT.clamp(0.0, 1.0);
  final x = start.xTicks + dx * t;
  final y = start.yTicks + dy * t;
  final separationX = point.xTicks - x;
  final separationY = point.yTicks - y;
  return (
    x: x,
    y: y,
    distanceSquared: separationX * separationX + separationY * separationY,
  );
}

double _minimumSolidBoundaryDistanceSquared(
  List<TerrainPoint> moving,
  List<TerrainAuthoringCollisionLoop> targets,
) {
  var minimum = double.infinity;
  for (final target in targets) {
    for (final vertex in moving) {
      for (final edge in _edges(target.vertices)) {
        minimum = math.min(
          minimum,
          _closestPointOnSegment(vertex, edge.$1, edge.$2).distanceSquared,
        );
      }
    }
    for (final vertex in target.vertices) {
      for (final edge in _edges(moving)) {
        minimum = math.min(
          minimum,
          _closestPointOnSegment(vertex, edge.$1, edge.$2).distanceSquared,
        );
      }
    }
  }
  return minimum;
}

TerrainPoint _physicsPoint(TerrainSourceVertexDef point) => TerrainPoint(
  point.xHalfPixels * _physicsTicksPerHalfPixel,
  point.yHalfPixels * _physicsTicksPerHalfPixel,
);

List<TerrainPoint> _physicsVertices(TerrainSourceShapeDef shape) =>
    shape.vertices.map(_physicsPoint).toList(growable: false);

BigInt _signedDoubledArea(List<TerrainPoint> vertices) {
  var area = BigInt.zero;
  for (var index = 0; index < vertices.length; index++) {
    final current = vertices[index];
    final next = vertices[(index + 1) % vertices.length];
    area +=
        BigInt.from(current.xTicks) * BigInt.from(next.yTicks) -
        BigInt.from(next.xTicks) * BigInt.from(current.yTicks);
  }
  return area;
}

(int, int, int, int) _bounds(List<TerrainPoint> vertices) {
  var minX = vertices.first.xTicks;
  var minY = vertices.first.yTicks;
  var maxX = minX;
  var maxY = minY;
  for (final vertex in vertices.skip(1)) {
    minX = math.min(minX, vertex.xTicks);
    minY = math.min(minY, vertex.yTicks);
    maxX = math.max(maxX, vertex.xTicks);
    maxY = math.max(maxY, vertex.yTicks);
  }
  return (minX, minY, maxX, maxY);
}

bool _aabbsIntersect((int, int, int, int) left, (int, int, int, int) right) =>
    left.$1 <= right.$3 &&
    left.$3 >= right.$1 &&
    left.$2 <= right.$4 &&
    left.$4 >= right.$2;

double _sourceDistanceSquared(
  TerrainSourceVertexDef left,
  TerrainSourceVertexDef right,
) {
  final dx = left.xHalfPixels - right.xHalfPixels;
  final dy = left.yHalfPixels - right.yHalfPixels;
  return (dx * dx + dy * dy).toDouble();
}

int _roundRatioAwayFromZero(int numerator, int denominator) {
  if (numerator == 0) return 0;
  final magnitude = numerator.abs();
  final rounded = (magnitude * 2 + denominator) ~/ (denominator * 2);
  return numerator.isNegative ? -rounded : rounded;
}

int _roundDoubleAwayFromZero(double value) =>
    value.isNegative ? (value - 0.5).ceil() : (value + 0.5).floor();

void _validateSnapArguments({
  required int snapStepHalfPixels,
  required double snapRadiusHalfPixels,
}) {
  if (snapStepHalfPixels <= 0) {
    throw ArgumentError.value(
      snapStepHalfPixels,
      'snapStepHalfPixels',
      'Must be positive.',
    );
  }
  if (!snapRadiusHalfPixels.isFinite || snapRadiusHalfPixels < 0) {
    throw ArgumentError.value(
      snapRadiusHalfPixels,
      'snapRadiusHalfPixels',
      'Must be finite and non-negative.',
    );
  }
}

final class _PointSnapCandidate implements Comparable<_PointSnapCandidate> {
  const _PointSnapCandidate({
    required this.point,
    required this.edgeDistanceSquared,
    required this.pointerDistanceSquared,
    required this.targetKey,
    required this.edgeIndex,
  });

  final TerrainSourceVertexDef point;
  final double edgeDistanceSquared;
  final double pointerDistanceSquared;
  final String targetKey;
  final int edgeIndex;

  @override
  int compareTo(_PointSnapCandidate other) {
    var order = edgeDistanceSquared.compareTo(other.edgeDistanceSquared);
    if (order != 0) return order;
    order = pointerDistanceSquared.compareTo(other.pointerDistanceSquared);
    if (order != 0) return order;
    order = targetKey.compareTo(other.targetKey);
    if (order != 0) return order;
    order = edgeIndex.compareTo(other.edgeIndex);
    if (order != 0) return order;
    order = point.xHalfPixels.compareTo(other.point.xHalfPixels);
    return order != 0
        ? order
        : point.yHalfPixels.compareTo(other.point.yHalfPixels);
  }
}

final class _ShapeSnapCandidate implements Comparable<_ShapeSnapCandidate> {
  const _ShapeSnapCandidate({
    required this.point,
    required this.boundaryDistanceSquared,
    required this.pointerDistanceSquared,
  });

  final TerrainSourceVertexDef point;
  final double boundaryDistanceSquared;
  final double pointerDistanceSquared;

  @override
  int compareTo(_ShapeSnapCandidate other) {
    var order = boundaryDistanceSquared.compareTo(
      other.boundaryDistanceSquared,
    );
    if (order != 0) return order;
    order = pointerDistanceSquared.compareTo(other.pointerDistanceSquared);
    if (order != 0) return order;
    order = point.xHalfPixels.compareTo(other.point.xHalfPixels);
    return order != 0
        ? order
        : point.yHalfPixels.compareTo(other.point.yHalfPixels);
  }
}
