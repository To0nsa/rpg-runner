import 'package:flutter/material.dart';

import '../../../../prefabs/models/models.dart';
import '../decoration_prefabs/decoration_prefabs_tab.dart';
import '../obstacle_prefabs/obstacle_prefabs_tab.dart';
import '../platform_modules/platform_module_controller.dart';
import '../platform_prefabs/platform_prefab_controller.dart';
import '../platform_prefabs/platform_prefabs_tab.dart';
import 'prefab_editor_data_reducer.dart';
import 'prefab_editor_page_contracts.dart';
import 'prefab_editor_mutations.dart';
import 'prefab_editor_prefab_controller.dart';
import 'prefab_editor_shell_state.dart';
import 'prefab_form_state.dart';
import 'prefab_scene_values.dart';

/// Page-shell coordination for obstacle/platform/decoration prefab authoring.
///
/// The prefab page still owns session commits and controller lifetimes, but
/// this seam keeps prefab-form orchestration out of the large shell widget.
class PrefabEditorPageCoordinator {
  const PrefabEditorPageCoordinator({
    required PrefabEditorPrefabController prefabController,
    required PlatformPrefabController platformPrefabController,
    required PlatformModuleController platformModuleController,
    required PrefabEditorDataReducer dataReducer,
    required PrefabEditorMutations mutations,
    required PrefabEditorShellState shellState,
    required PrefabFormState obstaclePrefabForm,
    required PrefabFormState platformPrefabForm,
    required PrefabFormState decorationPrefabForm,
    required TextEditingController moduleTileSizeController,
    required String Function() readWorkspaceRootPath,
    required PrefabEditorStateSetter updateState,
    required PrefabEditorLocalDraftMutation runWithoutLocalDraftHistory,
    required PrefabEditorLocalDraftMutation applyLocalDraftMutation,
    required VoidCallback syncFormDraftBaseline,
    required PrefabEditorCommitDataChange commitPrefabDataChange,
  }) : _prefabController = prefabController,
       _platformPrefabController = platformPrefabController,
       _platformModuleController = platformModuleController,
       _dataReducer = dataReducer,
       _mutations = mutations,
       _shellState = shellState,
       _obstaclePrefabForm = obstaclePrefabForm,
       _platformPrefabForm = platformPrefabForm,
       _decorationPrefabForm = decorationPrefabForm,
       _moduleTileSizeController = moduleTileSizeController,
       _readWorkspaceRootPath = readWorkspaceRootPath,
       _updateState = updateState,
       _runWithoutLocalDraftHistory = runWithoutLocalDraftHistory,
       _applyLocalDraftMutation = applyLocalDraftMutation,
       _syncFormDraftBaseline = syncFormDraftBaseline,
       _commitPrefabDataChange = commitPrefabDataChange;

  final PrefabEditorPrefabController _prefabController;
  final PlatformPrefabController _platformPrefabController;
  final PlatformModuleController _platformModuleController;
  final PrefabEditorDataReducer _dataReducer;
  final PrefabEditorMutations _mutations;
  final PrefabEditorShellState _shellState;
  final PrefabFormState _obstaclePrefabForm;
  final PrefabFormState _platformPrefabForm;
  final PrefabFormState _decorationPrefabForm;
  final TextEditingController _moduleTileSizeController;
  final String Function() _readWorkspaceRootPath;
  final PrefabEditorStateSetter _updateState;
  final PrefabEditorLocalDraftMutation _runWithoutLocalDraftHistory;
  final PrefabEditorLocalDraftMutation _applyLocalDraftMutation;
  final VoidCallback _syncFormDraftBaseline;
  final PrefabEditorCommitDataChange _commitPrefabDataChange;

  Widget buildObstaclePrefabsTab() {
    final data = _shellState.data;
    final editingPrefab = editingPrefabForForm(_obstaclePrefabForm);
    final editingObstaclePrefab =
        editingPrefab != null && editingPrefab.kind == PrefabKind.obstacle
        ? editingPrefab
        : null;
    final selectablePrefabSlices = _selectablePrefabSlicesForKind(
      kind: PrefabKind.obstacle,
      editingPrefab: editingObstaclePrefab,
    );
    final selectedSlice = findSliceById(
      slices: selectablePrefabSlices,
      sliceId: _shellState.selectedPrefabSliceId,
    );
    final sceneValues = _obstaclePrefabForm.tryParseSceneValues();

    return ObstaclePrefabsTab(
      form: _obstaclePrefabForm,
      prefabSlices: data.prefabSlices,
      selectablePrefabSlices: selectablePrefabSlices,
      obstaclePrefabs: data.prefabs
          .where((prefab) => prefab.kind == PrefabKind.obstacle)
          .toList(growable: false),
      selectedSliceId: _shellState.selectedPrefabSliceId,
      selectedSlice: selectedSlice,
      editingObstaclePrefab: editingObstaclePrefab,
      sceneValues: sceneValues,
      colliderDrafts: _obstaclePrefabForm.colliderDrafts,
      selectedColliderIndex: _obstaclePrefabForm.selectedColliderIndex,
      workspaceRootPath: _readWorkspaceRootPath(),
      onSelectedSliceChanged: (value) {
        _updateState(() {
          final previousSelectedSliceId = _shellState.selectedPrefabSliceId;
          _shellState.selectedPrefabSliceId = value;
          syncPrefabIdsWithSelectedSlice(
            previousSelectedSliceId: previousSelectedSliceId,
          );
        });
      },
      onSceneValuesChanged: onObstaclePrefabSceneValuesChanged,
      onSelectedColliderChanged: (index) {
        _applyColliderMutation(
          form: _obstaclePrefabForm,
          mutate: () => _obstaclePrefabForm.selectCollider(index),
        );
      },
      onAddCollider: () {
        _applyColliderMutation(
          form: _obstaclePrefabForm,
          mutate: _obstaclePrefabForm.addCollider,
        );
      },
      onDuplicateCollider: () {
        _applyColliderMutation(
          form: _obstaclePrefabForm,
          mutate: _obstaclePrefabForm.duplicateSelectedCollider,
        );
      },
      onDeleteCollider: _obstaclePrefabForm.canDeleteSelectedCollider
          ? () {
              _applyColliderMutation(
                form: _obstaclePrefabForm,
                mutate: _obstaclePrefabForm.deleteSelectedCollider,
              );
            }
          : null,
      onLoadPrefab: loadPrefabIntoForm,
      onDeletePrefab: deletePrefab,
      onUpsertPrefab: upsertObstaclePrefabFromForm,
      onDuplicatePrefab: duplicateLoadedObstaclePrefab,
      onDeprecatePrefab: deprecateLoadedObstaclePrefab,
      onStartNewFromCurrentValues: startNewObstaclePrefabFromCurrentValues,
      onClearForm: clearObstaclePrefabForm,
    );
  }

