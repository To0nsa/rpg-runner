import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/terrain/water_region.dart';

import 'chunk_v2_file_data.dart';

/// Allocates the first unused local water identity for either creation workflow.
String nextChunkWaterId(Iterable<WaterRegionData> regions) {
  final ids = regions.map((region) => region.id).toSet();
  var ordinal = 1;
  while (ids.contains('water_$ordinal')) {
    ordinal++;
  }
  return 'water_$ordinal';
}

/// Uses the runtime source codec for both draft feedback and commit admission.
String? chunkWaterValidationMessage(
  ChunkV2FileData chunk,
  Iterable<WaterRegionData> regions,
) {
  final ordered = regions.toList()..sort((a, b) => a.id.compareTo(b.id));
  try {
    decodeWaterRegions(
      ordered.map((region) => region.toJson()).toList(),
      sourcePath: '${chunk.chunkKey}.waterRegions',
      chunkWidth: chunk.width,
      chunkHeight: chunk.height,
    );
    return null;
  } on FormatException catch (error) {
    return error.message.toString();
  }
}

/// One stale-checked water edit; plugin validation owns publication and Save.
final class ChunkWaterCommit {
  ChunkWaterCommit({
    required this.expectedRevision,
    required Iterable<WaterRegionData> regions,
  }) : regions = List<WaterRegionData>.unmodifiable(regions);

  final int expectedRevision;
  final List<WaterRegionData> regions;

  /// Rejects stale, malformed and no-op edits without advancing the revision.
  ChunkV2FileData apply(ChunkV2FileData chunk) {
    if (chunk.revision != expectedRevision) return chunk;
    final ordered = regions.toList()..sort((a, b) => a.id.compareTo(b.id));
    if (chunkWaterValidationMessage(chunk, ordered) != null) {
      return chunk;
    }
    if (ordered.length == chunk.waterRegions.length &&
        List.generate(
          ordered.length,
          (i) => ordered[i] == chunk.waterRegions[i],
        ).every((equal) => equal)) {
      return chunk;
    }
    return chunk.copyWith(revision: chunk.revision + 1, waterRegions: ordered);
  }
}
