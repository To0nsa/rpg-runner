import 'terrain_edge.dart';
import 'terrain_edge_id.dart';
import 'terrain_numeric.dart';

/// Caller-owned result for a translating axis-aligned box against one edge.
final class TerrainAabbSweepHit {
  bool hit = false;
  bool startedOverlapping = false;
  double timeOfImpact = 1;
  TerrainEdgeId? edgeId;

  void reset() {
    hit = false;
    startedOverlapping = false;
    timeOfImpact = 1;
    edgeId = null;
  }

  void copyFrom(TerrainAabbSweepHit source) {
    hit = source.hit;
    startedOverlapping = source.startedOverlapping;
    timeOfImpact = source.timeOfImpact;
    edgeId = source.edgeId;
  }
}

/// Allocation-free continuous AABB/finite-segment intersection kernel.
///
/// The sweep uses the separating axes of the AABB and segment. Physical
/// sidedness, one-way filtering, and collision response remain caller policy.
final class TerrainAabbSegmentSweepKernel {
  double _entryTime = double.negativeInfinity;
  double _exitTime = double.infinity;

  void sweepAtCenter({
    required int centerXTicks,
    required int centerYTicks,
    required int halfWidthTicks,
    required int halfHeightTicks,
    required int displacementXTicks,
    required int displacementYTicks,
    required TerrainEdge edge,
    required TerrainAabbSweepHit out,
  }) {
    if (halfWidthTicks <= 0 || halfHeightTicks <= 0) {
      throw ArgumentError('Terrain AABB half extents must be positive.');
    }
    out.reset();
    _entryTime = double.negativeInfinity;
    _exitTime = double.infinity;

    if (!_intersectAxis(
          centerXTicks: centerXTicks,
          centerYTicks: centerYTicks,
          halfWidthTicks: halfWidthTicks,
          halfHeightTicks: halfHeightTicks,
          displacementXTicks: displacementXTicks,
          displacementYTicks: displacementYTicks,
          edge: edge,
          axisX: 1,
          axisY: 0,
        ) ||
        !_intersectAxis(
          centerXTicks: centerXTicks,
          centerYTicks: centerYTicks,
          halfWidthTicks: halfWidthTicks,
          halfHeightTicks: halfHeightTicks,
          displacementXTicks: displacementXTicks,
          displacementYTicks: displacementYTicks,
          edge: edge,
          axisX: 0,
          axisY: 1,
        ) ||
        !_intersectAxis(
          centerXTicks: centerXTicks,
          centerYTicks: centerYTicks,
          halfWidthTicks: halfWidthTicks,
          halfHeightTicks: halfHeightTicks,
          displacementXTicks: displacementXTicks,
          displacementYTicks: displacementYTicks,
          edge: edge,
          axisX: edge.dyTicks,
          axisY: -edge.dxTicks,
        )) {
      return;
    }

    if (_entryTime > _exitTime + terrainParametricGuard ||
        _exitTime < -terrainParametricGuard ||
        _entryTime > 1 + terrainParametricGuard) {
      return;
    }

    out
      ..hit = true
      ..startedOverlapping = _entryTime < -terrainParametricGuard
      ..timeOfImpact = _entryTime.clamp(0.0, 1.0)
      ..edgeId = edge.id;
  }

  int compareHits(TerrainAabbSweepHit left, TerrainAabbSweepHit right) {
    if (!left.hit ||
        !right.hit ||
        left.edgeId == null ||
        right.edgeId == null) {
      throw StateError('Only successful AABB sweep hits can be compared.');
    }
    final delta = left.timeOfImpact - right.timeOfImpact;
    if (delta.abs() > terrainParametricGuard) return delta < 0 ? -1 : 1;
    return left.edgeId!.compareTo(right.edgeId!);
  }

  bool _intersectAxis({
    required int centerXTicks,
    required int centerYTicks,
    required int halfWidthTicks,
    required int halfHeightTicks,
    required int displacementXTicks,
    required int displacementYTicks,
    required TerrainEdge edge,
    required int axisX,
    required int axisY,
  }) {
    if (axisX == 0 && axisY == 0) return false;
    final center = centerXTicks * axisX + centerYTicks * axisY;
    final radius = halfWidthTicks * axisX.abs() + halfHeightTicks * axisY.abs();
    final boxMin = center - radius;
    final boxMax = center + radius;
    final edgeStart = edge.start.xTicks * axisX + edge.start.yTicks * axisY;
    final edgeEnd = edge.end.xTicks * axisX + edge.end.yTicks * axisY;
    final edgeMin = edgeStart < edgeEnd ? edgeStart : edgeEnd;
    final edgeMax = edgeStart > edgeEnd ? edgeStart : edgeEnd;
    final velocity = displacementXTicks * axisX + displacementYTicks * axisY;

    if (velocity == 0) return boxMax >= edgeMin && boxMin <= edgeMax;

    var entry = (edgeMin - boxMax) / velocity;
    var exit = (edgeMax - boxMin) / velocity;
    if (entry > exit) {
      final swap = entry;
      entry = exit;
      exit = swap;
    }
    if (entry > _entryTime) _entryTime = entry;
    if (exit < _exitTime) _exitTime = exit;
    return _entryTime <= _exitTime + terrainParametricGuard;
  }
}
