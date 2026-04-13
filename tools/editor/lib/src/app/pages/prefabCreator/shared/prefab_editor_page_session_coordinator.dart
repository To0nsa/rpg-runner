import 'package:flutter/material.dart';

import '../../../../prefabs/atlas/workspace_scoped_size_cache.dart';
import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../prefabs/store/prefab_store.dart';
import '../../../../session/editor_session_controller.dart';
import '../atlas_slicer/atlas_slicer_page_coordinator.dart';
import '../platform_modules/platform_module_page_coordinator.dart';
import 'prefab_editor_page_contracts.dart';
import 'prefab_editor_page_coordinator.dart';
import 'prefab_editor_scene_projection.dart';
import 'prefab_editor_session_bridge.dart';
import 'prefab_editor_shell_state.dart';
import 'prefab_editor_workspace_io.dart';
import 'prefab_form_state.dart';

/// Page-shell coordinator for committed prefab session state and workspace I/O.
///
/// This owns reload/save/apply-scene mechanics so the page shell stays focused
/// on top-level route composition instead of session protocol details.
class PrefabEditorPageSessionCoordinator {
  const PrefabEditorPageSessionCoordinator({
    required EditorSessionController Function() readController,
    required BuildContext Function() readContext,
    required bool Function() isMounted,
    required WorkspaceScopedSizeCache atlasImageSizes,
    required PrefabEditorWorkspaceIo workspaceIo,
    required PrefabEditorSceneProjectionHelper sceneProjection,
    required PrefabEditorSessionBridge sessionBridge,
    required AtlasSlicerPageCoordinator atlasPageCoordinator,
    required PrefabEditorPageCoordinator prefabPageCoordinator,
    required PlatformModulePageCoordinator platformModulePageCoordinator,
    required PrefabEditorShellState shellState,
    required PrefabEditorStateSetter updateState,
    required VoidCallback ensurePrefabPluginSelection,
    required VoidCallback syncFormDraftBaseline,
    required String levelAssetsPath,
    required PrefabFormState obstaclePrefabForm,
    required PrefabFormState platformPrefabForm,
    required PrefabFormState decorationPrefabForm,
  }) : _readController = readController,
       _readContext = readContext,
       _isMounted = isMounted,
       _atlasImageSizes = atlasImageSizes,
       _workspaceIo = workspaceIo,
       _sceneProjection = sceneProjection,
       _sessionBridge = sessionBridge,
       _atlasPageCoordinator = atlasPageCoordinator,
       _prefabPageCoordinator = prefabPageCoordinator,
       _platformModulePageCoordinator = platformModulePageCoordinator,
       _shellState = shellState,
       _updateState = updateState,
       _ensurePrefabPluginSelection = ensurePrefabPluginSelection,
       _syncFormDraftBaseline = syncFormDraftBaseline,
       _levelAssetsPath = levelAssetsPath,
       _obstaclePrefabForm = obstaclePrefabForm,
       _platformPrefabForm = platformPrefabForm,
       _decorationPrefabForm = decorationPrefabForm;

  final EditorSessionController Function() _readController;
  final BuildContext Function() _readContext;
  final bool Function() _isMounted;
  final WorkspaceScopedSizeCache _atlasImageSizes;
  final PrefabEditorWorkspaceIo _workspaceIo;
  final PrefabEditorSceneProjectionHelper _sceneProjection;
  final PrefabEditorSessionBridge _sessionBridge;
  final AtlasSlicerPageCoordinator _atlasPageCoordinator;
  final PrefabEditorPageCoordinator _prefabPageCoordinator;
  final PlatformModulePageCoordinator _platformModulePageCoordinator;
  final PrefabEditorShellState _shellState;
  final PrefabEditorStateSetter _updateState;
  final VoidCallback _ensurePrefabPluginSelection;
  final VoidCallback _syncFormDraftBaseline;
  final String _levelAssetsPath;
  final PrefabFormState _obstaclePrefabForm;
  final PrefabFormState _platformPrefabForm;
  final PrefabFormState _decorationPrefabForm;