  Widget buildDecorationPrefabsTab() {
    final data = _shellState.data;
    final editingPrefab = editingPrefabForForm(_decorationPrefabForm);
    final editingDecorationPrefab =
        editingPrefab != null && editingPrefab.kind == PrefabKind.decoration
        ? editingPrefab
        : null;
    final selectablePrefabSlices = _selectablePrefabSlicesForKind(
      kind: PrefabKind.decoration,
      editingPrefab: editingDecorationPrefab,
    );
    final selectedSlice = findSliceById(
      slices: selectablePrefabSlices,
      sliceId: _shellState.selectedPrefabSliceId,
    );
    final sceneValues = _decorationPrefabForm.tryParseSceneValues();

    return DecorationPrefabsTab(
      form: _decorationPrefabForm,
      prefabSlices: data.prefabSlices,
      selectablePrefabSlices: selectablePrefabSlices,
      decorationPrefabs: data.prefabs
          .where((prefab) => prefab.kind == PrefabKind.decoration)
          .toList(growable: false),
      selectedSliceId: _shellState.selectedPrefabSliceId,
      selectedSlice: selectedSlice,
      editingDecorationPrefab: editingDecorationPrefab,
      sceneValues: sceneValues,
      workspaceRootPath: _readWorkspaceRootPath(),
      onSelectedSliceChanged: (value) {
        _updateState(() {
          final previousSelectedSliceId = _shellState.selectedPrefabSliceId;
          _shellState.selectedPrefabSliceId = value;
          syncPrefabIdsWithSelectedSlice(
            previousSelectedSliceId: previousSelectedSliceId,
          );
        });
      },
      onSceneValuesChanged: onDecorationPrefabSceneValuesChanged,
      onLoadPrefab: loadPrefabIntoForm,
      onDeletePrefab: deletePrefab,
      onUpsertPrefab: upsertDecorationPrefabFromForm,
      onDuplicatePrefab: duplicateLoadedDecorationPrefab,
      onDeprecatePrefab: deprecateLoadedDecorationPrefab,
      onStartNewFromCurrentValues: startNewDecorationPrefabFromCurrentValues,
      onClearForm: clearDecorationPrefabForm,
    );
  }

  Widget buildPlatformPrefabsTab() {
    final data = _shellState.data;
    final selectedPrefabPlatformModuleId =
        _shellState.selectedPrefabPlatformModuleId;
    final selectedModule = _platformModuleController.selectedModule(
      data: data,
      selectedModuleId: selectedPrefabPlatformModuleId,
    );
    final sceneValues = _platformPrefabForm.tryParseSceneValues();
    final editingPrefab = editingPrefabForForm(_platformPrefabForm);
    final editingPlatformPrefab =
        editingPrefab != null && editingPrefab.kind == PrefabKind.platform
        ? editingPrefab
        : null;

    return PlatformPrefabsTab(
      form: _platformPrefabForm,
      modules: data.platformModules,
      selectedModuleId: selectedPrefabPlatformModuleId,
      selectedModule: selectedModule,
      tileSlices: data.tileSlices,
      platformPrefabs: data.prefabs
          .where((prefab) => prefab.kind == PrefabKind.platform)
          .toList(growable: false),
      editingPlatformPrefab: editingPlatformPrefab,
      sceneValues: sceneValues,
      colliderDrafts: _platformPrefabForm.colliderDrafts,
      selectedColliderIndex: _platformPrefabForm.selectedColliderIndex,
      workspaceRootPath: _readWorkspaceRootPath(),
      onSelectedModuleChanged: (value) {
        _updateState(() {
          _shellState.selectedPrefabPlatformModuleId = value;
          _shellState.selectedModuleId = value;
        });
      },
      onLoadPrefabForModule: loadPlatformPrefabForSelectedModule,
      onUpsertPrefabForModule: upsertPlatformPrefabForSelectedModule,
      onStartNewFromCurrentValues: startNewPlatformPrefabFromCurrentValues,
      onSceneValuesChanged: onPlatformPrefabSceneValuesChanged,
      onSelectedColliderChanged: (index) {
        _applyColliderMutation(
          form: _platformPrefabForm,
          mutate: () => _platformPrefabForm.selectCollider(index),
        );
      },
      onAddCollider: () {
        _applyColliderMutation(
          form: _platformPrefabForm,
          mutate: _platformPrefabForm.addCollider,
        );
      },
      onDuplicateCollider: () {
        _applyColliderMutation(
          form: _platformPrefabForm,
          mutate: _platformPrefabForm.duplicateSelectedCollider,
        );
      },
      onDeleteCollider: _platformPrefabForm.canDeleteSelectedCollider
          ? () {
              _applyColliderMutation(
                form: _platformPrefabForm,
                mutate: _platformPrefabForm.deleteSelectedCollider,
              );
            }
          : null,
      onLoadPrefab: loadPrefabIntoForm,
      onDeletePrefab: deletePrefab,
    );
  }

