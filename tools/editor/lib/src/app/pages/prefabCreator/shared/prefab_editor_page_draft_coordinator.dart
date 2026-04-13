import 'package:flutter/material.dart';

import 'prefab_editor_page_contracts.dart';
import 'prefab_editor_local_draft_history.dart';
import 'prefab_editor_shell_state.dart';
import 'prefab_form_state.dart';

/// Page-shell owner for prefab editor local draft history and snapshot restore.
///
/// This keeps tracked text controllers, draft snapshot capture, and local
/// undo/redo wiring together so the page only coordinates route-level actions.
class PrefabEditorPageDraftCoordinator {
  PrefabEditorPageDraftCoordinator({
    required TextEditingController sliceIdController,
    required TextEditingController selectionXController,
    required TextEditingController selectionYController,
    required TextEditingController selectionWController,
    required TextEditingController selectionHController,
    required TextEditingController moduleIdController,
    required TextEditingController moduleTileSizeController,
    required PrefabFormState obstaclePrefabForm,
    required PrefabFormState platformPrefabForm,
    required PrefabFormState decorationPrefabForm,
    required PrefabEditorShellState shellState,
    required PrefabEditorStateSetter updateState,
    required bool Function() isMounted,
  }) : _sliceIdController = sliceIdController,
       _selectionXController = selectionXController,
       _selectionYController = selectionYController,
       _selectionWController = selectionWController,
       _selectionHController = selectionHController,
       _moduleIdController = moduleIdController,
       _moduleTileSizeController = moduleTileSizeController,
       _obstaclePrefabForm = obstaclePrefabForm,
       _platformPrefabForm = platformPrefabForm,
       _decorationPrefabForm = decorationPrefabForm,
       _shellState = shellState {
    _history = PrefabEditorLocalDraftHistory<PrefabEditorPageDraftSnapshot>(
      trackedControllers: <TextEditingController>[
        sliceIdController,
        moduleIdController,
        moduleTileSizeController,
        selectionXController,
        selectionYController,
        selectionWController,
        selectionHController,
        obstaclePrefabForm.prefabIdController,
        obstaclePrefabForm.anchorXController,
        obstaclePrefabForm.anchorYController,
        obstaclePrefabForm.colliderOffsetXController,
        obstaclePrefabForm.colliderOffsetYController,
        obstaclePrefabForm.colliderWidthController,
        obstaclePrefabForm.colliderHeightController,
        obstaclePrefabForm.tagsController,
        platformPrefabForm.prefabIdController,
        platformPrefabForm.anchorXController,
        platformPrefabForm.anchorYController,
        platformPrefabForm.colliderOffsetXController,
        platformPrefabForm.colliderOffsetYController,
        platformPrefabForm.colliderWidthController,
        platformPrefabForm.colliderHeightController,
        platformPrefabForm.tagsController,
        decorationPrefabForm.prefabIdController,
        decorationPrefabForm.anchorXController,
        decorationPrefabForm.anchorYController,
        decorationPrefabForm.colliderOffsetXController,
        decorationPrefabForm.colliderOffsetYController,
        decorationPrefabForm.colliderWidthController,
        decorationPrefabForm.colliderHeightController,
        decorationPrefabForm.tagsController,
      ],
      captureSnapshot: _captureSnapshot,
      restoreSnapshot: _restoreSnapshot,
      updateState: updateState,
      isMounted: isMounted,
    );
  }

  final TextEditingController _sliceIdController;
  final TextEditingController _selectionXController;
  final TextEditingController _selectionYController;
  final TextEditingController _selectionWController;
  final TextEditingController _selectionHController;
  final TextEditingController _moduleIdController;
  final TextEditingController _moduleTileSizeController;
  final PrefabFormState _obstaclePrefabForm;
  final PrefabFormState _platformPrefabForm;
  final PrefabFormState _decorationPrefabForm;
  final PrefabEditorShellState _shellState;
  late final PrefabEditorLocalDraftHistory<PrefabEditorPageDraftSnapshot>
  _history;

  bool get hasChanges => _history.hasChanges;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  void installListeners() {
    _history.installListeners();
  }

  void dispose() {
    _history.dispose();
  }

  void syncBaseline() {
    _history.syncBaseline();
  }

  void runWithoutTracking(VoidCallback callback) {
    _history.runWithoutTracking(callback);
  }

