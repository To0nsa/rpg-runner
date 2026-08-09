import 'dart:ui' show Size;

import '../models/models.dart';
import '../store/prefab_determinism.dart';
import '../validation/prefab_validation.dart';
import 'prefab_domain_models.dart';
import 'prefab_v3_owner_validation.dart';

const String _prefabSourcePath = 'assets/authoring/level/prefab_defs.json';
const String _tileSourcePath = 'assets/authoring/level/tile_defs.json';

/// Validates the complete retained catalog and every prefab-v3 owner.
///
/// Strict codecs remain the JSON authority. This validator covers mutable
/// in-memory candidates before serialization: deterministic order, identities,
/// atlas bounds, module-cell references, visual-owner references, and polygon
/// owner rules.
List<PrefabValidationIssue> validatePrefabV3CatalogDocument(
  PrefabV3StagingDocument document,
) {
  final issues = <PrefabValidationIssue>[];
  _validateSliceList(
    issues: issues,
    slices: document.data.slices,
    label: 'Prefab',
    atlasImageSizes: document.atlasImageSizes,
    sourcePath: _prefabSourcePath,
  );
  _validateSliceList(
    issues: issues,
    slices: document.tileData.tileSlices,
    label: 'Tile',
    atlasImageSizes: document.atlasImageSizes,
    sourcePath: _tileSourcePath,
  );

  final allSliceIds = <String>{};
  for (final slice in <AtlasSliceDef>[
    ...document.data.slices,
    ...document.tileData.tileSlices,
  ]) {
    if (!allSliceIds.add(slice.id.toLowerCase())) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_v3_slice_id_collision',
          message: 'Slice id ${slice.id} is already owned.',
          sourcePath: _prefabSourcePath,
        ),
      );
    }
  }

  _validateModules(document, issues);
  final sortedPrefabs = PrefabDeterminism.sortPrefabV3ByIdThenKey(
    document.data.prefabs,
  );
  if (!_prefabListsEqual(document.data.prefabs, sortedPrefabs)) {
    issues.add(
      const PrefabValidationIssue(
        code: 'prefab_v3_owner_order_noncanonical',
        message: 'Prefab owners must be ordered by human ID and stable key.',
        sourcePath: _prefabSourcePath,
      ),
    );
  }
  final ids = <String>{};
  final keys = <String>{};
  for (final prefab in document.data.prefabs) {
    if (prefab.id.isEmpty || prefab.id != prefab.id.trim()) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_v3_owner_id_invalid',
          message:
              'Prefab ${prefab.prefabKey} requires a non-empty trimmed ID.',
          sourcePath: '$_prefabSourcePath:${prefab.prefabKey}',
        ),
      );
    } else if (!ids.add(prefab.id.toLowerCase())) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_v3_owner_id_collision',
          message: 'Prefab id ${prefab.id} is already owned.',
          sourcePath: '$_prefabSourcePath:${prefab.prefabKey}',
        ),
      );
    }
    if (prefab.prefabKey.isEmpty ||
        prefab.prefabKey != prefab.prefabKey.trim()) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_v3_owner_key_invalid',
          message: 'Prefab ${prefab.id} requires a non-empty trimmed key.',
          sourcePath: '$_prefabSourcePath:${prefab.prefabKey}',
        ),
      );
    } else if (!keys.add(prefab.prefabKey.toLowerCase())) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_v3_owner_key_collision',
          message: 'Prefab key ${prefab.prefabKey} is already owned.',
          sourcePath: '$_prefabSourcePath:${prefab.prefabKey}',
        ),
      );
    }
    if (prefab.revision <= 0) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_v3_owner_revision_invalid',
          message: 'Prefab ${prefab.id} requires a positive revision.',
          sourcePath: '$_prefabSourcePath:${prefab.prefabKey}',
        ),
      );
    }
    issues.addAll(
      validatePrefabV3Owner(
        prefabData: document.data,
        tileData: document.tileData,
        prefab: prefab,
        visualBounds: document.visualBoundsByPrefabKey[prefab.prefabKey],
      ),
    );
  }

  issues.sort((left, right) {
    final pathOrder = left.sourcePath.compareTo(right.sourcePath);
    if (pathOrder != 0) return pathOrder;
    final codeOrder = left.code.compareTo(right.code);
    return codeOrder != 0 ? codeOrder : left.message.compareTo(right.message);
  });
  return List<PrefabValidationIssue>.unmodifiable(issues);
}

