import '../../../../prefabs/models/models.dart';
import '../shared/prefab_editor_data_reducer.dart';
import '../shared/prefab_editor_mutations.dart';
import '../shared/prefab_editor_prefab_controller.dart';

/// Platform-module workflow rules for CRUD and tile-cell mutations.
class PlatformModuleController {
  const PlatformModuleController({
    PrefabEditorDataReducer reducer = const PrefabEditorDataReducer(),
    PrefabEditorMutations mutations = const PrefabEditorMutations(),
  }) : _reducer = reducer,
       _mutations = mutations;

  final PrefabEditorDataReducer _reducer;
  final PrefabEditorMutations _mutations;

  TileModuleDef? moduleById({
    required PrefabData data,
    required String moduleId,
  }) {
    for (final module in data.platformModules) {
      if (module.id == moduleId) {
        return module;
      }
    }
    return null;
  }

  TileModuleDef? selectedModule({
    required PrefabData data,
    required String? selectedModuleId,
  }) {
    if (selectedModuleId == null) {
      return null;
    }
    return moduleById(data: data, moduleId: selectedModuleId);
  }

  PrefabEditorDecision<PlatformModuleCommitResult> upsertFromForm({
    required PrefabData data,
    required String rawId,
    required String rawTileSize,
    required String? currentPrefabPlatformModuleId,
  }) {
    final id = rawId.trim();
    final tileSize = int.tryParse(rawTileSize.trim());
    if (id.isEmpty) {
      return const PrefabEditorDecision.error(
        'Platform module id is required.',
      );
    }
    if (tileSize == null || tileSize <= 0) {
      return const PrefabEditorDecision.error(
        'Module tileSize must be a positive integer.',
      );
    }

    final previous = moduleById(data: data, moduleId: id);
    var nextModule = previous == null
        ? TileModuleDef(
            id: id,
            revision: 1,
            status: TileModuleStatus.active,
            tileSize: tileSize,
            cells: const [],
          )
        : previous.copyWith(tileSize: tileSize);
    if (previous != null &&
        _reducer.didModulePayloadChange(previous, nextModule)) {
      nextModule = nextModule.copyWith(revision: previous.revision + 1);
    }

    return PrefabEditorDecision.success(
      PlatformModuleCommitResult(
        data: _mutations.upsertModule(data: data, module: nextModule),
        selectedModuleId: id,
        selectedPrefabPlatformModuleId: currentPrefabPlatformModuleId ?? id,
        statusMessage:
            'Upserted platform module "$id" '
            '(rev=${nextModule.revision} status=${nextModule.status.jsonValue}).',
      ),
    );
  }

  PrefabEditorDecision<PlatformModuleCommitResult> duplicateSelectedModule({
    required PrefabData data,
    required TileModuleDef? source,
    required String rawNextId,
    required String? currentPrefabPlatformModuleId,
  }) {
    if (source == null) {
      return const PrefabEditorDecision.error(
        'Load/select a module before duplicating.',
      );
    }

    var nextId = rawNextId.trim();
    if (nextId.isEmpty || nextId == source.id) {
      nextId = _reducer.allocateModuleIdForDuplicate(data, source.id);
    }
    if (data.platformModules.any((module) => module.id == nextId)) {
      return PrefabEditorDecision.error(
        'Platform module id "$nextId" already exists.',
      );
    }

    final duplicate = source.copyWith(
      id: nextId,
      revision: 1,
      status: TileModuleStatus.active,
    );
    return PrefabEditorDecision.success(
      PlatformModuleCommitResult(
        data: _mutations.upsertModule(data: data, module: duplicate),
        selectedModuleId: duplicate.id,
        selectedPrefabPlatformModuleId:
            currentPrefabPlatformModuleId ?? duplicate.id,
        statusMessage:
            'Duplicated module "${source.id}" -> "${duplicate.id}" '
            '(rev=${duplicate.revision}).',
      ),
    );
  }

