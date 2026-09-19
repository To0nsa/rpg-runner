import 'package:flutter/material.dart';

import '../../../../chunks/chunk_connection_creation.dart';
import '../../../../chunks/chunk_level_target.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_models.dart';
import 'chunk_connections_panel.dart';
import 'chunk_v2_owner_form.dart';

/// Uses ordinary Chunk naming/group/difficulty controls with a checked joined
/// preview. The result is an intent; the plugin performs creation and history.
class ChunkConnectionCreationDialog extends StatefulWidget {
  const ChunkConnectionCreationDialog({
    super.key,
    required this.document,
    required this.scene,
    required this.template,
    required this.workspaceRootPath,
    this.initialGroup,
    this.initialDifficulty,
  });
  final String? initialGroup;
  final String? initialDifficulty;
  final ChunkV2Document document;
  final ChunkV2Scene scene;
  final ChunkConnectionTemplate template;
  final String workspaceRootPath;

  @override
  State<ChunkConnectionCreationDialog> createState() =>
      _ChunkConnectionCreationDialogState();
}

class _ChunkConnectionCreationDialogState
    extends State<ChunkConnectionCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _keyInput = TextEditingController();
  late String _group;
  late String _difficulty;
  ChunkV2FileData? _preview;
  String? _error;

  @override
  void initState() {
    super.initState();
    final predecessor = widget.template.predecessor;
    _group = widget.initialGroup ?? predecessor.assemblyGroupId;
    _difficulty = widget.initialDifficulty ?? predecessor.difficulty;
    final base = '${predecessor.chunkKey}_next';
    var key = base;
    var suffix = 2;
    while (widget.document.chunks.any(
      (chunk) => chunk.chunkKey.toLowerCase() == key.toLowerCase(),
    )) {
      key = '${base}_${suffix++}';
    }
    _keyInput.text = key;
    _refresh();
  }

  @override
  void dispose() {
    _keyInput.dispose();
    super.dispose();
  }

  ChunkConnectionCreation get _intent => ChunkConnectionCreation(
    predecessorKey: widget.template.predecessor.chunkKey,
    predecessorSignature: widget.template.signature,
    heightStepPx: widget.template.presets.stepPx,
    groundTopY: widget.template.presets.groundTopY,
    chunkKey: _keyInput.text.trim(),
    groupId: _group,
    difficulty: _difficulty,
  );

  void _refresh() {
    _preview = null;
    _error = validateChunkV2OwnerKey(
      _keyInput.text.trim(),
      document: widget.document,
    );
    if (_error != null) return;
    try {
      _preview = buildConnectingChunk(widget.document, _intent);
    } on ChunkTargetException catch (error) {
      _error = error.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entranceYHalfPixels =
        widget.template.boundary.coverageIntervals.single.minYTicks ~/ 512;
    final level = widget.document.levels.firstWhere(
      (level) => level.levelId == widget.template.predecessor.levelId,
    );
    return AlertDialog(
      title: const Text('Create connecting chunk'),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Flat ground: ${_heightLabel(entranceYHalfPixels)} · matches ${widget.template.predecessor.chunkKey} exit',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('connecting_chunk_key'),
                  controller: _keyInput,
                  decoration: const InputDecoration(labelText: 'Chunk key'),
                  validator: (value) => validateChunkV2OwnerKey(
                    value ?? '',
                    document: widget.document,
                  ),
                  onChanged: (_) => setState(_refresh),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _group,
                  decoration: const InputDecoration(labelText: 'Group'),
                  items: [
                    for (final group in level.chunkThemeGroups)
                      DropdownMenuItem(value: group, child: Text(group)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _group = value;
                        _refresh();
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _difficulty,
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                  items: [
                    for (final difficulty in [
                      'early',
                      'easy',
                      'normal',
                      'hard',
                    ])
                      DropdownMenuItem(
                        value: difficulty,
                        child: Text(difficulty),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _difficulty = value;
                        _refresh();
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (_preview case final preview?)
                  ChunkConnectionPreview(
                    left: widget.template.predecessor,
                    right: preview,
                    scene: widget.scene,
                    workspaceRootPath: widget.workspaceRootPath,
                  ),
                if (_error case final error?)
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Creates an independent editable chunk. Save writes it to the repository.',
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('connecting_chunk_create'),
          onPressed: _preview == null
              ? null
              : () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.of(context).pop(_intent);
                  }
                },
          child: const Text('Create'),
        ),
      ],
    );
  }

  String _heightLabel(int yHalfPixels) {
    final y = yHalfPixels / 2;
    final elevation = widget.template.presets.elevationAt(y);
    final name = elevation == null
        ? 'Custom'
        : '${elevation.name[0].toUpperCase()}${elevation.name.substring(1)}';
    return '$name · Y ${y.toStringAsFixed(y == y.roundToDouble() ? 0 : 1)}';
  }
}
