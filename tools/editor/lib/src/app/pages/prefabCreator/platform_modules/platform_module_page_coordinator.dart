import 'package:flutter/material.dart';

import '../../../../prefabs/models/models.dart';
import '../shared/prefab_editor_page_contracts.dart';
import '../shared/prefab_form_state.dart';
import '../shared/prefab_editor_shell_state.dart';
import '../shared/prefab_scene_values.dart';
import 'platform_module_controller.dart';
import 'platform_modules_tab.dart';

/// Page-shell coordinator for platform-module editing and its output tab.
///
/// Domain mutations stay in [PlatformModuleController]; this layer only keeps
/// the page-level tab wiring and selection choreography out of the main shell.
class PlatformModulePageCoordinator {
  const PlatformModulePageCoordinator({
    required PlatformModuleController moduleController,
    required PrefabEditorShellState shellState,
    required TextEditingController moduleIdController,
    required TextEditingController moduleTileSizeController,
    required PrefabFormState platformPrefabForm,
    required String Function() readWorkspaceRootPath,
    required PrefabEditorStateSetter updateState,
    required PrefabEditorLocalDraftMutation runWithoutLocalDraftHistory,
    required PrefabEditorCommitDataChange commitPrefabDataChange,
    required VoidCallback onPlatformPrefabLoad,
    required VoidCallback onPlatformPrefabUpsert,
    required ValueChanged<PrefabSceneValues> onPlatformPrefabSceneValuesChanged,
  }) : _moduleController = moduleController,
       _shellState = shellState,
       _moduleIdController = moduleIdController,
       _moduleTileSizeController = moduleTileSizeController,
       _platformPrefabForm = platformPrefabForm,
       _readWorkspaceRootPath = readWorkspaceRootPath,
       _updateState = updateState,
       _runWithoutLocalDraftHistory = runWithoutLocalDraftHistory,
       _commitPrefabDataChange = commitPrefabDataChange,
       _onPlatformPrefabLoad = onPlatformPrefabLoad,
       _onPlatformPrefabUpsert = onPlatformPrefabUpsert,
       _onPlatformPrefabSceneValuesChanged = onPlatformPrefabSceneValuesChanged;

  final PlatformModuleController _moduleController;
  final PrefabEditorShellState _shellState;
  final TextEditingController _moduleIdController;
  final TextEditingController _moduleTileSizeController;
  final PrefabFormState _platformPrefabForm;
  final String Function() _readWorkspaceRootPath;
  final PrefabEditorStateSetter _updateState;
  final PrefabEditorLocalDraftMutation _runWithoutLocalDraftHistory;
  final PrefabEditorCommitDataChange _commitPrefabDataChange;
  final VoidCallback _onPlatformPrefabLoad;
  final VoidCallback _onPlatformPrefabUpsert;
  final ValueChanged<PrefabSceneValues> _onPlatformPrefabSceneValuesChanged;

  Widget buildTab() {
    final data = _shellState.data;
    final modules = data.platformModules;
    final selectedModule = this.selectedModule();
    final sceneValues = _platformPrefabForm.tryParseSceneValues();

    return PlatformModulesTab(
      moduleIdController: _moduleIdController,
      moduleTileSizeController: _moduleTileSizeController,
      modules: modules,
      selectedModuleId: _shellState.selectedModuleId,
      selectedModule: selectedModule,
      tileSlices: data.tileSlices,
      selectedTileSliceId: _shellState.selectedTileSliceId,
      selectedModuleSceneTool: _shellState.selectedModuleSceneTool,
      sceneValues: sceneValues,
      workspaceRootPath: _readWorkspaceRootPath(),
      platformPrefabForm: _platformPrefabForm,
      onUpsertModule: upsertModuleFromForm,
      onRenameSelectedModule: renameSelectedModuleFromForm,
      onDuplicateSelectedModule: duplicateSelectedModule,
      onToggleDeprecateSelectedModule: toggleDeprecateSelectedModule,
      onSelectedModuleChanged: (value) {
        _updateState(() {
          _shellState.selectedModuleId = value;
          if (value == null) {
            return;
          }
          final module = modules.firstWhere(
            (candidate) => candidate.id == value,
          );
          _moduleIdController.text = module.id;
          _moduleTileSizeController.text = module.tileSize.toString();
        });
      },
      onSelectedTileSliceChanged: (value) {
        _updateState(() {
          _shellState.selectedTileSliceId = value;
        });
      },
      onPlatformPrefabSnapToGridChanged: (value) {
        _updateState(() {
          _platformPrefabForm.snapToGrid = value;
        });
      },
      onPlatformPrefabLoad: _onPlatformPrefabLoad,
      onPlatformPrefabUpsert: _onPlatformPrefabUpsert,
      onPlatformPrefabSceneValuesChanged: _onPlatformPrefabSceneValuesChanged,
      onModuleSceneToolChanged: (tool) {
        _updateState(() {
          _shellState.selectedModuleSceneTool = tool;
        });
      },
      onPaintCell: (gridX, gridY, sliceId) {
        paintCellInSelectedModuleAt(
          gridX: gridX,
          gridY: gridY,
          sliceId: sliceId,
        );
      },
      onEraseCell: (gridX, gridY) {
        eraseCellInSelectedModuleAt(gridX: gridX, gridY: gridY);
      },
      onMoveCell: (sourceGridX, sourceGridY, targetGridX, targetGridY) {
        moveCellInSelectedModuleAt(
          sourceGridX: sourceGridX,
          sourceGridY: sourceGridY,
          targetGridX: targetGridX,
          targetGridY: targetGridY,
        );
      },
      onDeleteModule: deleteModule,
      onDeleteModuleCell: (moduleId, cellIndex) {
        deleteModuleCell(moduleId: moduleId, cellIndex: cellIndex);
      },
    );
  }

