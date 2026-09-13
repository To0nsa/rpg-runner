import 'package:flutter/material.dart';
import 'package:terrain_materials/terrain_materials.dart';

/// Presentation for the workspace-owned water drawing mode and local draft.
class ChunkWaterDrawingControls extends StatelessWidget {
  const ChunkWaterDrawingControls({
    super.key,
    required this.materials,
    required this.materialKey,
    required this.snapToGrid,
    required this.snapToNeighbors,
    required this.gridSize,
    required this.hasDraft,
    required this.canSave,
    required this.error,
    required this.onMaterialChanged,
    required this.onGridChanged,
    required this.onNeighborsChanged,
    required this.onSave,
    required this.onCancel,
  });

  final TerrainMaterialCatalog? materials;
  final String? materialKey;
  final bool snapToGrid;
  final bool snapToNeighbors;
  final int gridSize;
  final bool hasDraft;
  final bool canSave;
  final String? error;
  final ValueChanged<String?> onMaterialChanged;
  final ValueChanged<bool> onGridChanged;
  final ValueChanged<bool> onNeighborsChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Drag opposite corners in the scene to draw water.'),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey('chunk_water_draw_material_$materialKey'),
        initialValue: materialKey,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Water material'),
        items: [
          for (final material in materials?.materials ?? [])
            DropdownMenuItem(
              value: material.key,
              child: Text(material.displayName),
            ),
        ],
        onChanged: hasDraft ? null : onMaterialChanged,
      ),
      if (materialKey == null)
        const Text('Create a terrain material before drawing water.'),
      CheckboxListTile(
        key: const ValueKey('chunk_water_snap_grid'),
        contentPadding: EdgeInsets.zero,
        title: Text('Snap to grid ($gridSize px)'),
        value: snapToGrid,
        onChanged: hasDraft ? null : (value) => onGridChanged(value!),
      ),
      CheckboxListTile(
        key: const ValueKey('chunk_water_snap_neighbors'),
        contentPadding: EdgeInsets.zero,
        title: const Text('Snap to neighbor vertices'),
        value: snapToNeighbors,
        onChanged: hasDraft ? null : (value) => onNeighborsChanged(value!),
      ),
      if (hasDraft) ...[
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('chunk_water_save_draft'),
          onPressed: canSave ? onSave : null,
          child: const Text('Save water'),
        ),
        TextButton(
          key: const ValueKey('chunk_water_cancel_draft'),
          onPressed: onCancel,
          child: const Text('Cancel drawing'),
        ),
      ],
      const Divider(),
    ],
  );
}
