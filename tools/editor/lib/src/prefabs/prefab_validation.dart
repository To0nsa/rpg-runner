import 'dart:math' as math;
import 'dart:ui' show Size;

import 'prefab_models.dart';

class PrefabValidationIssue {
  const PrefabValidationIssue({required this.code, required this.message});

  final String code;
  final String message;
}

List<PrefabValidationIssue> validatePrefabDataIssues({
  required PrefabData data,
  required Map<String, Size> atlasImageSizes,
}) {
  final issues = <PrefabValidationIssue>[];
  if (data.schemaVersion != currentPrefabSchemaVersion) {
    issues.add(
      PrefabValidationIssue(
        code: 'prefab_schema_version_invalid',
        message:
            'Invalid prefab schemaVersion ${data.schemaVersion}; '
            'expected $currentPrefabSchemaVersion.',
      ),
    );
  }

  final sortedPrefabSlices = List<AtlasSliceDef>.from(data.prefabSlices)
    ..sort(_compareSlices);
  final sortedTileSlices = List<AtlasSliceDef>.from(data.tileSlices)
    ..sort(_compareSlices);
  final sortedModules = List<TileModuleDef>.from(data.platformModules)
    ..sort((a, b) => a.id.compareTo(b.id));
  final sortedPrefabs = List<PrefabDef>.from(data.prefabs)
    ..sort(_comparePrefabs);

  final prefabSliceIds = <String>{};
  final tileSliceIds = <String>{};
  final allSliceIds = <String>{};
  final prefabSliceById = <String, AtlasSliceDef>{};
  final tileSliceById = <String, AtlasSliceDef>{};

  for (final slice in sortedPrefabSlices) {
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

  for (final slice in sortedTileSlices) {
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

  final moduleIds = <String>{};
  final moduleById = <String, TileModuleDef>{};
  for (final module in sortedModules) {
    if (module.id.isEmpty) {
      issues.add(
        const PrefabValidationIssue(
          code: 'platform_module_id_missing',
          message: 'Platform module with empty id.',
        ),
      );
    } else if (!moduleIds.add(module.id)) {
      issues.add(
        PrefabValidationIssue(
          code: 'platform_module_id_duplicate',
          message: 'Duplicate platform module id: ${module.id}',
        ),
      );
    } else {
      moduleById[module.id] = module;
    }

    if (module.revision <= 0) {
      issues.add(
        PrefabValidationIssue(
          code: 'platform_module_revision_invalid',
          message:
              'Platform module ${module.id} has invalid revision ${module.revision}.',
        ),
      );
    }

    if (module.status == TileModuleStatus.unknown) {
      issues.add(
        PrefabValidationIssue(
          code: 'platform_module_status_invalid',
          message: 'Platform module ${module.id} has unsupported status.',
        ),
      );
    }

    if (module.tileSize <= 0) {
      issues.add(
        PrefabValidationIssue(
          code: 'platform_module_tile_size_invalid',
          message: 'Platform module ${module.id} has non-positive tileSize.',
        ),
      );
    }

    if (module.status == TileModuleStatus.active && module.cells.isEmpty) {
      issues.add(
        PrefabValidationIssue(
          code: 'platform_module_cells_missing',
          message: 'Platform module ${module.id} has no cells.',
        ),
      );
    }

    final sortedCells = List<TileModuleCellDef>.from(module.cells)
      ..sort(_compareModuleCells);
    final cellKeys = <String>{};
    for (final cell in sortedCells) {
      if (!tileSliceIds.contains(cell.sliceId)) {
        issues.add(
          PrefabValidationIssue(
            code: 'platform_module_tile_slice_missing',
            message:
                'Platform module ${module.id} references missing tile slice ${cell.sliceId}.',
          ),
        );
      }

      final cellKey = '${cell.gridX}:${cell.gridY}';
      if (!cellKeys.add(cellKey)) {
        issues.add(
          PrefabValidationIssue(
            code: 'platform_module_cell_duplicate',
            message:
                'Platform module ${module.id} has duplicate cell at ($cellKey).',
          ),
        );
      }
    }
  }

  final prefabIds = <String>{};
  final prefabKeys = <String>{};
  for (final prefab in sortedPrefabs) {
    final prefabLabel = _prefabLabel(prefab);
    if (prefab.id.isEmpty) {
      issues.add(
        const PrefabValidationIssue(
          code: 'prefab_id_missing',
          message: 'Prefab with empty id.',
        ),
      );
    } else if (!prefabIds.add(prefab.id)) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_id_duplicate',
          message: 'Duplicate prefab id: ${prefab.id}',
        ),
      );
    }

    if (prefab.prefabKey.isEmpty) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_key_missing',
          message: 'Prefab $prefabLabel has empty prefabKey.',
        ),
      );
    } else if (!prefabKeys.add(prefab.prefabKey)) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_key_duplicate',
          message: 'Duplicate prefab key: ${prefab.prefabKey}',
        ),
      );
    }

    if (prefab.revision <= 0) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_revision_invalid',
          message:
              'Prefab $prefabLabel has invalid revision ${prefab.revision}.',
        ),
      );
    }

    if (prefab.status == PrefabStatus.unknown) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_status_invalid',
          message: 'Prefab $prefabLabel has unsupported status.',
        ),
      );
    }

    if (prefab.kind == PrefabKind.unknown) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_kind_invalid',
          message: 'Prefab $prefabLabel has unsupported kind.',
        ),
      );
    }

    final source = prefab.visualSource;
    _SourceGeometry? sourceGeometry;
    switch (source.type) {
      case PrefabVisualSourceType.atlasSlice:
        if (source.sliceId.isEmpty) {
          issues.add(
            PrefabValidationIssue(
              code: 'prefab_source_slice_id_missing',
              message: 'Prefab $prefabLabel has empty atlas slice source id.',
            ),
          );
        } else if (!prefabSliceIds.contains(source.sliceId)) {
          issues.add(
            PrefabValidationIssue(
              code: 'prefab_source_slice_missing',
              message:
                  'Prefab ${prefab.id} references missing prefab slice ${source.sliceId}.',
            ),
          );
        } else {
          final slice = prefabSliceById[source.sliceId];
          if (slice != null) {
            sourceGeometry = _SourceGeometry(
              widthPx: slice.width,
              heightPx: slice.height,
              snapUnitPx: 1,
            );
          }
        }
        if (prefab.kind == PrefabKind.platform) {
          issues.add(
            PrefabValidationIssue(
              code: 'prefab_kind_source_mismatch',
              message:
                  'Prefab $prefabLabel has incompatible kind/source '
                  '(platform + atlas_slice).',
            ),
          );
        }
      case PrefabVisualSourceType.platformModule:
        if (source.moduleId.isEmpty) {
          issues.add(
            PrefabValidationIssue(
              code: 'prefab_source_module_id_missing',
              message:
                  'Prefab $prefabLabel has empty platform module source id.',
            ),
          );
        } else if (!moduleIds.contains(source.moduleId)) {
          issues.add(
            PrefabValidationIssue(
              code: 'prefab_source_module_missing',
              message:
                  'Prefab ${prefab.id} references missing platform module ${source.moduleId}.',
            ),
          );
        } else {
          sourceGeometry = _geometryForModule(
            moduleById[source.moduleId]!,
            tileSliceById: tileSliceById,
          );
        }
        if (prefab.kind == PrefabKind.obstacle) {
          issues.add(
            PrefabValidationIssue(
              code: 'prefab_kind_source_mismatch',
              message:
                  'Prefab $prefabLabel has incompatible kind/source '
                  '(obstacle + platform_module).',
            ),
          );
        }
      case PrefabVisualSourceType.unknown:
        issues.add(
          PrefabValidationIssue(
            code: 'prefab_source_type_invalid',
            message: 'Prefab $prefabLabel has unsupported visual source type.',
          ),
        );
    }

    _validatePrefabTags(issues: issues, prefab: prefab);
    _validatePrefabAnchorAndColliders(
      issues: issues,
      prefab: prefab,
      sourceGeometry: sourceGeometry,
    );
  }

  issues.sort(_compareIssues);
  return List<PrefabValidationIssue>.unmodifiable(issues);
}

