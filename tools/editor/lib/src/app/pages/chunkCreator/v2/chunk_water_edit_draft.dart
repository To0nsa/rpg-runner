import 'package:runner_core/terrain/water_region.dart';

import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_water_commit.dart';
import '../../../../terrain_authoring/terrain_axis_aligned_rectangle.dart';

/// Inline water metadata stays bound to the selected source revision while the
/// shared rectangle editor owns coordinate text. One commit accepts both.
final class ChunkWaterEditDraft {
  ChunkWaterEditDraft(this.chunk, this.source)
    : nameInput = source.id,
      materialKey = source.materialKey;

  final ChunkV2FileData chunk;
  final WaterRegionData source;
  String nameInput;
  String materialKey;
  String? error;

  bool get hasMetadataChanges =>
      nameInput.trim() != source.id || materialKey != source.materialKey;

  String? get nameError => chunkWaterNameError(
    nameInput,
    chunk.waterRegions,
    excludingId: source.id,
  );

  /// Rectangle controls use half-pixel ticks; water admits only whole pixels.
  ChunkWaterCommit? buildCommit({
    required int xHalfPixels,
    required int bottomYHalfPixels,
    required int widthHalfPixels,
    required int heightHalfPixels,
  }) {
    error = nameError;
    if (error != null) return null;
    if ([
      xHalfPixels,
      bottomYHalfPixels,
      widthHalfPixels,
      heightHalfPixels,
    ].any((value) => value.isOdd)) {
      error = 'Use whole-pixel rectangle dimensions.';
      return null;
    }
    try {
      final candidate = WaterRegionData(
        id: nameInput.trim(),
        x: xHalfPixels ~/ 2,
        y: (bottomYHalfPixels - heightHalfPixels) ~/ 2,
        width: widthHalfPixels ~/ 2,
        height: heightHalfPixels ~/ 2,
        materialKey: materialKey,
      );
      final regions = [
        for (final region in chunk.waterRegions)
          if (region.id != source.id) region,
        candidate,
      ];
      error = chunkWaterValidationMessage(chunk, regions);
      if (error != null) return null;
      return ChunkWaterCommit(
        expectedRevision: chunk.revision,
        regions: regions,
      );
    } on ArgumentError {
      error = 'Keep a positive water rectangle inside the chunk.';
      return null;
    }
  }

  void discard() {
    nameInput = source.id;
    materialKey = source.materialKey;
    error = null;
  }
}

/// Read-only adapter into the same dimension controls used by solid rectangles.
TerrainAxisAlignedRectangle waterAuthoringRectangle(WaterRegionData region) =>
    TerrainAxisAlignedRectangle.tryCreate(
      xHalfPixels: region.x * 2,
      yHalfPixels: region.y * 2,
      widthHalfPixels: region.width * 2,
      heightHalfPixels: region.height * 2,
    )!;
