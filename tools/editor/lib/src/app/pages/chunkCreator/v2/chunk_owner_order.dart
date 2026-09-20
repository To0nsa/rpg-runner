import '../../../../chunks/chunk_v2_file_data.dart';

/// Stable owner ordering shared by Chunk headers, catalogs, and commands.
int compareChunkOwners(ChunkV2FileData left, ChunkV2FileData right) {
  return left.chunkKey.compareTo(right.chunkKey);
}

/// Applies the Chunk Creator catalog filters in its canonical owner order.
///
/// Keeping this projection outside the widget makes Play capture the exact
/// same owner set that the author can see in the catalog.
List<ChunkV2FileData> filterChunkOwners(
  Iterable<ChunkV2FileData> chunks, {
  String search = '',
  String difficulty = '',
  String group = '',
}) {
  final query = search.trim().toLowerCase();
  final matches =
      chunks
          .where(
            (chunk) =>
                (query.isEmpty ||
                    chunk.chunkKey.toLowerCase().contains(query)) &&
                (difficulty.isEmpty || chunk.difficulty == difficulty) &&
                (group.isEmpty || chunk.assemblyGroupId == group),
          )
          .toList(growable: false)
        ..sort(compareChunkOwners);
  return List<ChunkV2FileData>.unmodifiable(matches);
}