  AtlasSliceDef? findSliceById({
    required List<AtlasSliceDef> slices,
    required String? sliceId,
  }) {
    return _prefabController.findSliceById(slices: slices, sliceId: sliceId);
  }

  PrefabDef? editingPrefabForForm(PrefabFormState form) {
    return _prefabController.editingPrefabForForm(
      data: _shellState.data,
      form: form,
    );
  }

  String? _preferredSelectablePrefabSliceIdForKind({
    required PrefabKind kind,
    required PrefabDef? editingPrefab,
    PrefabData? data,
  }) {
    final selectablePrefabSlices = _selectablePrefabSlicesForKind(
      kind: kind,
      editingPrefab: editingPrefab,
      data: data,
    );
    if (selectablePrefabSlices.isEmpty) {
      return null;
    }
    final currentSelection = _shellState.selectedPrefabSliceId?.trim();
    if (currentSelection != null &&
        selectablePrefabSlices.any((slice) => slice.id == currentSelection)) {
      return currentSelection;
    }
    return selectablePrefabSlices.first.id;
  }

  List<AtlasSliceDef> _selectablePrefabSlicesForKind({
    required PrefabKind kind,
    required PrefabDef? editingPrefab,
    PrefabData? data,
  }) {
    final claimedSliceIds = _claimedAtlasSliceIdsForKind(
      kind: kind,
      excludingPrefabKey: editingPrefab?.prefabKey,
      data: data,
    );
    final sourceData = data ?? _shellState.data;
    return sourceData.prefabSlices
        .where((slice) => !claimedSliceIds.contains(slice.id))
        .toList(growable: false);
  }

  Set<String> _claimedAtlasSliceIdsForKind({
    required PrefabKind kind,
    String? excludingPrefabKey,
    PrefabData? data,
  }) {
    final sourceData = data ?? _shellState.data;
    final claimedSliceIds = <String>{};
    for (final prefab in sourceData.prefabs) {
      if (prefab.kind != kind || !prefab.usesAtlasSlice) {
        continue;
      }
      if (excludingPrefabKey != null &&
          prefab.prefabKey == excludingPrefabKey) {
        continue;
      }
      final sliceId = prefab.sliceId.trim();
      if (sliceId.isNotEmpty) {
        claimedSliceIds.add(sliceId);
      }
    }
    return claimedSliceIds;
  }

  PrefabDef? _prefabUsingAtlasSliceForKind({
    required PrefabKind kind,
    required String sliceId,
    String? excludingPrefabKey,
  }) {
    final normalizedSliceId = sliceId.trim();
    if (normalizedSliceId.isEmpty) {
      return null;
    }
    for (final prefab in _shellState.data.prefabs) {
      if (prefab.kind != kind || !prefab.usesAtlasSlice) {
        continue;
      }
      if (excludingPrefabKey != null &&
          prefab.prefabKey == excludingPrefabKey) {
        continue;
      }
      if (prefab.sliceId == normalizedSliceId) {
        return prefab;
      }
    }
    return null;
  }

  /// Keeps prefab ids and tags aligned with the selected atlas slice while the
  /// draft still matches the previously selected slice-provided values.
  ///
  /// This applies in both create mode and edit mode so selecting a new atlas
  /// slice can still reseed id/tag defaults for an existing prefab unless the
  /// user has already diverged from the slice-derived values.
  void syncPrefabIdsWithSelectedSlice({String? previousSelectedSliceId}) {
    final selectedSliceId = _shellState.selectedPrefabSliceId?.trim();
    if (selectedSliceId == null || selectedSliceId.isEmpty) {
      return;
    }
    final selectedSlice = _prefabController.findSliceById(
      slices: _shellState.data.prefabSlices,
      sliceId: selectedSliceId,
    );

    _syncCreateModePrefabIdWithSelectedSlice(
      form: _obstaclePrefabForm,
      previousSelectedSliceId: previousSelectedSliceId,
      selectedSliceId: selectedSliceId,
    );
    _syncCreateModePrefabIdWithSelectedSlice(
      form: _decorationPrefabForm,
      previousSelectedSliceId: previousSelectedSliceId,
      selectedSliceId: selectedSliceId,
    );
    if (selectedSlice == null) {
      return;
    }

    _syncCreateModePrefabTagsWithSelectedSlice(
      form: _obstaclePrefabForm,
      previousSelectedSliceId: previousSelectedSliceId,
      selectedSlice: selectedSlice,
    );
    _syncCreateModePrefabTagsWithSelectedSlice(
      form: _decorationPrefabForm,
      previousSelectedSliceId: previousSelectedSliceId,
      selectedSlice: selectedSlice,
    );
  }

