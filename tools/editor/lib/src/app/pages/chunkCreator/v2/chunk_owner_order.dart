import '../../../../chunks/chunk_v2_file_data.dart';

/// Stable owner ordering shared by Chunk headers, catalogs, and commands.
int compareChunkOwners(ChunkV2FileData left, ChunkV2FileData right) {
  final idOrder = left.id.compareTo(right.id);
  return idOrder != 0 ? idOrder : left.chunkKey.compareTo(right.chunkKey);
}