List<String> validatePrefabData({
  required PrefabData data,
  required Map<String, Size> atlasImageSizes,
}) {
  return validatePrefabDataIssues(
    data: data,
    atlasImageSizes: atlasImageSizes,
  ).map((issue) => issue.message).toList(growable: false);
}

String _prefabLabel(PrefabDef prefab) {
  if (prefab.id.isNotEmpty) {
    return prefab.id;
  }
  if (prefab.prefabKey.isNotEmpty) {
    return prefab.prefabKey;
  }
  return '(unidentified prefab)';
}

void _validatePrefabTags({
  required List<PrefabValidationIssue> issues,
  required PrefabDef prefab,
}) {
  final seenTags = <String>{};
  for (var i = 0; i < prefab.tags.length; i += 1) {
    final rawTag = prefab.tags[i];
    final normalized = rawTag.trim();
    if (normalized.isEmpty) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_tag_empty',
          message: 'Prefab ${prefab.id} has empty tag at index $i.',
        ),
      );
      continue;
    }
    if (normalized != rawTag) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_tag_whitespace',
          message:
              'Prefab ${prefab.id} tag "$rawTag" must not contain leading/trailing whitespace.',
        ),
      );
    }
    if (!seenTags.add(normalized)) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_tag_duplicate',
          message: 'Prefab ${prefab.id} has duplicate tag "$normalized".',
        ),
      );
    }
  }
}

