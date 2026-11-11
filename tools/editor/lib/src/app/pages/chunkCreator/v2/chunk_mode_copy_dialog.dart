import 'package:flutter/material.dart';

import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_lifecycle_commit.dart';
import '../../../../chunks/chunk_v2_models.dart';

/// Names an independent layout copy with shared prefab/material references.
/// Mission objectives remain on their mission; chunk combat content is omitted.
class ChunkModeCopyDialog extends StatefulWidget {
  const ChunkModeCopyDialog({
    super.key,
    required this.document,
    required this.source,
  });
  final ChunkV2Document document;
  final ChunkV2FileData source;
  @override
  State<ChunkModeCopyDialog> createState() => _ChunkModeCopyDialogState();
}

class _ChunkModeCopyDialogState extends State<ChunkModeCopyDialog> {
  static const _policy = ChunkV2LifecycleCommitPolicy();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String level = widget.source.levelId;
  late String group = widget.source.assemblyGroupId;
  late String tier = widget.source.difficulty;
  String get usage => widget.source.usage == 'campaign' ? 'runner' : 'campaign';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: _policy.suggestCopyKey(widget.document, widget.source.chunkKey),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      ChunkV2DuplicateOperation(
        sourceChunkKey: widget.source.chunkKey,
        targetId: _nameController.text,
        targetUsage: usage,
        targetLevelId: level,
        targetGroupId: group,
        targetDifficulty: tier,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.document.levels
        .firstWhere((l) => l.levelId == level)
        .chunkThemeGroups;
    return AlertDialog(
      title: Text(usage == 'runner' ? 'Copy to Runner' : 'Copy to Campaign'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Source: ${widget.source.chunkKey}\nThe original stays unchanged. The copy receives a fresh identity and revision 1.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('chunk_mode_copy_name'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Chunk name',
                    helperText: 'Lowercase letters, digits and underscores; start with a letter.',
                    helperMaxLines: 2,
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) =>
                      _policy.validateCopyKey(widget.document, value ?? ''),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Preserved: terrain, platforms, scenery and water. Prefabs, atlases and materials remain shared references.\n\nOmitted: enemy markers, rescue encounters, boss arenas and traps.',
                ),
                const SizedBox(height: 12),
                Text(
                  usage == 'runner'
                      ? 'Mission start, exit and objectives stay on the original mission. The runner copy starts inactive; review seams and activate it explicitly.'
                      : 'The copy stays outside runner pools. Add it to a mission and edit its content in Chunk Creator.',
                ),
                DropdownButtonFormField<String>(
                  initialValue: level,
                  decoration: const InputDecoration(labelText: 'Source owner'),
                  items: [
                    for (final l in widget.document.levels)
                      DropdownMenuItem(
                        value: l.levelId,
                        child: Text(l.displayName),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        level = v;
                        group = widget.document.levels
                            .firstWhere((l) => l.levelId == v)
                            .chunkThemeGroups
                            .first;
                      });
                    }
                  },
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey(level),
                  initialValue: group,
                  decoration: const InputDecoration(
                    labelText: 'Assembly group',
                  ),
                  items: [
                    for (final g in groups)
                      DropdownMenuItem(value: g, child: Text(g)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => group = v);
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: tier,
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                  items: [
                    for (final t in ['early', 'easy', 'normal', 'hard'])
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => tier = v);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Create editable copy'),
        ),
      ],
    );
  }
}