void _validateSliceList({
  required List<PrefabValidationIssue> issues,
  required List<AtlasSliceDef> slices,
  required String label,
  required Map<String, Size> atlasImageSizes,
  required String sourcePath,
}) {
  final sorted = PrefabDeterminism.sortSlicesByIdThenSourceRect(slices);
  if (!_sliceListsEqual(slices, sorted)) {
    issues.add(
      PrefabValidationIssue(
        code: 'prefab_v3_${label.toLowerCase()}_slice_order_noncanonical',
        message: '$label slices must be ordered by canonical source identity.',
        sourcePath: sourcePath,
      ),
    );
  }
  final ids = <String>{};
  for (final slice in slices) {
    final prefix = label.toLowerCase();
    if (slice.id.isEmpty || slice.id != slice.id.trim()) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_v3_${prefix}_slice_id_invalid',
          message: '$label slice requires a non-empty trimmed ID.',
          sourcePath: sourcePath,
        ),
      );
    } else if (!ids.add(slice.id.toLowerCase())) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_v3_${prefix}_slice_id_collision',
          message: '$label slice id ${slice.id} is already owned.',
          sourcePath: sourcePath,
        ),
      );
    }
    if (slice.sourceImagePath.isEmpty ||
        slice.sourceImagePath != slice.sourceImagePath.trim()) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_v3_${prefix}_slice_source_invalid',
          message: '$label slice ${slice.id} requires a trimmed atlas path.',
          sourcePath: sourcePath,
        ),
      );
    }
    if (slice.x < 0 || slice.y < 0 || slice.width <= 0 || slice.height <= 0) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_v3_${prefix}_slice_bounds_invalid',
          message:
              '$label slice ${slice.id} requires a non-negative origin and '
              'positive dimensions.',
          sourcePath: sourcePath,
        ),
      );
    }
    if (!_stringListsEqual(
      slice.tags,
      PrefabDeterminism.normalizeTags(slice.tags),
    )) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_v3_${prefix}_slice_tags_noncanonical',
          message:
              '$label slice ${slice.id} tags must be trimmed, unique, and '
              'ordered lexically.',
          sourcePath: sourcePath,
        ),
      );
    }
    final atlasSize =
        atlasImageSizes[slice.sourceImagePath.replaceAll('\\', '/')];
    if (atlasSize == null) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_v3_${prefix}_slice_atlas_missing',
          message:
              '$label slice ${slice.id} references unavailable atlas '
              '${slice.sourceImagePath}.',
          sourcePath: sourcePath,
        ),
      );
    } else if (slice.x + slice.width > atlasSize.width.toInt() ||
        slice.y + slice.height > atlasSize.height.toInt()) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_v3_${prefix}_slice_out_of_bounds',
          message:
              '$label slice ${slice.id} exceeds atlas bounds '
              '${atlasSize.width.toInt()}x${atlasSize.height.toInt()}.',
          sourcePath: sourcePath,
        ),
      );
    }
  }
}

void _validateModules(
  PrefabV3StagingDocument document,
  List<PrefabValidationIssue> issues,
) {
  final modules = document.tileData.platformModules;
  final sorted = PrefabDeterminism.sortModulesByStatusIdRevision(modules);
  if (!_moduleListsEqual(modules, sorted)) {
    issues.add(
      const PrefabValidationIssue(
        code: 'prefab_v3_module_order_noncanonical',
        message:
            'Platform modules must use canonical status/ID/revision order.',
        sourcePath: _tileSourcePath,
      ),
    );
  }
  final moduleIds = <String>{};
  final tileSliceIds = document.tileData.tileSlices
      .map((slice) => slice.id)
      .toSet();
  for (final module in modules) {
    if (module.id.isEmpty || module.id != module.id.trim()) {
      issues.add(
        const PrefabValidationIssue(
          code: 'prefab_v3_module_id_invalid',
          message: 'Platform module requires a non-empty trimmed ID.',
          sourcePath: _tileSourcePath,
        ),
      );
    } else if (!moduleIds.add(module.id.toLowerCase())) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_v3_module_id_collision',
          message: 'Platform module id ${module.id} is already owned.',
          sourcePath: _tileSourcePath,
        ),
      );
    }
    if (module.revision <= 0 ||
        module.status == TileModuleStatus.unknown ||
        module.tileSize <= 0) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_v3_module_metadata_invalid',
          message:
              'Module ${module.id} requires a positive revision/tileSize and '
              'supported status.',
          sourcePath: _tileSourcePath,
        ),
      );
    }
    if (module.status == TileModuleStatus.active && module.cells.isEmpty) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_v3_module_cells_missing',
          message:
              'Active module ${module.id} requires at least one tile cell.',
          sourcePath: _tileSourcePath,
        ),
      );
    }
    final canonicalCells = PrefabDeterminism.sortModuleCellsByGridPosition(
      module.cells,
    );
    if (!_cellListsEqual(module.cells, canonicalCells)) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_v3_module_cells_noncanonical',
          message: 'Module ${module.id} cells must use canonical grid order.',
          sourcePath: _tileSourcePath,
        ),
      );
    }
    final positions = <(int, int)>{};
    for (final cell in module.cells) {
      if (!tileSliceIds.contains(cell.sliceId)) {
        issues.add(
          PrefabValidationIssue(
            code: 'prefab_v3_module_tile_slice_missing',
            message:
                'Module ${module.id} references missing tile slice '
                '${cell.sliceId}.',
            sourcePath: _tileSourcePath,
          ),
        );
      }
      if (!positions.add((cell.gridX, cell.gridY))) {
        issues.add(
          PrefabValidationIssue(
            code: 'prefab_v3_module_cell_duplicate',
            message:
                'Module ${module.id} repeats grid position '
                '(${cell.gridX},${cell.gridY}).',
            sourcePath: _tileSourcePath,
          ),
        );
      }
    }
  }
}

bool _sliceListsEqual(List<AtlasSliceDef> left, List<AtlasSliceDef> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    final a = left[index];
    final b = right[index];
    if (a.id != b.id ||
        a.sourceImagePath != b.sourceImagePath ||
        a.x != b.x ||
        a.y != b.y ||
        a.width != b.width ||
        a.height != b.height ||
        !_stringListsEqual(a.tags, b.tags)) {
      return false;
    }
  }
  return true;
}

bool _prefabListsEqual(List<PrefabV3Def> left, List<PrefabV3Def> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _moduleListsEqual(List<TileModuleDef> left, List<TileModuleDef> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    final a = left[index];
    final b = right[index];
    if (a.id != b.id ||
        a.revision != b.revision ||
        a.status != b.status ||
        a.tileSize != b.tileSize ||
        !_cellListsEqual(a.cells, b.cells)) {
      return false;
    }
  }
  return true;
}

bool _cellListsEqual(
  List<TileModuleCellDef> left,
  List<TileModuleCellDef> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    final a = left[index];
    final b = right[index];
    if (a.sliceId != b.sliceId || a.gridX != b.gridX || a.gridY != b.gridY) {
      return false;
    }
  }
  return true;
}

bool _stringListsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