  void resetPrefabFormsForLoadedData({
    required String? defaultPlatformModuleId,
    required int defaultPlatformTileSize,
  }) {
    _runWithoutLocalDraftHistory(() {
      _obstaclePrefabForm.resetObstacleDefaults();
      _platformPrefabForm.resetPlatformDefaults(
        tileSize: defaultPlatformTileSize,
      );
      _decorationPrefabForm.resetDecorationDefaults();
      _shellState.selectedPrefabPlatformModuleId = defaultPlatformModuleId;
    });
  }

  void onObstaclePrefabSceneValuesChanged(PrefabSceneValues values) {
    _updateState(() {
      _applyLocalDraftMutation(() {
        _obstaclePrefabForm.applySceneValues(values);
      });
      _shellState.errorMessage = null;
    });
  }

  void onPlatformPrefabSceneValuesChanged(PrefabSceneValues values) {
    _updateState(() {
      _applyLocalDraftMutation(() {
        _platformPrefabForm.applySceneValues(values);
      });
      _shellState.errorMessage = null;
    });
  }

  void onDecorationPrefabSceneValuesChanged(PrefabSceneValues values) {
    _updateState(() {
      _applyLocalDraftMutation(() {
        _decorationPrefabForm.applyAnchorValues(
          PrefabAnchorValues(anchorX: values.anchorX, anchorY: values.anchorY),
        );
      });
      _shellState.errorMessage = null;
    });
  }

  void _applyColliderMutation({
    required PrefabFormState form,
    required String? Function() mutate,
  }) {
    _updateState(() {
      String? error;
      _applyLocalDraftMutation(() {
        error = mutate();
      });
      if (error != null) {
        _shellState.setError(error!);
        return;
      }
      _shellState.errorMessage = null;
    });
  }

  void loadPrefabIntoForm(PrefabDef prefab) {
    final form = _formForPrefabKind(prefab.kind);
    _updateState(() {
      applyPrefabToForm(form, prefab);
      _syncFormDraftBaseline();
    });
  }

  void applyPrefabToForm(
    PrefabFormState form,
    PrefabDef prefab, {
    bool setStatusMessage = true,
  }) {
    final backingModule = prefab.usesPlatformModule
        ? _platformModuleController.moduleById(
            data: _shellState.data,
            moduleId: prefab.moduleId,
          )
        : null;
    final projection = _prefabController.projectPrefabLoad(
      prefab: prefab,
      reducer: _dataReducer,
      backingModule: backingModule,
    );
    _runWithoutLocalDraftHistory(() {
      form.restoreDraftSnapshot(projection.formSnapshot);
      if (projection.selectedPrefabSliceId != null) {
        _shellState.selectedPrefabSliceId = projection.selectedPrefabSliceId;
      }
      if (projection.selectedPrefabPlatformModuleId != null) {
        _shellState.selectedPrefabPlatformModuleId =
            projection.selectedPrefabPlatformModuleId;
      }
      if (projection.selectedModuleId != null) {
        _shellState.selectedModuleId = projection.selectedModuleId;
      }
      if (projection.moduleTileSizeText != null) {
        _moduleTileSizeController.text = projection.moduleTileSizeText!;
      }
    });
    _shellState.errorMessage = null;
    if (setStatusMessage) {
      _shellState.statusMessage =
          'Loaded prefab "${prefab.id}" '
          '(key=${prefab.prefabKey} rev=${prefab.revision} '
          'status=${prefab.status.jsonValue}).';
    }
  }

  void deletePrefab(String prefabId) {
    PrefabDef? deleted;
    for (final prefab in _shellState.data.prefabs) {
      if (prefab.id == prefabId) {
        deleted = prefab;
        break;
      }
    }

    _commitPrefabDataChange(
      nextData: _mutations.deletePrefabById(
        data: _shellState.data,
        prefabId: prefabId,
      ),
      beforeSync: () {
        if (deleted != null) {
          if (deleted.prefabKey == _obstaclePrefabForm.editingPrefabKey) {
            _obstaclePrefabForm.editingPrefabKey = null;
          }
          if (deleted.prefabKey == _platformPrefabForm.editingPrefabKey) {
            _platformPrefabForm.editingPrefabKey = null;
          }
          if (deleted.prefabKey == _decorationPrefabForm.editingPrefabKey) {
            _decorationPrefabForm.editingPrefabKey = null;
          }
        }
      },
      statusMessage: 'Deleted prefab "$prefabId".',
    );
  }

  void upsertObstaclePrefabFromForm() {
    _updateState(() {
      _obstaclePrefabForm.selectedKind = PrefabKind.obstacle;
    });
    _upsertPrefabFromForm(_obstaclePrefabForm);
  }

  void duplicateLoadedObstaclePrefab() {
    final source = editingPrefabForForm(_obstaclePrefabForm);
    if (source == null || source.kind != PrefabKind.obstacle) {
      _setError('Load an obstacle prefab before duplicating.');
      return;
    }
    _duplicateLoadedPrefab(_obstaclePrefabForm);
  }

  void deprecateLoadedObstaclePrefab() {
    final source = editingPrefabForForm(_obstaclePrefabForm);
    if (source == null || source.kind != PrefabKind.obstacle) {
      _setError('Load an obstacle prefab before deprecating.');
      return;
    }
    _deprecateLoadedPrefab(_obstaclePrefabForm);
  }

