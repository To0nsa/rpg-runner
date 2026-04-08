import '../../../../prefabs/models/models.dart';
import 'prefab_editor_data_reducer.dart';

class PrefabEditorModuleRenameResult {
  const PrefabEditorModuleRenameResult({
    required this.data,
    required this.updatedPrefabCount,
  });

  final PrefabData data;
  final int updatedPrefabCount;
}

class PrefabEditorMutations {
  const PrefabEditorMutations({
    PrefabEditorDataReducer reducer = const PrefabEditorDataReducer(),
  }) : _reducer = reducer;

  final PrefabEditorDataReducer _reducer;

  PrefabData addSlice({
    required PrefabData data,
    required AtlasSliceKind kind,
    required AtlasSliceDef slice,
  }) {
    switch (kind) {
      case AtlasSliceKind.prefab:
        return data.copyWith(prefabSlices: [...data.prefabSlices, slice]);
      case AtlasSliceKind.tile:
        return data.copyWith(tileSlices: [...data.tileSlices, slice]);
    }
  }

  PrefabData deleteSlice({
    required PrefabData data,
    required AtlasSliceKind kind,
    required String sliceId,
  }) {
    switch (kind) {
      case AtlasSliceKind.prefab:
        return data.copyWith(
          prefabSlices: data.prefabSlices
              .where((slice) => slice.id != sliceId)
              .toList(growable: false),
          prefabs: data.prefabs
              .where((prefab) => prefab.sliceId != sliceId)
              .toList(growable: false),
        );
      case AtlasSliceKind.tile:
        final nextModules = data.platformModules
            .map(
              (module) => module.copyWith(
                cells: module.cells
                    .where((cell) => cell.sliceId != sliceId)
                    .toList(growable: false),
              ),
            )
            .toList(growable: false);
        return data.copyWith(
          tileSlices: data.tileSlices
              .where((slice) => slice.id != sliceId)
              .toList(growable: false),
          platformModules: nextModules,
        );
    }
  }

  PrefabData upsertPrefab({
    required PrefabData data,
    required PrefabDef prefab,
  }) {
    final nextPrefabs = _reducer.sortedPrefabsForUi(
      data.prefabs
          .where((existing) => existing.prefabKey != prefab.prefabKey)
          .followedBy([prefab])
          .toList(growable: false),
    );
    return data.copyWith(prefabs: nextPrefabs);
  }

  PrefabData deletePrefabById({
    required PrefabData data,
    required String prefabId,
  }) {
    return data.copyWith(
      prefabs: data.prefabs
          .where((prefab) => prefab.id != prefabId)
          .toList(growable: false),
    );
  }

  PrefabData upsertModule({
    required PrefabData data,
    required TileModuleDef module,
  }) {
    final nextModules = _reducer.sortedModulesForUi(
      data.platformModules
          .where((existing) => existing.id != module.id)
          .followedBy([module])
          .toList(growable: false),
    );
    return data.copyWith(platformModules: nextModules);
  }

  PrefabEditorModuleRenameResult renameModule({
    required PrefabData data,
    required String fromModuleId,
    required TileModuleDef renamedModule,
  }) {
    final rewrittenPrefabs = _reducer.rewritePrefabsForModuleRename(
      prefabs: data.prefabs,
      fromModuleId: fromModuleId,
      toModuleId: renamedModule.id,
    );
    final rewrittenModules = _reducer.sortedModulesForUi(
      data.platformModules
          .where((module) => module.id != fromModuleId)
          .where((module) => module.id != renamedModule.id)
          .followedBy([renamedModule])
          .toList(growable: false),
    );
    final updatedPrefabCount = rewrittenPrefabs
        .where(
          (prefab) =>
              prefab.usesPlatformModule && prefab.moduleId == renamedModule.id,
        )
        .length;
    return PrefabEditorModuleRenameResult(
      data: data.copyWith(
        prefabs: rewrittenPrefabs,
        platformModules: rewrittenModules,
      ),
      updatedPrefabCount: updatedPrefabCount,
    );
  }

