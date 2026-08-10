import 'package:flutter/material.dart';

import '../../../../chunks/chunk_domain_models.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_models.dart';

/// Validated editable metadata returned by the Chunk-v2 owner form.
///
/// Stable identity, dimensions, composition, markers, and collision geometry
/// are excluded so callers cannot accidentally fold them into a metadata edit.
@immutable
final class ChunkV2OwnerDialogResult {
  ChunkV2OwnerDialogResult({
    required this.status,
    required this.levelId,
    required this.difficulty,
    required this.assemblyGroupId,
    required Iterable<String> tags,
    required this.groundBandZIndex,
  }) : tags = List<String>.unmodifiable(tags);

  final String status;
  final String levelId;
  final String difficulty;
  final String assemblyGroupId;
  final List<String> tags;
  final int groundBandZIndex;
}

/// Opens the retained Chunk-v2 metadata form for one existing owner.
Future<ChunkV2OwnerDialogResult?> showChunkV2OwnerDialog(
  BuildContext context, {
  required ChunkV2Document document,
  required ChunkV2FileData chunk,
}) => showDialog<ChunkV2OwnerDialogResult>(
  context: context,
  builder: (context) => _ChunkV2OwnerDialog(document: document, chunk: chunk),
);

/// Opens the create form accepted by the current lifecycle policy.
Future<String?> showChunkV2CreateDialog(
  BuildContext context, {
  required ChunkV2Document document,
}) => showDialog<String>(
  context: context,
  builder: (context) => _ChunkV2IdDialog(
    document: document,
    title: 'Create chunk owner',
    applyLabel: 'Create',
    fieldKey: 'chunk_v2_create_id_field',
    applyKey: 'chunk_v2_create_apply',
    helperText:
        'Creates an empty deprecated owner using the active level\'s locked '
        'dimensions.',
  ),
);

/// Opens the stable-key-preserving human-ID rename form.
Future<String?> showChunkV2RenameDialog(
  BuildContext context, {
  required ChunkV2Document document,
  required ChunkV2FileData chunk,
}) => showDialog<String>(
  context: context,
  builder: (context) => _ChunkV2IdDialog(
    document: document,
    chunk: chunk,
    title: 'Rename chunk owner',
    applyLabel: 'Rename',
    fieldKey: 'chunk_v2_rename_id_field',
    applyKey: 'chunk_v2_rename_apply',
    helperText: 'The stable chunk key is preserved.',
  ),
);

final class _ChunkV2IdDialog extends StatefulWidget {
  const _ChunkV2IdDialog({
    required this.document,
    required this.title,
    required this.applyLabel,
    required this.fieldKey,
    required this.applyKey,
    required this.helperText,
    this.chunk,
  });

  final ChunkV2Document document;
  final ChunkV2FileData? chunk;
  final String title;
  final String applyLabel;
  final String fieldKey;
  final String applyKey;
  final String helperText;

  @override
  State<_ChunkV2IdDialog> createState() => _ChunkV2IdDialogState();
}

final class _ChunkV2IdDialogState extends State<_ChunkV2IdDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.chunk?.id ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 420,
      child: TextField(
        key: ValueKey<String>(widget.fieldKey),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Human ID',
          errorText: _error,
          helperText: widget.helperText,
        ),
        onSubmitted: (_) => _submit(),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: ValueKey<String>(widget.applyKey),
        onPressed: _submit,
        child: Text(widget.applyLabel),
      ),
    ],
  );

  void _submit() {
    final value = _validOwnerId(
      _controller.text,
      document: widget.document,
      exceptChunkKey: widget.chunk?.chunkKey,
    );
    if (value != null) {
      Navigator.of(context).pop(value);
      return;
    }
    setState(() {
      _error =
          'Use a unique lowercase ID beginning with a letter; digits and '
          'underscores are allowed.';
    });
  }
}

final class _ChunkV2OwnerDialog extends StatefulWidget {
  const _ChunkV2OwnerDialog({required this.document, required this.chunk});

  final ChunkV2Document document;
  final ChunkV2FileData chunk;

  @override
  State<_ChunkV2OwnerDialog> createState() => _ChunkV2OwnerDialogState();
}

