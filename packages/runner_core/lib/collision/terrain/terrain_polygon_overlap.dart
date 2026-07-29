import 'dart:math' as math;

import 'terrain_numeric.dart';

/// Exact positive-area overlap predicates for valid integer polygon loops.
///
/// Point-only contact and a shared boundary are not area overlap. Callers must
/// first validate that each loop is simple, non-degenerate, and has at least
/// three vertices. The predicates perform no floating-point operations.
abstract final class TerrainPolygonOverlap {
  /// Whether two validated half-unit source loops overlap in positive area.
  static bool sourceLoops(
    List<SourceTerrainPoint> left,
    List<SourceTerrainPoint> right,
  ) => _loops(
    left,
    right,
    xTicks: (point) => point.xTicks,
    yTicks: (point) => point.yTicks,
  );

  /// Whether two validated physics-grid loops overlap in positive area.
  static bool physicsLoops(List<TerrainPoint> left, List<TerrainPoint> right) =>
      _loops(
        left,
        right,
        xTicks: (point) => point.xTicks,
        yTicks: (point) => point.yTicks,
      );
}

bool _loops<T>(
  List<T> left,
  List<T> right, {
  required int Function(T point) xTicks,
  required int Function(T point) yTicks,
}) {
  if (left.length < 3 || right.length < 3) {
    throw ArgumentError('Polygon overlap requires two validated loops.');
  }
  final leftArea = _signedDoubledArea(left, xTicks, yTicks);
  final rightArea = _signedDoubledArea(right, xTicks, yTicks);
  if (leftArea == BigInt.zero || rightArea == BigInt.zero) {
    throw ArgumentError('Polygon overlap requires non-zero-area loops.');
  }

  for (var leftIndex = 0; leftIndex < left.length; leftIndex += 1) {
    final a = left[leftIndex];
    final b = left[(leftIndex + 1) % left.length];
    for (var rightIndex = 0; rightIndex < right.length; rightIndex += 1) {
      final c = right[rightIndex];
      final d = right[(rightIndex + 1) % right.length];
      if (_segmentsProperlyIntersect(a, b, c, d, xTicks, yTicks)) {
        return true;
      }
      if (_collinearSegmentsOverlap(a, b, c, d, xTicks, yTicks) &&
          _sharedBoundaryHasSameInteriorSide(
            a,
            b,
            c,
            d,
            leftArea,
            rightArea,
            xTicks,
            yTicks,
          )) {
        return true;
      }
    }
  }

  return left.any(
        (point) => _pointStrictlyInside(point, right, xTicks, yTicks),
      ) ||
      right.any((point) => _pointStrictlyInside(point, left, xTicks, yTicks));
}

bool _pointStrictlyInside<T>(
  T point,
  List<T> polygon,
  int Function(T point) xTicks,
  int Function(T point) yTicks,
) {
  if (_pointOnPolygonBoundary(point, polygon, xTicks, yTicks)) return false;
  var inside = false;
  for (var index = 0; index < polygon.length; index += 1) {
    final start = polygon[index];
    final end = polygon[(index + 1) % polygon.length];
    final pointY = yTicks(point);
    if ((yTicks(start) > pointY) == (yTicks(end) > pointY)) continue;

    // The horizontal ray crosses to the right exactly when cross/dy is
    // positive. Comparing signs avoids the division and its precision loss.
    final cross = _cross(start, end, point, xTicks, yTicks);
    final dy = yTicks(end) - yTicks(start);
    if ((cross.sign > 0) == (dy > 0)) inside = !inside;
  }
  return inside;
}

bool _pointOnPolygonBoundary<T>(
  T point,
  List<T> polygon,
  int Function(T point) xTicks,
  int Function(T point) yTicks,
) {
  for (var index = 0; index < polygon.length; index += 1) {
    if (_pointOnSegment(
      point,
      polygon[index],
      polygon[(index + 1) % polygon.length],
      xTicks,
      yTicks,
    )) {
      return true;
    }
  }
  return false;
}

