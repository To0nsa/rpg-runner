import '../../../../prefabs/models/models.dart';
import 'platform_module_cell_reducer.dart';
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

  PrefabData upsertSlice({
    required PrefabData data,
    required AtlasSliceKind kind,
    required AtlasSliceDef slice,
  }) {
    final normalizedSlice = slice.copyWith(
      tags: _reducer.normalizedTags(slice.tags),
    );
    switch (kind) {
      case AtlasSliceKind.prefab:
        return data.copyWith(
          prefabSlices: _reducer.sortedSlicesForUi(
            data.prefabSlices
                .where((existing) => existing.id != normalizedSlice.id)
                .followedBy([normalizedSlice])
                .toList(growable: false),
          ),
        );
      case AtlasSliceKind.tile:
        return data.copyWith(
          tileSlices: _reducer.sortedSlicesForUi(
            data.tileSlices
                .where((existing) => existing.id != normalizedSlice.id)
                .followedBy([normalizedSlice])
                .toList(growable: false),
          ),
        );
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
    if (current == null) return data;
    final nextCells = PlatformModuleCellReducer.deleteAt(
      current.cells,
      cellIndex,
    );
    if (nextCells == null) return data;
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
    if (current == null) return data;
    final nextCells = PlatformModuleCellReducer.paint(
      current.cells,
      gridX: gridX,
      gridY: gridY,
      sliceId: sliceId,
    );
    if (nextCells == null) return data;
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
    if (current == null) return data;
    final nextCells = PlatformModuleCellReducer.erase(
      current.cells,
      gridX: gridX,
      gridY: gridY,
    );
    if (nextCells == null) return data;
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
    final current = _moduleById(data.platformModules, moduleId);
    if (current == null) return data;
    final nextCells = PlatformModuleCellReducer.move(
      current.cells,
      sourceGridX: sourceGridX,
      sourceGridY: sourceGridY,
      targetGridX: targetGridX,
      targetGridY: targetGridY,
    );
    if (nextCells == null) return data;
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
