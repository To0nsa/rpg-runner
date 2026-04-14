import '../types/nav_tolerances.dart';

/// Full-footprint support requirement: the surface must fit the whole collider.
const double navFullSupportFraction = 1.0;

/// Ground enemies may use surfaces that support at least one third of their body.
const double groundEnemySupportFraction = 1.0 / 3.0;

typedef StandableCenterRange = ({double minX, double maxX});

/// Required supported width on a surface for a collider with [halfWidth].
double supportWidthForHalfWidth(
  double halfWidth, {
  double supportFraction = navFullSupportFraction,
}) {
  assert(halfWidth >= 0.0);
  assert(supportFraction > 0.0 && supportFraction <= 1.0);
  return halfWidth * 2.0 * supportFraction;
}

/// Computes the center-X range where a collider can remain supported.
///
/// The entity may overhang the ledge as long as at least [supportFraction] of
/// its full collider width remains supported by the surface.
StandableCenterRange? computeStandableCenterRange({
  required double surfaceMinX,
  required double surfaceMaxX,
  required double halfWidth,
  double supportFraction = navFullSupportFraction,
  double eps = navSpatialEps,
}) {
  assert(surfaceMaxX >= surfaceMinX);
  final requiredSupportWidth = supportWidthForHalfWidth(
    halfWidth,
    supportFraction: supportFraction,
  );
  final surfaceWidth = surfaceMaxX - surfaceMinX;
  if (surfaceWidth + eps < requiredSupportWidth) {
    return null;
  }

  final minX = surfaceMinX + requiredSupportWidth - halfWidth - eps;
  final maxX = surfaceMaxX - requiredSupportWidth + halfWidth + eps;
  if (minX > maxX + eps) {
    return null;
  }
  return (minX: minX, maxX: maxX);
}

/// Returns whether a collider center at [x] is sufficiently supported.
bool isStandableAtX({
  required double x,
  required double surfaceMinX,
  required double surfaceMaxX,
  required double halfWidth,
  double supportFraction = navFullSupportFraction,
  double eps = navSpatialEps,
}) {
  final range = computeStandableCenterRange(
    surfaceMinX: surfaceMinX,
    surfaceMaxX: surfaceMaxX,
    halfWidth: halfWidth,
    supportFraction: supportFraction,
    eps: eps,
  );
  if (range == null) {
    return false;
  }
  return x >= range.minX - eps && x <= range.maxX + eps;
}
