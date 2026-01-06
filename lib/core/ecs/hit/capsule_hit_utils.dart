import 'dart:math' as math;

const double _segmentEps = 1e-12;

/// Checks if a capsule (line segment + radius) intersects an Axis-Aligned Bounding Box (AABB).
///
/// The capsule is defined by start point ([ax], [ay]), end point ([bx], [by]),
/// and [radius]. The AABB is defined by min/max coordinates.
///
/// This works by padding the AABB by the capsule radius and performing a segment-to-box
/// intersection test.
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
  // Expanding the AABB by the radius allows us to treat the capsule as a simple
  // line segment against the larger box.
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

/// Core segment-AABB intersection test using slab method logic.
///
/// Checks if the line segment from A to B intersects the given AABB.
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

  // --- X-axis slab test ---
  if (dx.abs() < _segmentEps) {
    // Segment is parallel to Y-axis. If X is outside, no intersection.
    if (ax < minX || ax > maxX) return false;
  } else {
    // Compute intersection times (t) with X-planes.
    final inv = 1.0 / dx;
    var tNear = (minX - ax) * inv;
    var tFar = (maxX - ax) * inv;
    if (tNear > tFar) {
      final tmp = tNear;
      tNear = tFar;
      tFar = tmp;
    }
    // Narrow the valid segment range [t0, t1].
    t0 = math.max(t0, tNear);
    t1 = math.min(t1, tFar);
    // If range becomes invalid, segment missed.
    if (t0 > t1) return false;
  }

  // --- Y-axis slab test ---
  if (dy.abs() < _segmentEps) {
    // Segment is parallel to X-axis. If Y is outside, no intersection.
    if (ay < minY || ay > maxY) return false;
  } else {
    // Compute intersection times (t) with Y-planes.
    final inv = 1.0 / dy;
    var tNear = (minY - ay) * inv;
    var tFar = (maxY - ay) * inv;
    if (tNear > tFar) {
      final tmp = tNear;
      tNear = tFar;
      tFar = tmp;
    }
    // Further narrow the valid segment range.
    t0 = math.max(t0, tNear);
    t1 = math.min(t1, tFar);
    // If range becomes invalid, segment missed.
    if (t0 > t1) return false;
  }

  // Intersection confirmed if we survived both slab tests.
  return true;
}
