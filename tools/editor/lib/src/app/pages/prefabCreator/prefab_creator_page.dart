import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../prefabs/prefab_models.dart';
import '../../../prefabs/prefab_store.dart';
import '../../../prefabs/prefab_validation.dart';
import '../../../prefabs/workspace_scoped_size_cache.dart';
import '../../../session/editor_session_controller.dart';
import '../shared/atlas_selection_painter.dart';
import '../shared/editor_viewport_grid_painter.dart';
import '../shared/editor_zoom_controls.dart';
import '../shared/scene_input_utils.dart';
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
    with SingleTickerProviderStateMixin {
  static const String _levelAssetsPath = 'assets/images/level';
  static const double _zoomMin = 0.2;
  static const double _zoomMax = 24.0;
  static const double _zoomStep = 0.2;

  final PrefabStore _store = const PrefabStore();

  final TextEditingController _sliceIdController = TextEditingController();
  final TextEditingController _prefabIdController = TextEditingController();
  final TextEditingController _anchorXController = TextEditingController(
    text: '0',
  );
  final TextEditingController _anchorYController = TextEditingController(
    text: '0',
  );
  final TextEditingController _colliderOffsetXController =
      TextEditingController(text: '0');
  final TextEditingController _colliderOffsetYController =
      TextEditingController(text: '0');
  final TextEditingController _colliderWidthController = TextEditingController(
    text: '16',
  );
  final TextEditingController _colliderHeightController = TextEditingController(
    text: '16',
  );
  final TextEditingController _prefabTagsController = TextEditingController();
  final TextEditingController _prefabZIndexController = TextEditingController(
    text: '0',
  );
  bool _prefabSnapToGrid = true;

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

  bool _isLoading = false;
  bool _isSaving = false;
  String? _statusMessage;
  String? _errorMessage;

  String? _selectedAtlasPath;
  AtlasSliceKind _selectedSliceKind = AtlasSliceKind.prefab;
  PrefabKind _selectedPrefabKind = PrefabKind.obstacle;
  String? _selectedPrefabSliceId;
  String? _selectedPrefabPlatformModuleId;
  bool _autoManagePlatformModule = true;
  String? _editingPrefabKey;
  String? _selectedTileSliceId;
  String? _selectedModuleId;
  double _atlasZoom = 2.0;
  bool _atlasCtrlPanActive = false;
  PlatformModuleSceneTool _selectedModuleSceneTool =
      PlatformModuleSceneTool.paint;
  late final TabController _tabController;
  int _activeTabIndex = 0;
  _PrefabFormDraft _obstaclePrefabDraft = _PrefabFormDraft.obstacleDefaults();
  _PrefabFormDraft _platformPrefabDraft = _PrefabFormDraft.platformDefaults();

  Offset? _selectionStartImagePx;
  Offset? _selectionCurrentImagePx;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _activeTabIndex = _tabController.index;
    _tabController.addListener(_handleEditorTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_reloadData());
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleEditorTabChanged);
    _tabController.dispose();
    _sliceIdController.dispose();
    _prefabIdController.dispose();
    _anchorXController.dispose();
    _anchorYController.dispose();
    _colliderOffsetXController.dispose();
    _colliderOffsetYController.dispose();
    _colliderWidthController.dispose();
    _colliderHeightController.dispose();
    _prefabTagsController.dispose();
    _prefabZIndexController.dispose();
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
                  onPressed: _isLoading ? null : _reloadData,
                  icon: const Icon(Icons.sync),
                  label: const Text('Reload'),
                ),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveData,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Definitions'),
                ),
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
    _persistPrefabDraftForTab(_activeTabIndex);
    _activeTabIndex = nextIndex;
    _restorePrefabDraftForTab(nextIndex);
  }

  void _persistPrefabDraftForTab(int tabIndex) {
    final draft = _captureCurrentPrefabDraft();
    if (tabIndex == 1) {
      _obstaclePrefabDraft = draft;
      return;
    }
    if (tabIndex == 2) {
      _platformPrefabDraft = draft;
    }
  }

  void _restorePrefabDraftForTab(int tabIndex) {
    if (tabIndex == 1) {
      _applyPrefabDraft(_obstaclePrefabDraft, kind: PrefabKind.obstacle);
      return;
    }
    if (tabIndex == 2) {
      _applyPrefabDraft(_platformPrefabDraft, kind: PrefabKind.platform);
    }
  }

  _PrefabFormDraft _captureCurrentPrefabDraft() {
    return _PrefabFormDraft(
      prefabId: _prefabIdController.text,
      anchorX: _anchorXController.text,
      anchorY: _anchorYController.text,
      colliderOffsetX: _colliderOffsetXController.text,
      colliderOffsetY: _colliderOffsetYController.text,
      colliderWidth: _colliderWidthController.text,
      colliderHeight: _colliderHeightController.text,
      tags: _prefabTagsController.text,
      zIndex: _prefabZIndexController.text,
      snapToGrid: _prefabSnapToGrid,
      editingPrefabKey: _editingPrefabKey,
    );
  }

  void _applyPrefabDraft(_PrefabFormDraft draft, {required PrefabKind kind}) {
    _prefabIdController.text = draft.prefabId;
    _anchorXController.text = draft.anchorX;
    _anchorYController.text = draft.anchorY;
    _colliderOffsetXController.text = draft.colliderOffsetX;
    _colliderOffsetYController.text = draft.colliderOffsetY;
    _colliderWidthController.text = draft.colliderWidth;
    _colliderHeightController.text = draft.colliderHeight;
    _prefabTagsController.text = draft.tags;
    _prefabZIndexController.text = draft.zIndex;
    _prefabSnapToGrid = draft.snapToGrid;
    _editingPrefabKey = draft.editingPrefabKey;
    _selectedPrefabKind = kind;
  }

  void _seedPrefabDraftsForLoadedData({
    required String? defaultPlatformModuleId,
    required int defaultPlatformTileSize,
  }) {
    _obstaclePrefabDraft = _PrefabFormDraft.obstacleDefaults();
    _platformPrefabDraft = _PrefabFormDraft.platformDefaults(
      tileSize: defaultPlatformTileSize,
    );
    _selectedPrefabKind = PrefabKind.obstacle;
    _editingPrefabKey = null;
    _selectedPrefabPlatformModuleId = defaultPlatformModuleId;
  }

  void _restoreDraftForCurrentTab() {
    _restorePrefabDraftForTab(_tabController.index);
  }
}

