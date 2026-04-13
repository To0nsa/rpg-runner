import 'dart:async';
import 'package:flutter/material.dart';

import '../../../prefabs/domain/prefab_domain_plugin.dart';
import '../../../prefabs/models/models.dart';
import '../../../prefabs/atlas/workspace_scoped_size_cache.dart';
import '../../../session/editor_session_controller.dart';
import '../shared/editor_page_local_draft_state.dart';
import 'atlas_slicer/atlas_slicer_controller.dart';
import 'atlas_slicer/atlas_slicer_page_coordinator.dart';
import 'platform_modules/platform_module_controller.dart';
import 'platform_modules/platform_module_page_coordinator.dart';
import 'platform_prefabs/platform_prefab_controller.dart';
import 'shared/prefab_editor_data_reducer.dart';
import 'shared/prefab_editor_page_contracts.dart';
import 'shared/prefab_editor_page_coordinator.dart';
import 'shared/prefab_editor_page_draft_coordinator.dart';
import 'shared/prefab_editor_prefab_controller.dart';
import 'shared/prefab_editor_scene_projection.dart';
import 'shared/prefab_editor_page_session_coordinator.dart';
import 'shared/prefab_editor_session_bridge.dart';
import 'shared/ui/prefab_editor_shell_chrome.dart';
import 'shared/prefab_editor_shell_state.dart';
import 'shared/prefab_form_state.dart';
import 'shared/prefab_editor_mutations.dart';
import 'shared/prefab_editor_workspace_io.dart';

class PrefabCreatorPage extends StatefulWidget {
  const PrefabCreatorPage({super.key, required this.controller});

  final EditorSessionController controller;

  @override
  State<PrefabCreatorPage> createState() => _PrefabCreatorPageState();
}

