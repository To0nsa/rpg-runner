/// Renderer-facing snapshot for a gap in the ground band.
///
/// This is a read-only view for rendering/debug overlays. Authoritative
/// collision still lives in Core using `StaticWorldGeometry`.
class StaticGroundGapSnapshot {
  const StaticGroundGapSnapshot({
    required this.minX,
    required this.maxX,
  });

  final double minX;
  final double maxX;
}