void _validatePrefabAnchorAndColliders({
  required List<PrefabValidationIssue> issues,
  required PrefabDef prefab,
  required _SourceGeometry? sourceGeometry,
}) {
  final prefabId = prefab.id;
  final anchorX = prefab.anchorXPx;
  final anchorY = prefab.anchorYPx;

  if (sourceGeometry != null) {
    if (anchorX < 0 ||
        anchorY < 0 ||
        anchorX > sourceGeometry.widthPx ||
        anchorY > sourceGeometry.heightPx) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_anchor_out_of_bounds',
          message:
              'Prefab $prefabId has anchor ($anchorX,$anchorY) outside source bounds '
              '${sourceGeometry.widthPx}x${sourceGeometry.heightPx}.',
        ),
      );
    }

    if (prefab.kind == PrefabKind.platform &&
        prefab.snapToGrid &&
        sourceGeometry.snapUnitPx > 1) {
      if (!_isSnappedToUnit(anchorX, sourceGeometry.snapUnitPx) ||
          !_isSnappedToUnit(anchorY, sourceGeometry.snapUnitPx)) {
        issues.add(
          PrefabValidationIssue(
            code: 'platform_anchor_snap_violation',
            message:
                'Prefab $prefabId anchor must be snapped to module tileSize '
                '${sourceGeometry.snapUnitPx}.',
          ),
        );
      }
    }
  }

  if (prefab.colliders.isEmpty) {
    issues.add(
      PrefabValidationIssue(
        code: 'prefab_collider_missing',
        message: 'Prefab $prefabId must include at least one collider.',
      ),
    );
    return;
  }

  var hasColliderInsideSource = false;
  for (var i = 0; i < prefab.colliders.length; i += 1) {
    final collider = prefab.colliders[i];
    if (collider.width <= 0 || collider.height <= 0) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_collider_size_invalid',
          message: 'Prefab $prefabId has collider with non-positive size.',
        ),
      );
      continue;
    }

    if (sourceGeometry != null &&
        prefab.kind == PrefabKind.platform &&
        prefab.snapToGrid &&
        sourceGeometry.snapUnitPx > 1) {
      if (!_isSnappedToUnit(collider.offsetX, sourceGeometry.snapUnitPx) ||
          !_isSnappedToUnit(collider.offsetY, sourceGeometry.snapUnitPx) ||
          !_isSnappedToUnit(collider.width, sourceGeometry.snapUnitPx) ||
          !_isSnappedToUnit(collider.height, sourceGeometry.snapUnitPx)) {
        issues.add(
          PrefabValidationIssue(
            code: 'platform_collider_snap_violation',
            message:
                'Prefab $prefabId collider[$i] must be snapped to module tileSize '
                '${sourceGeometry.snapUnitPx}.',
          ),
        );
      }
    }

    if (sourceGeometry != null &&
        _colliderIntersectsSource(
          collider: collider,
          anchorX: anchorX,
          anchorY: anchorY,
          sourceWidthPx: sourceGeometry.widthPx,
          sourceHeightPx: sourceGeometry.heightPx,
        )) {
      hasColliderInsideSource = true;
    }
  }

  if (sourceGeometry != null && !hasColliderInsideSource) {
    final code = switch (prefab.kind) {
      PrefabKind.obstacle => 'obstacle_collider_outside_source',
      PrefabKind.platform => 'platform_collider_outside_source',
      PrefabKind.unknown => 'prefab_collider_outside_source',
    };
    issues.add(
      PrefabValidationIssue(
        code: code,
        message:
            'Prefab $prefabId colliders do not intersect its authored source bounds.',
      ),
    );
  }
}