  PrefabData deleteModuleById({
    required PrefabData data,
    required String moduleId,
  }) {
    return data.copyWith(
      platformModules: data.platformModules
          .where((module) => module.id != moduleId)
          .toList(growable: false),
    );
  }

  PrefabData deleteModuleCell({
    required PrefabData data,
    required String moduleId,
    required int cellIndex,
  }) {
    final current = _moduleById(data.platformModules, moduleId);
    if (current == null || cellIndex < 0 || cellIndex >= current.cells.length) {
      return data;
    }
    final nextCells = List<TileModuleCellDef>.from(current.cells)
      ..removeAt(cellIndex);
    final nextModule = current.copyWith(
      revision: current.revision + 1,
      cells: nextCells,
    );
    return upsertModule(data: data, module: nextModule);
  }

  PrefabData paintModuleCell({
    required PrefabData data,
    required String moduleId,
    required int gridX,
    required int gridY,
    required String sliceId,
  }) {
    final current = _moduleById(data.platformModules, moduleId);
    if (current == null) {
      return data;
    }
    var changed = false;
    final nextCells = <TileModuleCellDef>[];
    var found = false;
    for (final cell in current.cells) {
      if (cell.gridX == gridX && cell.gridY == gridY) {
        found = true;
        if (cell.sliceId == sliceId) {
          nextCells.add(cell);
        } else {
          changed = true;
          nextCells.add(
            TileModuleCellDef(sliceId: sliceId, gridX: gridX, gridY: gridY),
          );
        }
      } else {
        nextCells.add(cell);
      }
    }
    if (!found) {
      changed = true;
      nextCells.add(
        TileModuleCellDef(sliceId: sliceId, gridX: gridX, gridY: gridY),
      );
    }
    if (!changed) {
      return data;
    }
    final nextModule = current.copyWith(
      revision: current.revision + 1,
      cells: nextCells,
    );
    return upsertModule(data: data, module: nextModule);
  }

  PrefabData eraseModuleCell({
    required PrefabData data,
    required String moduleId,
    required int gridX,
    required int gridY,
  }) {
    final current = _moduleById(data.platformModules, moduleId);
    if (current == null) {
      return data;
    }
    var removed = false;
    final nextCells = <TileModuleCellDef>[];
    for (final cell in current.cells) {
      if (cell.gridX == gridX && cell.gridY == gridY) {
        removed = true;
        continue;
      }
      nextCells.add(cell);
    }
    if (!removed) {
      return data;
    }
    final nextModule = current.copyWith(
      revision: current.revision + 1,
      cells: nextCells,
    );
    return upsertModule(data: data, module: nextModule);
  }

  PrefabData moveModuleCell({
    required PrefabData data,
    required String moduleId,
    required int sourceGridX,
    required int sourceGridY,
    required int targetGridX,
    required int targetGridY,
  }) {
    if (sourceGridX == targetGridX && sourceGridY == targetGridY) {
      return data;
    }
    final current = _moduleById(data.platformModules, moduleId);
    if (current == null) {
      return data;
    }
    TileModuleCellDef? sourceCell;
    final nextCells = <TileModuleCellDef>[];
    for (final cell in current.cells) {
      if (cell.gridX == sourceGridX && cell.gridY == sourceGridY) {
        sourceCell ??= cell;
        continue;
      }
      if (cell.gridX == targetGridX && cell.gridY == targetGridY) {
        continue;
      }
      nextCells.add(cell);
    }
    if (sourceCell == null) {
      return data;
    }
    nextCells.add(
      TileModuleCellDef(
        sliceId: sourceCell.sliceId,
        gridX: targetGridX,
        gridY: targetGridY,
      ),
    );
    final nextModule = current.copyWith(
      revision: current.revision + 1,
      cells: nextCells,
    );
    return upsertModule(data: data, module: nextModule);
  }

  TileModuleDef? _moduleById(List<TileModuleDef> modules, String moduleId) {
    for (final module in modules) {
      if (module.id == moduleId) {
        return module;
      }
    }
    return null;
  }
}