  TileModuleDef? moduleById(String moduleId) {
    return _moduleController.moduleById(
      data: _shellState.data,
      moduleId: moduleId,
    );
  }

  TileModuleDef? selectedModule() {
    return _moduleController.selectedModule(
      data: _shellState.data,
      selectedModuleId: _shellState.selectedModuleId,
    );
  }

  void syncSelectedModuleInputs() {
    final selectedModule = this.selectedModule();
    _runWithoutLocalDraftHistory(() {
      if (selectedModule == null) {
        _moduleIdController.clear();
        _moduleTileSizeController.text = '16';
        return;
      }
      _moduleIdController.text = selectedModule.id;
      _moduleTileSizeController.text = selectedModule.tileSize.toString();
    });
  }

  void upsertModuleFromForm() {
    final decision = _moduleController.upsertFromForm(
      data: _shellState.data,
      rawId: _moduleIdController.text,
      rawTileSize: _moduleTileSizeController.text,
      currentPrefabPlatformModuleId: _shellState.selectedPrefabPlatformModuleId,
    );
    if (decision.error != null) {
      _setError(decision.error!);
      return;
    }
    final result = decision.value!;
    _commitPrefabDataChange(
      nextData: result.data,
      beforeSync: () {
        _shellState.selectedModuleId = result.selectedModuleId;
        _shellState.selectedPrefabPlatformModuleId =
            result.selectedPrefabPlatformModuleId;
      },
      statusMessage: result.statusMessage,
    );
  }

  void duplicateSelectedModule() {
    final decision = _moduleController.duplicateSelectedModule(
      data: _shellState.data,
      source: selectedModule(),
      rawNextId: _moduleIdController.text,
      currentPrefabPlatformModuleId: _shellState.selectedPrefabPlatformModuleId,
    );
    if (decision.error != null) {
      _setError(decision.error!);
      return;
    }
    final result = decision.value!;
    _commitPrefabDataChange(
      nextData: result.data,
      beforeSync: () {
        _shellState.selectedModuleId = result.selectedModuleId;
        _shellState.selectedPrefabPlatformModuleId =
            result.selectedPrefabPlatformModuleId;
      },
      statusMessage: result.statusMessage,
    );
  }

  void renameSelectedModuleFromForm() {
    final decision = _moduleController.renameSelectedModule(
      data: _shellState.data,
      source: selectedModule(),
      rawNextId: _moduleIdController.text,
      currentPrefabPlatformModuleId: _shellState.selectedPrefabPlatformModuleId,
    );
    if (decision.error != null) {
      _setError(decision.error!);
      return;
    }
    final result = decision.value!;
    _commitPrefabDataChange(
      nextData: result.data,
      beforeSync: () {
        _shellState.selectedModuleId = result.selectedModuleId;
        _shellState.selectedPrefabPlatformModuleId =
            result.selectedPrefabPlatformModuleId;
      },
      statusMessage: result.statusMessage,
    );
  }