bool _segmentsProperlyIntersect<T>(
  T a,
  T b,
  T c,
  T d,
  int Function(T point) xTicks,
  int Function(T point) yTicks,
) {
  final abC = _cross(a, b, c, xTicks, yTicks);
  final abD = _cross(a, b, d, xTicks, yTicks);
  final cdA = _cross(c, d, a, xTicks, yTicks);
  final cdB = _cross(c, d, b, xTicks, yTicks);
  return _oppositeSigns(abC, abD) && _oppositeSigns(cdA, cdB);
}

bool _collinearSegmentsOverlap<T>(
  T a,
  T b,
  T c,
  T d,
  int Function(T point) xTicks,
  int Function(T point) yTicks,
) {
  if (_cross(a, b, c, xTicks, yTicks) != BigInt.zero ||
      _cross(a, b, d, xTicks, yTicks) != BigInt.zero) {
    return false;
  }
  final abX = xTicks(b) - xTicks(a);
  final abY = yTicks(b) - yTicks(a);
  if (abX.abs() >= abY.abs()) {
    return math.max(
          math.min(xTicks(a), xTicks(b)),
          math.min(xTicks(c), xTicks(d)),
        ) <
        math.min(
          math.max(xTicks(a), xTicks(b)),
          math.max(xTicks(c), xTicks(d)),
        );
  }
  return math.max(
        math.min(yTicks(a), yTicks(b)),
        math.min(yTicks(c), yTicks(d)),
      ) <
      math.min(math.max(yTicks(a), yTicks(b)), math.max(yTicks(c), yTicks(d)));
}

bool _sharedBoundaryHasSameInteriorSide<T>(
  T a,
  T b,
  T c,
  T d,
  BigInt leftArea,
  BigInt rightArea,
  int Function(T point) xTicks,
  int Function(T point) yTicks,
) {
  final directionDot =
      BigInt.from(xTicks(b) - xTicks(a)) * BigInt.from(xTicks(d) - xTicks(c)) +
      BigInt.from(yTicks(b) - yTicks(a)) * BigInt.from(yTicks(d) - yTicks(c));
  final sameDirection = directionDot.sign > 0;
  final sameWinding = leftArea.sign == rightArea.sign;
  return sameDirection == sameWinding;
}

bool _pointOnSegment<T>(
  T point,
  T start,
  T end,
  int Function(T point) xTicks,
  int Function(T point) yTicks,
) =>
    _cross(start, end, point, xTicks, yTicks) == BigInt.zero &&
    xTicks(point) >= math.min(xTicks(start), xTicks(end)) &&
    xTicks(point) <= math.max(xTicks(start), xTicks(end)) &&
    yTicks(point) >= math.min(yTicks(start), yTicks(end)) &&
    yTicks(point) <= math.max(yTicks(start), yTicks(end));

BigInt _signedDoubledArea<T>(
  List<T> vertices,
  int Function(T point) xTicks,
  int Function(T point) yTicks,
) {
  var area = BigInt.zero;
  for (var index = 0; index < vertices.length; index += 1) {
    final current = vertices[index];
    final next = vertices[(index + 1) % vertices.length];
    area +=
        BigInt.from(xTicks(current)) * BigInt.from(yTicks(next)) -
        BigInt.from(xTicks(next)) * BigInt.from(yTicks(current));
  }
  return area;
}

BigInt _cross<T>(
  T origin,
  T a,
  T b,
  int Function(T point) xTicks,
  int Function(T point) yTicks,
) =>
    BigInt.from(xTicks(a) - xTicks(origin)) *
        BigInt.from(yTicks(b) - yTicks(origin)) -
    BigInt.from(yTicks(a) - yTicks(origin)) *
        BigInt.from(xTicks(b) - xTicks(origin));

bool _oppositeSigns(BigInt left, BigInt right) => left.sign * right.sign < 0;
