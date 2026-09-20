part of 'terrain_compiler.dart';

// Compare clockwise turns in Y-down coordinates without trigonometry. The
// first turn in [0, 2*pi) follows the boundary of the occupied face. Equal turns
// retain the caller's canonical identity order.
int _compareUnionTurns(
  _RawEdge incomingA,
  _RawEdge outgoingA,
  _RawEdge incomingB,
  _RawEdge outgoingB,
) {
  (BigInt, BigInt) turn(_RawEdge incoming, _RawEdge outgoing) {
    final ix = BigInt.from(incoming.end.xTicks - incoming.start.xTicks);
    final iy = BigInt.from(incoming.end.yTicks - incoming.start.yTicks);
    final ox = BigInt.from(outgoing.end.xTicks - outgoing.start.xTicks);
    final oy = BigInt.from(outgoing.end.yTicks - outgoing.start.yTicks);
    return (ix * ox + iy * oy, ix * oy - iy * ox);
  }

  final a = turn(incomingA, outgoingA);
  final b = turn(incomingB, outgoingB);
  int half((BigInt, BigInt) value) =>
      value.$2.isNegative || (value.$2 == BigInt.zero && value.$1.isNegative)
      ? 1
      : 0;
  final halfOrder = half(a).compareTo(half(b));
  return halfOrder != 0 ? halfOrder : -(a.$1 * b.$2 - a.$2 * b.$1).sign;
}

// Classify exact rational intervals before rounding their endpoints. Sampling
// rounded midpoints would lose narrow exposed slivers and disagree at crossings.
List<_RawEdge> _solidUnionBoundary(
  List<_RawEdge> edges,
  List<TerrainPolygon> polygons,
) {
  final solids = [
    for (final polygon in polygons)
      if (polygon.collisionMode == TerrainCollisionMode.solid)
        (polygon, _bounds(polygon.vertices)),
  ];
  final result = <_RawEdge>[];
  final nextSubIndex = <TerrainEdgeId, int>{};
  for (final edge in edges) {
    if (edge.collisionMode != TerrainCollisionMode.solid) {
      result.add(edge);
      continue;
    }
    final edgeBounds = _bounds([edge.start, edge.end]);
    final neighbors = <TerrainPolygon>[
      for (final (polygon, bounds) in solids)
        if (!_unionOwnsEdge(polygon, edge) && bounds.intersects(edgeBounds))
          polygon,
    ];
    final splits = SplayTreeSet<_UnionFraction>()
      ..add(_UnionFraction.zero)
      ..add(_UnionFraction.one);
    for (final polygon in neighbors) {
      for (var i = 0; i < polygon.vertices.length; i += 1) {
        _unionSplitAtIntersection(
          edge,
          polygon.vertices[i],
          polygon.vertices[(i + 1) % polygon.vertices.length],
          splits,
        );
      }
    }
    final parameters = splits.toList(growable: false);
    final sourceId = TerrainEdgeId(
      chunkIndex: edge.id.chunkIndex,
      chunkKey: edge.id.chunkKey,
      placementKey: edge.id.placementKey,
      shapeId: edge.id.shapeId,
      localEdgeIndex: edge.id.localEdgeIndex,
    );
    for (var i = 1; i < parameters.length; i += 1) {
      final subIndex = nextSubIndex[sourceId] ?? 0;
      nextSubIndex[sourceId] = subIndex + 1;
      final midpoint = parameters[i - 1].midpoint(parameters[i]);
      if (neighbors.any((polygon) => _unionCovers(edge, midpoint, polygon))) {
        continue;
      }
      final start = _unionPointAt(edge, parameters[i - 1]);
      final end = _unionPointAt(edge, parameters[i]);
      // Sub-tick intervals have no representable collision segment.
      if (start == end) continue;
      result.add(
        edge.copyWith(
          id: TerrainEdgeId(
            chunkIndex: sourceId.chunkIndex,
            chunkKey: sourceId.chunkKey,
            placementKey: sourceId.placementKey,
            shapeId: sourceId.shapeId,
            localEdgeIndex: sourceId.localEdgeIndex,
            subEdgeIndex: subIndex,
          ),
          start: start,
          end: end,
        ),
      );
    }
  }
  return result;
}

bool _unionOwnsEdge(TerrainPolygon polygon, _RawEdge edge) =>
    polygon.identity.chunkIndex == edge.id.chunkIndex &&
    polygon.identity.chunkKey == edge.id.chunkKey &&
    polygon.identity.placementKey == edge.id.placementKey &&
    polygon.identity.shapeId == edge.id.shapeId;

