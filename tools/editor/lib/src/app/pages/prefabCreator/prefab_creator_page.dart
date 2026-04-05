import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../domain/authoring_types.dart';
import '../../../prefabs/prefab_domain_models.dart';
import '../../../prefabs/prefab_domain_plugin.dart';
import '../../../prefabs/prefab_models.dart';
import '../../../prefabs/prefab_store.dart';
import '../../../prefabs/prefab_validation.dart';
import '../../../prefabs/workspace_scoped_size_cache.dart';
import '../../../session/editor_session_controller.dart';
import '../shared/atlas_selection_painter.dart';
import '../shared/editor_page_local_draft_state.dart';
import '../shared/editor_viewport_grid_painter.dart';
import '../shared/editor_zoom_controls.dart';
import '../shared/scene_input_utils.dart';
import 'state/prefab_editor_data_reducer.dart';
import 'state/prefab_form_state.dart';
import 'widgets/platform_module_scene_view.dart';
import 'widgets/prefab_scene_view.dart';
import 'widgets/prefab_scene_values.dart';

part 'tabs/atlas_slicer_tab.dart';
part 'tabs/prefabs_tab.dart';
part 'tabs/platform_modules_tab.dart';
part 'state/data_io.dart';
part 'state/selection_logic.dart';
part 'state/prefab_logic.dart';
part 'state/module_logic.dart';

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
  final PrefabFormState _obstaclePrefabForm = PrefabFormState.obstacle();
  final PrefabFormState _platformPrefabForm = PrefabFormState.platform();

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

  PrefabData _data = const PrefabData();
  List<String> _atlasImagePaths = const <String>[];
  final WorkspaceScopedSizeCache _atlasImageSizes = WorkspaceScopedSizeCache();
  final PrefabEditorDataReducer _dataReducer = const PrefabEditorDataReducer();
  final PrefabStore _prefabStore = const PrefabStore();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _statusMessage;
  String? _errorMessage;

  String? _selectedAtlasPath;
  AtlasSliceKind _selectedSliceKind = AtlasSliceKind.prefab;
  String? _selectedPrefabSliceId;
  String? _selectedPrefabPlatformModuleId;
  String? _selectedTileSliceId;
  String? _selectedModuleId;
  double _atlasZoom = 2.0;
  bool _atlasCtrlPanActive = false;
  PlatformModuleSceneTool _selectedModuleSceneTool =
      PlatformModuleSceneTool.paint;
  late final TabController _tabController;
  late _PrefabCreatorFormDraftSnapshot _formDraftBaseline;
  late _PrefabCreatorFormDraftSnapshot _lastObservedFormDraftSnapshot;
  final List<_PrefabCreatorFormDraftSnapshot> _localDraftUndoStack =
      <_PrefabCreatorFormDraftSnapshot>[];
  final List<_PrefabCreatorFormDraftSnapshot> _localDraftRedoStack =
      <_PrefabCreatorFormDraftSnapshot>[];
  bool _suppressLocalDraftHistory = false;
  bool _localDraftRefreshScheduled = false;
  int _activeTabIndex = 0;

  PrefabFormState get _activePrefabForm =>
      _activeTabIndex == 2 ? _platformPrefabForm : _obstaclePrefabForm;

  TextEditingController get _prefabIdController =>
      _activePrefabForm.prefabIdController;
  TextEditingController get _anchorXController =>
      _activePrefabForm.anchorXController;
  TextEditingController get _anchorYController =>
      _activePrefabForm.anchorYController;
  TextEditingController get _colliderOffsetXController =>
      _activePrefabForm.colliderOffsetXController;
  TextEditingController get _colliderOffsetYController =>
      _activePrefabForm.colliderOffsetYController;
  TextEditingController get _colliderWidthController =>
      _activePrefabForm.colliderWidthController;
  TextEditingController get _colliderHeightController =>
      _activePrefabForm.colliderHeightController;
  TextEditingController get _prefabTagsController =>
      _activePrefabForm.tagsController;
  TextEditingController get _prefabZIndexController =>
      _activePrefabForm.zIndexController;

  bool get _prefabSnapToGrid => _activePrefabForm.snapToGrid;
  set _prefabSnapToGrid(bool value) {
    _activePrefabForm.snapToGrid = value;
  }

  PrefabKind get _selectedPrefabKind => _activePrefabForm.selectedKind;
  set _selectedPrefabKind(PrefabKind value) {
    _activePrefabForm.selectedKind = value;
  }

  bool get _autoManagePlatformModule =>
      _activePrefabForm.autoManagePlatformModule;
  set _autoManagePlatformModule(bool value) {
    _activePrefabForm.autoManagePlatformModule = value;
  }

  String? get _editingPrefabKey => _activePrefabForm.editingPrefabKey;
  set _editingPrefabKey(String? value) {
    _activePrefabForm.editingPrefabKey = value;
  }

  Offset? _selectionStartImagePx;
  Offset? _selectionCurrentImagePx;

  @override
  bool get hasLocalDraftChanges {
    return _hasLocalDataDraftChanges() ||
        _captureFormDraftSnapshot() != _formDraftBaseline;
  }

  @override
  bool get canHandleUndoSessionShortcut =>
      _canUndoLocalDraftChanges || widget.controller.canUndo;

  @override
  bool get canHandleRedoSessionShortcut =>
      _canRedoLocalDraftChanges || widget.controller.canRedo;

  @override
  bool get canReloadEditorPage => !_isLoading && !_isSaving;

  @override
  bool handleUndoSessionShortcut() {
    if (_undoLocalDraftChange()) {
      return true;
    }
    if (!widget.controller.canUndo) {
      return false;
    }
    _undoCommittedEdit();
    return true;
  }

  @override
  bool handleRedoSessionShortcut() {
    if (_redoLocalDraftChange()) {
      return true;
    }
    if (!widget.controller.canRedo) {
      return false;
    }
    _redoCommittedEdit();
    return true;
  }

  @override
  Future<void> reloadEditorPage() => _reloadData();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _activeTabIndex = _tabController.index;
    _formDraftBaseline = _captureFormDraftSnapshot();
    _lastObservedFormDraftSnapshot = _formDraftBaseline;
    _installLocalDraftHistoryListeners();
    _tabController.addListener(_handleEditorTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePrefabPluginSelection();
      unawaited(_reloadData());
    });
  }

  @override
  void dispose() {
    _removeLocalDraftHistoryListeners();
    _tabController.removeListener(_handleEditorTabChanged);
    _tabController.dispose();
    _sliceIdController.dispose();
    _obstaclePrefabForm.dispose();
    _platformPrefabForm.dispose();
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveData,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Definitions'),
                ),
                if (_activeTabIndex != 0) ...[
                  OutlinedButton.icon(
                    key: const ValueKey<String>('prefab_editor_undo_button'),
                    onPressed:
                        _isLoading || _isSaving || !canHandleUndoSessionShortcut
                        ? null
                        : () {
                            handleUndoSessionShortcut();
                          },
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey<String>('prefab_editor_redo_button'),
                    onPressed:
                        _isLoading || _isSaving || !canHandleRedoSessionShortcut
                        ? null
                        : () {
                            handleRedoSessionShortcut();
                          },
                    icon: const Icon(Icons.redo),
                    label: const Text('Redo'),
                  ),
                ],
              ],
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _statusMessage!,
                style: const TextStyle(color: Color(0xFF8DE28D)),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFFFF7F7F)),
              ),
            ],
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              onTap: _handleEditorTabTapped,
              tabs: const [
                Tab(text: 'Atlas Slicer'),
                Tab(text: 'Obstacle Prefabs'),
                Tab(text: 'Platform Prefabs'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAtlasSlicerTab(),
                  _buildPrefabInspectorTab(),
                  _buildPlatformModulesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateState(VoidCallback callback) {
    setState(callback);
  }

  void _handleEditorTabChanged() {
    final nextIndex = _tabController.index;
    if (nextIndex == _activeTabIndex) {
      return;
    }
    _updateState(() {
      _switchToTab(nextIndex);
    });
  }

  void _handleEditorTabTapped(int nextIndex) {
    if (nextIndex == _activeTabIndex) {
      return;
    }
    _updateState(() {
      _switchToTab(nextIndex);
    });
  }

  void _switchToTab(int nextIndex) {
    _activeTabIndex = nextIndex;
  }

  void _resetPrefabFormsForLoadedData({
    required String? defaultPlatformModuleId,
    required int defaultPlatformTileSize,
  }) {
    _runWithoutLocalDraftHistory(() {
      _obstaclePrefabForm.resetObstacleDefaults();
      _platformPrefabForm.resetPlatformDefaults(
        tileSize: defaultPlatformTileSize,
      );
      _selectedPrefabPlatformModuleId = defaultPlatformModuleId;
    });
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
}

class _PrefabCreatorFormDraftSnapshot {
  const _PrefabCreatorFormDraftSnapshot({
    required this.sliceId,
    required this.selectionX,
    required this.selectionY,
    required this.selectionW,
    required this.selectionH,
    required this.selectedPrefabSliceId,
    required this.selectedPrefabPlatformModuleId,
    required this.moduleId,
    required this.moduleTileSize,
    required this.obstaclePrefabId,
    required this.obstacleAnchorX,
    required this.obstacleAnchorY,
    required this.obstacleColliderOffsetX,
    required this.obstacleColliderOffsetY,
    required this.obstacleColliderWidth,
    required this.obstacleColliderHeight,
    required this.obstacleTags,
    required this.obstacleZIndex,
    required this.obstacleSnapToGrid,
    required this.obstacleAutoManagePlatformModule,
    required this.obstacleSelectedKind,
    required this.obstacleEditingPrefabKey,
    required this.platformPrefabId,
    required this.platformAnchorX,
    required this.platformAnchorY,
    required this.platformColliderOffsetX,
    required this.platformColliderOffsetY,
    required this.platformColliderWidth,
    required this.platformColliderHeight,
    required this.platformTags,
    required this.platformZIndex,
    required this.platformSnapToGrid,
    required this.platformAutoManagePlatformModule,
    required this.platformSelectedKind,
    required this.platformEditingPrefabKey,
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
  final String obstaclePrefabId;
  final String obstacleAnchorX;
  final String obstacleAnchorY;
  final String obstacleColliderOffsetX;
  final String obstacleColliderOffsetY;
  final String obstacleColliderWidth;
  final String obstacleColliderHeight;
  final String obstacleTags;
  final String obstacleZIndex;
  final bool obstacleSnapToGrid;
  final bool obstacleAutoManagePlatformModule;
  final PrefabKind obstacleSelectedKind;
  final String? obstacleEditingPrefabKey;
  final String platformPrefabId;
  final String platformAnchorX;
  final String platformAnchorY;
  final String platformColliderOffsetX;
  final String platformColliderOffsetY;
  final String platformColliderWidth;
  final String platformColliderHeight;
  final String platformTags;
  final String platformZIndex;
  final bool platformSnapToGrid;
  final bool platformAutoManagePlatformModule;
  final PrefabKind platformSelectedKind;
  final String? platformEditingPrefabKey;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _PrefabCreatorFormDraftSnapshot &&
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
        other.obstaclePrefabId == obstaclePrefabId &&
        other.obstacleAnchorX == obstacleAnchorX &&
        other.obstacleAnchorY == obstacleAnchorY &&
        other.obstacleColliderOffsetX == obstacleColliderOffsetX &&
        other.obstacleColliderOffsetY == obstacleColliderOffsetY &&
        other.obstacleColliderWidth == obstacleColliderWidth &&
        other.obstacleColliderHeight == obstacleColliderHeight &&
        other.obstacleTags == obstacleTags &&
        other.obstacleZIndex == obstacleZIndex &&
        other.obstacleSnapToGrid == obstacleSnapToGrid &&
        other.obstacleAutoManagePlatformModule ==
            obstacleAutoManagePlatformModule &&
        other.obstacleSelectedKind == obstacleSelectedKind &&
        other.obstacleEditingPrefabKey == obstacleEditingPrefabKey &&
        other.platformPrefabId == platformPrefabId &&
        other.platformAnchorX == platformAnchorX &&
        other.platformAnchorY == platformAnchorY &&
        other.platformColliderOffsetX == platformColliderOffsetX &&
        other.platformColliderOffsetY == platformColliderOffsetY &&
        other.platformColliderWidth == platformColliderWidth &&
        other.platformColliderHeight == platformColliderHeight &&
        other.platformTags == platformTags &&
        other.platformZIndex == platformZIndex &&
        other.platformSnapToGrid == platformSnapToGrid &&
        other.platformAutoManagePlatformModule ==
            platformAutoManagePlatformModule &&
        other.platformSelectedKind == platformSelectedKind &&
        other.platformEditingPrefabKey == platformEditingPrefabKey;
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
    obstaclePrefabId,
    obstacleAnchorX,
    obstacleAnchorY,
    obstacleColliderOffsetX,
    obstacleColliderOffsetY,
    obstacleColliderWidth,
    obstacleColliderHeight,
    obstacleTags,
    obstacleZIndex,
    obstacleSnapToGrid,
    obstacleAutoManagePlatformModule,
    obstacleSelectedKind,
    obstacleEditingPrefabKey,
    platformPrefabId,
    platformAnchorX,
    platformAnchorY,
    platformColliderOffsetX,
    platformColliderOffsetY,
    platformColliderWidth,
    platformColliderHeight,
    platformTags,
    platformZIndex,
    platformSnapToGrid,
    platformAutoManagePlatformModule,
    platformSelectedKind,
    platformEditingPrefabKey,
  ]);
}
