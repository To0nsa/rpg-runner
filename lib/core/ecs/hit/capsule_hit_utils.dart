import 'dart:math' as math;

const double _segmentEps = 1e-12;

bool capsuleIntersectsAabb({
  required double ax,
  required double ay,
  required double bx,
  required double by,
  required double radius,
  required double minX,
  required double minY,
  required double maxX,
  required double maxY,
}) {
  final r = radius < 0 ? 0.0 : radius;
  return _segmentIntersectsAabb(
    ax: ax,
    ay: ay,
    bx: bx,
    by: by,
    minX: minX - r,
    minY: minY - r,
    maxX: maxX + r,
    maxY: maxY + r,
  );
}

bool _segmentIntersectsAabb({
  required double ax,
  required double ay,
  required double bx,
  required double by,
  required double minX,
  required double minY,
  required double maxX,
  required double maxY,
}) {
  final dx = bx - ax;
  final dy = by - ay;
  var t0 = 0.0;
  var t1 = 1.0;

  if (dx.abs() < _segmentEps) {
    if (ax < minX || ax > maxX) return false;
  } else {
    final inv = 1.0 / dx;
    var tNear = (minX - ax) * inv;
    var tFar = (maxX - ax) * inv;
    if (tNear > tFar) {
      final tmp = tNear;
      tNear = tFar;
      tFar = tmp;
    }
    t0 = math.max(t0, tNear);
    t1 = math.min(t1, tFar);
    if (t0 > t1) return false;
  }

  if (dy.abs() < _segmentEps) {
    if (ay < minY || ay > maxY) return false;
  } else {
    final inv = 1.0 / dy;
    var tNear = (minY - ay) * inv;
    var tFar = (maxY - ay) * inv;
    if (tNear > tFar) {
      final tmp = tNear;
      tNear = tFar;
      tFar = tmp;
    }
    t0 = math.max(t0, tNear);
    t1 = math.min(t1, tFar);
    if (t0 > t1) return false;
  }

  return true;
}