final class _ChunkV2OwnerDialogState extends State<_ChunkV2OwnerDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _tagsController;
  late final TextEditingController _groundBandZIndexController;
  late String _status;
  late String _levelId;
  late String _difficulty;
  late String _assemblyGroupId;

  @override
  void initState() {
    super.initState();
    final chunk = widget.chunk;
    _status = chunk.status;
    _levelId = chunk.levelId;
    _difficulty = chunk.difficulty;
    final groups = _assemblyGroups(widget.document, _levelId);
    _assemblyGroupId = groups.contains(chunk.assemblyGroupId)
        ? chunk.assemblyGroupId
        : groups.first;
    _tagsController = TextEditingController(text: chunk.tags.join(', '));
    _groundBandZIndexController = TextEditingController(
      text: chunk.groundBandZIndex.toString(),
    );
  }

  @override
  void dispose() {
    _tagsController.dispose();
    _groundBandZIndexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _assemblyGroups(widget.document, _levelId);
    final levelIds = widget.document.availableLevelIds.toList(growable: false)
      ..sort();
    return AlertDialog(
      title: Text('Edit ${widget.chunk.id} metadata'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'chunkKey: ${widget.chunk.chunkKey} · '
                  'revision ${widget.chunk.revision}',
                ),
                Text(
                  '${widget.chunk.width}×${widget.chunk.height} px · '
                  'tile ${widget.chunk.tileSize} px',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey<String>('chunk_v2_owner_status_$_status'),
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items:
                      const <String>[chunkStatusActive, chunkStatusDeprecated]
                          .map(
                            (status) => DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey<String>('chunk_v2_owner_level_$_levelId'),
                  initialValue: _levelId,
                  decoration: const InputDecoration(labelText: 'Level'),
                  items: levelIds
                      .map(
                        (levelId) => DropdownMenuItem<String>(
                          value: levelId,
                          child: Text(levelId),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null || value == _levelId) return;
                    setState(() {
                      _levelId = value;
                      final nextGroups = _assemblyGroups(
                        widget.document,
                        value,
                      );
                      if (!nextGroups.contains(_assemblyGroupId)) {
                        _assemblyGroupId = nextGroups.first;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey<String>(
                    'chunk_v2_owner_assembly_${_levelId}_$_assemblyGroupId',
                  ),
                  initialValue: _assemblyGroupId,
                  decoration: const InputDecoration(
                    labelText: 'Chunk theme group',
                  ),
                  items: groups
                      .map(
                        (groupId) => DropdownMenuItem<String>(
                          value: groupId,
                          child: Text(groupId),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _assemblyGroupId = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey<String>(
                    'chunk_v2_owner_difficulty_$_difficulty',
                  ),
                  initialValue: _difficulty,
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                  items:
                      const <String>[
                            chunkDifficultyEarly,
                            chunkDifficultyEasy,
                            chunkDifficultyNormal,
                            chunkDifficultyHard,
                          ]
                          .map(
                            (difficulty) => DropdownMenuItem<String>(
                              value: difficulty,
                              child: Text(difficulty),
                            ),
                          )
                          .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setState(() => _difficulty = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey<String>('chunk_v2_owner_tags_field'),
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    helperText:
                        'Comma-separated; saved uniquely in lexical order.',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey<String>(
                    'chunk_v2_owner_ground_band_z_field',
                  ),
                  controller: _groundBandZIndexController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ground band z-index',
                  ),
                  validator: (value) =>
                      int.tryParse(value?.trim() ?? '') == null
                      ? 'Enter a whole number.'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('chunk_v2_owner_dialog_apply'),
          onPressed: _submit,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      ChunkV2OwnerDialogResult(
        status: _status,
        levelId: _levelId,
        difficulty: _difficulty,
        assemblyGroupId: _assemblyGroupId,
        tags: _canonicalTags(_tagsController.text.split(',')),
        groundBandZIndex: int.parse(_groundBandZIndexController.text.trim()),
      ),
    );
  }
}

List<String> _assemblyGroups(ChunkV2Document document, String levelId) {
  final groups = document.levels
      .where((level) => level.levelId == levelId)
      .firstOrNull
      ?.chunkThemeGroups
      .toSet()
      .toList(growable: false);
  final result = groups == null || groups.isEmpty
      ? <String>[defaultChunkAssemblyGroupId]
      : groups;
  result.sort();
  return result;
}

List<String> _canonicalTags(Iterable<String> tags) {
  final canonical = tags
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList(growable: false);
  canonical.sort();
  return canonical;
}

String? _validOwnerId(
  String raw, {
  required ChunkV2Document document,
  String? exceptChunkKey,
}) {
  final id = raw.trim();
  if (id != raw || !_stableChunkId.hasMatch(id)) return null;
  if (document.chunks.any(
    (chunk) => chunk.chunkKey != exceptChunkKey && chunk.id == id,
  )) {
    return null;
  }
  return id;
}

final RegExp _stableChunkId = RegExp(r'^[a-z][a-z0-9_]*$');