void _unionSplitAtIntersection(
  _RawEdge edge,
  TerrainPoint start,
  TerrainPoint end,
  SplayTreeSet<_UnionFraction> splits,
) {
  final rx = BigInt.from(edge.end.xTicks - edge.start.xTicks);
  final ry = BigInt.from(edge.end.yTicks - edge.start.yTicks);
  final sx = BigInt.from(end.xTicks - start.xTicks);
  final sy = BigInt.from(end.yTicks - start.yTicks);
  final qx = BigInt.from(start.xTicks - edge.start.xTicks);
  final qy = BigInt.from(start.yTicks - edge.start.yTicks);
  final denominator = rx * sy - ry * sx;
  if (denominator == BigInt.zero) {
    // Collinear endpoints were already split by the compiler's line groups.
    return;
  }
  final t = _UnionFraction(qx * sy - qy * sx, denominator);
  final u = _UnionFraction(qx * ry - qy * rx, denominator);
  if (t.inUnitInterval && u.inUnitInterval) splits.add(t);
}

bool _unionCovers(
  _RawEdge edge,
  _UnionFraction parameter,
  TerrainPolygon polygon,
) {
  final denominator = parameter.denominator;
  final x =
      BigInt.from(edge.start.xTicks) * denominator +
      BigInt.from(edge.end.xTicks - edge.start.xTicks) * parameter.numerator;
  final y =
      BigInt.from(edge.start.yTicks) * denominator +
      BigInt.from(edge.end.yTicks - edge.start.yTicks) * parameter.numerator;
  var inside = false;
  for (var i = 0; i < polygon.vertices.length; i += 1) {
    final start = polygon.vertices[i];
    final end = polygon.vertices[(i + 1) % polygon.vertices.length];
    final ax = BigInt.from(start.xTicks) * denominator;
    final ay = BigInt.from(start.yTicks) * denominator;
    final bx = BigInt.from(end.xTicks) * denominator;
    final by = BigInt.from(end.yTicks) * denominator;
    final dx = BigInt.from(end.xTicks - start.xTicks);
    final dy = BigInt.from(end.yTicks - start.yTicks);
    final cross = dx * (y - ay) - dy * (x - ax);
    if (cross == BigInt.zero &&
        x >= (ax < bx ? ax : bx) &&
        x <= (ax > bx ? ax : bx) &&
        y >= (ay < by ? ay : by) &&
        y <= (ay > by ? ay : by)) {
      final dot =
          dx * BigInt.from(edge.end.xTicks - edge.start.xTicks) +
          dy * BigInt.from(edge.end.yTicks - edge.start.yTicks);
      // Opposing interiors bury both faces. Coincident outward faces keep the
      // lowest source edge identity, independent of input and visual order.
      return dot.isNegative ||
          polygon.identity.edgeId(i).compareTo(edge.id) < 0;
    }
    if ((ay > y) != (by > y) && (cross.sign > 0) == (dy.sign > 0)) {
      inside = !inside;
    }
  }
  return inside;
}

TerrainPoint _unionPointAt(_RawEdge edge, _UnionFraction t) => TerrainPoint(
  _unionRound(
    BigInt.from(edge.start.xTicks) * t.denominator +
        BigInt.from(edge.end.xTicks - edge.start.xTicks) * t.numerator,
    t.denominator,
  ),
  _unionRound(
    BigInt.from(edge.start.yTicks) * t.denominator +
        BigInt.from(edge.end.yTicks - edge.start.yTicks) * t.numerator,
    t.denominator,
  ),
);

int _unionRound(BigInt numerator, BigInt denominator) {
  final rounded =
      (numerator.abs() * BigInt.two + denominator) ~/
      (denominator * BigInt.two);
  return (numerator.isNegative ? -rounded : rounded).toInt();
}

final class _UnionFraction implements Comparable<_UnionFraction> {
  _UnionFraction(BigInt numerator, BigInt denominator)
    : numerator = denominator.isNegative ? -numerator : numerator,
      denominator = denominator.abs();

  static final zero = _UnionFraction(BigInt.zero, BigInt.one);
  static final one = _UnionFraction(BigInt.one, BigInt.one);

  final BigInt numerator;
  final BigInt denominator;

  bool get inUnitInterval =>
      numerator >= BigInt.zero && numerator <= denominator;

  _UnionFraction midpoint(_UnionFraction other) => _UnionFraction(
    numerator * other.denominator + other.numerator * denominator,
    BigInt.two * denominator * other.denominator,
  );

  @override
  int compareTo(_UnionFraction other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);
}
