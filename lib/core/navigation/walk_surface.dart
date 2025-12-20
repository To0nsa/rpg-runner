class WalkSurface {
  const WalkSurface({
    required this.id,
    required this.xMin,
    required this.xMax,
    required this.yTop,
  }) : assert(xMax >= xMin);

  /// Packed surface id (see `surface_id.dart`).
  final int id;

  /// Inclusive horizontal bounds for the walkable top segment.
  final double xMin;
  final double xMax;

  /// World-space Y coordinate of the top surface.
  final double yTop;

  double get centerX => (xMin + xMax) * 0.5;
}

