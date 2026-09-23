import 'package:flutter/material.dart';
import 'package:runner_core/traps/trap_catalog.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:runner_core/traps/trap_placement.dart';

import '../../../../atlas/atlas_pixel_rect.dart';
import '../../shared/atlas_region_preview_tile.dart';
import '../../shared/editor_list_card.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_section_card.dart';
import 'chunk_trap_gesture.dart';

String trapDisplayName(TrapId id) => switch (id) {
  TrapId.spike => 'Spike',
  TrapId.swingingAxe => 'Swinging Axe',
  TrapId.poisonDarts => 'Poison Darts',
};

/// Callback-only trap catalog and selection controls. The workspace owns commands.
class ChunkTrapPanel extends StatelessWidget {
  const ChunkTrapPanel({
    super.key,
    required this.workspaceRootPath,
    required this.images,
    required this.traps,
    required this.selected,
    required this.catalogId,
    required this.tool,
    required this.frame,
    required this.enabled,
    required this.onCatalog,
    required this.onSelect,
    required this.onTool,
    required this.onFrame,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    this.error,
  });
  final String workspaceRootPath;
  final EditorUiImageCache images;
  final List<TrapPlacement> traps;
  final TrapPlacement? selected;
  final TrapId catalogId;
  final ChunkTrapTool tool;
  final int frame;
  final bool enabled;
  final ValueChanged<TrapId> onCatalog;
  final ValueChanged<TrapPlacement> onSelect;
  final ValueChanged<ChunkTrapTool> onTool;
  final ValueChanged<int> onFrame;
  final VoidCallback onEdit, onDuplicate, onDelete;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      EditorSectionCard(
        title: 'Trap catalog',
        key: const ValueKey('chunk_trap_catalog'),
        child: Column(
          children: [
            for (final id in TrapId.values)
              Builder(
                builder: (context) {
                  final def = TrapCatalog.get(id),
                      source = TrapCatalog.get(id)
                          .frames[TrapCatalog.get(id).idleFrameIndex]
                          .source;
                  return EditorListCard(
                    isSelected: catalogId == id && tool == ChunkTrapTool.place,
                    onTap: enabled && traps.length < 8
                        ? () => onCatalog(id)
                        : null,
                    child: ListTile(
                      title: Text(trapDisplayName(id)),
                      subtitle: Text(
                        '${def.damage100 / 100} HP · ${def.firstHarmfulTick(60) / 60}s warning',
                      ),
                      leading: AtlasRegionPreviewTile(
                        imageCache: images,
                        workspaceRootPath: workspaceRootPath,
                        sourceImagePath: 'assets/images/${def.assetPath}',
                        region: AtlasPixelRect(
                          x: source.x,
                          y: source.y,
                          width: source.width,
                          height: source.height,
                        ),
                      ),
                    ),
                  );
                },
              ),
            const Text(
              'Choose a trap, then click or drag its anchor in the scene. Up to eight per chunk.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      EditorSectionCard(
        title: 'Placed traps',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final value in [
                  ChunkTrapTool.select,
                  ChunkTrapTool.moveTrigger,
                  ChunkTrapTool.drawTrigger,
                ])
                  ChoiceChip(
                    key: ValueKey('chunk_trap_tool_${value.name}'),
                    selected: tool == value,
                    label: Text(switch (value) {
                      ChunkTrapTool.select => 'Select / move',
                      ChunkTrapTool.moveTrigger => 'Move trigger',
                      _ => 'Draw trigger',
                    }),
                    onSelected: enabled ? (_) => onTool(value) : null,
                  ),
              ],
            ),
            const Text(
              'Blue: activation trigger. Red: read-only damage pose. Drag a selected trigger corner to resize.',
            ),
            for (final (index, trap) in traps.indexed)
              ListTile(
                key: ValueKey('chunk_trap_placement_$index'),
                selected: trap == selected,
                title: Text(
                  '${trapDisplayName(trap.trapId)} · ${trap.x}, ${trap.y}',
                ),
                subtitle: Text(
                  'Trigger ${trap.trigger.width} × ${trap.trigger.height} · ${trap.facing.name}',
                ),
                onTap: enabled ? () => onSelect(trap) : null,
              ),
            if (selected != null) ...[
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    key: const ValueKey('chunk_trap_edit'),
                    onPressed: enabled ? onEdit : null,
                    child: const Text('Edit geometry'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('chunk_trap_duplicate'),
                    onPressed: enabled && traps.length < 8 ? onDuplicate : null,
                    child: const Text('Duplicate'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('chunk_trap_delete'),
                    onPressed: enabled ? onDelete : null,
                    child: const Text('Delete'),
                  ),
                ],
              ),
              Text(
                frame < 0
                    ? 'Preview: idle'
                    : 'Preview frame $frame · ${TrapCatalog.get(selected!.trapId).frameStartTick(frame, 60)} ticks',
              ),
              Slider(
                key: const ValueKey('chunk_trap_frame'),
                min: -1,
                max: TrapCatalog.get(selected!.trapId).frames.length - 1.0,
                divisions: TrapCatalog.get(selected!.trapId).frames.length,
                value: frame.toDouble(),
                onChanged: enabled ? (value) => onFrame(value.round()) : null,
              ),
            ],
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ],
  );
}