class _PrefabCreatorPageState extends State<PrefabCreatorPage>
    with SingleTickerProviderStateMixin
    implements
        EditorPageLocalDraftState,
        EditorPageSessionShortcutHandler,
        EditorPageReloadHandler {
  static const String _levelAssetsPath = 'assets/images/level';
  static const double _zoomMin = 0.2;
  static const double _zoomMax = 24.0;
  static const double _zoomStep = 0.2;

  final TextEditingController _sliceIdController = TextEditingController();
  final TextEditingController _sliceTagsController = TextEditingController();
  final PrefabFormState _obstaclePrefabForm = PrefabFormState.obstacle();
  final PrefabFormState _platformPrefabForm = PrefabFormState.platform();
  final PrefabFormState _decorationPrefabForm = PrefabFormState.decoration();

  final TextEditingController _moduleIdController = TextEditingController();
  final TextEditingController _moduleTileSizeController = TextEditingController(
    text: '16',
  );
  final TextEditingController _selectionXController = TextEditingController();
  final TextEditingController _selectionYController = TextEditingController();
  final TextEditingController _selectionWController = TextEditingController();
  final TextEditingController _selectionHController = TextEditingController();

  final ScrollController _atlasHorizontalScrollController = ScrollController();
  final ScrollController _atlasVerticalScrollController = ScrollController();
  final PrefabEditorShellState _shellState = PrefabEditorShellState();

  final WorkspaceScopedSizeCache _atlasImageSizes = WorkspaceScopedSizeCache();
  final AtlasSlicerController _atlasSlicer = const AtlasSlicerController();
  final PrefabEditorDataReducer _dataReducer = const PrefabEditorDataReducer();
  final PrefabEditorPrefabController _prefabController =
      const PrefabEditorPrefabController();
  final PlatformModuleController _platformModuleController =
      const PlatformModuleController();
  final PlatformPrefabController _platformPrefabController =
      const PlatformPrefabController();
  final PrefabEditorMutations _mutations = const PrefabEditorMutations();
  final PrefabEditorWorkspaceIo _workspaceIo = const PrefabEditorWorkspaceIo();
  final PrefabEditorSceneProjectionHelper _sceneProjection =
      const PrefabEditorSceneProjectionHelper();
  final PrefabEditorSessionBridge _sessionBridge =
      const PrefabEditorSessionBridge();
  late final AtlasSlicerPageCoordinator _atlasPageCoordinator;
  late final PrefabEditorPageCoordinator _prefabPageCoordinator;
  late final PlatformModulePageCoordinator _platformModulePageCoordinator;
  late final PrefabEditorPageDraftCoordinator _draftCoordinator;
  late final PrefabEditorPageSessionCoordinator _sessionCoordinator;
  late final TabController _tabController;

  @override
  bool get hasLocalDraftChanges {
    return _sessionCoordinator.hasSerializedDataChanges() ||
        _draftCoordinator.hasChanges;
  }

  @override
  bool get canHandleUndoSessionShortcut =>
      _draftCoordinator.canUndo || widget.controller.canUndo;

  @override
  bool get canHandleRedoSessionShortcut =>
      _draftCoordinator.canRedo || widget.controller.canRedo;

  @override
  bool get canReloadEditorPage => _shellState.canReload;

  @override
  bool handleUndoSessionShortcut() {
    if (_draftCoordinator.undo(context)) {
      return true;
    }
    if (!widget.controller.canUndo) {
      return false;
    }
    _sessionCoordinator.undoCommittedEdit();
    return true;
  }

  @override
  bool handleRedoSessionShortcut() {
    if (_draftCoordinator.redo(context)) {
      return true;
    }
    if (!widget.controller.canRedo) {
      return false;
    }
    _sessionCoordinator.redoCommittedEdit();
    return true;
  }

  @override
  Future<void> reloadEditorPage() => _sessionCoordinator.reloadData();

  @override
  void initState() {
    super.initState();
    final workspaceRootPath = _readWorkspaceRootPath;
    final PrefabEditorCommitDataChange commitPrefabDataChange =
        _commitPrefabDataChange;

    _draftCoordinator = PrefabEditorPageDraftCoordinator(
      sliceIdController: _sliceIdController,
      sliceTagsController: _sliceTagsController,
      selectionXController: _selectionXController,
      selectionYController: _selectionYController,
      selectionWController: _selectionWController,
      selectionHController: _selectionHController,
      moduleIdController: _moduleIdController,
      moduleTileSizeController: _moduleTileSizeController,
      obstaclePrefabForm: _obstaclePrefabForm,
      platformPrefabForm: _platformPrefabForm,
      decorationPrefabForm: _decorationPrefabForm,
      shellState: _shellState,
      updateState: _updateState,
      isMounted: () => mounted,
    );
    _prefabPageCoordinator = PrefabEditorPageCoordinator(
      prefabController: _prefabController,
      platformPrefabController: _platformPrefabController,
      platformModuleController: _platformModuleController,
      dataReducer: _dataReducer,
      mutations: _mutations,
      shellState: _shellState,
      obstaclePrefabForm: _obstaclePrefabForm,
      platformPrefabForm: _platformPrefabForm,
      decorationPrefabForm: _decorationPrefabForm,
      moduleTileSizeController: _moduleTileSizeController,
      readWorkspaceRootPath: workspaceRootPath,
      updateState: _updateState,
      runWithoutLocalDraftHistory: _draftCoordinator.runWithoutTracking,
      applyLocalDraftMutation: _draftCoordinator.applyMutation,
      syncFormDraftBaseline: _draftCoordinator.syncBaseline,
      commitPrefabDataChange: commitPrefabDataChange,
    );
    _atlasPageCoordinator = AtlasSlicerPageCoordinator(
      atlasSlicer: _atlasSlicer,
      shellState: _shellState,
      atlasImageSizes: _atlasImageSizes,
      syncPrefabIdsWithSelectedSlice: (previousSelectedSliceId) {
        _prefabPageCoordinator.syncPrefabIdsWithSelectedSlice(
          previousSelectedSliceId: previousSelectedSliceId,
        );
      },
      sliceIdController: _sliceIdController,
      sliceTagsController: _sliceTagsController,
      selectionXController: _selectionXController,
      selectionYController: _selectionYController,
      selectionWController: _selectionWController,
      selectionHController: _selectionHController,
      horizontalScrollController: _atlasHorizontalScrollController,
      verticalScrollController: _atlasVerticalScrollController,
      readWorkspaceRootPath: workspaceRootPath,
      updateState: _updateState,
    );
    _platformModulePageCoordinator = PlatformModulePageCoordinator(
      moduleController: _platformModuleController,
      shellState: _shellState,
      moduleIdController: _moduleIdController,
      moduleTileSizeController: _moduleTileSizeController,
      readWorkspaceRootPath: workspaceRootPath,
      updateState: _updateState,
      runWithoutLocalDraftHistory: _draftCoordinator.runWithoutTracking,
      commitPrefabDataChange: commitPrefabDataChange,
    );
    _sessionCoordinator = PrefabEditorPageSessionCoordinator(
      readController: () => widget.controller,
      readContext: () => context,
      isMounted: () => mounted,
      atlasImageSizes: _atlasImageSizes,
      workspaceIo: _workspaceIo,
      sceneProjection: _sceneProjection,
      sessionBridge: _sessionBridge,
      atlasPageCoordinator: _atlasPageCoordinator,
      prefabPageCoordinator: _prefabPageCoordinator,
      platformModulePageCoordinator: _platformModulePageCoordinator,
      shellState: _shellState,
      updateState: _updateState,
      ensurePrefabPluginSelection: _ensurePrefabPluginSelection,
      syncFormDraftBaseline: _draftCoordinator.syncBaseline,
      levelAssetsPath: _levelAssetsPath,
      obstaclePrefabForm: _obstaclePrefabForm,
      platformPrefabForm: _platformPrefabForm,
      decorationPrefabForm: _decorationPrefabForm,
    );
    _tabController = TabController(length: 5, vsync: this);
    _shellState.activeTabIndex = _tabController.index;
    _draftCoordinator.syncBaseline();
    _draftCoordinator.installListeners();
    _tabController.addListener(_handleEditorTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePrefabPluginSelection();
      unawaited(_sessionCoordinator.reloadData());
    });
  }

  @override
  void dispose() {
    _draftCoordinator.dispose();
    _tabController.removeListener(_handleEditorTabChanged);
    _tabController.dispose();
    _sliceIdController.dispose();
    _sliceTagsController.dispose();
    _obstaclePrefabForm.dispose();
    _platformPrefabForm.dispose();
    _decorationPrefabForm.dispose();
    _moduleIdController.dispose();
    _moduleTileSizeController.dispose();
    _selectionXController.dispose();
    _selectionYController.dispose();
    _selectionWController.dispose();
    _selectionHController.dispose();
    _atlasHorizontalScrollController.dispose();
    _atlasVerticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrefabEditorShellChrome(
      shellState: _shellState,
      tabController: _tabController,
      canHandleUndo: canHandleUndoSessionShortcut,
      canHandleRedo: canHandleRedoSessionShortcut,
      onSave: () {
        unawaited(_sessionCoordinator.saveData());
      },
      onUndo: () {
        handleUndoSessionShortcut();
      },
      onRedo: () {
        handleRedoSessionShortcut();
      },
      onTabTapped: _handleEditorTabTapped,
      children: [
        _atlasPageCoordinator.buildTab(
          zoomMin: _zoomMin,
          zoomMax: _zoomMax,
          zoomStep: _zoomStep,
        ),
        _prefabPageCoordinator.buildObstaclePrefabsTab(),
        _prefabPageCoordinator.buildDecorationPrefabsTab(),
        _platformModulePageCoordinator.buildTab(),
        _prefabPageCoordinator.buildPlatformPrefabsTab(),
      ],
    );
  }

  void _updateState(VoidCallback callback) {
    setState(callback);
  }

  void _handleEditorTabChanged() {
    final nextIndex = _tabController.index;
    if (nextIndex == _shellState.activeTabIndex) {
      return;
    }
    _updateState(() {
      _switchToTab(nextIndex);
    });
  }

  void _handleEditorTabTapped(int nextIndex) {
    if (nextIndex == _shellState.activeTabIndex) {
      return;
    }
    _updateState(() {
      _switchToTab(nextIndex);
    });
  }

  void _switchToTab(int nextIndex) {
    _shellState.activeTabIndex = nextIndex;
    if (nextIndex == 3) {
      _platformModulePageCoordinator.syncSelectedModuleInputs();
    }
  }

  void _ensurePrefabPluginSelection() {
    if (widget.controller.selectedPluginId == PrefabDomainPlugin.pluginId) {
      return;
    }
    final hasPrefabPlugin = widget.controller.availablePlugins.any(
      (plugin) => plugin.id == PrefabDomainPlugin.pluginId,
    );
    if (!hasPrefabPlugin) {
      return;
    }
    widget.controller.setSelectedPluginId(PrefabDomainPlugin.pluginId);
  }

  String _readWorkspaceRootPath() => widget.controller.workspacePath.trim();

  void _commitPrefabDataChange({
    required PrefabData nextData,
    required String statusMessage,
    VoidCallback? beforeSync,
  }) {
    _sessionCoordinator.commitPrefabDataChange(
      nextData: nextData,
      statusMessage: statusMessage,
      beforeSync: beforeSync,
    );
  }
}