  Future<void> reloadData() async {
    final workspacePath = _readController().workspacePath.trim();
    if (workspacePath.isEmpty) {
      _updateState(() {
        _shellState.errorMessage =
            'Workspace path is empty. Set workspace path then reload.';
        _shellState.statusMessage = null;
      });
      return;
    }

    _updateState(() {
      _shellState.isLoading = true;
      _shellState.errorMessage = null;
      _shellState.statusMessage = null;
    });

    try {
      _ensurePrefabPluginSelection();
      final result = await _workspaceIo.load(
        controller: _readController(),
        atlasImageSizes: _atlasImageSizes,
        workspacePath: workspacePath,
        previousAtlasSelection: _shellState.atlasState.selectedAtlasPath,
        levelAssetsPath: _levelAssetsPath,
      );
      if (!_isMounted()) {
        return;
      }

      final scene = result.scene;
      final projection = _sceneProjection.projectLoadedData(
        data: scene.data,
        atlasImagePaths: result.atlasImagePaths,
        selectedAtlasPath: result.selectedAtlasPath,
      );

      _updateState(() {
        _shellState.data = projection.data;
        _shellState.atlasImagePaths = projection.atlasImagePaths;
        _shellState.atlasState = _shellState.atlasState.withSelectedAtlasPath(
          projection.selectedAtlasPath,
        );
        _atlasPageCoordinator.clearSelection();
        _shellState.selectedPrefabSliceId = projection.selectedPrefabSliceId;
        _prefabPageCoordinator.resetPrefabFormsForLoadedData(
          defaultPlatformModuleId: projection.defaultPlatformModuleId,
          defaultPlatformTileSize: projection.defaultPlatformTileSize,
        );
        _shellState.selectedTileSliceId = projection.selectedTileSliceId;
        _shellState.selectedModuleId = projection.selectedModuleId;
        _platformModulePageCoordinator.syncSelectedModuleInputs();
        _syncFormDraftBaseline();
        final hints = scene.migrationHints;
        _shellState.statusMessage = hints.isEmpty
            ? 'Loaded prefab/tile authoring data.'
            : 'Loaded prefab/tile authoring data. ${hints.join(' ')}';
      });
    } catch (error) {
      _updateState(() {
        _shellState.errorMessage = 'Reload failed: $error';
      });
    } finally {
      _updateState(() {
        _shellState.isLoading = false;
      });
    }
  }

  Future<void> saveData() async {
    final workspacePath = _readController().workspacePath.trim();
    if (workspacePath.isEmpty) {
      _updateState(() {
        _shellState.errorMessage = 'Workspace path is empty. Cannot save.';
        _shellState.statusMessage = null;
      });
      return;
    }

    _updateState(() {
      _shellState.isSaving = true;
      _shellState.errorMessage = null;
      _shellState.statusMessage = null;
    });
    try {
      _ensurePrefabPluginSelection();
      await _workspaceIo.save(
        controller: _readController(),
        atlasImageSizes: _atlasImageSizes,
        data: _shellState.data,
        workspacePath: workspacePath,
      );
      if (!_isMounted()) {
        return;
      }
      syncStateFromControllerScene();
      _updateState(() {
        _shellState.statusMessage =
            'Saved ${PrefabStore.prefabDefsPath} and ${PrefabStore.tileDefsPath}.';
      });
    } on PrefabEditorValidationException catch (error) {
      _updateState(() {
        _shellState.errorMessage = error.errors.join('\n');
        _shellState.statusMessage = null;
      });
    } catch (error) {
      _updateState(() {
        _shellState.errorMessage = 'Save failed: $error';
      });
    } finally {
      _updateState(() {
        _shellState.isSaving = false;
      });
    }
  }

  void commitPrefabDataChange({
    required PrefabData nextData,
    required String statusMessage,
    VoidCallback? beforeSync,
  }) {
    FocusScope.of(_readContext()).unfocus();
    PrefabScene scene;
    try {
      scene = _sessionBridge.applyPrefabDataChange(
        controller: _readController(),
        nextData: nextData,
      );
    } on PrefabEditorSessionException catch (error) {
      _setError(error.message);
      return;
    }

    _updateState(() {
      beforeSync?.call();
      _applySceneSnapshot(scene);
      _shellState.statusMessage = statusMessage;
      _shellState.errorMessage = null;
    });
  }

