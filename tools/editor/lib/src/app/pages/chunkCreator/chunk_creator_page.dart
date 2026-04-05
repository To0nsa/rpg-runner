import 'dart:async';

import 'package:flutter/material.dart';

import '../../../chunks/chunk_domain_models.dart';
import '../../../domain/authoring_types.dart';
import '../../../session/editor_session_controller.dart';
import '../shared/editor_page_local_draft_state.dart';

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
  final TextEditingController _entrySocketController = TextEditingController();
  final TextEditingController _exitSocketController = TextEditingController();
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
    _entrySocketController.dispose();
    _exitSocketController.dispose();
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
                          flex: 2,
                          child: _buildChunkListPanel(chunkScene, chunks),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: _buildChunkInspector(
                            selectedChunk,
                            chunkScene,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: _buildDiagnosticsPanel()),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chunks', style: Theme.of(context).textTheme.titleMedium),
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
                              final selectedChunk = _selectedChunk(chunks);
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: ListView.builder(
              itemCount: chunks.length,
              itemBuilder: (context, index) {
                final chunk = chunks[index];
                final isSelected = chunk.chunkKey == _selectedChunkKey;
                final isDirty = widget.controller.dirtyItemIds.contains(
                  chunk.chunkKey,
                );
                return ListTile(
                  selected: isSelected,
                  title: Text(isDirty ? '* ${chunk.id}' : chunk.id),
                  subtitle: Text(
                    '${chunk.levelId} | ${chunk.status} | rev ${chunk.revision}',
                  ),
                  onTap: () {
                    setState(() {
                      _selectedChunkKey = chunk.chunkKey;
                      _syncInspector(chunk);
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
            Text(
              'Inspector: ${selectedChunk.id}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
            Expanded(
              child: ListView(
                children: [
                  _buildMetadataFields(selectedChunk, scene),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      _applyMetadata(selectedChunk);
                    },
                    child: const Text('Apply Metadata'),
                  ),
                  const Divider(height: 20),
                  _buildGroundProfileSection(selectedChunk),
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
              child: TextField(
                controller: _entrySocketController,
                decoration: const InputDecoration(
                  labelText: 'entrySocket',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _exitSocketController,
                decoration: const InputDecoration(
                  labelText: 'exitSocket',
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
      ],
    );
  }

  Widget _buildGroundProfileSection(LevelChunkDef selectedChunk) {
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
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _groundProfileKind = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _groundTopYController,
                decoration: const InputDecoration(
                  labelText: 'topY',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final topY = int.tryParse(_groundTopYController.text.trim());
                if (topY == null) {
                  _showSnackBar('groundProfile.topY must be an integer.');
                  return;
                }
                widget.controller.applyCommand(
                  AuthoringCommand(
                    kind: 'update_ground_profile',
                    payload: <String, Object?>{
                      'chunkKey': selectedChunk.chunkKey,
                      'kind': _groundProfileKind,
                      'topY': topY,
                    },
                  ),
                );
              },
              child: const Text('Apply'),
            ),
          ],
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

  Widget _buildDiagnosticsPanel() {
    final issues = widget.controller.issues;
    final pendingChanges = widget.controller.pendingChanges;
    final selectedDiff = _selectedDiff(pendingChanges);
    return Column(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Validation (${widget.controller.errorCount} errors, '
                    '${widget.controller.warningCount} warnings)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: issues.isEmpty
                        ? const Text('No validation issues.')
                        : ListView.builder(
                            itemCount: issues.length,
                            itemBuilder: (context, index) {
                              final issue = issues[index];
                              return ListTile(
                                dense: true,
                                title: Text(issue.message),
                                subtitle: issue.sourcePath == null
                                    ? Text(issue.code)
                                    : Text(
                                        '${issue.code} - ${issue.sourcePath}',
                                      ),
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
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending Diff',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'chunks=${pendingChanges.changedItemIds.length} '
                    'files=${pendingChanges.fileDiffs.length}',
                  ),
                  if (pendingChanges.fileDiffs.length > 1) ...[
                    const SizedBox(height: 8),
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
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    child: selectedDiff == null
                        ? const Text('No pending file changes.')
                        : SingleChildScrollView(
                            child: SelectableText(
                              selectedDiff.unifiedDiff,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontFamily: 'monospace'),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
    _entrySocketController.text = chunk.entrySocket;
    _exitSocketController.text = chunk.exitSocket;
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
        _widthController.text.trim() != chunk.width.toString() ||
        _heightController.text.trim() != chunk.height.toString() ||
        _entrySocketController.text.trim() != chunk.entrySocket ||
        _exitSocketController.text.trim() != chunk.exitSocket ||
        _tagsController.text.trim() != chunk.tags.join(', ') ||
        _groundTopYController.text.trim() !=
            chunk.groundProfile.topY.toString() ||
        _difficulty != chunk.difficulty ||
        _status != chunk.status ||
        _groundProfileKind != chunk.groundProfile.kind;
  }

  void _applyMetadata(LevelChunkDef chunk) {
    final tileSize = int.tryParse(_tileSizeController.text.trim());
    final width = int.tryParse(_widthController.text.trim());
    final height = int.tryParse(_heightController.text.trim());
    if (tileSize == null || width == null || height == null) {
      _showSnackBar('tileSize/width/height must be integers.');
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
          'width': width,
          'height': height,
          'entrySocket': _entrySocketController.text.trim(),
          'exitSocket': _exitSocketController.text.trim(),
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
