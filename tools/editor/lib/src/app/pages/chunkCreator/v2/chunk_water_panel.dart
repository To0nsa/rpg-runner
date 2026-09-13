import 'package:flutter/material.dart';
import 'package:runner_core/terrain/water_region.dart';

import '../../shared/editor_list_card.dart';
import '../../shared/editor_section_card.dart';
import '../../shared/terrain_polygon_exact_edit_controller.dart';
import '../../shared/terrain_polygon_rectangle_editor.dart';
import 'chunk_water_edit_draft.dart';

/// Matches Terrain's separate creation and saved-shape sections. The workspace
/// owns selection, pending-edit resolution and publication of inline edits.
class ChunkWaterPanel extends StatelessWidget {
  const ChunkWaterPanel({
    super.key,
    required this.creationCard,
    required this.regions,
    required this.selectedId,
    required this.enabled,
    required this.onSelect,
    required this.selectedEditor,
    required this.expanded,
    required this.onExpansionChanged,
  });

  final Widget creationCard;
  final List<WaterRegionData> regions;
  final String? selectedId;
  final bool enabled;
  final ValueChanged<WaterRegionData> onSelect;
  final Widget? selectedEditor;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      creationCard,
      const SizedBox(height: 12),
      EditorSectionCard(
        key: const ValueKey('chunk_water_regions_panel'),
        expansionKey: const ValueKey('chunk_water_regions_panel_toggle'),
        title: 'Existing water regions',
        description: regions.isEmpty
            ? 'Saved water rectangles will appear here.'
            : 'Select a region to edit its metadata, geometry, or lifecycle.',
        trailing: Text('${regions.length} total'),
        collapsible: true,
        expanded: expanded,
        onExpansionChanged: onExpansionChanged,
        child: Column(
          key: const ValueKey('chunk_water_region_list'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (regions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No existing water regions. Use the creation card above to draw the first one.',
                ),
              ),
            for (final region in regions) ...[
              EditorListCard(
                key: ValueKey('chunk_water_region_${region.id}'),
                isSelected: region.id == selectedId,
                onTap: enabled ? () => onSelect(region) : null,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  selected: region.id == selectedId,
                  leading: const Icon(Icons.water_outlined),
                  title: Text(region.id),
                  subtitle: Text(
                    'Water · Rectangle · ${region.materialKey}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text('${region.width} × ${region.height} px'),
                ),
              ),
              if (region.id == selectedId && selectedEditor != null)
                Padding(
                  key: const ValueKey('chunk_water_selected_region_editor'),
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  child: selectedEditor,
                ),
            ],
          ],
        ),
      ),
    ],
  );
}

/// Water uses Terrain's exact rectangle fields and Save edit action in-place.
/// The parent supplies mutations so this presentation owns no document writes.
class ChunkWaterInlineInspector extends StatelessWidget {
  const ChunkWaterInlineInspector({
    super.key,
    required this.draft,
    required this.editController,
    required this.materialSelector,
    required this.hasPendingInput,
    required this.onNameChanged,
    required this.onDelete,
    required this.onCancel,
    required this.onApply,
  });

  final ChunkWaterEditDraft draft;
  final TerrainPolygonExactEditController editController;
  final Widget materialSelector;
  final bool hasPendingInput;
  final ValueChanged<String> onNameChanged;
  final VoidCallback? onDelete;
  final VoidCallback onCancel;
  final bool Function({
    required int xHalfPixels,
    required int bottomYHalfPixels,
    required int widthHalfPixels,
    required int heightHalfPixels,
  })
  onApply;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Edit ${draft.source.id}',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('chunk_water_delete_region'),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text('Metadata', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      TextFormField(
        key: ValueKey(
          'chunk_water_region_name_${draft.source.id}_${draft.chunk.revision}',
        ),
        initialValue: draft.nameInput,
        decoration: InputDecoration(
          labelText: 'Region name',
          helperText: 'Lowercase letters, numbers, and underscores; unique in this chunk.',
          errorText: draft.nameError,
          border: const OutlineInputBorder(),
        ),
        onChanged: onNameChanged,
      ),
      const SizedBox(height: 8),
      materialSelector,
      const SizedBox(height: 8),
      TerrainPolygonRectangleEditor(
        key: ValueKey(
          'chunk_water_rectangle_editor_${draft.source.id}_${draft.chunk.revision}',
        ),
        keyPrefix: 'chunk_water',
        rectangle: waterAuthoringRectangle(draft.source),
        coordinateStepHalfPixels: 2,
        editController: editController,
        applyButtonKey: const ValueKey('chunk_water_save_edit'),
        applyLabel: 'Save edit',
        applyEnabled: draft.nameError == null,
        onApply: onApply,
      ),
      if (draft.error != null) ...[
        const SizedBox(height: 8),
        Text(
          draft.error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      if (hasPendingInput)
        TextButton(onPressed: onCancel, child: const Text('Cancel edit')),
    ],
  );
}
