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

  /// A Play request may first accept completed inspector text; capture stays
  /// blocked until the route finalizes and checks [isReady] again.
  bool get canRequestPlay => isReady || code == 'pendingInspectorInput';
}

/// Route header for level/owner context and Play readiness.
class ChunkWorkspaceHeader extends StatelessWidget {
  const ChunkWorkspaceHeader({
    super.key,
    required this.scene,
    required this.selectedChunkKey,
    required this.readiness,
    required this.onLevelSelected,
    required this.onOwnerSelected,
    required this.onPlayRequested,
  });

  final ChunkV2Scene scene;
  final String? selectedChunkKey;
  final ChunkPlaytestWorkspaceReadiness readiness;
  final ValueChanged<String?> onLevelSelected;
  final ValueChanged<String> onOwnerSelected;
  final VoidCallback? onPlayRequested;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
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
        value: scene.chunks.any((chunk) => chunk.chunkKey == selectedChunkKey)
            ? selectedChunkKey
            : null,
        hint: const Text('No chunk owner'),
        items:
            (List<ChunkV2FileData>.of(scene.chunks)..sort(compareChunkOwners))
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
      Tooltip(
        message: readiness.message,
        child: FilledButton.icon(
          key: const ValueKey<String>('chunk_playtest_button'),
          onPressed: readiness.canRequestPlay ? onPlayRequested : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Play (F5)'),
        ),
      ),
    ],
  );
}
