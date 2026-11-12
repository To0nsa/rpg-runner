import 'package:flutter/material.dart';

import '../../../chunks/chunk_v2_actor_terrain_projection.dart';
import '../shared/editor_actor_terrain_controls.dart';
import '../shared/editor_placement_tools.dart';
import '../shared/editor_zoom_controls.dart';
import 'campaign_marker_editing.dart';

/// Scene chrome shares Chunk's tools; Campaign retains draft and command gates.
class CampaignSceneControls extends StatelessWidget {
  const CampaignSceneControls({
    super.key,
    required this.editing,
    required this.visualPreview,
    required this.onVisualPreviewChanged,
    required this.showGrid,
    required this.onGridChanged,
    required this.showActorTerrain,
    required this.onActorTerrainChanged,
    required this.actor,
    required this.onActorChanged,
    required this.zoom,
    required this.onZoomChanged,
    required this.onResetView,
  });

  final CampaignMarkerEditing editing;
  final bool visualPreview, showGrid, showActorTerrain;
  final ValueChanged<bool> onVisualPreviewChanged,
      onGridChanged,
      onActorTerrainChanged;
  final ChunkV2TerrainActor actor;
  final ValueChanged<ChunkV2TerrainActor> onActorChanged;
  final double zoom;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onResetView;

  @override
  Widget build(BuildContext context) {
    final e = editing;
    final enabled = !visualPreview && !e.gestureActive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              key: const ValueKey('campaign_visual_preview_toggle'),
              label: const Text('Visual preview'),
              selected: visualPreview,
              onSelected: e.gestureActive ? null : onVisualPreviewChanged,
            ),
            FilterChip(
              key: const ValueKey('campaign_show_grid_toggle'),
              label: const Text('Show grid'),
              selected: showGrid,
              onSelected: enabled ? onGridChanged : null,
            ),
            EditorActorTerrainControls(
              keyPrefix: 'campaign_actor_terrain',
              visible: showActorTerrain,
              actor: actor,
              enabled: enabled,
              onVisibilityChanged: onActorTerrainChanged,
              onActorChanged: onActorChanged,
            ),
            IgnorePointer(
              ignoring: e.gestureActive,
              child: EditorZoomControls(
                value: zoom,
                min: .5,
                max: 4,
                step: .25,
                sliderWidth: 140,
                onChanged: onZoomChanged,
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('campaign_reset_view'),
              onPressed: e.gestureActive ? null : onResetView,
              icon: const Icon(Icons.center_focus_strong),
              label: const Text('Reset view'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            EditorPlacementTools<CampaignMarkerTool>(
              keyPrefix: 'campaign_marker_tool',
              select: CampaignMarkerTool.select,
              place: CampaignMarkerTool.place,
              move: CampaignMarkerTool.move,
              selected: e.tool,
              onChanged: enabled
                  ? (tool) {
                      if (!e.finishDraft()) return;
                      e.tool = tool;
                      e.candidate = null;
                      e.changed();
                    }
                  : null,
            ),
            FilterChip(
              label: const Text('Snap 8 px'),
              selected: e.snap,
              onSelected: enabled
                  ? (value) {
                      e.snap = value;
                      e.changed();
                    }
                  : null,
            ),
            IconButton(
              tooltip: 'Duplicate marker',
              onPressed: enabled && e.selected != null ? e.duplicate : null,
              icon: const Icon(Icons.copy),
            ),
            IconButton(
              tooltip: 'Delete marker and its objective',
              onPressed: enabled && e.selected != null ? e.delete : null,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          visualPreview
              ? 'Visual preview · Ctrl+drag pans · Ctrl+scroll zooms.'
              : 'Click to place; drag to move. Ctrl+drag pans · Ctrl+scroll zooms · Escape cancels.',
        ),
        if (!visualPreview && showActorTerrain)
          Text('Chunk terrain · ${terrainActorLegend(actor)}'),
        if (e.error != null)
          Text(
            e.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
