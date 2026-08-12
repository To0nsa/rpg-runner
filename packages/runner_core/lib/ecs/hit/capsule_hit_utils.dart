import 'dart:math' as math;

const double _degenerateSegmentLengthSquared = 1e-24;

/// Returns whether two finite-segment capsules overlap or touch.
///
/// Coordinates and radii use world units. A zero-length segment represents a
/// circle. The calculation is allocation-free and treats exact tangency as a
/// hit so all combat delivery paths share one boundary rule.
bool capsulesOverlap({
  required double firstAx,
  required double firstAy,
  required double firstBx,
  required double firstBy,
  required double firstRadius,
  required double secondAx,
  required double secondAy,
  required double secondBx,
  required double secondBy,
  required double secondRadius,
}) {
  final radiusSum = math.max(0.0, firstRadius) + math.max(0.0, secondRadius);
  return segmentDistanceSquared(
        firstAx: firstAx,
        firstAy: firstAy,
        firstBx: firstBx,
        firstBy: firstBy,
        secondAx: secondAx,
        secondAy: secondAy,
        secondBx: secondBx,
        secondBy: secondBy,
      ) <=
      radiusSum * radiusSum;
}

/// Returns the squared minimum distance between two finite segments.
///
/// Coordinates use world units. Degenerate point/segment and point/point cases
/// are handled explicitly, and no temporary geometry objects are allocated.
double segmentDistanceSquared({
  required double firstAx,
  required double firstAy,
  required double firstBx,
  required double firstBy,
  required double secondAx,
  required double secondAy,
  required double secondBx,
  required double secondBy,
}) {
  final firstDx = firstBx - firstAx;
  final firstDy = firstBy - firstAy;
  final secondDx = secondBx - secondAx;
  final secondDy = secondBy - secondAy;
  final originDx = firstAx - secondAx;
  final originDy = firstAy - secondAy;

  final firstLengthSquared = firstDx * firstDx + firstDy * firstDy;
  final secondLengthSquared = secondDx * secondDx + secondDy * secondDy;
  final secondOriginDot = secondDx * originDx + secondDy * originDy;

  double firstT;
  double secondT;
  if (firstLengthSquared <= _degenerateSegmentLengthSquared &&
      secondLengthSquared <= _degenerateSegmentLengthSquared) {
    return originDx * originDx + originDy * originDy;
  }

  if (firstLengthSquared <= _degenerateSegmentLengthSquared) {
    firstT = 0.0;
    secondT = (secondOriginDot / secondLengthSquared).clamp(0.0, 1.0);
  } else {
    final firstOriginDot = firstDx * originDx + firstDy * originDy;
    if (secondLengthSquared <= _degenerateSegmentLengthSquared) {
      secondT = 0.0;
      firstT = (-firstOriginDot / firstLengthSquared).clamp(0.0, 1.0);
    } else {
      final directionsDot = firstDx * secondDx + firstDy * secondDy;
      final denominator =
          firstLengthSquared * secondLengthSquared -
          directionsDot * directionsDot;
      firstT = denominator.abs() > _degenerateSegmentLengthSquared
          ? ((directionsDot * secondOriginDot -
                        firstOriginDot * secondLengthSquared) /
                    denominator)
                .clamp(0.0, 1.0)
          : 0.0;
      secondT =
          (directionsDot * firstT + secondOriginDot) / secondLengthSquared;

      if (secondT < 0.0) {
        secondT = 0.0;
        firstT = (-firstOriginDot / firstLengthSquared).clamp(0.0, 1.0);
      } else if (secondT > 1.0) {
        secondT = 1.0;
        firstT = ((directionsDot - firstOriginDot) / firstLengthSquared).clamp(
          0.0,
          1.0,
        );
      }
    }
  }

  final separationX = originDx + firstDx * firstT - secondDx * secondT;
  final separationY = originDy + firstDy * firstT - secondDy * secondT;
  return separationX * separationX + separationY * separationY;
}
