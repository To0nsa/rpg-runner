import 'dart:math' as math;

import 'capsule_hit_utils.dart';

/// First contact fraction for a translating capsule against a fixed capsule.
///
/// The moving spine retains its orientation over this tick. Initial overlap
/// returns zero; exact tangency counts. Endpoint/segment contacts cover every
/// boundary of the segments' Minkowski difference without temporal sampling.
double? capsuleSweepFirstContact({
  required double ax,
  required double ay,
  required double bx,
  required double by,
  required double radius,
  required double deltaX,
  required double deltaY,
  required double targetAx,
  required double targetAy,
  required double targetBx,
  required double targetBy,
  required double targetRadius,
}) {
  if (capsulesOverlap(
    firstAx: ax,
    firstAy: ay,
    firstBx: bx,
    firstBy: by,
    firstRadius: radius,
    secondAx: targetAx,
    secondAy: targetAy,
    secondBx: targetBx,
    secondBy: targetBy,
    secondRadius: targetRadius,
  )) {
    return 0;
  }
  final sumRadius = math.max(0.0, radius) + math.max(0.0, targetRadius);
  double? first;
  void accept(double? t) {
    if (t != null && (first == null || t < first!)) first = t;
  }

  accept(
    _pointAgainstCapsule(
      ax,
      ay,
      deltaX,
      deltaY,
      targetAx,
      targetAy,
      targetBx,
      targetBy,
      sumRadius,
    ),
  );
  accept(
    _pointAgainstCapsule(
      bx,
      by,
      deltaX,
      deltaY,
      targetAx,
      targetAy,
      targetBx,
      targetBy,
      sumRadius,
    ),
  );
  accept(
    _pointAgainstCapsule(
      targetAx,
      targetAy,
      -deltaX,
      -deltaY,
      ax,
      ay,
      bx,
      by,
      sumRadius,
    ),
  );
  accept(
    _pointAgainstCapsule(
      targetBx,
      targetBy,
      -deltaX,
      -deltaY,
      ax,
      ay,
      bx,
      by,
      sumRadius,
    ),
  );
  return first;
}

double? _pointAgainstCapsule(
  double x,
  double y,
  double dx,
  double dy,
  double ax,
  double ay,
  double bx,
  double by,
  double radius,
) {
  var first = _pointAgainstCircle(x, y, dx, dy, ax, ay, radius);
  final end = _pointAgainstCircle(x, y, dx, dy, bx, by, radius);
  if (end != null && (first == null || end < first)) first = end;
  final sx = bx - ax, sy = by - ay;
  final length = math.sqrt(sx * sx + sy * sy);
  if (length <= 1e-12) return first;
  final ux = sx / length, uy = sy / length;
  final perpendicular = (x - ax) * -uy + (y - ay) * ux;
  final speed = dx * -uy + dy * ux;
  if (speed.abs() <= 1e-12) return first;
  for (final side in const [-1.0, 1.0]) {
    final t = (side * radius - perpendicular) / speed;
    if (t < 0 || t > 1 || (first != null && t >= first)) continue;
    final along = (x + t * dx - ax) * ux + (y + t * dy - ay) * uy;
    if (along >= 0 && along <= length) first = t;
  }
  return first;
}

double? _pointAgainstCircle(
  double x,
  double y,
  double dx,
  double dy,
  double cx,
  double cy,
  double radius,
) {
  final ox = x - cx, oy = y - cy;
  final c = ox * ox + oy * oy - radius * radius;
  if (c <= 0) return 0;
  final a = dx * dx + dy * dy;
  if (a <= 1e-24) return null;
  final b = ox * dx + oy * dy;
  final discriminant = b * b - a * c;
  if (discriminant < 0) return null;
  final t = (-b - math.sqrt(discriminant)) / a;
  return t >= 0 && t <= 1 ? t : null;
}