  void clearObstaclePrefabForm() {
    _updateState(() {
      _resetObstaclePrefabFormForCreate(data: _shellState.data);
      _syncFormDraftBaseline();
      _shellState.statusMessage = 'Cleared prefab form.';
      _shellState.errorMessage = null;
    });
  }

  void startNewObstaclePrefabFromCurrentValues() {
    final source = editingPrefabForForm(_obstaclePrefabForm);
    if (source == null || source.kind != PrefabKind.obstacle) {
      _updateState(() {
        _shellState.statusMessage =
            'Obstacle prefab form is already in create mode.';
        _shellState.errorMessage = null;
      });
      return;
    }

    _updateState(() {
      _runWithoutLocalDraftHistory(() {
        _obstaclePrefabForm.selectedKind = PrefabKind.obstacle;
        _obstaclePrefabForm.editingPrefabKey = null;
        _shellState.selectedPrefabSliceId =
            _preferredSelectablePrefabSliceIdForKind(
              kind: PrefabKind.obstacle,
              editingPrefab: null,
            );
        _syncCreateModePrefabIdForLoadedPrefabTransition(
          form: _obstaclePrefabForm,
          sourcePrefabId: source.id,
        );
        _syncCreateModePrefabTagsForLoadedPrefabTransition(
          form: _obstaclePrefabForm,
          sourcePrefab: source,
        );
      });
      _syncFormDraftBaseline();
      _shellState.statusMessage =
          'Creating a new obstacle prefab from the current form values.';
      _shellState.errorMessage = null;
    });
  }

  void upsertDecorationPrefabFromForm() {
    _updateState(() {
      _decorationPrefabForm.selectedKind = PrefabKind.decoration;
    });
    _upsertPrefabFromForm(_decorationPrefabForm);
  }

  void duplicateLoadedDecorationPrefab() {
    final source = editingPrefabForForm(_decorationPrefabForm);
    if (source == null || source.kind != PrefabKind.decoration) {
      _setError('Load a decoration prefab before duplicating.');
      return;
    }
    _duplicateLoadedPrefab(_decorationPrefabForm);
  }

  void deprecateLoadedDecorationPrefab() {
    final source = editingPrefabForForm(_decorationPrefabForm);
    if (source == null || source.kind != PrefabKind.decoration) {
      _setError('Load a decoration prefab before deprecating.');
      return;
    }
    _deprecateLoadedPrefab(_decorationPrefabForm);
  }

  void clearDecorationPrefabForm() {
    _updateState(() {
      _resetDecorationPrefabFormForCreate();
      _syncFormDraftBaseline();
      _shellState.statusMessage = 'Cleared decoration prefab form.';
      _shellState.errorMessage = null;
    });
  }

  void startNewDecorationPrefabFromCurrentValues() {
    final source = editingPrefabForForm(_decorationPrefabForm);
    if (source == null || source.kind != PrefabKind.decoration) {
      _updateState(() {
        _shellState.statusMessage =
            'Decoration prefab form is already in create mode.';
        _shellState.errorMessage = null;
      });
      return;
    }

    _updateState(() {
      _runWithoutLocalDraftHistory(() {
        _decorationPrefabForm.selectedKind = PrefabKind.decoration;
        _decorationPrefabForm.editingPrefabKey = null;
        _shellState.selectedPrefabSliceId =
            _preferredSelectablePrefabSliceIdForKind(
              kind: PrefabKind.decoration,
              editingPrefab: null,
            );
        _syncCreateModePrefabIdForLoadedPrefabTransition(
          form: _decorationPrefabForm,
          sourcePrefabId: source.id,
        );
        _syncCreateModePrefabTagsForLoadedPrefabTransition(
          form: _decorationPrefabForm,
          sourcePrefab: source,
        );
      });
      _syncFormDraftBaseline();
      _shellState.statusMessage =
          'Creating a new decoration prefab from the current form values.';
      _shellState.errorMessage = null;
    });
  }

  void loadPlatformPrefabForSelectedModule() {
    final module = _platformModuleController.selectedModule(
      data: _shellState.data,
      selectedModuleId: _shellState.selectedPrefabPlatformModuleId,
    );
    if (module == null) {
      _setError('Select a module before loading prefab defaults.');
      return;
    }
    final existing = _dataReducer.firstPlatformPrefabForModuleId(
      _shellState.data.prefabs,
      module.id,
    );
    if (existing != null) {
      loadPrefabIntoForm(existing);
      _updateState(() {
        _runWithoutLocalDraftHistory(() {
          _platformPrefabForm.selectedKind = PrefabKind.platform;
          _platformPrefabForm.autoManagePlatformModule = false;
          _shellState.selectedPrefabPlatformModuleId = module.id;
        });
        _syncFormDraftBaseline();
        _shellState.statusMessage =
            'Loaded platform prefab "${existing.id}" for module "${module.id}".';
        _shellState.errorMessage = null;
      });
      return;
    }

    _updateState(() {
      _seedPlatformPrefabFormForSelectedModule(
        module: module,
        clearEditingKey: true,
        fillSceneDefaults: true,
      );
      _syncFormDraftBaseline();
      _shellState.statusMessage =
          'Initialized platform prefab form for module "${module.id}".';
      _shellState.errorMessage = null;
    });
  }