class _PrefabFormDraft {
  const _PrefabFormDraft({
    required this.prefabId,
    required this.anchorX,
    required this.anchorY,
    required this.colliderOffsetX,
    required this.colliderOffsetY,
    required this.colliderWidth,
    required this.colliderHeight,
    required this.tags,
    required this.zIndex,
    required this.snapToGrid,
    required this.editingPrefabKey,
  });

  factory _PrefabFormDraft.obstacleDefaults() {
    return const _PrefabFormDraft(
      prefabId: '',
      anchorX: '0',
      anchorY: '0',
      colliderOffsetX: '0',
      colliderOffsetY: '0',
      colliderWidth: '16',
      colliderHeight: '16',
      tags: '',
      zIndex: '0',
      snapToGrid: true,
      editingPrefabKey: null,
    );
  }

  factory _PrefabFormDraft.platformDefaults({int tileSize = 16}) {
    final size = tileSize > 0 ? tileSize : 16;
    final tileSizeText = size.toString();
    return _PrefabFormDraft(
      prefabId: '',
      anchorX: '0',
      anchorY: '0',
      colliderOffsetX: '0',
      colliderOffsetY: '0',
      colliderWidth: tileSizeText,
      colliderHeight: tileSizeText,
      tags: '',
      zIndex: '0',
      snapToGrid: true,
      editingPrefabKey: null,
    );
  }

  final String prefabId;
  final String anchorX;
  final String anchorY;
  final String colliderOffsetX;
  final String colliderOffsetY;
  final String colliderWidth;
  final String colliderHeight;
  final String tags;
  final String zIndex;
  final bool snapToGrid;
  final String? editingPrefabKey;
}
