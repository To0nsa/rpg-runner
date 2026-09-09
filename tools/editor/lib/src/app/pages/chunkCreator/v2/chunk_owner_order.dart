import '../../../../chunks/chunk_v2_file_data.dart';

/// Stable owner ordering shared by Chunk headers, catalogs, and commands.
int compareChunkOwners(ChunkV2FileData left, ChunkV2FileData right) {
  return left.chunkKey.compareTo(right.chunkKey);
}