  void upsertPlatformPrefabForSelectedModule() {
    final module = _platformModuleController.selectedModule(
      data: _shellState.data,
      selectedModuleId: _shellState.selectedPrefabPlatformModuleId,
    );
    if (module == null) {
      _setError('Select a module before saving a platform prefab.');
      return;
    }
    final existing = _dataReducer.firstPlatformPrefabForModuleId(
      _shellState.data.prefabs,
      module.id,
    );
    final editing = editingPrefabForForm(_platformPrefabForm);

    _updateState(() {
      _seedPlatformPrefabFormForSelectedModule(
        module: module,
        existingPrefabKey: existing?.prefabKey,
        existingPrefabId: existing?.id,
        clearEditingKey:
            existing == null && editing?.kind != PrefabKind.platform,
        fillSceneDefaults: false,
      );
    });
    _upsertPrefabFromForm(_platformPrefabForm);
  }

  void startNewPlatformPrefabFromCurrentValues() {
    final source = editingPrefabForForm(_platformPrefabForm);
    if (source == null || source.kind != PrefabKind.platform) {
      _updateState(() {
        _shellState.statusMessage =
            'Platform prefab form is already in create mode.';
        _shellState.errorMessage = null;
      });
      return;
    }

    _updateState(() {
      _runWithoutLocalDraftHistory(() {
        _platformPrefabForm.selectedKind = PrefabKind.platform;
        _platformPrefabForm.autoManagePlatformModule = false;
        _platformPrefabForm.editingPrefabKey = null;
      });
      _syncFormDraftBaseline();
      _shellState.statusMessage =
          'Creating a new platform prefab from the current form values.';
      _shellState.errorMessage = null;
    });
  }

  void _upsertPrefabFromForm(PrefabFormState form) {
    final identityDecision = _prefabController.resolveUpsertIdentity(
      data: _shellState.data,
      reducer: _dataReducer,
      form: form,
    );
    if (identityDecision.error != null) {
      _setError(identityDecision.error!);
      return;
    }
    final identity = identityDecision.value!;

    var nextData = _shellState.data;
    String? forcedPlatformModuleId;
    if (form.selectedKind == PrefabKind.platform &&
        form.autoManagePlatformModule) {
      final ensuredModule = _ensureAutoManagedPlatformModule(
        data: nextData,
        prefabKey: identity.prefabKey,
      );
      if (ensuredModule == null) {
        return;
      }
      nextData = ensuredModule.data;
      forcedPlatformModuleId = ensuredModule.module.id;
    }

    final visualSource = _selectedVisualSourceForForm(
      form,
      platformModuleIdOverride: forcedPlatformModuleId,
    );
    if (visualSource == null) {
      return;
    }

    final prefabDecision = _prefabController.buildUpsertPrefab(
      reducer: _dataReducer,
      form: form,
      identity: identity,
      visualSource: visualSource,
    );
    if (prefabDecision.error != null) {
      _setError(prefabDecision.error!);
      return;
    }
    final nextPrefab = prefabDecision.value!;
    final isCreate = identity.existingPrefab == null;
    final committedData = _mutations.upsertPrefab(data: nextData, prefab: nextPrefab);

    _commitPrefabDataChange(
      nextData: committedData,
      beforeSync: () {
        if (isCreate) {
          _resetCreatedPrefabForm(
            kind: nextPrefab.kind,
            data: committedData,
            platformModuleIdOverride: forcedPlatformModuleId,
          );
        } else {
          form.editingPrefabKey = nextPrefab.prefabKey;
          if (forcedPlatformModuleId != null) {
            _shellState.selectedPrefabPlatformModuleId = forcedPlatformModuleId;
            _shellState.selectedModuleId = forcedPlatformModuleId;
          }
        }
      },
      statusMessage:
          'Upserted ${nextPrefab.kind.jsonValue} prefab "${nextPrefab.id}" '
          '(rev=${nextPrefab.revision} source='
          '${nextPrefab.visualSource.type.jsonValue}:${nextPrefab.sourceRefId}).',
    );
  }

  PrefabVisualSource? _selectedVisualSourceForForm(
    PrefabFormState form, {
    String? platformModuleIdOverride,
  }) {
    switch (form.selectedKind) {
      case PrefabKind.obstacle:
        return _selectedObstacleVisualSource();
      case PrefabKind.platform:
        return _selectedPlatformVisualSource(
          form: form,
          platformModuleIdOverride: platformModuleIdOverride,
        );
      case PrefabKind.decoration:
        return _selectedDecorationVisualSource();
      case PrefabKind.unknown:
        _setError('Prefab kind must be obstacle, platform, or decoration.');
        return null;
    }
  }

  PrefabVisualSource? _selectedObstacleVisualSource() {
    return _selectedAtlasSliceVisualSourceForForm(
      form: _obstaclePrefabForm,
      kind: PrefabKind.obstacle,
      missingSelectionMessage:
          'Select an atlas slice for obstacle prefab source.',
    );
  }

  PrefabVisualSource? _selectedDecorationVisualSource() {
    return _selectedAtlasSliceVisualSourceForForm(
      form: _decorationPrefabForm,
      kind: PrefabKind.decoration,
      missingSelectionMessage:
          'Select an atlas slice for decoration prefab source.',
    );
  }

