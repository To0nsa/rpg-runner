/// Minimal 2D vector type for Core ↔ UI data transfer.
///
/// Immutable, allocation-light, pure Dart. Used in snapshots and events.
/// Internal systems prefer raw `double` fields for hot loops.
library;

/// Immutable 2D vector with [x] and [y] coordinates.
class Vec2 {
  /// Creates a new immutable vector at ([x], [y]).
  const Vec2(this.x, this.y);

  /// Zero vector (0, 0).
  static const Vec2 zero = Vec2(0, 0);

  /// X coordinate (Horizontal), usually in world units/pixels.
  final double x;

  /// Y coordinate (Vertical), usually in world units/pixels.
  final double y;

  /// Returns a new [Vec2] with [x] replaced by [value].
  Vec2 withX(double value) => Vec2(value, y);

  /// Returns a new [Vec2] with [y] replaced by [value].
  Vec2 withY(double value) => Vec2(x, value);

  /// Component-wise Addition.
  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);

  /// Component-wise Subtraction.
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);

  /// Scalar Multiplication.
  Vec2 scale(double factor) => Vec2(x * factor, y * factor);

  @override
  String toString() => 'Vec2(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vec2 &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}
