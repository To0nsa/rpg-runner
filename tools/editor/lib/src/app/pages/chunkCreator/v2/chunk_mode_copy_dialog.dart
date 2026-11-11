import 'package:flutter/material.dart';

import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_lifecycle_commit.dart';
import '../../../../chunks/chunk_v2_models.dart';

/// Only destination metadata changes; shared prefab/material references remain
/// shared. Mission objectives are separate records and are never copied.
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
  late String level = widget.source.levelId;
  late String group = widget.source.assemblyGroupId;
  late String tier = widget.source.difficulty;
  String get usage => widget.source.usage == 'campaign' ? 'runner' : 'campaign';
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Source: ${widget.source.chunkKey}\nThe original stays unchanged. The copy receives a fresh identity and revision 1.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Preserved: terrain, platforms, scenery, water, traps, enemy markers, rescue encounters and boss arenas. Prefabs, atlases and materials remain shared references.',
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
                decoration: const InputDecoration(labelText: 'Assembly group'),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            ChunkV2DuplicateOperation(
              sourceChunkKey: widget.source.chunkKey,
              targetUsage: usage,
              targetLevelId: level,
              targetGroupId: group,
              targetDifficulty: tier,
            ),
          ),
          child: const Text('Create editable copy'),
        ),
      ],
    );
  }
}