  PrefabVisualSource? _selectedAtlasSliceVisualSourceForForm({
    required PrefabFormState form,
    required PrefabKind kind,
    required String missingSelectionMessage,
  }) {
    final sliceId = _shellState.selectedPrefabSliceId;
    if (sliceId == null || sliceId.isEmpty) {
      _setError(missingSelectionMessage);
      return null;
    }
    final editingPrefab = editingPrefabForForm(form);
    final conflictingPrefab = _prefabUsingAtlasSliceForKind(
      kind: kind,
      sliceId: sliceId,
      excludingPrefabKey: editingPrefab?.prefabKey,
    );
    if (conflictingPrefab != null) {
      _setError(
        'Atlas slice "$sliceId" is already used by '
        '${kind.jsonValue} prefab "${conflictingPrefab.id}".',
      );
      return null;
    }
    return PrefabVisualSource.atlasSlice(sliceId);
  }

  PrefabVisualSource? _selectedPlatformVisualSource({
    required PrefabFormState form,
    String? platformModuleIdOverride,
  }) {
    final decision = _platformPrefabController.resolveVisualSource(
      autoManagePlatformModule: form.autoManagePlatformModule,
      selectedPlatformModuleId: _shellState.selectedPrefabPlatformModuleId,
      moduleIdOverride: platformModuleIdOverride,
    );
    if (decision.error != null) {
      _setError(decision.error!);
      return null;
    }
    return decision.value!;
  }

  PlatformAutoManagedModuleResult? _ensureAutoManagedPlatformModule({
    required PrefabData data,
    required String prefabKey,
  }) {
    final decision = _platformPrefabController.ensureAutoManagedPlatformModule(
      data: data,
      prefabKey: prefabKey,
      rawTileSize: _moduleTileSizeController.text,
      reducer: _dataReducer,
    );
    if (decision.error != null) {
      _setError(decision.error!);
      return null;
    }
    return decision.value!;
  }

  void _duplicateLoadedPrefab(PrefabFormState form) {
    final source = editingPrefabForForm(form);
    if (source == null) {
      _setError('Load a prefab before duplicating.');
      return;
    }

    final duplicateDecision = _prefabController.buildDuplicate(
      data: _shellState.data,
      reducer: _dataReducer,
      form: form,
      source: source,
    );
    if (duplicateDecision.error != null) {
      _setError(duplicateDecision.error!);
      return;
    }
    final duplicate = duplicateDecision.value!;

    _commitPrefabDataChange(
      nextData: _mutations.upsertPrefab(
        data: _shellState.data,
        prefab: duplicate,
      ),
      beforeSync: () {
        form.editingPrefabKey = duplicate.prefabKey;
      },
      statusMessage:
          'Duplicated prefab "${source.id}" -> "${duplicate.id}" '
          '(key=${duplicate.prefabKey}).',
    );
  }

  void _deprecateLoadedPrefab(PrefabFormState form) {
    final source = editingPrefabForForm(form);
    if (source == null) {
      _setError('Load a prefab before deprecating.');
      return;
    }
    if (source.status == PrefabStatus.deprecated) {
      _updateState(() {
        _shellState.statusMessage =
            'Prefab "${source.id}" is already deprecated.';
        _shellState.errorMessage = null;
      });
      return;
    }
    final deprecated = source.copyWith(
      status: PrefabStatus.deprecated,
      revision: source.revision + 1,
    );
    _commitPrefabDataChange(
      nextData: _mutations.upsertPrefab(
        data: _shellState.data,
        prefab: deprecated,
      ),
      beforeSync: () {
        form.editingPrefabKey = deprecated.prefabKey;
      },
      statusMessage:
          'Deprecated prefab "${deprecated.id}" (rev=${deprecated.revision}).',
    );
  }

  void _seedPlatformPrefabFormForSelectedModule({
    required TileModuleDef module,
    String? existingPrefabKey,
    String? existingPrefabId,
    required bool clearEditingKey,
    required bool fillSceneDefaults,
  }) {
    _runWithoutLocalDraftHistory(() {
      _platformPrefabForm.selectedKind = PrefabKind.platform;
      _platformPrefabForm.autoManagePlatformModule = false;
      _shellState.selectedPrefabPlatformModuleId = module.id;
      if (existingPrefabKey != null) {
        _platformPrefabForm.editingPrefabKey = existingPrefabKey;
      } else if (clearEditingKey) {
        _platformPrefabForm.editingPrefabKey = null;
      }
      _platformPrefabForm.prefabIdController.text =
          _platformPrefabForm.prefabIdController.text.trim().isEmpty
          ? (existingPrefabId ?? '${module.id}_platform')
          : _platformPrefabForm.prefabIdController.text.trim();
      if (fillSceneDefaults) {
        if (_platformPrefabForm.anchorXController.text.trim().isEmpty) {
          _platformPrefabForm.anchorXController.text = '0';
        }
        if (_platformPrefabForm.anchorYController.text.trim().isEmpty) {
          _platformPrefabForm.anchorYController.text = '0';
        }
        if (_platformPrefabForm.colliderOffsetXController.text.trim().isEmpty) {
          _platformPrefabForm.colliderOffsetXController.text = '0';
        }
        if (_platformPrefabForm.colliderOffsetYController.text.trim().isEmpty) {
          _platformPrefabForm.colliderOffsetYController.text = '0';
        }
      }
      if (_platformPrefabForm.colliderWidthController.text.trim().isEmpty) {
        _platformPrefabForm.colliderWidthController.text = module.tileSize
            .toString();
      }
      if (_platformPrefabForm.colliderHeightController.text.trim().isEmpty) {
        _platformPrefabForm.colliderHeightController.text = module.tileSize
            .toString();
      }
    });
  }

