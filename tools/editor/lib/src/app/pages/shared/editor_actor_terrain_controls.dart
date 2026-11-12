import 'package:flutter/material.dart';

import '../../../chunks/chunk_v2_actor_terrain_projection.dart';

/// Presentation for the existing Core-backed actor terrain diagnostic. Toggling
/// it must not change source or substitute a different traversal policy.
class EditorActorTerrainControls extends StatelessWidget {
  const EditorActorTerrainControls({
    super.key,
    required this.visible,
    required this.actor,
    required this.onVisibilityChanged,
    required this.onActorChanged,
    required this.keyPrefix,
    this.enabled = true,
  });

  final bool visible, enabled;
  final ChunkV2TerrainActor actor;
  final ValueChanged<bool> onVisibilityChanged;
  final ValueChanged<ChunkV2TerrainActor> onActorChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      FilterChip(
        key: ValueKey('${keyPrefix}_toggle'),
        label: const Text('Actor terrain'),
        selected: visible,
        onSelected: enabled ? onVisibilityChanged : null,
      ),
      DropdownButton<ChunkV2TerrainActor>(
        key: ValueKey('${keyPrefix}_selector'),
        value: actor,
        items: [
          for (final value in ChunkV2TerrainActor.values)
            DropdownMenuItem(
              value: value,
              child: Text(terrainActorLabel(value)),
            ),
        ],
        onChanged: enabled && visible
            ? (value) {
                if (value != null) onActorChanged(value);
              }
            : null,
      ),
    ],
  );
}

String terrainActorLabel(ChunkV2TerrainActor actor) => switch (actor) {
  ChunkV2TerrainActor.eloise => 'Éloïse',
  ChunkV2TerrainActor.grojib => 'Grojib',
  ChunkV2TerrainActor.hashash => 'Hashash',
  ChunkV2TerrainActor.unoco => 'Unoco Demon',
  ChunkV2TerrainActor.derf => 'Derf',
};

/// Color key for the existing actor-terrain overlay painter.
String terrainActorLegend(ChunkV2TerrainActor actor) => switch (actor) {
  ChunkV2TerrainActor.eloise => 'cyan walkable surfaces',
  ChunkV2TerrainActor.grojib || ChunkV2TerrainActor.hashash =>
    'walkable surfaces · blue walk · pink jump · yellow drop',
  ChunkV2TerrainActor.unoco => 'red solid blockers · cyan hover surfaces',
  ChunkV2TerrainActor.derf =>
    'green perches · yellow short supports · red ineligible surfaces',
};
