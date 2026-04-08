part of 'prefab_validation.dart';

/// Validates platform modules and builds module lookup indexes.
_ModuleValidationIndex _validateAndIndexModules({
  required List<PrefabValidationIssue> issues,
  required List<TileModuleDef> modules,
  required Set<String> tileSliceIds,
}) {
  final moduleIds = <String>{};
  final moduleById = <String, TileModuleDef>{};

  for (final module in modules) {
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

  return _ModuleValidationIndex(moduleIds: moduleIds, moduleById: moduleById);
}
