import '../track/chunk_pattern_source.dart';

/// One run-local section occurrence, independent of repeated source/group IDs.
///
/// Bounds use world units and the owning chunk's width. Automatic levels and
/// standalone chunk play have no assembly and retain a one-chunk territory.
final class NpcGuardRegion {
  NpcGuardRegion.forChunk({
    required int chunkIndex,
    required double startX,
    required double endX,
    ChunkAssemblySelection? assembly,
  }) : firstChunkIndex = assembly?.startChunkIndex ?? chunkIndex,
       chunkCount = assembly?.chunkCount ?? 1,
       minX =
           startX -
           (chunkIndex - (assembly?.startChunkIndex ?? chunkIndex)) *
               (endX - startX),
       maxX =
           startX +
           ((assembly?.startChunkIndex ?? chunkIndex) +
                   (assembly?.chunkCount ?? 1) -
                   chunkIndex) *
               (endX - startX) {
    if (firstChunkIndex < 0 ||
        chunkCount <= 0 ||
        chunkIndex < firstChunkIndex ||
        chunkIndex >= firstChunkIndex + chunkCount ||
        !startX.isFinite ||
        !endX.isFinite ||
        startX >= endX ||
        !minX.isFinite ||
        !maxX.isFinite ||
        minX >= maxX) {
      throw ArgumentError('Guard region must contain its owning chunk.');
    }
  }

  final int firstChunkIndex;
  final int chunkCount;
  final double minX;
  final double maxX;

  /// Membership uses body-center X with an exclusive right boundary.
  bool contains(double bodyX) => bodyX >= minX && bodyX < maxX;
}
