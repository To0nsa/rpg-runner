/// Renderer-facing snapshot for one piece of static collision geometry.
///
/// This is a read-only view for rendering/debug overlays. Authoritative
/// collision still lives in Core using `StaticWorldGeometry`.
class StaticSolidSnapshot {
  const StaticSolidSnapshot({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    required this.sides,
    required this.oneWayTop,
  });

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  /// Bitmask of enabled faces.
  final int sides;

  /// Whether the top face behaves as one-way (platform).
  final bool oneWayTop;
}