  void applyMutation(VoidCallback callback) {
    _history.applyMutation(callback);
  }

  bool undo(BuildContext context) {
    return _history.undo(
      context: context,
      afterRestore: () {
        _shellState.statusMessage = 'Undid prefab draft edit.';
        _shellState.errorMessage = null;
      },
    );
  }

  bool redo(BuildContext context) {
    return _history.redo(
      context: context,
      afterRestore: () {
        _shellState.statusMessage = 'Redid prefab draft edit.';
        _shellState.errorMessage = null;
      },
    );
  }

  PrefabEditorPageDraftSnapshot _captureSnapshot() {
    return PrefabEditorPageDraftSnapshot(
      sliceId: _sliceIdController.text,
      selectionX: _selectionXController.text,
      selectionY: _selectionYController.text,
      selectionW: _selectionWController.text,
      selectionH: _selectionHController.text,
      selectedPrefabSliceId: _shellState.selectedPrefabSliceId,
      selectedPrefabPlatformModuleId:
          _shellState.selectedPrefabPlatformModuleId,
      moduleId: _moduleIdController.text,
      moduleTileSize: _moduleTileSizeController.text,
      obstacleForm: _obstaclePrefabForm.captureDraftSnapshot(),
      platformForm: _platformPrefabForm.captureDraftSnapshot(),
      decorationForm: _decorationPrefabForm.captureDraftSnapshot(),
    );
  }

  void _restoreSnapshot(PrefabEditorPageDraftSnapshot snapshot) {
    runWithoutTracking(() {
      _sliceIdController.text = snapshot.sliceId;
      _selectionXController.text = snapshot.selectionX;
      _selectionYController.text = snapshot.selectionY;
      _selectionWController.text = snapshot.selectionW;
      _selectionHController.text = snapshot.selectionH;
      _shellState.selectedPrefabSliceId = snapshot.selectedPrefabSliceId;
      _shellState.selectedPrefabPlatformModuleId =
          snapshot.selectedPrefabPlatformModuleId;
      _moduleIdController.text = snapshot.moduleId;
      _moduleTileSizeController.text = snapshot.moduleTileSize;
      _obstaclePrefabForm.restoreDraftSnapshot(snapshot.obstacleForm);
      _platformPrefabForm.restoreDraftSnapshot(snapshot.platformForm);
      _decorationPrefabForm.restoreDraftSnapshot(snapshot.decorationForm);
    });
  }
}

class PrefabEditorPageDraftSnapshot {
  const PrefabEditorPageDraftSnapshot({
    required this.sliceId,
    required this.selectionX,
    required this.selectionY,
    required this.selectionW,
    required this.selectionH,
    required this.selectedPrefabSliceId,
    required this.selectedPrefabPlatformModuleId,
    required this.moduleId,
    required this.moduleTileSize,
    required this.obstacleForm,
    required this.platformForm,
    required this.decorationForm,
  });

  final String sliceId;
  final String selectionX;
  final String selectionY;
  final String selectionW;
  final String selectionH;
  final String? selectedPrefabSliceId;
  final String? selectedPrefabPlatformModuleId;
  final String moduleId;
  final String moduleTileSize;
  final PrefabFormDraftSnapshot obstacleForm;
  final PrefabFormDraftSnapshot platformForm;
  final PrefabFormDraftSnapshot decorationForm;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PrefabEditorPageDraftSnapshot &&
        other.sliceId == sliceId &&
        other.selectionX == selectionX &&
        other.selectionY == selectionY &&
        other.selectionW == selectionW &&
        other.selectionH == selectionH &&
        other.selectedPrefabSliceId == selectedPrefabSliceId &&
        other.selectedPrefabPlatformModuleId ==
            selectedPrefabPlatformModuleId &&
        other.moduleId == moduleId &&
        other.moduleTileSize == moduleTileSize &&
        other.obstacleForm == obstacleForm &&
        other.platformForm == platformForm &&
        other.decorationForm == decorationForm;
  }

  @override
  int get hashCode => Object.hashAll([
    sliceId,
    selectionX,
    selectionY,
    selectionW,
    selectionH,
    selectedPrefabSliceId,
    selectedPrefabPlatformModuleId,
    moduleId,
    moduleTileSize,
    obstacleForm,
    platformForm,
    decorationForm,
  ]);
}