  void toggleDeprecateSelectedModule() {
    final decision = _moduleController.toggleDeprecateSelectedModule(
      data: _shellState.data,
      source: selectedModule(),
      currentPrefabPlatformModuleId: _shellState.selectedPrefabPlatformModuleId,
    );
    if (decision.error != null) {
      _setError(decision.error!);
      return;
    }
    final result = decision.value!;
    _commitPrefabDataChange(
      nextData: result.data,
      beforeSync: () {
        _shellState.selectedModuleId = result.selectedModuleId;
        _shellState.selectedPrefabPlatformModuleId =
            result.selectedPrefabPlatformModuleId;
      },
      statusMessage: result.statusMessage,
    );
  }

  void deleteModule(String moduleId) {
    final decision = _moduleController.deleteModule(
      data: _shellState.data,
      moduleId: moduleId,
      currentSelectedModuleId: _shellState.selectedModuleId,
      currentPrefabPlatformModuleId: _shellState.selectedPrefabPlatformModuleId,
    );
    if (decision.error != null) {
      _setError(decision.error!);
      return;
    }
    final result = decision.value!;
    _commitPrefabDataChange(
      nextData: result.data,
      beforeSync: () {
        _shellState.selectedModuleId = result.selectedModuleId;
        _shellState.selectedPrefabPlatformModuleId =
            result.selectedPrefabPlatformModuleId;
      },
      statusMessage: result.statusMessage,
    );
  }

  void deleteModuleCell({required String moduleId, required int cellIndex}) {
    final result = _moduleController.deleteModuleCell(
      data: _shellState.data,
      moduleId: moduleId,
      cellIndex: cellIndex,
    );
    if (result == null) {
      return;
    }
    _commitPrefabDataChange(
      nextData: result.data,
      statusMessage: result.statusMessage,
    );
  }

  void paintCellInSelectedModuleAt({
    required int gridX,
    required int gridY,
    required String sliceId,
  }) {
    final module = selectedModule();
    if (module == null) {
      return;
    }
    _paintCellInModuleAt(
      moduleId: module.id,
      gridX: gridX,
      gridY: gridY,
      sliceId: sliceId,
    );
  }

  void eraseCellInSelectedModuleAt({required int gridX, required int gridY}) {
    final module = selectedModule();
    if (module == null) {
      return;
    }
    _eraseCellInModuleAt(moduleId: module.id, gridX: gridX, gridY: gridY);
  }

  void moveCellInSelectedModuleAt({
    required int sourceGridX,
    required int sourceGridY,
    required int targetGridX,
    required int targetGridY,
  }) {
    final module = selectedModule();
    if (module == null) {
      return;
    }
    _moveCellInModuleAt(
      moduleId: module.id,
      sourceGridX: sourceGridX,
      sourceGridY: sourceGridY,
      targetGridX: targetGridX,
      targetGridY: targetGridY,
    );
  }

  void _paintCellInModuleAt({
    required String moduleId,
    required int gridX,
    required int gridY,
    required String sliceId,
  }) {
    final result = _moduleController.paintModuleCell(
      data: _shellState.data,
      moduleId: moduleId,
      gridX: gridX,
      gridY: gridY,
      sliceId: sliceId,
    );
    if (result == null) {
      return;
    }
    _commitPrefabDataChange(
      nextData: result.data,
      statusMessage: result.statusMessage,
    );
  }

  void _eraseCellInModuleAt({
    required String moduleId,
    required int gridX,
    required int gridY,
  }) {
    final result = _moduleController.eraseModuleCell(
      data: _shellState.data,
      moduleId: moduleId,
      gridX: gridX,
      gridY: gridY,
    );
    if (result == null) {
      return;
    }
    _commitPrefabDataChange(
      nextData: result.data,
      statusMessage: result.statusMessage,
    );
  }

  void _moveCellInModuleAt({
    required String moduleId,
    required int sourceGridX,
    required int sourceGridY,
    required int targetGridX,
    required int targetGridY,
  }) {
    final result = _moduleController.moveModuleCell(
      data: _shellState.data,
      moduleId: moduleId,
      sourceGridX: sourceGridX,
      sourceGridY: sourceGridY,
      targetGridX: targetGridX,
      targetGridY: targetGridY,
    );
    if (result == null) {
      return;
    }
    _commitPrefabDataChange(
      nextData: result.data,
      statusMessage: result.statusMessage,
    );
  }

  void _setError(String message) {
    _updateState(() {
      _shellState.setError(message);
    });
  }
}