  PrefabEditorDecision<PlatformModuleCommitResult> renameSelectedModule({
    required PrefabData data,
    required TileModuleDef? source,
    required String rawNextId,
    required String? currentPrefabPlatformModuleId,
  }) {
    if (source == null) {
      return const PrefabEditorDecision.error(
        'Load/select a module before renaming.',
      );
    }

    final nextId = rawNextId.trim();
    if (nextId.isEmpty) {
      return const PrefabEditorDecision.error(
        'Platform module id is required.',
      );
    }
    if (nextId == source.id) {
      return const PrefabEditorDecision.error(
        'Rename target must differ from current module id.',
      );
    }
    if (data.platformModules.any((module) => module.id == nextId)) {
      return PrefabEditorDecision.error(
        'Platform module id "$nextId" already exists.',
      );
    }

    final renamed = source.copyWith(id: nextId, revision: source.revision + 1);
    final result = _mutations.renameModule(
      data: data,
      fromModuleId: source.id,
      renamedModule: renamed,
    );
    return PrefabEditorDecision.success(
      PlatformModuleCommitResult(
        data: result.data,
        selectedModuleId: renamed.id,
        selectedPrefabPlatformModuleId:
            currentPrefabPlatformModuleId == source.id
            ? renamed.id
            : currentPrefabPlatformModuleId,
        statusMessage:
            'Renamed module "${source.id}" -> "${renamed.id}" '
            '(rev=${renamed.revision}, updatedPrefabs=${result.updatedPrefabCount}).',
      ),
    );
  }

  PrefabEditorDecision<PlatformModuleCommitResult>
  toggleDeprecateSelectedModule({
    required PrefabData data,
    required TileModuleDef? source,
    required String? currentPrefabPlatformModuleId,
  }) {
    if (source == null) {
      return const PrefabEditorDecision.error(
        'Load/select a module before changing status.',
      );
    }

    final nextStatus = source.status == TileModuleStatus.deprecated
        ? TileModuleStatus.active
        : TileModuleStatus.deprecated;
    final updated = source.copyWith(
      status: nextStatus,
      revision: source.revision + 1,
    );
    return PrefabEditorDecision.success(
      PlatformModuleCommitResult(
        data: _mutations.upsertModule(data: data, module: updated),
        selectedModuleId: updated.id,
        selectedPrefabPlatformModuleId: currentPrefabPlatformModuleId,
        statusMessage:
            '${nextStatus == TileModuleStatus.deprecated ? 'Deprecated' : 'Reactivated'} '
            'module "${updated.id}" (rev=${updated.revision}).',
      ),
    );
  }

  PrefabEditorDecision<PlatformModuleDeleteResult> deleteModule({
    required PrefabData data,
    required String moduleId,
    required String? currentSelectedModuleId,
    required String? currentPrefabPlatformModuleId,
  }) {
    final referencedPrefabs = data.prefabs
        .where(
          (prefab) => prefab.usesPlatformModule && prefab.moduleId == moduleId,
        )
        .toList(growable: false);
    if (referencedPrefabs.isNotEmpty) {
      return PrefabEditorDecision.error(
        'Cannot delete module "$moduleId": '
        '${referencedPrefabs.length} prefab(s) still reference it.',
      );
    }

    final nextData = _mutations.deleteModuleById(
      data: data,
      moduleId: moduleId,
    );
    final nextPreferredModuleId = _reducer.preferredModuleIdForPicker(
      nextData.platformModules,
    );
    return PrefabEditorDecision.success(
      PlatformModuleDeleteResult(
        data: nextData,
        selectedModuleId: currentSelectedModuleId == moduleId
            ? nextPreferredModuleId
            : currentSelectedModuleId,
        selectedPrefabPlatformModuleId:
            currentPrefabPlatformModuleId == moduleId
            ? nextPreferredModuleId
            : currentPrefabPlatformModuleId,
        statusMessage: 'Deleted module "$moduleId".',
      ),
    );
  }

  PlatformModuleCellMutationResult? deleteModuleCell({
    required PrefabData data,
    required String moduleId,
    required int cellIndex,
  }) {
    final current = moduleById(data: data, moduleId: moduleId);
    if (current == null || cellIndex < 0 || cellIndex >= current.cells.length) {
      return null;
    }
    final nextData = _mutations.deleteModuleCell(
      data: data,
      moduleId: moduleId,
      cellIndex: cellIndex,
    );
    if (identical(nextData, data)) {
      return null;
    }
    final updatedModule = moduleById(data: nextData, moduleId: moduleId);
    if (updatedModule == null) {
      return null;
    }
    return PlatformModuleCellMutationResult(
      data: nextData,
      statusMessage:
          'Removed cell from module "$moduleId" (rev=${updatedModule.revision}).',
    );
  }

