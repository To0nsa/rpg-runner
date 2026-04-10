import 'dart:async';

import 'package:flutter/material.dart';

import '../../../chunks/chunk_domain_models.dart';
import '../../../domain/authoring_types.dart';
import '../../../prefabs/models/models.dart';
import '../../../session/editor_session_controller.dart';
import '../shared/atlas_slice_preview_tile.dart';
import '../shared/editor_page_local_draft_state.dart';
import '../shared/editor_scene_view_utils.dart';
import '../shared/platform_module_preview_tile.dart';
import 'widgets/chunk_scene_view.dart';

class ChunkCreatorPage extends StatefulWidget {
  const ChunkCreatorPage({super.key, required this.controller});

  final EditorSessionController controller;

  @override
  State<ChunkCreatorPage> createState() => _ChunkCreatorPageState();
}

class _ChunkCreatorPageState extends State<ChunkCreatorPage>
    implements EditorPageLocalDraftState {
  static const String _chunkListDifficultyAll = 'all';
  static const String _prefabPaletteTagAll = 'all';
  static const String _defaultNewChunkId = 'new_chunk';
  static const String _defaultNewGapX = '0';
  static const String _defaultNewGapWidth = '16';
  static const int _defaultNewMarkerChancePercent = 100;
  static const int _defaultNewMarkerSalt = 0;
  static const String _defaultNewMarkerPlacement = markerPlacementGround;
  static const List<String> _enemyMarkerIds = <String>[
    'grojib',
    'hashash',
    'derf',
    'unocoDemon',
  ];
  static const List<String> _markerPlacementValues = <String>[
    markerPlacementGround,
    markerPlacementHighestSurfaceAtX,
    markerPlacementObstacleTop,
  ];

  final TextEditingController _newChunkIdController = TextEditingController(
    text: _defaultNewChunkId,
  );
  final TextEditingController _renameIdController = TextEditingController();
  final TextEditingController _levelIdController = TextEditingController();
  final TextEditingController _tileSizeController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _groundTopYController = TextEditingController();
  final TextEditingController _newGapXController = TextEditingController(
    text: _defaultNewGapX,
  );
  final TextEditingController _newGapWidthController = TextEditingController(
    text: _defaultNewGapWidth,
  );
  final EditorUiImageCache _prefabPalettePreviewImageCache =
      EditorUiImageCache();

  String? _selectedChunkKey;
  String? _selectedDiffPath;
  String _difficulty = chunkDifficultyNormal;
  String _status = chunkStatusActive;
  String _groundProfileKind = groundProfileKindFlat;
  String? _selectedPalettePrefabKey;
  String? _selectedPlacementKey;
  String? _selectedMarkerKey;
  ChunkSceneTool _sceneTool = ChunkSceneTool.place;
  ChunkScenePlaceMode _composerPlaceMode = ChunkScenePlaceMode.prefab;
  String _newEnemyMarkerId = _enemyMarkerIds.first;
  bool _showParallaxPreview = true;
  final bool _newPlacementSnapToGrid = true;
  final int _newPlacementZIndex = 0;
  bool _inspectorExpanded = false;
  bool _validationExpanded = false;
  bool _pendingDiffExpanded = false;
  bool _placedPrefabsExpanded = false;
  bool _groundProfileExpanded = false;
  bool _groundGapsExpanded = false;
  bool _enemyMarkersExpanded = false;
  final Map<String, String> _groundGapXDraftByKey = <String, String>{};
  final Map<String, String> _groundGapWidthDraftByKey = <String, String>{};
  bool _createChunkExpanded = true;
  bool _chunkListExpanded = false;
  bool _prefabPaletteExpanded = false;
  String _chunkListDifficultyFilter = _chunkListDifficultyAll;
  String _prefabPaletteTagFilter = _prefabPaletteTagAll;
  PrefabKind? _prefabPaletteKindFilter;

  static const double _spaceXs = 4;
  static const double _spaceSm = 8;
  static const double _spaceMd = 12;
  static const double _spaceLg = 16;
  static const double _panelPadding = 12;
  static const double _listViewportHeight = 220;
  static const double _paletteViewportHeight = 260;
  static const double _chunkListViewportHeight = 280;

  @override
  bool get hasLocalDraftChanges {
    return _newChunkIdController.text.trim() != _defaultNewChunkId ||
        _newGapXController.text.trim() != _defaultNewGapX ||
        _newGapWidthController.text.trim() != _defaultNewGapWidth ||
        _metadataDraftDiffersFromSelectedChunk(
          _selectedChunkForDraftChecks(),
        ) ||
        _hasUnsavedGroundGapDraftChanges();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadWorkspace();
    });
  }

  @override
  void dispose() {
    _prefabPalettePreviewImageCache.dispose();
    _newChunkIdController.dispose();
    _renameIdController.dispose();
    _levelIdController.dispose();
    _tileSizeController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _tagsController.dispose();
    _groundTopYController.dispose();
    _newGapXController.dispose();
    _newGapWidthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final scene = widget.controller.scene;
        final chunkScene = scene is ChunkScene ? scene : null;
        final chunks = chunkScene?.chunks ?? const <LevelChunkDef>[];
        _ensureSelectionAfterBuild(chunks);
        final selectedChunk = _selectedChunk(chunks);
        _ensurePaletteSelectionAfterBuild(chunkScene);
        _ensurePlacementSelectionAfterBuild(selectedChunk);
        _ensureMarkerSelectionAfterBuild(selectedChunk);
        _ensureDiffSelectionAfterBuild(widget.controller.pendingChanges);

        if (widget.controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            inputDecorationTheme: theme.inputDecorationTheme.copyWith(
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
          ),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(_spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildControls(chunkScene),
                  const SizedBox(height: _spaceMd),
                  if (widget.controller.loadError != null)
                    _buildErrorBanner(widget.controller.loadError!),
                  if (widget.controller.exportError != null)
                    _buildErrorBanner(widget.controller.exportError!),
                  if (chunkScene == null)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Chunk scene is not loaded for this route.',
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 1,
                            child: _buildChunkListPanel(chunkScene, chunks),
                          ),
                          const SizedBox(width: _spaceMd),
                          Expanded(
                            flex: 2,
                            child: _buildChunkComposerPanel(
                              selectedChunk,
                              chunkScene,
                            ),
                          ),
                          const SizedBox(width: _spaceMd),
                          Expanded(
                            flex: 1,
                            child: _buildChunkInspector(
                              selectedChunk,
                              chunkScene,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls(ChunkScene? scene) {
    return Wrap(
      spacing: _spaceSm,
      runSpacing: _spaceSm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: widget.controller.canUndo ? widget.controller.undo : null,
          icon: const Icon(Icons.undo),
          label: const Text('Undo'),
        ),
        OutlinedButton.icon(
          onPressed: widget.controller.canRedo ? widget.controller.redo : null,
          icon: const Icon(Icons.redo),
          label: const Text('Redo'),
        ),
        FilledButton.icon(
          onPressed: widget.controller.isExporting
              ? null
              : () {
                  unawaited(_confirmAndApplyToFiles());
                },
          icon: const Icon(Icons.save_outlined),
          label: const Text('Apply To Files'),
        ),
        if (scene != null)
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              key: ValueKey<String?>('active-${scene.activeLevelId}'),
              initialValue: scene.activeLevelId,
              decoration: InputDecoration(
                labelText: 'Active Level (${scene.levelOptionSource})',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final levelId in scene.availableLevelIds)
                  DropdownMenuItem<String>(
                    value: levelId,
                    child: Text(levelId),
                  ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                widget.controller.applyCommand(
                  AuthoringCommand(
                    kind: 'set_active_level',
                    payload: <String, Object?>{'levelId': value},
                  ),
                );
              },
            ),
          ),
        if (scene != null)
          Text(
            'gridSnap=${scene.runtimeGridSnap.toStringAsFixed(1)} '
            'chunkWidth=${scene.runtimeChunkWidth.toStringAsFixed(1)}',
          ),
      ],
    );
  }

  Widget _buildChunkListPanel(ChunkScene scene, List<LevelChunkDef> chunks) {
    final filteredChunks = _chunkListDifficultyFilter == _chunkListDifficultyAll
        ? chunks
        : chunks
              .where((chunk) => chunk.difficulty == _chunkListDifficultyFilter)
              .toList(growable: false);
    final chunkListTitle = 'Chunk List';
    final fillChunkList = _chunkListExpanded;
    final fillPrefabPalette = _prefabPaletteExpanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExpandableSectionCard(
          title: 'Create Chunk',
          subtitle: 'Create, duplicate, or deprecate chunk definitions.',
          expanded: _createChunkExpanded,
          onToggle: () {
            setState(() {
              _createChunkExpanded = !_createChunkExpanded;
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _newChunkIdController,
                decoration: const InputDecoration(
                  labelText: 'New Chunk ID',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: _spaceSm),
              Wrap(
                spacing: _spaceSm,
                runSpacing: _spaceSm,
                children: [
                  FilledButton(
                    onPressed: () {
                      widget.controller.applyCommand(
                        AuthoringCommand(
                          kind: 'create_chunk',
                          payload: <String, Object?>{
                            'id': _newChunkIdController.text.trim(),
                          },
                        ),
                      );
                    },
                    child: const Text('Create'),
                  ),
                  OutlinedButton(
                    onPressed: _selectedChunkKey == null
                        ? null
                        : () {
                            final selectedChunk = _selectedChunk(chunks);
                            widget.controller.applyCommand(
                              AuthoringCommand(
                                kind: 'duplicate_chunk',
                                payload: <String, Object?>{
                                  'chunkKey': _selectedChunkKey!,
                                  'id': '${selectedChunk?.id ?? 'chunk'}_copy',
                                },
                              ),
                            );
                          },
                    child: const Text('Duplicate'),
                  ),
                  OutlinedButton(
                    onPressed: _selectedChunkKey == null
                        ? null
                        : () {
                            widget.controller.applyCommand(
                              AuthoringCommand(
                                kind: 'deprecate_chunk',
                                payload: <String, Object?>{
                                  'chunkKey': _selectedChunkKey!,
                                },
                              ),
                            );
                          },
                    child: const Text('Deprecate'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: _spaceSm),
        Expanded(
          child: Column(
            children: [
              if (fillChunkList)
                Expanded(
                  child: _buildChunkListBrowseCard(
                    scene: scene,
                    chunks: filteredChunks,
                    chunkListTitle: chunkListTitle,
                    fillHeight: true,
                  ),
                )
              else
                _buildChunkListBrowseCard(
                  scene: scene,
                  chunks: filteredChunks,
                  chunkListTitle: chunkListTitle,
                  fillHeight: false,
                ),
              const SizedBox(height: _spaceSm),
              if (fillPrefabPalette)
                Expanded(
                  child: _buildPrefabPaletteCard(scene, fillHeight: true),
                )
              else
                _buildPrefabPaletteCard(scene, fillHeight: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChunkListBrowseCard({
    required ChunkScene scene,
    required List<LevelChunkDef> chunks,
    required String chunkListTitle,
    required bool fillHeight,
  }) {
    final listContent = chunks.isEmpty
        ? const Center(child: Text('No chunks for this difficulty.'))
        : ListView.builder(
            itemCount: chunks.length,
            itemBuilder: (context, index) {
              final chunk = chunks[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == chunks.length - 1 ? 0 : _spaceSm,
                ),
                child: _buildChunkListEntry(scene: scene, chunk: chunk),
              );
            },
          );

    return _buildExpandableSectionCard(
      title: chunkListTitle,
      subtitle: 'Browse authored chunks and select one to edit.',
      expanded: _chunkListExpanded,
      expandBody: fillHeight,
      onToggle: () {
        setState(() {
          _chunkListExpanded = !_chunkListExpanded;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: _spaceSm,
            runSpacing: _spaceSm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _chunkListDifficultyFilter == _chunkListDifficultyAll,
                onSelected: (_) {
                  setState(() {
                    _chunkListDifficultyFilter = _chunkListDifficultyAll;
                  });
                },
              ),
              ChoiceChip(
                label: const Text(chunkDifficultyEarly),
                selected: _chunkListDifficultyFilter == chunkDifficultyEarly,
                onSelected: (_) {
                  setState(() {
                    _chunkListDifficultyFilter = chunkDifficultyEarly;
                  });
                },
              ),
              ChoiceChip(
                label: const Text(chunkDifficultyEasy),
                selected: _chunkListDifficultyFilter == chunkDifficultyEasy,
                onSelected: (_) {
                  setState(() {
                    _chunkListDifficultyFilter = chunkDifficultyEasy;
                  });
                },
              ),
              ChoiceChip(
                label: const Text(chunkDifficultyNormal),
                selected: _chunkListDifficultyFilter == chunkDifficultyNormal,
                onSelected: (_) {
                  setState(() {
                    _chunkListDifficultyFilter = chunkDifficultyNormal;
                  });
                },
              ),
              ChoiceChip(
                label: const Text(chunkDifficultyHard),
                selected: _chunkListDifficultyFilter == chunkDifficultyHard,
                onSelected: (_) {
                  setState(() {
                    _chunkListDifficultyFilter = chunkDifficultyHard;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: _spaceSm),
          if (fillHeight)
            Expanded(child: listContent)
          else
            SizedBox(height: _chunkListViewportHeight, child: listContent),
        ],
      ),
    );
  }

  Widget _buildChunkListEntry({
    required ChunkScene scene,
    required LevelChunkDef chunk,
  }) {
    final isSelected = chunk.chunkKey == _selectedChunkKey;
    final isDirty = widget.controller.dirtyItemIds.contains(chunk.chunkKey);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderColor = isSelected
        ? colorScheme.primary
        : colorScheme.outlineVariant.withValues(alpha: 0.55);
    final backgroundColor = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.22)
        : colorScheme.surface;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final metadataStyle = theme.textTheme.bodySmall;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(_spaceSm),
          border: Border.all(color: borderColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(_spaceSm),
          onTap: () => _selectChunk(chunk),
          child: Padding(
            padding: const EdgeInsets.all(_spaceSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        isDirty ? '* ${chunk.id}' : chunk.id,
                        style: titleStyle,
                      ),
                    ),
                    _buildIssueMarker(
                      chunk.status,
                      color: chunk.status == chunkStatusDeprecated
                          ? colorScheme.error
                          : colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: _spaceSm),
                ChunkScenePreviewTile(
                  key: ValueKey<String>('chunk_list_preview_${chunk.chunkKey}'),
                  imageCache: _prefabPalettePreviewImageCache,
                  workspaceRootPath: widget.controller.workspacePath,
                  chunk: chunk,
                  prefabData: scene.prefabData,
                  runtimeGridSnap: scene.runtimeGridSnap,
                  height: 92,
                ),
                const SizedBox(height: _spaceSm),
                Text(
                  '${chunk.levelId} | ${chunk.difficulty} | rev ${chunk.revision}',
                  style: metadataStyle,
                ),
                if (chunk.tags.isNotEmpty) ...[
                  const SizedBox(height: _spaceXs),
                  Text(
                    chunk.tags.join(', '),
                    style: metadataStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChunkComposerPanel(
    LevelChunkDef? selectedChunk,
    ChunkScene scene,
  ) {
    if (selectedChunk == null) {
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Select a chunk to start composing prefab placements.'),
          ),
        ),
      );
    }

    final selectedPlacement = _selectedPlacement(selectedChunk);
    final selectedPlacementPrefab = _selectedPlacementPrefab(
      scene,
      selectedChunk,
    );
    final selectedMarker = _selectedMarker(selectedChunk);
    final selectedEnemyLabel = selectedMarker == null
        ? null
        : '${selectedMarker.marker.markerId} @ '
              '(${selectedMarker.marker.x}, ${selectedMarker.marker.y})';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(_panelPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chunk Composer',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: _spaceXs),
                      Text(
                        _composerPlaceMode == ChunkScenePlaceMode.prefab
                            ? (selectedPlacement == null
                                  ? 'Place or move prefabs directly in the scene.'
                                  : 'Selected: ${selectedPlacementPrefab?.id ?? selectedPlacement.prefab.resolvedPrefabRef} '
                                        '@ (${selectedPlacement.prefab.x}, ${selectedPlacement.prefab.y})')
                            : (selectedEnemyLabel == null
                                  ? 'Place or move enemy spawn markers directly in the scene.'
                                  : 'Selected Marker: $selectedEnemyLabel'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: _spaceSm),
                FilterChip(
                  key: const ValueKey<String>('chunk_scene_parallax_toggle'),
                  label: const Text('Parallax Preview'),
                  selected: _showParallaxPreview,
                  onSelected: (value) {
                    setState(() {
                      _showParallaxPreview = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: _spaceSm),
            _buildComposerModeControls(
              selectedChunk: selectedChunk,
              selectedMarker: selectedMarker,
            ),
            if (_composerPlaceMode == ChunkScenePlaceMode.prefab) ...[
              const SizedBox(height: _spaceSm),
              _buildSelectedPlacementComposerControls(
                selectedChunk,
                selectedPlacement,
              ),
            ],
            const SizedBox(height: _spaceMd),
            Expanded(
              child: ChunkSceneView(
                workspaceRootPath: widget.controller.workspacePath,
                chunk: selectedChunk,
                prefabData: scene.prefabData,
                runtimeGridSnap: scene.runtimeGridSnap,
                tool: _sceneTool,
                placeMode: _composerPlaceMode,
                placeSnapToGrid: _newPlacementSnapToGrid,
                selectedPalettePrefabKey: _selectedPalettePrefabKey,
                selectedPlacementKey: _selectedPlacementKey,
                selectedEnemyMarkerId: _newEnemyMarkerId,
                selectedMarkerKey: _selectedMarkerKey,
                showParallaxPreview: _showParallaxPreview,
                onToolChanged: (tool) {
                  setState(() {
                    _sceneTool = tool;
                  });
                },
                onPlacePrefab: (x, y) {
                  _placePrefab(selectedChunk, scene, x: x, y: y);
                },
                onSelectPlacement: (selectionKey) {
                  setState(() {
                    _selectedPlacementKey = selectionKey;
                    if (selectionKey != null) {
                      _selectedMarkerKey = null;
                    }
                    if (selectionKey != null) {
                      _sceneTool = ChunkSceneTool.select;
                    }
                  });
                },
                onMovePlacement: (selectionKey, x, y) {
                  _movePlacement(
                    selectedChunk,
                    selectionKey: selectionKey,
                    x: x,
                    y: y,
                  );
                },
                onCommitPlacementMove: () {
                  widget.controller.commitCoalescedUndoStep();
                },
                onRemovePlacement: (selectionKey) {
                  _removePlacement(selectedChunk, selectionKey);
                },
                onPlaceMarker: (x, y) {
                  _placeEnemyMarker(selectedChunk, x: x, y: y);
                },
                onSelectMarker: (selectionKey) {
                  setState(() {
                    _selectedMarkerKey = selectionKey;
                    if (selectionKey != null) {
                      _selectedPlacementKey = null;
                    }
                    if (selectionKey != null) {
                      _sceneTool = ChunkSceneTool.select;
                    }
                  });
                },
                onMoveMarker: (selectionKey, x, y) {
                  _moveEnemyMarker(
                    selectedChunk,
                    selectionKey: selectionKey,
                    x: x,
                    y: y,
                  );
                },
                onCommitMarkerMove: () {
                  widget.controller.commitCoalescedUndoStep();
                },
                onRemoveMarker: (selectionKey) {
                  _removeEnemyMarker(selectedChunk, selectionKey);
                },
              ),
            ),
            const SizedBox(height: _spaceSm),
            _buildDiagnosticsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildPrefabPaletteCard(ChunkScene scene, {bool fillHeight = false}) {
    final allPalette = _placeablePrefabs(scene.prefabData);
    final palette = _filterPrefabsForPalette(allPalette);
    final kindScopedPalette = _prefabPaletteKindFilter == null
        ? allPalette
        : allPalette
              .where((prefab) => prefab.kind == _prefabPaletteKindFilter)
              .toList(growable: false);
    final availableTags = <String>{
      for (final prefab in kindScopedPalette) ...prefab.tags,
    }.toList(growable: false)..sort();
    final prefabSlicesById = <String, AtlasSliceDef>{
      for (final slice in scene.prefabData.prefabSlices) slice.id: slice,
    };
    final tileSlicesById = <String, AtlasSliceDef>{
      for (final slice in scene.prefabData.tileSlices) slice.id: slice,
    };
    final modulesById = <String, TileModuleDef>{
      for (final module in scene.prefabData.platformModules) module.id: module,
    };
    final paletteTitle = 'Prefab Palette';
    return _buildExpandableSectionCard(
      title: paletteTitle,
      subtitle: 'Pick a prefab to place in the chunk scene.',
      expanded: _prefabPaletteExpanded,
      expandBody: fillHeight,
      onToggle: () {
        setState(() {
          _prefabPaletteExpanded = !_prefabPaletteExpanded;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: _spaceSm,
            runSpacing: _spaceSm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _prefabPaletteKindFilter == null,
                onSelected: (_) {
                  setState(() {
                    _prefabPaletteKindFilter = null;
                    final matching = _filterPrefabsForPalette(allPalette);
                    if (matching.any(
                      (prefab) => prefab.prefabKey == _selectedPalettePrefabKey,
                    )) {
                      return;
                    }
                    _selectedPalettePrefabKey = matching.isEmpty
                        ? null
                        : matching.first.prefabKey;
                  });
                },
              ),
              ChoiceChip(
                label: const Text('Obstacle'),
                selected: _prefabPaletteKindFilter == PrefabKind.obstacle,
                onSelected: (_) {
                  setState(() {
                    _prefabPaletteKindFilter = PrefabKind.obstacle;
                    final matching = _filterPrefabsForPalette(allPalette);
                    if (matching.any(
                      (prefab) => prefab.prefabKey == _selectedPalettePrefabKey,
                    )) {
                      return;
                    }
                    _selectedPalettePrefabKey = matching.isEmpty
                        ? null
                        : matching.first.prefabKey;
                  });
                },
              ),
              ChoiceChip(
                label: const Text('Platform'),
                selected: _prefabPaletteKindFilter == PrefabKind.platform,
                onSelected: (_) {
                  setState(() {
                    _prefabPaletteKindFilter = PrefabKind.platform;
                    final matching = _filterPrefabsForPalette(allPalette);
                    if (matching.any(
                      (prefab) => prefab.prefabKey == _selectedPalettePrefabKey,
                    )) {
                      return;
                    }
                    _selectedPalettePrefabKey = matching.isEmpty
                        ? null
                        : matching.first.prefabKey;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: _spaceSm),
          Row(
            children: [
              const SizedBox(width: _spaceSm),
              Expanded(
                child: Autocomplete<String>(
                  initialValue: TextEditingValue(
                    text: _prefabPaletteTagFilter == _prefabPaletteTagAll
                        ? ''
                        : _prefabPaletteTagFilter,
                  ),
                  optionsBuilder: (value) {
                    final query = value.text.trim().toLowerCase();
                    if (query.isEmpty) {
                      return availableTags;
                    }
                    return availableTags.where(
                      (tag) => tag.toLowerCase().contains(query),
                    );
                  },
                  onSelected: (tag) {
                    setState(() {
                      _applyPrefabPaletteTagFilter(allPalette, tag);
                    });
                  },
                  fieldViewBuilder:
                      (
                        context,
                        textEditingController,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Tag',
                            hintText: 'filter prefabs by tag',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon:
                                _prefabPaletteTagFilter == _prefabPaletteTagAll
                                ? null
                                : IconButton(
                                    tooltip: 'Clear tag filter',
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        textEditingController.clear();
                                        _applyPrefabPaletteTagFilter(
                                          allPalette,
                                          '',
                                        );
                                      });
                                    },
                                  ),
                          ),
                          onSubmitted: (value) {
                            setState(() {
                              _applyPrefabPaletteTagFilter(allPalette, value);
                            });
                          },
                        );
                      },
                ),
              ),
            ],
          ),
          const SizedBox(height: _spaceSm),
          const Divider(height: 1),
          const SizedBox(height: _spaceSm),
          if (fillHeight)
            Expanded(
              child: allPalette.isEmpty
                  ? const Center(
                      child: Text('No active prefabs are available to place.'),
                    )
                  : palette.isEmpty
                  ? const Center(
                      child: Text('No prefabs found for the entered tag.'),
                    )
                  : ListView.builder(
                      itemCount: palette.length,
                      itemBuilder: (context, index) {
                        final prefab = palette[index];
                        final isSelected =
                            prefab.prefabKey == _selectedPalettePrefabKey;
                        return ListTile(
                          selected: isSelected,
                          dense: true,
                          leading: _buildPalettePrefabPreview(
                            prefab: prefab,
                            workspaceRootPath: widget.controller.workspacePath,
                            prefabSlicesById: prefabSlicesById,
                            tileSlicesById: tileSlicesById,
                            modulesById: modulesById,
                          ),
                          title: Text(prefab.id),
                          subtitle: Text(
                            '${prefab.kind.jsonValue} | '
                            '${prefab.visualSource.type.jsonValue}',
                          ),
                          onTap: () {
                            setState(() {
                              _selectedPalettePrefabKey = prefab.prefabKey;
                              _composerPlaceMode = ChunkScenePlaceMode.prefab;
                              _selectedMarkerKey = null;
                              _sceneTool = ChunkSceneTool.place;
                            });
                          },
                        );
                      },
                    ),
            )
          else
            SizedBox(
              height: _paletteViewportHeight,
              child: allPalette.isEmpty
                  ? const Center(
                      child: Text('No active prefabs are available to place.'),
                    )
                  : palette.isEmpty
                  ? const Center(
                      child: Text('No prefabs found for the entered tag.'),
                    )
                  : ListView.builder(
                      itemCount: palette.length,
                      itemBuilder: (context, index) {
                        final prefab = palette[index];
                        final isSelected =
                            prefab.prefabKey == _selectedPalettePrefabKey;
                        return ListTile(
                          selected: isSelected,
                          dense: true,
                          leading: _buildPalettePrefabPreview(
                            prefab: prefab,
                            workspaceRootPath: widget.controller.workspacePath,
                            prefabSlicesById: prefabSlicesById,
                            tileSlicesById: tileSlicesById,
                            modulesById: modulesById,
                          ),
                          title: Text(prefab.id),
                          subtitle: Text(
                            '${prefab.kind.jsonValue} | '
                            '${prefab.visualSource.type.jsonValue}',
                          ),
                          onTap: () {
                            setState(() {
                              _selectedPalettePrefabKey = prefab.prefabKey;
                              _composerPlaceMode = ChunkScenePlaceMode.prefab;
                              _selectedMarkerKey = null;
                              _sceneTool = ChunkSceneTool.place;
                            });
                          },
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildPalettePrefabPreview({
    required PrefabDef prefab,
    required String workspaceRootPath,
    required Map<String, AtlasSliceDef> prefabSlicesById,
    required Map<String, AtlasSliceDef> tileSlicesById,
    required Map<String, TileModuleDef> modulesById,
  }) {
    const previewWidth = 40.0;
    const previewHeight = 32.0;
    switch (prefab.visualSource.type) {
      case PrefabVisualSourceType.atlasSlice:
        return AtlasSlicePreviewTile(
          imageCache: _prefabPalettePreviewImageCache,
          workspaceRootPath: workspaceRootPath,
          slice: prefabSlicesById[prefab.sliceId],
          width: previewWidth,
          height: previewHeight,
        );
      case PrefabVisualSourceType.platformModule:
        return PlatformModulePreviewTile(
          imageCache: _prefabPalettePreviewImageCache,
          workspaceRootPath: workspaceRootPath,
          module: modulesById[prefab.moduleId],
          tileSlicesById: tileSlicesById,
          width: previewWidth,
          height: previewHeight,
        );
      case PrefabVisualSourceType.unknown:
        return Icon(
          prefab.kind == PrefabKind.platform
              ? Icons.view_agenda_outlined
              : Icons.category_outlined,
        );
    }
  }

  Widget _buildChunkInspector(LevelChunkDef? selectedChunk, ChunkScene scene) {
    if (selectedChunk == null) {
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Select a chunk to inspect and edit metadata.'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(_panelPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: 'Inspector: ${selectedChunk.id}',
              subtitle: 'Inspect and edit selected chunk details.',
              expanded: _inspectorExpanded,
              onTap: () {
                setState(() {
                  _inspectorExpanded = !_inspectorExpanded;
                });
              },
            ),
            if (_inspectorExpanded) ...[
              const SizedBox(height: _spaceSm),
              _buildReadOnlyIdentitySection(selectedChunk, scene),
              const SizedBox(height: _spaceSm),
              _buildMetadataFields(selectedChunk, scene),
              const SizedBox(height: _spaceSm),
              FilledButton(
                onPressed: () {
                  _applyMetadata(selectedChunk);
                },
                child: const Text('Apply Changes'),
              ),
              const SizedBox(height: _spaceMd),
            ],
            Expanded(
              child: ListView(
                children: [
                  _buildPlacedPrefabSection(selectedChunk, scene),
                  const SizedBox(height: _spaceMd),
                  _buildEnemyMarkerSection(selectedChunk),
                  const SizedBox(height: _spaceMd),
                  _buildGroundProfileSection(selectedChunk, scene),
                  const SizedBox(height: _spaceMd),
                  _buildGroundGapsSection(selectedChunk),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyIdentitySection(
    LevelChunkDef selectedChunk,
    ChunkScene scene,
  ) {
    final sourcePath =
        scene.sourcePathByChunkKey[selectedChunk.chunkKey] ??
        '(new chunk file will be created on apply)';
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(_spaceSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('chunkKey: ${selectedChunk.chunkKey}'),
            Text('sourcePath: $sourcePath'),
            Text('revision: ${selectedChunk.revision}'),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacedPrefabSection(
    LevelChunkDef selectedChunk,
    ChunkScene scene,
  ) {
    final placements = buildChunkPlacedPrefabSelections(selectedChunk.prefabs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExpandableSectionHeader(
          title: 'Placed Prefabs',
          subtitle: placements.isEmpty
              ? 'No placements in this chunk.'
              : '${placements.length} placement${placements.length == 1 ? '' : 's'} in this chunk.',
          expanded: _placedPrefabsExpanded,
          onTap: () {
            setState(() {
              _placedPrefabsExpanded = !_placedPrefabsExpanded;
            });
          },
        ),
        if (_placedPrefabsExpanded) ...[
          const SizedBox(height: _spaceSm),
          if (placements.isEmpty)
            const Text('No prefab placements in this chunk.')
          else
            SizedBox(
              height: _listViewportHeight,
              child: Card(
                margin: EdgeInsets.zero,
                child: ListView.builder(
                  itemCount: placements.length,
                  itemBuilder: (context, index) {
                    final placement = placements[index];
                    final prefab = _resolvePrefabByPlacement(
                      scene.prefabData,
                      placement.prefab,
                    );
                    return ListTile(
                      dense: true,
                      selected: placement.selectionKey == _selectedPlacementKey,
                      title: Text(
                        prefab?.id ?? placement.prefab.resolvedPrefabRef,
                      ),
                      subtitle: Text(
                        'x=${placement.prefab.x}, y=${placement.prefab.y} | '
                        '${placement.prefab.snapToGrid ? 'snap' : 'free'} | '
                        'z=${placement.prefab.zIndex}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Delete placement',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          _removePlacement(
                            selectedChunk,
                            placement.selectionKey,
                          );
                        },
                      ),
                      onTap: () {
                        setState(() {
                          _selectedPlacementKey = placement.selectionKey;
                          _selectedMarkerKey = null;
                          _composerPlaceMode = ChunkScenePlaceMode.prefab;
                          _sceneTool = ChunkSceneTool.select;
                        });
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildComposerModeControls({
    required LevelChunkDef selectedChunk,
    required ChunkPlacedMarkerSelection? selectedMarker,
  }) {
    final enemyControlsSelectedMarker =
        _composerPlaceMode == ChunkScenePlaceMode.enemyMarker
        ? selectedMarker
        : null;
    final enemyChanceRaw = enemyControlsSelectedMarker == null
        ? _defaultNewMarkerChancePercent.toString()
        : enemyControlsSelectedMarker.marker.chancePercent.toString();
    final enemySaltRaw = enemyControlsSelectedMarker == null
        ? _defaultNewMarkerSalt.toString()
        : enemyControlsSelectedMarker.marker.salt.toString();
    final enemyPlacementValue = enemyControlsSelectedMarker == null
        ? _defaultNewMarkerPlacement
        : enemyControlsSelectedMarker.marker.placement;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: _spaceSm,
          runSpacing: _spaceSm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Composer Mode'),
            ChoiceChip(
              label: const Text('Prefabs'),
              selected: _composerPlaceMode == ChunkScenePlaceMode.prefab,
              onSelected: (_) {
                setState(() {
                  _composerPlaceMode = ChunkScenePlaceMode.prefab;
                });
              },
            ),
            ChoiceChip(
              label: const Text('Enemy Spawners'),
              selected: _composerPlaceMode == ChunkScenePlaceMode.enemyMarker,
              onSelected: (_) {
                setState(() {
                  _composerPlaceMode = ChunkScenePlaceMode.enemyMarker;
                  _sceneTool = ChunkSceneTool.place;
                });
              },
            ),
            if (_composerPlaceMode == ChunkScenePlaceMode.enemyMarker)
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String>(
                    'new_enemy_marker_id_$_newEnemyMarkerId',
                  ),
                  initialValue: _newEnemyMarkerId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'enemyId',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final enemyId in _enemyMarkerIds)
                      DropdownMenuItem<String>(
                        value: enemyId,
                        child: Text(enemyId),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _newEnemyMarkerId = value;
                    });
                  },
                ),
              ),
          ],
        ),
        if (_composerPlaceMode == ChunkScenePlaceMode.enemyMarker) ...[
          const SizedBox(height: _spaceSm),
          Wrap(
            spacing: _spaceSm,
            runSpacing: _spaceSm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 120,
                child: TextFormField(
                  key: ValueKey<String>(
                    'new_enemy_marker_chance_percent_'
                    '${enemyControlsSelectedMarker?.selectionKey ?? 'draft'}_'
                    '$enemyChanceRaw',
                  ),
                  initialValue: enemyChanceRaw,
                  decoration: const InputDecoration(
                    labelText: 'chance%',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  enabled: enemyControlsSelectedMarker != null,
                  onChanged: (value) {
                    if (enemyControlsSelectedMarker == null) {
                      return;
                    }
                    final chancePercent = int.tryParse(value.trim());
                    if (chancePercent == null ||
                        chancePercent < 0 ||
                        chancePercent > 100) {
                      return;
                    }
                    _updateEnemyMarkerSettings(
                      selectedChunk,
                      selectionKey: enemyControlsSelectedMarker.selectionKey,
                      chancePercent: chancePercent,
                      salt: enemyControlsSelectedMarker.marker.salt,
                      placement: enemyControlsSelectedMarker.marker.placement,
                    );
                  },
                ),
              ),
              SizedBox(
                width: 100,
                child: TextFormField(
                  key: ValueKey<String>(
                    'new_enemy_marker_salt_'
                    '${enemyControlsSelectedMarker?.selectionKey ?? 'draft'}_'
                    '$enemySaltRaw',
                  ),
                  initialValue: enemySaltRaw,
                  decoration: const InputDecoration(
                    labelText: 'salt',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  enabled: enemyControlsSelectedMarker != null,
                  onChanged: (value) {
                    if (enemyControlsSelectedMarker == null) {
                      return;
                    }
                    final salt = int.tryParse(value.trim());
                    if (salt == null || salt < 0) {
                      return;
                    }
                    _updateEnemyMarkerSettings(
                      selectedChunk,
                      selectionKey: enemyControlsSelectedMarker.selectionKey,
                      chancePercent:
                          enemyControlsSelectedMarker.marker.chancePercent,
                      salt: salt,
                      placement: enemyControlsSelectedMarker.marker.placement,
                    );
                  },
                ),
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String>(
                    'new_enemy_marker_placement_'
                    '${enemyControlsSelectedMarker?.selectionKey ?? 'draft'}_'
                    '$enemyPlacementValue',
                  ),
                  initialValue: enemyPlacementValue,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'placement',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: enemyControlsSelectedMarker == null
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          _updateEnemyMarkerSettings(
                            selectedChunk,
                            selectionKey:
                                enemyControlsSelectedMarker.selectionKey,
                            chancePercent: enemyControlsSelectedMarker
                                .marker
                                .chancePercent,
                            salt: enemyControlsSelectedMarker.marker.salt,
                            placement: value,
                          );
                        },
                  items: [
                    for (final placement in _markerPlacementValues)
                      DropdownMenuItem<String>(
                        value: placement,
                        child: Text(placement),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (enemyControlsSelectedMarker == null) ...[
            const SizedBox(height: _spaceXs),
            const Text(
              'Select an enemy spawner to edit chance%, salt, and placement.',
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildSelectedPlacementComposerControls(
    LevelChunkDef chunk,
    ChunkPlacedPrefabSelection? selectedPlacement,
  ) {
    if (selectedPlacement == null) {
      return const Text(
        'Select a placed prefab to edit selected layer and placement mode.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLayerStepper(
          label: 'Selected Prefab Layer',
          zIndex: selectedPlacement.prefab.zIndex,
          onChanged: (value) {
            _updatePlacementSettings(
              chunk,
              selectionKey: selectedPlacement.selectionKey,
              snapToGrid: selectedPlacement.prefab.snapToGrid,
              zIndex: value,
            );
          },
          keyPrefix: 'selected_prefab_layer',
        ),
        const SizedBox(height: _spaceSm),
        _buildPlacementModeChips(
          label: 'Selected Prefab Placement Mode',
          snapToGrid: selectedPlacement.prefab.snapToGrid,
          onChanged: (value) {
            _updatePlacementSettings(
              chunk,
              selectionKey: selectedPlacement.selectionKey,
              snapToGrid: value,
              zIndex: selectedPlacement.prefab.zIndex,
            );
          },
        ),
      ],
    );
  }

  Widget _buildEnemyMarkerSection(LevelChunkDef selectedChunk) {
    final markers = buildChunkPlacedMarkerSelections(selectedChunk.markers);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExpandableSectionHeader(
          title: 'Enemy Spawn Markers',
          subtitle: markers.isEmpty
              ? 'No enemy markers in this chunk.'
              : '${markers.length} marker${markers.length == 1 ? '' : 's'} in this chunk.',
          expanded: _enemyMarkersExpanded,
          onTap: () {
            setState(() {
              _enemyMarkersExpanded = !_enemyMarkersExpanded;
            });
          },
        ),
        if (_enemyMarkersExpanded) ...[
          const SizedBox(height: _spaceSm),
          if (markers.isEmpty)
            const Text('No enemy spawn markers in this chunk.')
          else
            SizedBox(
              height: _listViewportHeight,
              child: Card(
                margin: EdgeInsets.zero,
                child: ListView.builder(
                  itemCount: markers.length,
                  itemBuilder: (context, index) {
                    final marker = markers[index];
                    return ListTile(
                      dense: true,
                      selected: marker.selectionKey == _selectedMarkerKey,
                      title: Text(marker.marker.markerId),
                      subtitle: Text(
                        'x=${marker.marker.x}, y=${marker.marker.y} | '
                        '${marker.marker.chancePercent}% | '
                        'salt=${marker.marker.salt} | '
                        '${marker.marker.placement}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Delete marker',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          _removeEnemyMarker(
                            selectedChunk,
                            marker.selectionKey,
                          );
                        },
                      ),
                      onTap: () {
                        setState(() {
                          _selectedMarkerKey = marker.selectionKey;
                          _composerPlaceMode = ChunkScenePlaceMode.enemyMarker;
                          _sceneTool = ChunkSceneTool.select;
                        });
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildMetadataFields(LevelChunkDef selectedChunk, ChunkScene scene) {
    return Column(
      children: [
        TextField(
          controller: _renameIdController,
          decoration: const InputDecoration(
            labelText: 'id',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: _spaceSm),
        TextField(
          controller: _levelIdController,
          decoration: const InputDecoration(
            labelText: 'levelId',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: _spaceSm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tileSizeController,
                readOnly: true,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'tileSize',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: _spaceSm),
            Expanded(
              child: TextField(
                controller: _widthController,
                readOnly: true,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'width',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: _spaceSm),
            Expanded(
              child: TextField(
                controller: _heightController,
                readOnly: true,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'height',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: _spaceSm),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey<String>('difficulty-$_difficulty'),
                initialValue: _difficulty,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'difficulty',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: chunkDifficultyEarly,
                    child: Text(chunkDifficultyEarly),
                  ),
                  DropdownMenuItem(
                    value: chunkDifficultyEasy,
                    child: Text(chunkDifficultyEasy),
                  ),
                  DropdownMenuItem(
                    value: chunkDifficultyNormal,
                    child: Text(chunkDifficultyNormal),
                  ),
                  DropdownMenuItem(
                    value: chunkDifficultyHard,
                    child: Text(chunkDifficultyHard),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _difficulty = value;
                  });
                },
              ),
            ),
            const SizedBox(width: _spaceSm),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey<String>('status-$_status'),
                initialValue: _status,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'status',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: chunkStatusActive,
                    child: Text(chunkStatusActive),
                  ),
                  DropdownMenuItem(
                    value: chunkStatusDeprecated,
                    child: Text(chunkStatusDeprecated),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _status = value;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: _spaceSm),
        TextField(
          controller: _tagsController,
          decoration: const InputDecoration(
            labelText: 'tags (comma separated)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: _spaceXs),
        Text(
          'Runtime authority: gridSnap=${scene.runtimeGridSnap.toStringAsFixed(1)}, '
          'chunkWidth=${scene.runtimeChunkWidth.toStringAsFixed(1)}',
        ),
        const SizedBox(height: _spaceXs),
        Text(
          'Locked viewport: width=${scene.runtimeChunkWidth.round()}, '
          'height=${scene.lockedChunkHeight}, '
          'floorY=${scene.runtimeGroundTopY}',
        ),
      ],
    );
  }

  Widget _buildGroundProfileSection(
    LevelChunkDef selectedChunk,
    ChunkScene scene,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExpandableSectionHeader(
          title: 'Ground Profile',
          subtitle: 'Runtime floor lock and ground band layer for this chunk.',
          expanded: _groundProfileExpanded,
          onTap: () {
            setState(() {
              _groundProfileExpanded = !_groundProfileExpanded;
            });
          },
        ),
        if (_groundProfileExpanded) ...[
          const SizedBox(height: _spaceSm),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String>('ground-kind-$_groundProfileKind'),
                  initialValue: _groundProfileKind,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'kind',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: groundProfileKindFlat,
                      child: Text(groundProfileKindFlat),
                    ),
                  ],
                  onChanged: null,
                ),
              ),
              const SizedBox(width: _spaceSm),
              Expanded(
                child: TextField(
                  controller: _groundTopYController,
                  readOnly: true,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'topY',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _spaceXs),
          Text(
            'Locked to runtime viewport floor baseline ${scene.runtimeGroundTopY}.',
          ),
          const SizedBox(height: _spaceSm),
          _buildLayerStepper(
            label: 'Ground Band Layer',
            keyPrefix: 'ground_band_layer',
            zIndex: selectedChunk.groundBandZIndex,
            onChanged: (value) {
              _updateGroundBandZIndex(selectedChunk, value);
            },
          ),
          const SizedBox(height: _spaceXs),
          const Text(
            'Compared against placed prefab z values in the chunk scene.',
          ),
        ],
      ],
    );
  }

  Widget _buildExpandableSectionHeader({
    required String title,
    String? subtitle,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return _buildSectionHeader(
      title: title,
      subtitle: subtitle,
      expanded: expanded,
      onTap: onTap,
    );
  }

  Widget _buildExpandableSectionCard({
    required String title,
    String? subtitle,
    Widget? marker,
    required bool expanded,
    bool expandBody = false,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(_panelPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              title: title,
              subtitle: subtitle,
              expanded: expanded,
              onTap: onToggle,
              marker: marker,
            ),
            if (expanded && expandBody) ...[
              const SizedBox(height: _spaceSm),
              Expanded(child: child),
            ] else if (expanded) ...[
              const SizedBox(height: _spaceSm),
              child,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? subtitle,
    required bool expanded,
    required VoidCallback onTap,
    Widget? marker,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: _spaceXs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (marker != null) ...[marker, const SizedBox(width: _spaceSm)],
              Icon(expanded ? Icons.expand_more : Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroundGapsSection(LevelChunkDef selectedChunk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExpandableSectionHeader(
          title: 'Ground Gaps',
          subtitle: selectedChunk.groundGaps.isEmpty
              ? 'No gaps configured for this chunk.'
              : '${selectedChunk.groundGaps.length} gap${selectedChunk.groundGaps.length == 1 ? '' : 's'} configured.',
          expanded: _groundGapsExpanded,
          onTap: () {
            setState(() {
              _groundGapsExpanded = !_groundGapsExpanded;
            });
          },
        ),
        if (_groundGapsExpanded) ...[
          const SizedBox(height: _spaceSm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('new_ground_gap_x'),
                  controller: _newGapXController,
                  decoration: const InputDecoration(
                    labelText: 'x',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: _spaceSm),
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('new_ground_gap_width'),
                  controller: _newGapWidthController,
                  decoration: const InputDecoration(
                    labelText: 'width',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: _spaceSm),
              FilledButton(
                key: const ValueKey<String>('add_ground_gap'),
                onPressed: () {
                  final x = int.tryParse(_newGapXController.text.trim());
                  final width = int.tryParse(
                    _newGapWidthController.text.trim(),
                  );
                  if (x == null || width == null) {
                    _showSnackBar('Gap x/width must be integers.');
                    return;
                  }
                  final snappedGap = _snapGroundGapValues(
                    selectedChunk,
                    x: x,
                    width: width,
                  );
                  widget.controller.applyCommand(
                    AuthoringCommand(
                      kind: 'add_ground_gap',
                      payload: <String, Object?>{
                        'chunkKey': selectedChunk.chunkKey,
                        'x': snappedGap.x,
                        'width': snappedGap.width,
                      },
                    ),
                  );
                  _resetNewGapDraft();
                },
                child: const Text('Add Gap'),
              ),
            ],
          ),
          const SizedBox(height: _spaceSm),
          if (selectedChunk.groundGaps.isEmpty)
            const Text('No gaps.')
          else
            ...selectedChunk.groundGaps.map((gap) {
              final draftKey = _groundGapDraftKey(selectedChunk, gap);
              final draftXRaw =
                  _groundGapXDraftByKey[draftKey] ?? gap.x.toString();
              final draftWidthRaw =
                  _groundGapWidthDraftByKey[draftKey] ?? gap.width.toString();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${gap.gapId} (${gap.type})'),
                subtitle: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: TextFormField(
                        key: ValueKey<String>(
                          'ground_gap_x_${selectedChunk.chunkKey}_${gap.gapId}',
                        ),
                        initialValue: draftXRaw,
                        decoration: const InputDecoration(
                          labelText: 'x',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          _groundGapXDraftByKey[draftKey] = value;
                        },
                      ),
                    ),
                    const SizedBox(width: _spaceSm),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        key: ValueKey<String>(
                          'ground_gap_width_${selectedChunk.chunkKey}_${gap.gapId}',
                        ),
                        initialValue: draftWidthRaw,
                        decoration: const InputDecoration(
                          labelText: 'width',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          _groundGapWidthDraftByKey[draftKey] = value;
                        },
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: ValueKey<String>(
                        'ground_gap_save_${selectedChunk.chunkKey}_${gap.gapId}',
                      ),
                      icon: const Icon(Icons.save_outlined),
                      tooltip: 'Save Gap',
                      onPressed: () {
                        _saveGroundGapDraft(
                          selectedChunk,
                          gap,
                          draftXRaw:
                              _groundGapXDraftByKey[draftKey] ?? draftXRaw,
                          draftWidthRaw:
                              _groundGapWidthDraftByKey[draftKey] ??
                              draftWidthRaw,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        widget.controller.applyCommand(
                          AuthoringCommand(
                            kind: 'remove_ground_gap',
                            payload: <String, Object?>{
                              'chunkKey': selectedChunk.chunkKey,
                              'gapId': gap.gapId,
                            },
                          ),
                        );
                        setState(() {
                          _groundGapXDraftByKey.remove(draftKey);
                          _groundGapWidthDraftByKey.remove(draftKey);
                        });
                      },
                    ),
                  ],
                ),
              );
            }),
        ],
      ],
    );
  }

  Widget _buildDiagnosticsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildValidationSummaryCard()),
        const SizedBox(width: _spaceSm),
        Expanded(child: _buildPendingDiffSummaryCard()),
      ],
    );
  }

  Widget _buildValidationSummaryCard() {
    final issues = widget.controller.issues;
    final hasIssues = issues.isNotEmpty;
    final summary = hasIssues
        ? '${widget.controller.errorCount} errors, ${widget.controller.warningCount} warnings'
        : 'No validation issues';
    return _buildExpandableSummaryCard(
      title: 'Validation',
      expanded: _validationExpanded,
      onToggle: () {
        setState(() {
          _validationExpanded = !_validationExpanded;
        });
      },
      marker: hasIssues
          ? _buildIssueMarker(
              '${widget.controller.errorCount + widget.controller.warningCount}',
              color: widget.controller.errorCount > 0
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.tertiary,
            )
          : null,
      summary: summary,
      child: issues.isEmpty
          ? const Text('No validation issues.')
          : SizedBox(
              height: _listViewportHeight,
              child: ListView.builder(
                itemCount: issues.length,
                itemBuilder: (context, index) {
                  final issue = issues[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(issue.message),
                    subtitle: issue.sourcePath == null
                        ? Text(issue.code)
                        : Text('${issue.code} - ${issue.sourcePath}'),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildPendingDiffSummaryCard() {
    final pendingChanges = widget.controller.pendingChanges;
    final selectedDiff = _selectedDiff(pendingChanges);
    final hasPending = pendingChanges.fileDiffs.isNotEmpty;
    final summary = hasPending
        ? 'chunks=${pendingChanges.changedItemIds.length} files=${pendingChanges.fileDiffs.length}'
        : 'No pending file changes';
    return _buildExpandableSummaryCard(
      title: 'Pending Diff',
      expanded: _pendingDiffExpanded,
      onToggle: () {
        setState(() {
          _pendingDiffExpanded = !_pendingDiffExpanded;
        });
      },
      marker: hasPending
          ? _buildIssueMarker(
              '${pendingChanges.fileDiffs.length}',
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      summary: summary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pendingChanges.fileDiffs.length > 1)
            DropdownButton<String>(
              value: selectedDiff?.relativePath,
              isExpanded: true,
              items: [
                for (final fileDiff in pendingChanges.fileDiffs)
                  DropdownMenuItem<String>(
                    value: fileDiff.relativePath,
                    child: Text(fileDiff.relativePath),
                  ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedDiffPath = value;
                });
              },
            ),
          if (pendingChanges.fileDiffs.length > 1)
            const SizedBox(height: _spaceSm),
          SizedBox(
            height: _listViewportHeight,
            child: selectedDiff == null
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No pending file changes.'),
                  )
                : SingleChildScrollView(
                    child: SelectableText(
                      selectedDiff.unifiedDiff,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSummaryCard({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required String summary,
    required Widget child,
    Widget? marker,
  }) {
    return _buildExpandableSectionCard(
      title: title,
      subtitle: summary,
      marker: marker,
      expanded: expanded,
      onToggle: onToggle,
      child: child,
    );
  }

  Widget _buildIssueMarker(String label, {required Color color}) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _spaceSm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: onSurface)),
    );
  }

  Widget _buildErrorBanner(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: _spaceSm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(_spaceSm),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(_spaceSm),
        ),
        child: Text(
          message,
          style: TextStyle(color: colorScheme.onErrorContainer),
        ),
      ),
    );
  }

  void _ensureSelectionAfterBuild(List<LevelChunkDef> chunks) {
    if (chunks.isEmpty) {
      if (_selectedChunkKey == null) {
        return;
      }
      _runAfterBuild(() {
        _selectedChunkKey = null;
      });
      return;
    }
    if (_selectedChunkKey != null &&
        chunks.any((chunk) => chunk.chunkKey == _selectedChunkKey)) {
      return;
    }
    final fallback = chunks.first;
    _runAfterBuild(() {
      _selectedChunkKey = fallback.chunkKey;
      _syncInspector(fallback);
    });
  }

  void _ensureDiffSelectionAfterBuild(PendingChanges pendingChanges) {
    if (pendingChanges.fileDiffs.isEmpty) {
      if (_selectedDiffPath == null) {
        return;
      }
      _runAfterBuild(() {
        _selectedDiffPath = null;
      });
      return;
    }
    final selectedStillValid = pendingChanges.fileDiffs.any(
      (diff) => diff.relativePath == _selectedDiffPath,
    );
    if (selectedStillValid) {
      return;
    }
    final fallbackPath = pendingChanges.fileDiffs.first.relativePath;
    _runAfterBuild(() {
      _selectedDiffPath = fallbackPath;
    });
  }

  void _runAfterBuild(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(callback);
    });
  }

  LevelChunkDef? _selectedChunk(List<LevelChunkDef> chunks) {
    final selectedChunkKey = _selectedChunkKey;
    if (selectedChunkKey == null) {
      return null;
    }
    for (final chunk in chunks) {
      if (chunk.chunkKey == selectedChunkKey) {
        return chunk;
      }
    }
    return null;
  }

  void _ensurePaletteSelectionAfterBuild(ChunkScene? scene) {
    final allPalette = scene == null
        ? const <PrefabDef>[]
        : _placeablePrefabs(scene.prefabData);
    final palette = _filterPrefabsForPalette(allPalette);
    if (palette.isEmpty) {
      if (_selectedPalettePrefabKey == null) {
        return;
      }
      _runAfterBuild(() {
        _selectedPalettePrefabKey = null;
      });
      return;
    }
    final selectedKey = _selectedPalettePrefabKey;
    if (selectedKey != null &&
        palette.any((prefab) => prefab.prefabKey == selectedKey)) {
      return;
    }
    final fallbackKey = palette.first.prefabKey;
    _runAfterBuild(() {
      _selectedPalettePrefabKey = fallbackKey;
    });
  }

  List<PrefabDef> _filterPrefabsByTag(List<PrefabDef> prefabs, String tag) {
    if (tag == _prefabPaletteTagAll) {
      return prefabs;
    }
    final query = tag.toLowerCase();
    return prefabs
        .where(
          (prefab) => prefab.tags.any((value) => value.toLowerCase() == query),
        )
        .toList(growable: false);
  }

  List<PrefabDef> _filterPrefabsForPalette(List<PrefabDef> prefabs) {
    final byKind = _prefabPaletteKindFilter == null
        ? prefabs
        : prefabs
              .where((prefab) => prefab.kind == _prefabPaletteKindFilter)
              .toList(growable: false);
    return _filterPrefabsByTag(byKind, _prefabPaletteTagFilter);
  }

  void _applyPrefabPaletteTagFilter(List<PrefabDef> allPalette, String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      _prefabPaletteTagFilter = _prefabPaletteTagAll;
    } else {
      final canonicalTag = allPalette
          .expand((prefab) => prefab.tags)
          .firstWhere(
            (tag) => tag.toLowerCase() == trimmed.toLowerCase(),
            orElse: () => trimmed,
          );
      _prefabPaletteTagFilter = canonicalTag;
    }

    final matching = _filterPrefabsForPalette(allPalette);
    if (matching.any(
      (prefab) => prefab.prefabKey == _selectedPalettePrefabKey,
    )) {
      return;
    }
    _selectedPalettePrefabKey = matching.isEmpty
        ? null
        : matching.first.prefabKey;
  }

  void _ensurePlacementSelectionAfterBuild(LevelChunkDef? chunk) {
    if (chunk == null) {
      if (_selectedPlacementKey == null) {
        return;
      }
      _runAfterBuild(() {
        _selectedPlacementKey = null;
      });
      return;
    }
    final selectedPlacementKey = _selectedPlacementKey;
    if (selectedPlacementKey == null) {
      return;
    }
    final placementStillValid = buildChunkPlacedPrefabSelections(
      chunk.prefabs,
    ).any((placement) => placement.selectionKey == selectedPlacementKey);
    if (placementStillValid) {
      return;
    }
    _runAfterBuild(() {
      _selectedPlacementKey = null;
    });
  }

  void _ensureMarkerSelectionAfterBuild(LevelChunkDef? chunk) {
    if (chunk == null) {
      if (_selectedMarkerKey == null) {
        return;
      }
      _runAfterBuild(() {
        _selectedMarkerKey = null;
      });
      return;
    }
    final selectedMarkerKey = _selectedMarkerKey;
    if (selectedMarkerKey == null) {
      return;
    }
    final markerStillValid = buildChunkPlacedMarkerSelections(
      chunk.markers,
    ).any((marker) => marker.selectionKey == selectedMarkerKey);
    if (markerStillValid) {
      return;
    }
    _runAfterBuild(() {
      _selectedMarkerKey = null;
    });
  }

  List<PrefabDef> _placeablePrefabs(PrefabData prefabData) {
    final prefabs =
        prefabData.prefabs
            .where((prefab) => prefab.status == PrefabStatus.active)
            .toList(growable: false)
          ..sort((a, b) {
            final kindCompare = a.kind.jsonValue.compareTo(b.kind.jsonValue);
            if (kindCompare != 0) {
              return kindCompare;
            }
            final idCompare = a.id.compareTo(b.id);
            if (idCompare != 0) {
              return idCompare;
            }
            return a.prefabKey.compareTo(b.prefabKey);
          });
    return prefabs;
  }

  PrefabDef? _selectedPalettePrefab(ChunkScene scene) {
    final selectedPalettePrefabKey = _selectedPalettePrefabKey;
    if (selectedPalettePrefabKey == null || selectedPalettePrefabKey.isEmpty) {
      return null;
    }
    for (final prefab in scene.prefabData.prefabs) {
      if (prefab.prefabKey == selectedPalettePrefabKey) {
        return prefab;
      }
    }
    return null;
  }

  ChunkPlacedPrefabSelection? _selectedPlacement(LevelChunkDef chunk) {
    final selectedPlacementKey = _selectedPlacementKey;
    if (selectedPlacementKey == null || selectedPlacementKey.isEmpty) {
      return null;
    }
    for (final placement in buildChunkPlacedPrefabSelections(chunk.prefabs)) {
      if (placement.selectionKey == selectedPlacementKey) {
        return placement;
      }
    }
    return null;
  }

  ChunkPlacedMarkerSelection? _selectedMarker(LevelChunkDef chunk) {
    final selectedMarkerKey = _selectedMarkerKey;
    if (selectedMarkerKey == null || selectedMarkerKey.isEmpty) {
      return null;
    }
    for (final marker in buildChunkPlacedMarkerSelections(chunk.markers)) {
      if (marker.selectionKey == selectedMarkerKey) {
        return marker;
      }
    }
    return null;
  }

  String _groundGapDraftKey(LevelChunkDef chunk, GroundGapDef gap) {
    return '${chunk.chunkKey}::${gap.gapId}';
  }

  LevelChunkDef? _selectedChunkForDraftChecks() {
    final scene = widget.controller.scene;
    final chunkScene = scene is ChunkScene ? scene : null;
    return chunkScene == null ? null : _selectedChunk(chunkScene.chunks);
  }

  bool _hasUnsavedGroundGapDraftChanges() {
    final document = widget.controller.document;
    if (document is! ChunkDocument) {
      return false;
    }

    final gapByDraftKey = <String, GroundGapDef>{};
    for (final chunk in document.chunks) {
      for (final gap in chunk.groundGaps) {
        gapByDraftKey[_groundGapDraftKey(chunk, gap)] = gap;
      }
    }

    for (final entry in _groundGapXDraftByKey.entries) {
      final gap = gapByDraftKey[entry.key];
      if (gap != null && entry.value.trim() != gap.x.toString()) {
        return true;
      }
    }
    for (final entry in _groundGapWidthDraftByKey.entries) {
      final gap = gapByDraftKey[entry.key];
      if (gap != null && entry.value.trim() != gap.width.toString()) {
        return true;
      }
    }
    return false;
  }

  ({int x, int width}) _snapGroundGapValues(
    LevelChunkDef chunk, {
    required int x,
    required int width,
  }) {
    final snapUnit = _authoritativeRuntimeTileSize(chunk);
    final snappedX = _roundToNearestMultiple(x, snapUnit);
    var snappedWidth = _roundToNearestMultiple(width, snapUnit);
    if (snappedWidth <= 0) {
      snappedWidth = snapUnit;
    }
    return (x: snappedX, width: snappedWidth);
  }

  int _authoritativeRuntimeTileSize(LevelChunkDef chunk) {
    final document = widget.controller.document;
    if (document is ChunkDocument) {
      final runtimeTileSize = document.runtimeGridSnap.round();
      if (runtimeTileSize > 0) {
        return runtimeTileSize;
      }
    }
    return chunk.tileSize > 0 ? chunk.tileSize : 1;
  }

  void _resetNewGapDraft() {
    _newGapXController.text = _defaultNewGapX;
    _newGapWidthController.text = _defaultNewGapWidth;
  }

  void _saveGroundGapDraft(
    LevelChunkDef chunk,
    GroundGapDef gap, {
    required String draftXRaw,
    required String draftWidthRaw,
  }) {
    final x = int.tryParse(draftXRaw.trim());
    final width = int.tryParse(draftWidthRaw.trim());
    if (x == null || width == null) {
      _showSnackBar('Gap x/width must be integers.');
      return;
    }

    final snappedGap = _snapGroundGapValues(chunk, x: x, width: width);
    final draftKey = _groundGapDraftKey(chunk, gap);
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'update_ground_gap',
        payload: <String, Object?>{
          'chunkKey': chunk.chunkKey,
          'gapId': gap.gapId,
          'type': gap.type,
          'x': snappedGap.x,
          'width': snappedGap.width,
        },
      ),
    );
    setState(() {
      _groundGapXDraftByKey[draftKey] = snappedGap.x.toString();
      _groundGapWidthDraftByKey[draftKey] = snappedGap.width.toString();
    });
  }

  int _roundToNearestMultiple(int value, int multiple) {
    if (multiple <= 0) {
      return value;
    }
    return (value / multiple).round() * multiple;
  }

  String _selectionKeyForPlacementChange(
    LevelChunkDef chunk, {
    String? currentSelectionKey,
    required PlacedPrefabDef nextPlacement,
  }) {
    return buildChunkPlacedPrefabSelectionKey(
      nextPlacement.resolvedPrefabRef,
      x: nextPlacement.x,
      y: nextPlacement.y,
      ordinalAtLocation: _ordinalAtLocationForPlacement(
        chunk,
        nextPlacement: nextPlacement,
        currentSelectionKey: currentSelectionKey,
      ),
    );
  }

  int _ordinalAtLocationForPlacement(
    LevelChunkDef chunk, {
    required PlacedPrefabDef nextPlacement,
    String? currentSelectionKey,
  }) {
    var ordinal = 0;
    for (final entry in buildChunkPlacedPrefabSelections(chunk.prefabs)) {
      if (currentSelectionKey != null &&
          entry.selectionKey == currentSelectionKey) {
        continue;
      }
      final placement = entry.prefab;
      if (placement.resolvedPrefabRef != nextPlacement.resolvedPrefabRef ||
          placement.x != nextPlacement.x ||
          placement.y != nextPlacement.y) {
        continue;
      }
      if (comparePlacedPrefabsDeterministic(placement, nextPlacement) < 0) {
        ordinal += 1;
      }
    }
    return ordinal;
  }

  String _selectionKeyForMarkerChange(
    LevelChunkDef chunk, {
    String? currentSelectionKey,
    required PlacedMarkerDef nextMarker,
  }) {
    return buildChunkPlacedMarkerSelectionKey(
      nextMarker.markerId,
      x: nextMarker.x,
      y: nextMarker.y,
      ordinalAtLocation: _ordinalAtLocationForMarker(
        chunk,
        nextMarker: nextMarker,
        currentSelectionKey: currentSelectionKey,
      ),
    );
  }

  int _ordinalAtLocationForMarker(
    LevelChunkDef chunk, {
    required PlacedMarkerDef nextMarker,
    String? currentSelectionKey,
  }) {
    var ordinal = 0;
    for (final entry in buildChunkPlacedMarkerSelections(chunk.markers)) {
      if (currentSelectionKey != null &&
          entry.selectionKey == currentSelectionKey) {
        continue;
      }
      final marker = entry.marker;
      if (marker.markerId != nextMarker.markerId ||
          marker.x != nextMarker.x ||
          marker.y != nextMarker.y) {
        continue;
      }
      if (comparePlacedMarkersDeterministic(marker, nextMarker) < 0) {
        ordinal += 1;
      }
    }
    return ordinal;
  }

  Widget _buildPlacementModeChips({
    String label = 'Placement Mode',
    required bool snapToGrid,
    required ValueChanged<bool> onChanged,
  }) {
    return Wrap(
      spacing: _spaceSm,
      runSpacing: _spaceSm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(label),
        ChoiceChip(
          label: const Text('Snap'),
          selected: snapToGrid,
          onSelected: (_) => onChanged(true),
        ),
        ChoiceChip(
          label: const Text('Free'),
          selected: !snapToGrid,
          onSelected: (_) => onChanged(false),
        ),
      ],
    );
  }

  Widget _buildLayerStepper({
    required String label,
    required int zIndex,
    required ValueChanged<int> onChanged,
    String? keyPrefix,
  }) {
    return Wrap(
      spacing: _spaceSm,
      runSpacing: _spaceSm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(label),
        OutlinedButton.icon(
          key: keyPrefix == null
              ? null
              : ValueKey<String>('${keyPrefix}_lower'),
          onPressed: () => onChanged(zIndex - 1),
          icon: const Icon(Icons.remove, size: 18),
          label: const Text('Lower'),
        ),
        Chip(
          key: keyPrefix == null
              ? null
              : ValueKey<String>('${keyPrefix}_value'),
          label: Text('z=$zIndex'),
        ),
        OutlinedButton.icon(
          key: keyPrefix == null
              ? null
              : ValueKey<String>('${keyPrefix}_raise'),
          onPressed: () => onChanged(zIndex + 1),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Raise'),
        ),
      ],
    );
  }

  PrefabDef? _selectedPlacementPrefab(ChunkScene scene, LevelChunkDef chunk) {
    final placement = _selectedPlacement(chunk);
    if (placement == null) {
      return null;
    }
    return _resolvePrefabByPlacement(scene.prefabData, placement.prefab);
  }

  PrefabDef? _resolvePrefabByPlacement(
    PrefabData prefabData,
    PlacedPrefabDef placement,
  ) {
    for (final prefab in prefabData.prefabs) {
      if (placement.prefabKey.isNotEmpty &&
          prefab.prefabKey == placement.prefabKey) {
        return prefab;
      }
      if (placement.prefabId.isNotEmpty && prefab.id == placement.prefabId) {
        return prefab;
      }
    }
    return null;
  }

  void _placePrefab(
    LevelChunkDef chunk,
    ChunkScene scene, {
    required int x,
    required int y,
  }) {
    final selectedPrefab = _selectedPalettePrefab(scene);
    if (selectedPrefab == null) {
      _showSnackBar('Choose a prefab from the palette first.');
      return;
    }
    final nextPlacement = PlacedPrefabDef(
      prefabId: selectedPrefab.id,
      prefabKey: selectedPrefab.prefabKey,
      x: x,
      y: y,
      zIndex: _newPlacementZIndex,
      snapToGrid: _newPlacementSnapToGrid,
    );
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'add_prefab_placement',
        payload: <String, Object?>{
          'chunkKey': chunk.chunkKey,
          'prefabKey': selectedPrefab.prefabKey,
          'x': x,
          'y': y,
          'zIndex': _newPlacementZIndex,
          'snapToGrid': _newPlacementSnapToGrid,
        },
      ),
    );
    setState(() {
      _selectedPlacementKey = _selectionKeyForPlacementChange(
        chunk,
        nextPlacement: nextPlacement,
      );
      _selectedMarkerKey = null;
      _composerPlaceMode = ChunkScenePlaceMode.prefab;
      _sceneTool = ChunkSceneTool.select;
    });
  }

  void _placeEnemyMarker(
    LevelChunkDef chunk, {
    required int x,
    required int y,
  }) {
    final markerId = _newEnemyMarkerId.trim();
    const chancePercent = _defaultNewMarkerChancePercent;
    const salt = _defaultNewMarkerSalt;
    if (markerId.isEmpty) {
      _showSnackBar('Choose an enemy marker type first.');
      return;
    }
    final nextMarker = PlacedMarkerDef(
      markerId: markerId,
      x: x,
      y: y,
      chancePercent: chancePercent,
      salt: salt,
      placement: _defaultNewMarkerPlacement,
    );
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'add_enemy_marker',
        payload: <String, Object?>{
          'chunkKey': chunk.chunkKey,
          'markerId': markerId,
          'x': x,
          'y': y,
          'chancePercent': chancePercent,
          'salt': salt,
          'placement': _defaultNewMarkerPlacement,
        },
      ),
    );
    setState(() {
      _selectedMarkerKey = _selectionKeyForMarkerChange(
        chunk,
        nextMarker: nextMarker,
      );
      _composerPlaceMode = ChunkScenePlaceMode.enemyMarker;
      _sceneTool = ChunkSceneTool.select;
    });
  }

  void _movePlacement(
    LevelChunkDef chunk, {
    required String selectionKey,
    required int x,
    required int y,
  }) {
    final selectedPlacement = _selectedPlacement(chunk);
    widget.controller.applyCoalescedCommand(
      AuthoringCommand(
        kind: 'move_prefab_placement',
        payload: <String, Object?>{
          'chunkKey': chunk.chunkKey,
          'selectionKey': selectionKey,
          'x': x,
          'y': y,
        },
      ),
    );
    if (selectedPlacement == null) {
      return;
    }
    setState(() {
      _selectedPlacementKey = _selectionKeyForPlacementChange(
        chunk,
        currentSelectionKey: selectionKey,
        nextPlacement: selectedPlacement.prefab.copyWith(x: x, y: y),
      );
    });
  }

  void _updatePlacementSettings(
    LevelChunkDef chunk, {
    required String selectionKey,
    required bool snapToGrid,
    required int zIndex,
  }) {
    final selectedPlacement = _selectedPlacement(chunk);
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'update_prefab_placement_settings',
        payload: <String, Object?>{
          'chunkKey': chunk.chunkKey,
          'selectionKey': selectionKey,
          'zIndex': zIndex,
          'snapToGrid': snapToGrid,
        },
      ),
    );
    if (selectedPlacement == null) {
      return;
    }
    setState(() {
      _selectedPlacementKey = _selectionKeyForPlacementChange(
        chunk,
        currentSelectionKey: selectionKey,
        nextPlacement: selectedPlacement.prefab.copyWith(
          zIndex: zIndex,
          snapToGrid: snapToGrid,
        ),
      );
    });
  }

  void _removePlacement(LevelChunkDef chunk, String selectionKey) {
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'remove_prefab_placement',
        payload: <String, Object?>{
          'chunkKey': chunk.chunkKey,
          'selectionKey': selectionKey,
        },
      ),
    );
    setState(() {
      if (_selectedPlacementKey == selectionKey) {
        _selectedPlacementKey = null;
      }
    });
  }

  void _moveEnemyMarker(
    LevelChunkDef chunk, {
    required String selectionKey,
    required int x,
    required int y,
  }) {
    final selectedMarker = _selectedMarker(chunk);
    widget.controller.applyCoalescedCommand(
      AuthoringCommand(
        kind: 'move_enemy_marker',
        payload: <String, Object?>{
          'chunkKey': chunk.chunkKey,
          'selectionKey': selectionKey,
          'x': x,
          'y': y,
        },
      ),
    );
    if (selectedMarker == null) {
      return;
    }
    setState(() {
      _selectedMarkerKey = _selectionKeyForMarkerChange(
        chunk,
        currentSelectionKey: selectionKey,
        nextMarker: selectedMarker.marker.copyWith(x: x, y: y),
      );
    });
  }

  void _updateEnemyMarkerSettings(
    LevelChunkDef chunk, {
    required String selectionKey,
    required int chancePercent,
    required int salt,
    required String placement,
  }) {
    final selectedMarker = _selectedMarker(chunk);
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'update_enemy_marker_settings',
        payload: <String, Object?>{
          'chunkKey': chunk.chunkKey,
          'selectionKey': selectionKey,
          'chancePercent': chancePercent,
          'salt': salt,
          'placement': placement,
        },
      ),
    );
    if (selectedMarker == null) {
      return;
    }
    setState(() {
      _selectedMarkerKey = _selectionKeyForMarkerChange(
        chunk,
        currentSelectionKey: selectionKey,
        nextMarker: selectedMarker.marker.copyWith(
          chancePercent: chancePercent,
          salt: salt,
          placement: placement,
        ),
      );
    });
  }

  void _removeEnemyMarker(LevelChunkDef chunk, String selectionKey) {
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'remove_enemy_marker',
        payload: <String, Object?>{
          'chunkKey': chunk.chunkKey,
          'selectionKey': selectionKey,
        },
      ),
    );
    setState(() {
      if (_selectedMarkerKey == selectionKey) {
        _selectedMarkerKey = null;
      }
    });
  }

  void _updateGroundBandZIndex(LevelChunkDef chunk, int groundBandZIndex) {
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'update_ground_band_z_index',
        payload: <String, Object?>{
          'chunkKey': chunk.chunkKey,
          'groundBandZIndex': groundBandZIndex,
        },
      ),
    );
  }

  PendingFileDiff? _selectedDiff(PendingChanges pendingChanges) {
    final selectedPath = _selectedDiffPath;
    if (selectedPath == null) {
      return pendingChanges.fileDiffs.isEmpty
          ? null
          : pendingChanges.fileDiffs.first;
    }
    for (final diff in pendingChanges.fileDiffs) {
      if (diff.relativePath == selectedPath) {
        return diff;
      }
    }
    return pendingChanges.fileDiffs.isEmpty
        ? null
        : pendingChanges.fileDiffs.first;
  }

  void _selectChunk(LevelChunkDef chunk) {
    setState(() {
      _selectedChunkKey = chunk.chunkKey;
      _selectedPlacementKey = null;
      _selectedMarkerKey = null;
      _sceneTool = ChunkSceneTool.select;
      _syncInspector(chunk);
    });
  }

  void _syncInspector(LevelChunkDef chunk) {
    _renameIdController.text = chunk.id;
    _levelIdController.text = chunk.levelId;
    _tileSizeController.text = chunk.tileSize.toString();
    _widthController.text = chunk.width.toString();
    _heightController.text = chunk.height.toString();
    _tagsController.text = chunk.tags.join(', ');
    _groundTopYController.text = chunk.groundProfile.topY.toString();
    _difficulty = chunk.difficulty;
    _status = chunk.status;
    _groundProfileKind = chunk.groundProfile.kind;
  }

  bool _metadataDraftDiffersFromSelectedChunk(LevelChunkDef? chunk) {
    if (chunk == null) {
      return false;
    }
    return _renameIdController.text.trim() != chunk.id ||
        _levelIdController.text.trim() != chunk.levelId ||
        _tileSizeController.text.trim() != chunk.tileSize.toString() ||
        _tagsController.text.trim() != chunk.tags.join(', ') ||
        _difficulty != chunk.difficulty ||
        _status != chunk.status;
  }

  void _applyMetadata(LevelChunkDef chunk) {
    final tileSize = _authoritativeRuntimeTileSize(chunk);

    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'update_chunk_metadata',
        payload: <String, Object?>{
          'chunkKey': chunk.chunkKey,
          'id': _renameIdController.text.trim(),
          'levelId': _levelIdController.text.trim(),
          'tileSize': tileSize,
          'difficulty': _difficulty,
          'status': _status,
          'tags': _tagsController.text.trim(),
        },
      ),
    );
  }

  Future<void> _confirmAndApplyToFiles() async {
    final pendingChanges = widget.controller.pendingChanges;
    if (!pendingChanges.hasChanges) {
      _showSnackBar('No pending changes to apply.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Apply Chunk Changes'),
          content: Text(
            'Write ${pendingChanges.changedItemIds.length} chunk change(s) '
            'across ${pendingChanges.fileDiffs.length} file(s)?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await widget.controller.exportDirectWrite();
    if (!mounted) {
      return;
    }
    if (widget.controller.exportError != null) {
      _showSnackBar('Apply failed: ${widget.controller.exportError}');
      return;
    }
    _showSnackBar('Chunk changes applied.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
