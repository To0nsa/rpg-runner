import 'package:flutter/material.dart';

import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_models.dart';
import 'chunk_owner_order.dart';

/// Snapshot readiness exposed to the Chunk Creator Play/Edit orchestrator.
///
/// Accepted session changes are intentionally absent from the blockers. Only
/// state not represented by the immutable plugin document, or a blocking
/// document/session condition, prevents scenario capture.
@immutable
final class ChunkPlaytestWorkspaceReadiness {
  const ChunkPlaytestWorkspaceReadiness({
    required this.code,
    required this.message,
    required this.selectedChunkKey,
  });

  /// Stable readiness code used by tests and editor presentation.
  final String code;

  /// Concise author-facing explanation or ready-state description.
  final String message;

  /// Selected accepted owner, absent when owner/level context is incomplete.
  final String? selectedChunkKey;

  bool get isReady => code == 'ready';
}

/// Route header for level/owner context and Play readiness.
class ChunkWorkspaceHeader extends StatelessWidget {
  const ChunkWorkspaceHeader({
    super.key,
    required this.document,
    required this.scene,
    required this.selectedChunkKey,
    required this.readiness,
    required this.onLevelSelected,
    required this.onOwnerSelected,
    required this.onPlayRequested,
  });

  final ChunkV2Document document;
  final ChunkV2Scene scene;
  final String? selectedChunkKey;
  final ChunkPlaytestWorkspaceReadiness readiness;
  final ValueChanged<String?> onLevelSelected;
  final ValueChanged<String> onOwnerSelected;
  final VoidCallback? onPlayRequested;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          const Chip(
            avatar: Icon(Icons.science_outlined, size: 18),
            label: Text('Chunk v2 authoring'),
          ),
          DropdownButton<String>(
            key: const ValueKey<String>('chunk_polygon_level_selector'),
            value: scene.activeLevelId,
            items: scene.availableLevelIds
                .map(
                  (levelId) => DropdownMenuItem<String>(
                    value: levelId,
                    child: Text(levelId),
                  ),
                )
                .toList(growable: false),
            onChanged: onLevelSelected,
          ),
          DropdownButton<String>(
            key: const ValueKey<String>('chunk_polygon_owner_selector'),
            value:
                scene.chunks.any((chunk) => chunk.chunkKey == selectedChunkKey)
                ? selectedChunkKey
                : null,
            hint: const Text('No chunk owner'),
            items:
                (List<ChunkV2FileData>.of(scene.chunks)
                      ..sort(compareChunkOwners))
                    .map(
                      (chunk) => DropdownMenuItem<String>(
                        value: chunk.chunkKey,
                        child: Text(chunk.id),
                      ),
                    )
                    .toList(growable: false),
            onChanged: (chunkKey) {
              if (chunkKey != null) onOwnerSelected(chunkKey);
            },
          ),
          Text(
            document.changedChunkKeys.isEmpty
                ? 'No pending chunk changes'
                : '${document.changedChunkKeys.length} pending chunk change(s)',
          ),
          Tooltip(
            message: readiness.message,
            child: FilledButton.icon(
              key: const ValueKey<String>('chunk_playtest_button'),
              onPressed: readiness.isReady ? onPlayRequested : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play (F5)'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        readiness.isReady
            ? 'Play ready: ${readiness.message}'
            : 'Play unavailable: ${readiness.message}',
        key: const ValueKey<String>('chunk_playtest_readiness'),
        style: TextStyle(
          color: readiness.isReady
              ? const Color(0xFF7DD3FC)
              : const Color(0xFFFFD166),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Current-schema workspace: apply rechecks the complete chunk source '
        'set and commits it atomically. Legacy migration stays read-only; '
        'runtime terrain updates after the generated outputs are refreshed.',
        style: TextStyle(color: Color(0xFFFFD166)),
      ),
    ],
  );
}