bool _colliderIntersectsSource({
  required PrefabColliderDef collider,
  required int anchorX,
  required int anchorY,
  required int sourceWidthPx,
  required int sourceHeightPx,
}) {
  final sourceLeft = -anchorX.toDouble();
  final sourceTop = -anchorY.toDouble();
  final sourceRight = (sourceWidthPx - anchorX).toDouble();
  final sourceBottom = (sourceHeightPx - anchorY).toDouble();

  final colliderCenterX = collider.offsetX.toDouble();
  final colliderCenterY = collider.offsetY.toDouble();
  final halfW = collider.width * 0.5;
  final halfH = collider.height * 0.5;
  final colliderLeft = colliderCenterX - halfW;
  final colliderTop = colliderCenterY - halfH;
  final colliderRight = colliderCenterX + halfW;
  final colliderBottom = colliderCenterY + halfH;

  return colliderLeft < sourceRight &&
      colliderRight > sourceLeft &&
      colliderTop < sourceBottom &&
      colliderBottom > sourceTop;
}

_SourceGeometry? _geometryForModule(
  TileModuleDef module, {
  required Map<String, AtlasSliceDef> tileSliceById,
}) {
  if (module.cells.isEmpty || module.tileSize <= 0) {
    return null;
  }

  final tileSize = module.tileSize.toDouble();
  double? minLeft;
  double? minTop;
  double? maxRight;
  double? maxBottom;
  for (final cell in module.cells) {
    final slice = tileSliceById[cell.sliceId];
    final width = math.max(1, slice?.width ?? module.tileSize).toDouble();
    final height = math.max(1, slice?.height ?? module.tileSize).toDouble();
    final left = cell.gridX * tileSize;
    final top = cell.gridY * tileSize;
    final right = left + width;
    final bottom = top + height;

    minLeft = minLeft == null ? left : math.min(minLeft, left);
    minTop = minTop == null ? top : math.min(minTop, top);
    maxRight = maxRight == null ? right : math.max(maxRight, right);
    maxBottom = maxBottom == null ? bottom : math.max(maxBottom, bottom);
  }

  if (minLeft == null ||
      minTop == null ||
      maxRight == null ||
      maxBottom == null) {
    return null;
  }

  final widthPx = (maxRight - minLeft).round();
  final heightPx = (maxBottom - minTop).round();
  if (widthPx <= 0 || heightPx <= 0) {
    return null;
  }

  return _SourceGeometry(
    widthPx: widthPx,
    heightPx: heightPx,
    snapUnitPx: module.tileSize,
  );
}

bool _isSnappedToUnit(int value, int unit) {
  if (unit <= 1) {
    return true;
  }
  return value % unit == 0;
}

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

  if (!allSliceIds.add(slice.id)) {
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

int _compareIssues(PrefabValidationIssue a, PrefabValidationIssue b) {
  final codeCompare = a.code.compareTo(b.code);
  if (codeCompare != 0) {
    return codeCompare;
  }
  return a.message.compareTo(b.message);
}

int _compareSlices(AtlasSliceDef a, AtlasSliceDef b) {
  final idCompare = a.id.compareTo(b.id);
  if (idCompare != 0) {
    return idCompare;
  }
  final sourceCompare = a.sourceImagePath.compareTo(b.sourceImagePath);
  if (sourceCompare != 0) {
    return sourceCompare;
  }
  final yCompare = a.y.compareTo(b.y);
  if (yCompare != 0) {
    return yCompare;
  }
  return a.x.compareTo(b.x);
}

int _comparePrefabs(PrefabDef a, PrefabDef b) {
  final idCompare = a.id.compareTo(b.id);
  if (idCompare != 0) {
    return idCompare;
  }
  return a.prefabKey.compareTo(b.prefabKey);
}

int _compareModuleCells(TileModuleCellDef a, TileModuleCellDef b) {
  final yCompare = a.gridY.compareTo(b.gridY);
  if (yCompare != 0) {
    return yCompare;
  }
  final xCompare = a.gridX.compareTo(b.gridX);
  if (xCompare != 0) {
    return xCompare;
  }
  return a.sliceId.compareTo(b.sliceId);
}

class _SourceGeometry {
  const _SourceGeometry({
    required this.widthPx,
    required this.heightPx,
    required this.snapUnitPx,
  });

  final int widthPx;
  final int heightPx;
  final int snapUnitPx;
}