  void _resetCreatedPrefabForm({
    required PrefabKind kind,
    required PrefabData data,
    String? platformModuleIdOverride,
  }) {
    switch (kind) {
      case PrefabKind.obstacle:
        _resetObstaclePrefabFormForCreate(data: data);
        return;
      case PrefabKind.decoration:
        _resetDecorationPrefabFormForCreate();
        return;
      case PrefabKind.platform:
        _resetPlatformPrefabFormForCreate(
          data: data,
        );
        return;
      case PrefabKind.unknown:
        return;
    }
  }

  void _resetObstaclePrefabFormForCreate({required PrefabData data}) {
    _runWithoutLocalDraftHistory(() {
      _obstaclePrefabForm.resetObstacleDefaults();
      _moduleTileSizeController.text = '16';
      _shellState.selectedPrefabSliceId = null;
      _shellState.selectedPrefabPlatformModuleId = _dataReducer
          .preferredModuleIdForPicker(data.platformModules);
    });
  }

  void _resetDecorationPrefabFormForCreate() {
    _runWithoutLocalDraftHistory(() {
      _decorationPrefabForm.resetDecorationDefaults();
      _shellState.selectedPrefabSliceId = null;
    });
  }

  void _resetPlatformPrefabFormForCreate({
    required PrefabData data,
  }) {
    _runWithoutLocalDraftHistory(() {
      _platformPrefabForm.resetPlatformDefaults();
      _platformPrefabForm.autoManagePlatformModule = false;
      _shellState.selectedPrefabPlatformModuleId = null;
    });
  }

  PrefabFormState _formForPrefabKind(PrefabKind kind) {
    switch (kind) {
      case PrefabKind.platform:
        return _platformPrefabForm;
      case PrefabKind.decoration:
        return _decorationPrefabForm;
      case PrefabKind.obstacle:
      case PrefabKind.unknown:
        return _obstaclePrefabForm;
    }
  }

  void _setError(String message) {
    _updateState(() {
      _shellState.setError(message);
    });
  }

  void _syncCreateModePrefabIdWithSelectedSlice({
    required PrefabFormState form,
    required String selectedSliceId,
    String? previousSelectedSliceId,
  }) {
    final currentPrefabId = form.prefabIdController.text.trim();
    final isTrackingPreviousSlice =
        previousSelectedSliceId != null &&
        previousSelectedSliceId.isNotEmpty &&
        currentPrefabId == previousSelectedSliceId;
    if (currentPrefabId.isNotEmpty && !isTrackingPreviousSlice) {
      return;
    }

    form.prefabIdController.text = selectedSliceId;
  }

  void _syncCreateModePrefabIdForLoadedPrefabTransition({
    required PrefabFormState form,
    required String sourcePrefabId,
  }) {
    final selectedSliceId = _shellState.selectedPrefabSliceId?.trim();
    if (selectedSliceId == null || selectedSliceId.isEmpty) {
      return;
    }

    final currentPrefabId = form.prefabIdController.text.trim();
    if (currentPrefabId.isNotEmpty && currentPrefabId != sourcePrefabId) {
      return;
    }

    form.prefabIdController.text = selectedSliceId;
  }

  void _syncCreateModePrefabTagsWithSelectedSlice({
    required PrefabFormState form,
    required AtlasSliceDef selectedSlice,
    String? previousSelectedSliceId,
  }) {
    final currentTagText = _normalizedTagText(form.tagsController.text);
    final previousTagText = _normalizedSelectedSliceTagText(
      previousSelectedSliceId,
    );
    final isTrackingPreviousSlice =
        previousTagText.isNotEmpty && currentTagText == previousTagText;
    if (currentTagText.isNotEmpty && !isTrackingPreviousSlice) {
      return;
    }

    form.tagsController.text = _normalizedTagTextFromList(selectedSlice.tags);
  }

  void _syncCreateModePrefabTagsForLoadedPrefabTransition({
    required PrefabFormState form,
    required PrefabDef sourcePrefab,
  }) {
    final selectedSliceId = _shellState.selectedPrefabSliceId?.trim();
    if (selectedSliceId == null || selectedSliceId.isEmpty) {
      return;
    }
    final selectedSlice = _prefabController.findSliceById(
      slices: _shellState.data.prefabSlices,
      sliceId: selectedSliceId,
    );
    if (selectedSlice == null) {
      return;
    }

    final currentTagText = _normalizedTagText(form.tagsController.text);
    final sourceTagText = _normalizedTagTextFromList(sourcePrefab.tags);
    if (currentTagText.isNotEmpty && currentTagText != sourceTagText) {
      return;
    }

    form.tagsController.text = _normalizedTagTextFromList(selectedSlice.tags);
  }

  String _normalizedSelectedSliceTagText(String? sliceId) {
    final normalizedSliceId = sliceId?.trim();
    if (normalizedSliceId == null || normalizedSliceId.isEmpty) {
      return '';
    }
    final slice = _prefabController.findSliceById(
      slices: _shellState.data.prefabSlices,
      sliceId: normalizedSliceId,
    );
    if (slice == null) {
      return '';
    }
    return _normalizedTagTextFromList(slice.tags);
  }

  String _normalizedTagText(String raw) {
    return _normalizedTagTextFromList(
      raw
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false),
    );
  }

  String _normalizedTagTextFromList(List<String> tags) {
    return _dataReducer.normalizedTags(tags).join(', ');
  }
}
