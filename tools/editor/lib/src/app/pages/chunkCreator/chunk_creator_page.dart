import 'dart:async';

import 'package:flutter/material.dart';

import '../../../chunks/chunk_domain_models.dart';
import '../../../domain/authoring_types.dart';
import '../../../prefabs/models/models.dart';
import '../../../session/editor_session_controller.dart';
import '../shared/editor_page_local_draft_state.dart';
import 'widgets/chunk_scene_view.dart';

class ChunkCreatorPage extends StatefulWidget {
  const ChunkCreatorPage({super.key, required this.controller});

  final EditorSessionController controller;

  @override
  State<ChunkCreatorPage> createState() => _ChunkCreatorPageState();
}

class _ChunkCreatorPageState extends State<ChunkCreatorPage>
    implements EditorPageLocalDraftState {
  static const String _defaultNewChunkId = 'new_chunk';
  static const String _defaultNewGapX = '0';
  static const String _defaultNewGapWidth = '16';

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

  String? _selectedChunkKey;
  String? _selectedDiffPath;
  String _difficulty = chunkDifficultyNormal;
  String _status = chunkStatusActive;
  String _groundProfileKind = groundProfileKindFlat;
  String? _selectedPalettePrefabKey;
  String? _selectedPlacementKey;
  ChunkSceneTool _sceneTool = ChunkSceneTool.place;
  bool _newPlacementSnapToGrid = true;
  int _newPlacementZIndex = 0;
  bool _inspectorExpanded = true;
  bool _validationExpanded = false;
  bool _pendingDiffExpanded = false;

  @override
  bool get hasLocalDraftChanges {
    final scene = widget.controller.scene;
    final chunkScene = scene is ChunkScene ? scene : null;
    final selectedChunk = chunkScene == null
        ? null
        : _selectedChunk(chunkScene.chunks);
    return _newChunkIdController.text.trim() != _defaultNewChunkId ||
        _newGapXController.text.trim() != _defaultNewGapX ||
        _newGapWidthController.text.trim() != _defaultNewGapWidth ||
        _metadataDraftDiffersFromSelectedChunk(selectedChunk);
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
        _ensureDiffSelectionAfterBuild(widget.controller.pendingChanges);

        if (widget.controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildControls(chunkScene),
                const SizedBox(height: 12),
                if (widget.controller.loadError != null)
                  _buildErrorBanner(widget.controller.loadError!),
                if (widget.controller.exportError != null)
                  _buildErrorBanner(widget.controller.exportError!),
                if (chunkScene == null)
                  const Expanded(
                    child: Center(
                      child: Text('Chunk scene is not loaded for this route.'),
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
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildChunkComposerPanel(
                            selectedChunk,
                            chunkScene,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: _buildChunkInspector(selectedChunk, chunkScene),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls(ChunkScene? scene) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chunks',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _newChunkIdController,
                          decoration: const InputDecoration(
                            labelText: 'New Chunk ID',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
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
                                      final selectedChunk = _selectedChunk(
                                        chunks,
                                      );
                                      widget.controller.applyCommand(
                                        AuthoringCommand(
                                          kind: 'duplicate_chunk',
                                          payload: <String, Object?>{
                                            'chunkKey': _selectedChunkKey!,
                                            'id':
                                                '${selectedChunk?.id ?? 'chunk'}_copy',
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
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: chunks.length,
                            itemBuilder: (context, index) {
                              final chunk = chunks[index];
                              final isSelected =
                                  chunk.chunkKey == _selectedChunkKey;
                              final isDirty =
                                  widget.controller.dirtyItemIds.contains(
                                chunk.chunkKey,
                              );
                              return ListTile(
                                selected: isSelected,
                                title: Text(
                                  isDirty ? '* ${chunk.id}' : chunk.id,
                                ),
                                subtitle: Text(
                                  '${chunk.levelId} | ${chunk.status} | rev ${chunk.revision}',
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedChunkKey = chunk.chunkKey;
                                    _selectedPlacementKey = null;
                                    _sceneTool = ChunkSceneTool.select;
                                    _syncInspector(chunk);
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildPrefabPaletteCard(scene)),
            ],
          ),
        ),
      ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chunk Composer',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              selectedPlacement == null
                  ? 'Place or move prefabs directly in the scene.'
                  : 'Selected: ${selectedPlacementPrefab?.id ?? selectedPlacement.prefab.resolvedPrefabRef} '
                        '@ (${selectedPlacement.prefab.x}, ${selectedPlacement.prefab.y})',
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ChunkSceneView(
                workspaceRootPath: widget.controller.workspacePath,
                chunk: selectedChunk,
                prefabData: scene.prefabData,
                runtimeGridSnap: scene.runtimeGridSnap,
                tool: _sceneTool,
                placeSnapToGrid: _newPlacementSnapToGrid,
                selectedPalettePrefabKey: _selectedPalettePrefabKey,
                selectedPlacementKey: _selectedPlacementKey,
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
              ),
            ),
            const SizedBox(height: 8),
            _buildDiagnosticsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildPrefabPaletteCard(ChunkScene scene) {
    final palette = _placeablePrefabs(scene.prefabData);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prefab Palette',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _buildPlacementModeChips(
              snapToGrid: _newPlacementSnapToGrid,
              onChanged: (value) {
                setState(() {
                  _newPlacementSnapToGrid = value;
                });
              },
            ),
            const SizedBox(height: 8),
            _buildPlacementLayerStepper(
              zIndex: _newPlacementZIndex,
              onChanged: (value) {
                setState(() {
                  _newPlacementZIndex = value;
                });
              },
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: palette.isEmpty
                  ? const Center(
                      child: Text('No active prefabs are available to place.'),
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
                          leading: Icon(
                            prefab.kind == PrefabKind.platform
                                ? Icons.view_agenda_outlined
                                : Icons.category_outlined,
                          ),
                          title: Text(prefab.id),
                          subtitle: Text(
                            '${prefab.kind.jsonValue} | '
                            '${prefab.visualSource.type.jsonValue}',
                          ),
                          onTap: () {
                            setState(() {
                              _selectedPalettePrefabKey = prefab.prefabKey;
                              _sceneTool = ChunkSceneTool.place;
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _inspectorExpanded = !_inspectorExpanded;
                });
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Inspector: ${selectedChunk.id}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Icon(
                    _inspectorExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                ],
              ),
            ),
            if (_inspectorExpanded) ...[
              const SizedBox(height: 8),
              _buildReadOnlyIdentitySection(selectedChunk, scene),
              const SizedBox(height: 8),
              TextField(
                controller: _renameIdController,
                decoration: const InputDecoration(
                  labelText: 'Rename ID',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  widget.controller.applyCommand(
                    AuthoringCommand(
                      kind: 'rename_chunk',
                      payload: <String, Object?>{
                        'chunkKey': selectedChunk.chunkKey,
                        'id': _renameIdController.text.trim(),
                      },
                    ),
                  );
                },
                child: const Text('Rename'),
              ),
              const Divider(height: 20),
            ],
            Expanded(
              child: ListView(
                children: [
                  _buildPlacedPrefabSection(selectedChunk, scene),
                  const Divider(height: 20),
                  _buildMetadataFields(selectedChunk, scene),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      _applyMetadata(selectedChunk);
                    },
                    child: const Text('Apply Metadata'),
                  ),
                  const Divider(height: 20),
                  _buildGroundProfileSection(selectedChunk, scene),
                  const SizedBox(height: 8),
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
    return Card(
      color: const Color(0xFF1E2730),
      child: Padding(
        padding: const EdgeInsets.all(8),
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
    final selectedPlacement = _selectedPlacement(selectedChunk);
    final selectedPlacementPrefab = _selectedPlacementPrefab(
      scene,
      selectedChunk,
    );
    final selectedPalettePrefab = _selectedPalettePrefab(scene);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Placed Prefabs', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (selectedPlacement != null)
          Card(
            color: const Color(0xFF18232C),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedPlacementPrefab?.id ??
                        selectedPlacement.prefab.resolvedPrefabRef,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'anchor=(${selectedPlacement.prefab.x}, ${selectedPlacement.prefab.y})',
                  ),
                  if (selectedPlacementPrefab != null)
                    Text(
                      'kind=${selectedPlacementPrefab.kind.jsonValue} '
                      'source=${selectedPlacementPrefab.visualSource.type.jsonValue}',
                    ),
                  Text(
                    'placement=${selectedPlacement.prefab.snapToGrid ? 'snap' : 'free'} '
                    '| z=${selectedPlacement.prefab.zIndex}',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Placement settings are owned by this chunk instance, not by the prefab definition.',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildPlacementModeChips(
                        snapToGrid: selectedPlacement.prefab.snapToGrid,
                        onChanged: (value) {
                          _updatePlacementSettings(
                            selectedChunk,
                            selectionKey: selectedPlacement.selectionKey,
                            snapToGrid: value,
                            zIndex: selectedPlacement.prefab.zIndex,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildPlacementLayerStepper(
                    zIndex: selectedPlacement.prefab.zIndex,
                    onChanged: (value) {
                      _updatePlacementSettings(
                        selectedChunk,
                        selectionKey: selectedPlacement.selectionKey,
                        snapToGrid: selectedPlacement.prefab.snapToGrid,
                        zIndex: value,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: selectedPalettePrefab == null
                            ? null
                            : () {
                                _replacePlacement(
                                  selectedChunk,
                                  selectedPlacement.selectionKey,
                                  selectedPalettePrefab,
                                );
                              },
                        child: const Text('Retarget To Palette'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          _removePlacement(
                            selectedChunk,
                            selectedPlacement.selectionKey,
                          );
                        },
                        child: const Text('Delete Placement'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          const Text('No placement selected.'),
        const SizedBox(height: 8),
        if (placements.isEmpty)
          const Text('No prefab placements in this chunk.')
        else
          SizedBox(
            height: 180,
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
                    onTap: () {
                      setState(() {
                        _selectedPlacementKey = placement.selectionKey;
                        _sceneTool = ChunkSceneTool.select;
                      });
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMetadataFields(LevelChunkDef selectedChunk, ChunkScene scene) {
    return Column(
      children: [
        TextField(
          controller: _levelIdController,
          decoration: const InputDecoration(
            labelText: 'levelId',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tileSizeController,
                decoration: const InputDecoration(
                  labelText: 'tileSize',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
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
            const SizedBox(width: 8),
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
        const SizedBox(height: 8),
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
            const SizedBox(width: 8),
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
        const SizedBox(height: 8),
        TextField(
          controller: _tagsController,
          decoration: const InputDecoration(
            labelText: 'tags (comma separated)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Runtime authority: gridSnap=${scene.runtimeGridSnap.toStringAsFixed(1)}, '
          'chunkWidth=${scene.runtimeChunkWidth.toStringAsFixed(1)}',
        ),
        const SizedBox(height: 4),
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
        Text('Ground Profile', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
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
            const SizedBox(width: 8),
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
        const SizedBox(height: 4),
        Text(
          'Locked to runtime viewport floor baseline ${scene.runtimeGroundTopY}.',
        ),
      ],
    );
  }

  Widget _buildGroundGapsSection(LevelChunkDef selectedChunk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ground Gaps', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newGapXController,
                decoration: const InputDecoration(
                  labelText: 'x',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _newGapWidthController,
                decoration: const InputDecoration(
                  labelText: 'width',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final x = int.tryParse(_newGapXController.text.trim());
                final width = int.tryParse(_newGapWidthController.text.trim());
                if (x == null || width == null) {
                  _showSnackBar('Gap x/width must be integers.');
                  return;
                }
                widget.controller.applyCommand(
                  AuthoringCommand(
                    kind: 'add_ground_gap',
                    payload: <String, Object?>{
                      'chunkKey': selectedChunk.chunkKey,
                      'x': x,
                      'width': width,
                    },
                  ),
                );
              },
              child: const Text('Add Gap'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (selectedChunk.groundGaps.isEmpty)
          const Text('No gaps.')
        else
          ...selectedChunk.groundGaps.map((gap) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${gap.gapId} (${gap.type})'),
              subtitle: Text('x=${gap.x}, width=${gap.width}'),
              trailing: IconButton(
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
                },
              ),
            );
          }),
      ],
    );
  }

  Widget _buildDiagnosticsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildValidationSummaryCard()),
        const SizedBox(width: 8),
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
                  ? const Color(0xFFB94B4B)
                  : const Color(0xFFB58A33),
            )
          : null,
      summary: summary,
      child: issues.isEmpty
          ? const Text('No validation issues.')
          : SizedBox(
              height: 180,
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
              color: const Color(0xFF497AA8),
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
          if (pendingChanges.fileDiffs.length > 1) const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: selectedDiff == null
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No pending file changes.'),
                  )
                : SingleChildScrollView(
                    child: SelectableText(
                      selectedDiff.unifiedDiff,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onToggle,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (marker != null) ...[marker, const SizedBox(width: 8)],
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(summary, style: Theme.of(context).textTheme.bodySmall),
            if (expanded) ...[
              const SizedBox(height: 8),
              child,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIssueMarker(String label, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        color: const Color(0xFF5A1F1F),
        child: Text(message),
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
    final palette = scene == null
        ? const <PrefabDef>[]
        : _placeablePrefabs(scene.prefabData);
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

  Widget _buildPlacementModeChips({
    required bool snapToGrid,
    required ValueChanged<bool> onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Placement Mode'),
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

  Widget _buildPlacementLayerStepper({
    required int zIndex,
    required ValueChanged<int> onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Layer'),
        OutlinedButton.icon(
          onPressed: () => onChanged(zIndex - 1),
          icon: const Icon(Icons.remove, size: 18),
          label: const Text('Lower'),
        ),
        Chip(label: Text('z=$zIndex')),
        OutlinedButton.icon(
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

  void _replacePlacement(
    LevelChunkDef chunk,
    String selectionKey,
    PrefabDef prefab,
  ) {
    final placement = _selectedPlacement(chunk);
    if (placement == null) {
      return;
    }
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: 'replace_prefab_placement',
        payload: <String, Object?>{
          'chunkKey': chunk.chunkKey,
          'selectionKey': selectionKey,
          'prefabKey': prefab.prefabKey,
        },
      ),
    );
    setState(() {
      _selectedPlacementKey = _selectionKeyForPlacementChange(
        chunk,
        currentSelectionKey: selectionKey,
        nextPlacement: placement.prefab.copyWith(
          prefabKey: prefab.prefabKey,
          prefabId: prefab.id,
        ),
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
    final tileSize = int.tryParse(_tileSizeController.text.trim());
    if (tileSize == null) {
      _showSnackBar('tileSize must be an integer.');
      return;
    }

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
