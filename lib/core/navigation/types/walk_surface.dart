/// Represents a horizontal walkable platform segment in world space.
///
/// **Geometry**:
/// - A 1D segment along the X-axis at a fixed Y height ([yTop]).
/// - Defined by [[xMin], [xMax]] (inclusive bounds).
///
/// **Usage**:
/// - Used by the navigation system to represent ground/platforms.
/// - Entities can stand on this surface if their X is within [xMin, xMax].
class WalkSurface {
  const WalkSurface({
    required this.id,
    required this.xMin,
    required this.xMax,
    required this.yTop,
  }) : assert(xMax >= xMin);

  /// Unique identifier (packed via [packSurfaceId]).
  final int id;

  /// Left edge of the walkable segment (inclusive).
  final double xMin;
  
  /// Right edge of the walkable segment (inclusive).
  final double xMax;

  /// World-space Y coordinate of the top surface (where entities stand).
  final double yTop;

  /// Horizontal center of the surface.
  double get centerX => (xMin + xMax) * 0.5;
  
  /// Width of the walkable segment.
  double get width => xMax - xMin;
}

