import 'dart:ui' show Size;

import 'prefab_models.dart';

List<String> validatePrefabData({
  required PrefabData data,
  required Map<String, Size> atlasImageSizes,
}) {
  final errors = <String>[];
  final prefabSliceIds = <String>{};
  final tileSliceIds = <String>{};
  final allSliceIds = <String>{};

  for (final slice in data.prefabSlices) {
    _validateSlice(
      errors: errors,
      slice: slice,
      kindLabel: 'Prefab',
      knownSliceIds: prefabSliceIds,
      allSliceIds: allSliceIds,
      atlasImageSizes: atlasImageSizes,
    );
  }

  for (final slice in data.tileSlices) {
    _validateSlice(
      errors: errors,
      slice: slice,
      kindLabel: 'Tile',
      knownSliceIds: tileSliceIds,
      allSliceIds: allSliceIds,
      atlasImageSizes: atlasImageSizes,
    );
  }

  final prefabIds = <String>{};
  for (final prefab in data.prefabs) {
    if (prefab.id.isEmpty) {
      errors.add('Prefab with empty id.');
    } else if (!prefabIds.add(prefab.id)) {
      errors.add('Duplicate prefab id: ${prefab.id}');
    }
    if (!prefabSliceIds.contains(prefab.sliceId)) {
      errors.add(
        'Prefab ${prefab.id} references missing prefab slice ${prefab.sliceId}.',
      );
    }
    if (prefab.colliders.isEmpty) {
      errors.add('Prefab ${prefab.id} must include at least one collider.');
    }
    for (final collider in prefab.colliders) {
      if (collider.width <= 0 || collider.height <= 0) {
        errors.add('Prefab ${prefab.id} has collider with non-positive size.');
      }
    }
  }

  final moduleIds = <String>{};
  for (final module in data.platformModules) {
    if (module.id.isEmpty) {
      errors.add('Platform module with empty id.');
    } else if (!moduleIds.add(module.id)) {
      errors.add('Duplicate platform module id: ${module.id}');
    }
    if (module.tileSize <= 0) {
      errors.add('Platform module ${module.id} has non-positive tileSize.');
    }
    final cellKeys = <String>{};
    for (final cell in module.cells) {
      if (!tileSliceIds.contains(cell.sliceId)) {
        errors.add(
          'Platform module ${module.id} references missing tile slice ${cell.sliceId}.',
        );
      }
      final cellKey = '${cell.gridX}:${cell.gridY}';
      if (!cellKeys.add(cellKey)) {
        errors.add(
          'Platform module ${module.id} has duplicate cell at ($cellKey).',
        );
      }
    }
  }

  return errors;
}

void _validateSlice({
  required List<String> errors,
  required AtlasSliceDef slice,
  required String kindLabel,
  required Set<String> knownSliceIds,
  required Set<String> allSliceIds,
  required Map<String, Size> atlasImageSizes,
}) {
  if (slice.id.isEmpty) {
    errors.add('$kindLabel slice with empty id.');
  } else if (!knownSliceIds.add(slice.id)) {
    errors.add('Duplicate ${kindLabel.toLowerCase()} slice id: ${slice.id}');
  }
  if (!allSliceIds.add(slice.id)) {
    errors.add('Slice id reused across prefab/tile slices: ${slice.id}');
  }
  if (slice.sourceImagePath.isEmpty) {
    errors.add('$kindLabel slice ${slice.id} has empty sourceImagePath.');
  }
  if (slice.width <= 0 || slice.height <= 0) {
    errors.add('$kindLabel slice ${slice.id} has non-positive size.');
  }
  if (slice.x < 0 || slice.y < 0) {
    errors.add('$kindLabel slice ${slice.id} has negative origin.');
  }

  final atlasSize = atlasImageSizes[slice.sourceImagePath];
  if (slice.sourceImagePath.isNotEmpty && atlasSize == null) {
    errors.add(
      '$kindLabel slice ${slice.id} references missing atlas image '
      '${slice.sourceImagePath}.',
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
    errors.add(
      '$kindLabel slice ${slice.id} exceeds atlas bounds for '
      '${slice.sourceImagePath} (${atlasWidth}x$atlasHeight).',
    );
  }
}
