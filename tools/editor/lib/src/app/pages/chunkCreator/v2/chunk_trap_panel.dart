import 'package:flutter/material.dart';
import 'package:runner_core/traps/trap_catalog.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:runner_core/traps/trap_placement.dart';

import '../../../../atlas/atlas_pixel_rect.dart';
import '../../shared/atlas_region_preview_tile.dart';
import '../../shared/editor_list_card.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_section_card.dart';

String trapDisplayName(TrapId id) => switch (id) {
  TrapId.spike => 'Spike',
  TrapId.swingingAxe => 'Swinging Axe',
  TrapId.poisonDarts => 'Poison Darts',
};

/// Creation and saved-item sections; the workspace owns selection and commands.
class ChunkTrapPanel extends StatelessWidget {
  const ChunkTrapPanel({
    super.key,
    required this.workspaceRootPath,
    required this.images,
    required this.traps,
    required this.selected,
    required this.catalogId,
    required this.placing,
    required this.enabled,
    required this.creationExpanded,
    required this.existingExpanded,
    required this.onCreationExpansionChanged,
    required this.onExistingExpansionChanged,
    required this.snapControls,
    required this.selectedEditor,
    required this.onCatalog,
    required this.onSelect,
    required this.onPlace,
    required this.onCancel,
    this.error,
  });
  final String workspaceRootPath;
  final EditorUiImageCache images;
  final List<TrapPlacement> traps;
  final TrapPlacement? selected;
  final TrapId catalogId;
  final bool placing, enabled, creationExpanded, existingExpanded;
  final ValueChanged<bool> onCreationExpansionChanged,
      onExistingExpansionChanged;
  final Widget snapControls;
  final Widget? selectedEditor;
  final ValueChanged<TrapId> onCatalog;
  final ValueChanged<TrapPlacement> onSelect;
  final VoidCallback onPlace, onCancel;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final def = TrapCatalog.get(catalogId);
    final source = def.frames[def.idleFrameIndex].source;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorSectionCard(
          key: const ValueKey('chunk_trap_creation_panel'),
          expansionKey: const ValueKey('chunk_trap_creation_panel_toggle'),
          title: 'Create trap',
          description: 'Choose a type, then place its anchor in the scene.',
          collapsible: true,
          expanded: creationExpanded,
          onExpansionChanged: onCreationExpansionChanged,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<TrapId>(
                key: ValueKey(('chunk_trap_catalog', catalogId)),
                initialValue: catalogId,
                decoration: const InputDecoration(labelText: 'Trap type'),
                items: [
                  for (final id in TrapId.values)
                    DropdownMenuItem(
                      value: id,
                      child: Text(trapDisplayName(id)),
                    ),
                ],
                onChanged: enabled && !placing
                    ? (id) {
                        if (id != null) onCatalog(id);
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
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
                title: Text('${def.damage100 / 100} HP on hit'),
                subtitle: Text(
                  '${def.firstHarmfulTick(60) / 60} s before damage',
                ),
              ),
              snapControls,
              const SizedBox(height: 8),
              Text(
                placing
                    ? 'Click or drag in the scene to place the trap. Escape cancels.'
                    : '${traps.length} of 8 traps placed.',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('chunk_trap_place'),
                    onPressed: enabled && !placing && traps.length < 8
                        ? onPlace
                        : null,
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Place in scene'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('chunk_trap_cancel_placement'),
                    onPressed: placing ? onCancel : null,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        EditorSectionCard(
          key: const ValueKey('chunk_trap_existing_panel'),
          expansionKey: const ValueKey('chunk_trap_existing_panel_toggle'),
          title: 'Existing traps',
          description: 'Select a trap to edit its anchor and trigger.',
          trailing: Text('${traps.length}'),
          collapsible: true,
          expanded: existingExpanded,
          onExpansionChanged: onExistingExpansionChanged,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (traps.isEmpty) const Text('No traps in this chunk yet.'),
              for (final (index, trap) in traps.indexed) ...[
                EditorListCard(
                  key: ValueKey('chunk_trap_placement_$index'),
                  isSelected: trap == selected,
                  onTap: enabled ? () => onSelect(trap) : null,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${trapDisplayName(trap.trapId)} · ${trap.x}, ${trap.y}',
                    ),
                    subtitle: Text(
                      'Trigger ${trap.trigger.width} × ${trap.trigger.height} · ${trap.facing.name}',
                    ),
                  ),
                ),
                if (trap == selected && selectedEditor != null) selectedEditor!,
              ],
              // A stale local edit remains visible until explicitly resolved.
              if (selected != null &&
                  !traps.contains(selected) &&
                  selectedEditor != null)
                selectedEditor!,
            ],
          ),
        ),
      ],
    );
  }
}