  void undoCommittedEdit() {
    PrefabScene? scene;
    try {
      scene = _sessionBridge.undoCommittedEdit(_readController());
    } on PrefabEditorSessionException catch (error) {
      _setError(error.message);
      return;
    }
    if (scene == null) {
      return;
    }
    _updateState(() {
      _applySceneSnapshot(scene!);
      _shellState.statusMessage = 'Undid prefab/module edit.';
      _shellState.errorMessage = null;
    });
  }

  void redoCommittedEdit() {
    PrefabScene? scene;
    try {
      scene = _sessionBridge.redoCommittedEdit(_readController());
    } on PrefabEditorSessionException catch (error) {
      _setError(error.message);
      return;
    }
    if (scene == null) {
      return;
    }
    _updateState(() {
      _applySceneSnapshot(scene!);
      _shellState.statusMessage = 'Redid prefab/module edit.';
      _shellState.errorMessage = null;
    });
  }

  void syncStateFromControllerScene({String? statusMessage}) {
    PrefabScene scene;
    try {
      scene = _sessionBridge.requireCurrentPrefabScene(_readController());
    } on PrefabEditorSessionException catch (error) {
      _setError(error.message);
      return;
    }
    _updateState(() {
      _applySceneSnapshot(scene);
      _shellState.statusMessage = statusMessage;
      _shellState.errorMessage = null;
    });
  }

  bool hasSerializedDataChanges() {
    final scene = _sessionBridge.currentPrefabScene(_readController());
    if (scene == null) {
      return false;
    }
    return _sceneProjection.hasSerializedDataChanges(
      currentData: _shellState.data,
      baselineScene: scene,
    );
  }

  void _applySceneSnapshot(PrefabScene scene) {
    final projection = _sceneProjection.projectScene(
      scene: scene,
      currentAtlasSelection: _shellState.atlasState.selectedAtlasPath,
      currentPrefabSliceSelection: _shellState.selectedPrefabSliceId,
      currentTileSliceSelection: _shellState.selectedTileSliceId,
      currentModuleSelection: _shellState.selectedModuleId,
      currentPrefabPlatformModuleSelection:
          _shellState.selectedPrefabPlatformModuleId,
    );

    _shellState.data = projection.data;
    _shellState.atlasImagePaths = projection.atlasImagePaths;
    _shellState.atlasState = _shellState.atlasState.withSelectedAtlasPath(
      projection.selectedAtlasPath,
    );
    for (final entry in scene.atlasImageSizes.entries) {
      _atlasImageSizes[entry.key] = entry.value;
    }

    _shellState.selectedPrefabSliceId = projection.selectedPrefabSliceId;
    _shellState.selectedTileSliceId = projection.selectedTileSliceId;
    _shellState.selectedModuleId = projection.selectedModuleId;
    _shellState.selectedPrefabPlatformModuleId =
        projection.selectedPrefabPlatformModuleId;
    _platformModulePageCoordinator.syncSelectedModuleInputs();

    final editingObstaclePrefab = _prefabPageCoordinator.editingPrefabForForm(
      _obstaclePrefabForm,
    );
    if (editingObstaclePrefab != null) {
      _prefabPageCoordinator.applyPrefabToForm(
        _obstaclePrefabForm,
        editingObstaclePrefab,
        setStatusMessage: false,
      );
    } else {
      _obstaclePrefabForm.editingPrefabKey = null;
    }

    final editingPlatformPrefab = _prefabPageCoordinator.editingPrefabForForm(
      _platformPrefabForm,
    );
    if (editingPlatformPrefab != null) {
      _prefabPageCoordinator.applyPrefabToForm(
        _platformPrefabForm,
        editingPlatformPrefab,
        setStatusMessage: false,
      );
    } else {
      _platformPrefabForm.editingPrefabKey = null;
    }

    final editingDecorationPrefab = _prefabPageCoordinator.editingPrefabForForm(
      _decorationPrefabForm,
    );
    if (editingDecorationPrefab != null) {
      _prefabPageCoordinator.applyPrefabToForm(
        _decorationPrefabForm,
        editingDecorationPrefab,
        setStatusMessage: false,
      );
    } else {
      _decorationPrefabForm.editingPrefabKey = null;
    }
    _syncFormDraftBaseline();
  }

  void _setError(String message) {
    _updateState(() {
      _shellState.setError(message);
    });
  }
}
