import 'package:flutter/material.dart';
import 'package:runner_core/traps/trap_placement.dart';

import '../../shared/editor_scene_view_utils.dart';
import '../../shared/terrain_polygon_scene_painter.dart';
import 'chunk_scene_visual_source.dart';
import 'chunk_trap_visual_source.dart';

/// Interleaves authored sprites by depth; previewing a pose never changes order.
class ChunkScenePlacementLayers extends StatelessWidget {
  const ChunkScenePlacementLayers({
    super.key,
    required this.workspaceRootPath,
    required this.images,
    required this.prefabs,
    required this.traps,
    required this.selectedTrap,
    required this.previewFrame,
    required this.transform,
  });

  final String workspaceRootPath;
  final EditorUiImageCache images;
  final List<ChunkScenePlacedVisual> prefabs;
  final List<TrapPlacement> traps;
  final TrapPlacement? selectedTrap;
  final int previewFrame;
  final TerrainPolygonViewportTransform transform;

  @override
  Widget build(BuildContext context) {
    final depths = {
      for (final prefab in prefabs) prefab.zIndex,
      for (final trap in traps) trap.zIndex,
    }.toList()..sort();
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final zIndex in depths) ...[
          if (prefabs.any((p) => p.zIndex == zIndex))
            ChunkSceneVisualSource(
              key: ValueKey(('prefabs', zIndex)),
              workspaceRootPath: workspaceRootPath,
              placements: prefabs.where((p) => p.zIndex == zIndex),
              imageCache: images,
              transform: transform,
            ),
          if (traps.any((t) => t.zIndex == zIndex))
            ChunkTrapVisualSource(
              key: ValueKey(('traps', zIndex)),
              workspaceRootPath: workspaceRootPath,
              images: images,
              traps: traps.where((t) => t.zIndex == zIndex).toList()
                ..sort(compareTrapPlacements),
              selected: selectedTrap,
              previewFrame: previewFrame,
              transform: transform,
              pass: ChunkTrapVisualPass.sprites,
            ),
        ],
      ],
    );
  }
}
