import 'dart:math' as math;

/// Whether an angle is a finite, canonical clockwise degree value in [0, 360).
bool isCanonicalPrefabRotationDegrees(double value) =>
    value.isFinite && value >= 0 && value < 360;

/// Wraps finite author input to [0, 360); whole turns become zero.
double normalizePrefabRotationDegrees(double value) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', 'Must be finite.');
  }
  return value % 360;
}

/// Strict optional-placement decoder; callers supply zero when the key is absent.
/// Explicit null, nonnumeric, nonfinite and noncanonical values fail closed.
double decodePrefabRotationDegrees(
  Object? value, {
  required String sourcePath,
}) {
  if (value is! num || !isCanonicalPrefabRotationDegrees(value.toDouble())) {
    throw FormatException('$sourcePath must be a finite number in [0, 360).');
  }
  return value.toDouble();
}

/// Rotation never changes physics, so only collision-free decorations admit it.
bool prefabSupportsCenterRotation({
  required String kind,
  required int collisionShapeCount,
}) => kind == 'decoration' && collisionShapeCount == 0;

/// Rotates a visual point clockwise in Y-down pixel space about a fixed center.
/// This floating-point projection is render-only and never enters terrain math.
({double x, double y}) rotatePrefabVisualPoint({
  required double x,
  required double y,
  required double centerX,
  required double centerY,
  required double degrees,
}) {
  if (degrees == 0) return (x: x, y: y);
  final radians = degrees * math.pi / 180;
  final cos = math.cos(radians), sin = math.sin(radians);
  final dx = x - centerX, dy = y - centerY;
  return (x: centerX + dx * cos - dy * sin, y: centerY + dx * sin + dy * cos);
}
