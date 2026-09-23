import 'capsule_hit_utils.dart';

/// Conservative continuous envelope between two capsule spine poses.
/// The four endpoint convex hull, expanded by the larger radius, covers a
/// translating/rotating blade. Degenerate poses use ordinary capsule distance.
bool capsulePoseSweepOverlaps({
  required double ax,
  required double ay,
  required double bx,
  required double by,
  required double previousAx,
  required double previousAy,
  required double previousBx,
  required double previousBy,
  required double radius,
  required double targetAx,
  required double targetAy,
  required double targetBx,
  required double targetBy,
  required double targetRadius,
}) {
  final points = [
    (ax, ay),
    (bx, by),
    (previousAx, previousAy),
    (previousBx, previousBy),
  ];
  // All triangles of four points form their convex hull even when a changing
  // blade orientation reverses endpoint winding.
  for (var i = 0; i < 4; i++) {
    for (var j = i + 1; j < 4; j++) {
      final a = points[i], b = points[j];
      if (capsulesOverlap(
        firstAx: a.$1,
        firstAy: a.$2,
        firstBx: b.$1,
        firstBy: b.$2,
        firstRadius: radius,
        secondAx: targetAx,
        secondAy: targetAy,
        secondBx: targetBx,
        secondBy: targetBy,
        secondRadius: targetRadius,
      )) {
        return true;
      }
      for (var k = j + 1; k < 4; k++) {
        final c = points[k];
        if (_inside(targetAx, targetAy, a, b, c) ||
            _inside(targetBx, targetBy, a, b, c)) {
          return true;
        }
      }
    }
  }
  return false;
}

bool _inside(
  double x,
  double y,
  (double, double) a,
  (double, double) b,
  (double, double) c,
) {
  final area = (b.$1 - a.$1) * (c.$2 - a.$2) - (b.$2 - a.$2) * (c.$1 - a.$1);
  if (area.abs() < 1e-12) return false;
  double side((double, double) p, (double, double) q) =>
      (q.$1 - p.$1) * (y - p.$2) - (q.$2 - p.$2) * (x - p.$1);
  final ab = side(a, b), bc = side(b, c), ca = side(c, a);
  return area > 0
      ? ab >= 0 && bc >= 0 && ca >= 0
      : ab <= 0 && bc <= 0 && ca <= 0;
}
