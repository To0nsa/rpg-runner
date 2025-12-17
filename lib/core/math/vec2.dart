/// Minimal 2D vector type used by the Core simulation.
///
/// This is intentionally kept small and dependency-free so `lib/core/**` can
/// stay pure Dart (no Flutter/Flame imports) and deterministic.
class Vec2 {
  const Vec2(this.x, this.y);

  /// X coordinate, in world units (virtual pixels).
  final double x;

  /// Y coordinate, in world units (virtual pixels).
  final double y;

  /// Returns a copy with a different X value.
  Vec2 withX(double value) => Vec2(value, y);

  /// Returns a copy with a different Y value.
  Vec2 withY(double value) => Vec2(x, value);

  /// Vector addition.
  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);

  /// Vector subtraction.
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);

  /// Scalar multiplication.
  Vec2 scale(double factor) => Vec2(x * factor, y * factor);
}
