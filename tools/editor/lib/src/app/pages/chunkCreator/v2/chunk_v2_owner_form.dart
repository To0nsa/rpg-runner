import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../chunks/chunk_domain_models.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_models.dart';

/// Validated editable metadata owned by one Chunk-v2 owner form.
///
/// Stable identity, dimensions, composition, markers, and collision geometry
/// are excluded so an inline metadata edit cannot mutate them accidentally.
@immutable
final class ChunkV2OwnerFormValue {
  ChunkV2OwnerFormValue({
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

typedef ChunkV2OwnerFormSubmit = FutureOr<bool> Function(
  ChunkV2OwnerFormValue value,
);

/// Route-local Chunk-v2 metadata form used below the selected owner row.
///
/// It captures the displayed fields until [onSubmit] accepts them and reports
/// dirty state so navigation and Apply-to-files cannot discard the draft.
class ChunkV2OwnerForm extends StatefulWidget {
  const ChunkV2OwnerForm({
    super.key,
    required this.document,
    required this.chunk,
    required this.onSubmit,
    required this.onCancel,
    required this.submitKey,
    this.cancelKey,
    this.onDirtyChanged,
  });

  final ChunkV2Document document;
  final ChunkV2FileData chunk;
  final ChunkV2OwnerFormSubmit onSubmit;
  final VoidCallback onCancel;
  final Key submitKey;
  final Key? cancelKey;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  State<ChunkV2OwnerForm> createState() => ChunkV2OwnerFormState();
}

/// Submission handle used when owner or level navigation requests Save.
class ChunkV2OwnerFormState extends State<ChunkV2OwnerForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _tagsController;
  late final TextEditingController _groundBandZIndexController;
  late final String _initialStatus;
  late final String _initialLevelId;
  late final String _initialDifficulty;
  late final String _initialAssemblyGroupId;
  late final String _initialTags;
  late final String _initialGroundBandZIndex;
  late String _status;
  late String _levelId;
  late String _difficulty;
  late String _assemblyGroupId;
  String? _submissionError;
  bool _reportedDirty = false;

  bool get isDirty =>
      _status != _initialStatus ||
      _levelId != _initialLevelId ||
      _difficulty != _initialDifficulty ||
      _assemblyGroupId != _initialAssemblyGroupId ||
      _tagsController.text != _initialTags ||
      _groundBandZIndexController.text != _initialGroundBandZIndex;

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
    _initialStatus = _status;
    _initialLevelId = _levelId;
    _initialDifficulty = _difficulty;
    _initialAssemblyGroupId = _assemblyGroupId;
    _initialTags = _tagsController.text;
    _initialGroundBandZIndex = _groundBandZIndexController.text;
    _tagsController.addListener(_handleFieldChanged);
    _groundBandZIndexController.addListener(_handleFieldChanged);
  }

  @override
  void dispose() {
    _tagsController
      ..removeListener(_handleFieldChanged)
      ..dispose();
    _groundBandZIndexController
      ..removeListener(_handleFieldChanged)
      ..dispose();
    super.dispose();
  }

  /// Validates and submits the captured fields without closing on rejection.
  Future<bool> submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    final accepted = await widget.onSubmit(
      ChunkV2OwnerFormValue(
        status: _status,
        levelId: _levelId,
        difficulty: _difficulty,
        assemblyGroupId: _assemblyGroupId,
        tags: _canonicalTags(_tagsController.text.split(',')),
        groundBandZIndex: int.parse(_groundBandZIndexController.text.trim()),
      ),
    );
    if (!accepted && mounted) {
      setState(() {
        _submissionError =
            'The chunk changed or the metadata was rejected. Review the '
            'current diagnostics and retry without closing this draft.';
      });
    }
    return accepted;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _assemblyGroups(widget.document, _levelId);
    final levelIds = widget.document.availableLevelIds.toList(growable: false)
      ..sort();
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DropdownButtonFormField<String>(
            key: ValueKey<String>('chunk_v2_owner_status_$_status'),
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const <String>[chunkStatusActive, chunkStatusDeprecated]
                .map(
                  (status) => DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null || value == _status) return;
              setState(() {
                _status = value;
                _submissionError = null;
              });
              _reportDirty();
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
                final nextGroups = _assemblyGroups(widget.document, value);
                if (!nextGroups.contains(_assemblyGroupId)) {
                  _assemblyGroupId = nextGroups.first;
                }
                _submissionError = null;
              });
              _reportDirty();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(
              'chunk_v2_owner_assembly_${_levelId}_$_assemblyGroupId',
            ),
            initialValue: _assemblyGroupId,
            decoration: const InputDecoration(labelText: 'Chunk theme group'),
            items: groups
                .map(
                  (groupId) => DropdownMenuItem<String>(
                    value: groupId,
                    child: Text(groupId),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null || value == _assemblyGroupId) return;
              setState(() {
                _assemblyGroupId = value;
                _submissionError = null;
              });
              _reportDirty();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('chunk_v2_owner_difficulty_$_difficulty'),
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
              if (value == null || value == _difficulty) return;
              setState(() {
                _difficulty = value;
                _submissionError = null;
              });
              _reportDirty();
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey<String>('chunk_v2_owner_tags_field'),
            controller: _tagsController,
            decoration: const InputDecoration(
              labelText: 'Tags',
              helperText: 'Comma-separated; saved uniquely in lexical order.',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey<String>('chunk_v2_owner_ground_band_z_field'),
            controller: _groundBandZIndexController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Ground band z-index'),
            validator: (value) => int.tryParse(value?.trim() ?? '') == null
                ? 'Enter a whole number.'
                : null,
          ),
          if (_submissionError != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _submissionError!,
              key: const ValueKey<String>('chunk_v2_owner_form_error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              TextButton(
                key: widget.cancelKey,
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: widget.submitKey,
                onPressed: submit,
                child: const Text('Apply changes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleFieldChanged() {
    if (_submissionError != null && mounted) {
      setState(() => _submissionError = null);
    }
    _reportDirty();
  }

  void _reportDirty() {
    final dirty = isDirty;
    if (dirty == _reportedDirty) return;
    _reportedDirty = dirty;
    widget.onDirtyChanged?.call(dirty);
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

/// Returns the user-facing Chunk-v2 owner ID validation error, if any.
String? validateChunkV2OwnerId(
  String raw, {
  required ChunkV2Document document,
  String? exceptChunkKey,
}) {
  final id = raw.trim();
  if (id != raw || !_stableChunkOwnerId.hasMatch(id)) {
    return 'Use a lowercase ID beginning with a letter; digits and underscores are allowed.';
  }
  if (document.chunks.any(
    (chunk) => chunk.chunkKey != exceptChunkKey && chunk.id == id,
  )) {
    return 'Enter a unique chunk ID.';
  }
  return null;
}

final RegExp _stableChunkOwnerId = RegExp(r'^[a-z][a-z0-9_]*$');
