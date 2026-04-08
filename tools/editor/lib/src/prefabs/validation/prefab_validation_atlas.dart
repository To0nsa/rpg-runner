part of 'prefab_validation.dart';

/// Validates prefab/tile atlas slices and builds id lookup indexes.
_SliceValidationIndex _validateAndIndexSlices({
  required List<PrefabValidationIssue> issues,
  required List<AtlasSliceDef> prefabSlices,
  required List<AtlasSliceDef> tileSlices,
  required Map<String, Size> atlasImageSizes,
}) {
  final prefabSliceIds = <String>{};
  final tileSliceIds = <String>{};
  final allSliceIds = <String>{};
  final prefabSliceById = <String, AtlasSliceDef>{};
  final tileSliceById = <String, AtlasSliceDef>{};

  for (final slice in prefabSlices) {
    _validateSlice(
      issues: issues,
      slice: slice,
      kindLabel: 'Prefab',
      knownSliceIds: prefabSliceIds,
      allSliceIds: allSliceIds,
      atlasImageSizes: atlasImageSizes,
    );
    if (slice.id.isNotEmpty && !prefabSliceById.containsKey(slice.id)) {
      prefabSliceById[slice.id] = slice;
    }
  }

  for (final slice in tileSlices) {
    _validateSlice(
      issues: issues,
      slice: slice,
      kindLabel: 'Tile',
      knownSliceIds: tileSliceIds,
      allSliceIds: allSliceIds,
      atlasImageSizes: atlasImageSizes,
    );
    if (slice.id.isNotEmpty && !tileSliceById.containsKey(slice.id)) {
      tileSliceById[slice.id] = slice;
    }
  }

  return _SliceValidationIndex(
    prefabSliceIds: prefabSliceIds,
    tileSliceIds: tileSliceIds,
    prefabSliceById: prefabSliceById,
    tileSliceById: tileSliceById,
  );
}

/// Validates one slice definition, including atlas image bounds.
void _validateSlice({
  required List<PrefabValidationIssue> issues,
  required AtlasSliceDef slice,
  required String kindLabel,
  required Set<String> knownSliceIds,
  required Set<String> allSliceIds,
  required Map<String, Size> atlasImageSizes,
}) {
  final kindCodePrefix = kindLabel.toLowerCase();
  if (slice.id.isEmpty) {
    issues.add(
      PrefabValidationIssue(
        code: '${kindCodePrefix}_slice_id_missing',
        message: '$kindLabel slice with empty id.',
      ),
    );
  } else if (!knownSliceIds.add(slice.id)) {
    issues.add(
      PrefabValidationIssue(
        code: '${kindCodePrefix}_slice_id_duplicate',
        message: 'Duplicate ${kindLabel.toLowerCase()} slice id: ${slice.id}',
      ),
    );
  }

  if (slice.id.isNotEmpty && !allSliceIds.add(slice.id)) {
    issues.add(
      PrefabValidationIssue(
        code: 'slice_id_reused_between_prefab_and_tile',
        message: 'Slice id reused across prefab/tile slices: ${slice.id}',
      ),
    );
  }
  if (slice.sourceImagePath.isEmpty) {
    issues.add(
      PrefabValidationIssue(
        code: '${kindCodePrefix}_slice_source_missing',
        message: '$kindLabel slice ${slice.id} has empty sourceImagePath.',
      ),
    );
  }
  if (slice.width <= 0 || slice.height <= 0) {
    issues.add(
      PrefabValidationIssue(
        code: '${kindCodePrefix}_slice_size_invalid',
        message: '$kindLabel slice ${slice.id} has non-positive size.',
      ),
    );
  }
  if (slice.x < 0 || slice.y < 0) {
    issues.add(
      PrefabValidationIssue(
        code: '${kindCodePrefix}_slice_origin_invalid',
        message: '$kindLabel slice ${slice.id} has negative origin.',
      ),
    );
  }

  final atlasSize = atlasImageSizes[slice.sourceImagePath];
  if (slice.sourceImagePath.isNotEmpty && atlasSize == null) {
    issues.add(
      PrefabValidationIssue(
        code: '${kindCodePrefix}_slice_atlas_missing',
        message:
            '$kindLabel slice ${slice.id} references missing atlas image '
            '${slice.sourceImagePath}.',
      ),
    );
    return;
  }
  if (atlasSize == null) {
    return;
  }

  final atlasWidth = atlasSize.width.toInt();
  final atlasHeight = atlasSize.height.toInt();
  final right = slice.x + slice.width;
  final bottom = slice.y + slice.height;
  if (right > atlasWidth || bottom > atlasHeight) {
    issues.add(
      PrefabValidationIssue(
        code: '${kindCodePrefix}_slice_out_of_bounds',
        message:
            '$kindLabel slice ${slice.id} exceeds atlas bounds for '
            '${slice.sourceImagePath} (${atlasWidth}x$atlasHeight).',
      ),
    );
  }
}