  PlatformModuleCellMutationResult? paintModuleCell({
    required PrefabData data,
    required String moduleId,
    required int gridX,
    required int gridY,
    required String sliceId,
  }) {
    final module = moduleById(data: data, moduleId: moduleId);
    if (module == null) {
      return null;
    }
    final nextData = _mutations.paintModuleCell(
      data: data,
      moduleId: moduleId,
      gridX: gridX,
      gridY: gridY,
      sliceId: sliceId,
    );
    if (identical(nextData, data)) {
      return null;
    }
    final updatedModule = moduleById(data: nextData, moduleId: module.id);
    if (updatedModule == null) {
      return null;
    }
    return PlatformModuleCellMutationResult(
      data: nextData,
      statusMessage:
          'Painted cell ($gridX,$gridY) in "${module.id}" '
          '(rev=${updatedModule.revision}).',
    );
  }

  PlatformModuleCellMutationResult? eraseModuleCell({
    required PrefabData data,
    required String moduleId,
    required int gridX,
    required int gridY,
  }) {
    final module = moduleById(data: data, moduleId: moduleId);
    if (module == null) {
      return null;
    }
    final nextData = _mutations.eraseModuleCell(
      data: data,
      moduleId: moduleId,
      gridX: gridX,
      gridY: gridY,
    );
    if (identical(nextData, data)) {
      return null;
    }
    final updatedModule = moduleById(data: nextData, moduleId: module.id);
    if (updatedModule == null) {
      return null;
    }
    return PlatformModuleCellMutationResult(
      data: nextData,
      statusMessage:
          'Erased cell ($gridX,$gridY) from "${module.id}" '
          '(rev=${updatedModule.revision}).',
    );
  }

  PlatformModuleCellMutationResult? moveModuleCell({
    required PrefabData data,
    required String moduleId,
    required int sourceGridX,
    required int sourceGridY,
    required int targetGridX,
    required int targetGridY,
  }) {
    if (sourceGridX == targetGridX && sourceGridY == targetGridY) {
      return null;
    }
    final module = moduleById(data: data, moduleId: moduleId);
    if (module == null) {
      return null;
    }
    final nextData = _mutations.moveModuleCell(
      data: data,
      moduleId: moduleId,
      sourceGridX: sourceGridX,
      sourceGridY: sourceGridY,
      targetGridX: targetGridX,
      targetGridY: targetGridY,
    );
    if (identical(nextData, data)) {
      return null;
    }
    final updatedModule = moduleById(data: nextData, moduleId: module.id);
    if (updatedModule == null) {
      return null;
    }
    return PlatformModuleCellMutationResult(
      data: nextData,
      statusMessage:
          'Moved cell ($sourceGridX,$sourceGridY) -> '
          '($targetGridX,$targetGridY) in "${module.id}" '
          '(rev=${updatedModule.revision}).',
    );
  }
}

class PlatformModuleCommitResult {
  const PlatformModuleCommitResult({
    required this.data,
    required this.selectedModuleId,
    required this.selectedPrefabPlatformModuleId,
    required this.statusMessage,
  });

  final PrefabData data;
  final String? selectedModuleId;
  final String? selectedPrefabPlatformModuleId;
  final String statusMessage;
}

class PlatformModuleDeleteResult {
  const PlatformModuleDeleteResult({
    required this.data,
    required this.selectedModuleId,
    required this.selectedPrefabPlatformModuleId,
    required this.statusMessage,
  });

  final PrefabData data;
  final String? selectedModuleId;
  final String? selectedPrefabPlatformModuleId;
  final String statusMessage;
}

class PlatformModuleCellMutationResult {
  const PlatformModuleCellMutationResult({
    required this.data,
    required this.statusMessage,
  });

  final PrefabData data;
  final String statusMessage;
}
