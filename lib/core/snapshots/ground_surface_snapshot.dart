/// Renderer-facing snapshot for one walkable ground surface span.
///
/// This is a read-only projection of Core-authored geometry. The authoritative
/// collision model remains in `StaticWorldGeometryIndex`.
class GroundSurfaceSnapshot {
  const GroundSurfaceSnapshot({
    required this.minX,
    required this.maxX,
    required this.topY,
    required this.chunkIndex,
    required this.localSegmentIndex,
  }) : assert(maxX >= minX);

  /// Left world-space bound of the walkable span.
  final double minX;

  /// Right world-space bound of the walkable span.
  final double maxX;

  /// World-space Y of the walkable top surface.
  final double topY;

  /// Owning streamed chunk index, or `StaticSolid.groundChunk` for base ground.
  final int chunkIndex;

  /// Stable local index within the source chunk/list.
  final int localSegmentIndex;
}
