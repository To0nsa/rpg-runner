import 'package:flutter/material.dart';
import 'package:runner_core/terrain/water_region.dart';
import 'package:terrain_materials/terrain_materials.dart';

import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_water_commit.dart';
import '../../shared/editor_section_card.dart';

/// Water drawing controls and exact edits share the chunk transaction path.
class ChunkWaterPanel extends StatelessWidget {
  const ChunkWaterPanel({
    super.key,
    required this.chunk,
    required this.materials,
    required this.enabled,
    required this.onCommit,
    this.drawingControls,
  });

  final Widget? drawingControls;
  final ChunkV2FileData chunk;
  final TerrainMaterialCatalog? materials;
  final bool enabled;
  final ValueChanged<ChunkWaterCommit> onCommit;

  @override
  Widget build(BuildContext context) => EditorSectionCard(
    title: 'Water regions',
    collapsible: true,
    initiallyExpanded: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?drawingControls,
        const Text(
          'Pools have a horizontal surface. Use solid terrain for banks '
          'and a floor, and place the level kill plane below the pool.',
        ),
        for (final region in chunk.waterRegions)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(region.id),
            subtitle: Text(
              '${region.x}, ${region.y} · ${region.width} × ${region.height} px',
            ),
            onTap:
                enabled && materials != null && materials!.materials.isNotEmpty
                ? () => _edit(context, region)
                : null,
            trailing: IconButton(
              tooltip: 'Delete water ${region.id}',
              icon: const Icon(Icons.delete_outline),
              onPressed: !enabled
                  ? null
                  : () => onCommit(
                      ChunkWaterCommit(
                        expectedRevision: chunk.revision,
                        regions: chunk.waterRegions.where(
                          (water) => water.id != region.id,
                        ),
                      ),
                    ),
            ),
          ),
        OutlinedButton.icon(
          key: const ValueKey('chunk_add_water'),
          onPressed:
              enabled && materials != null && materials!.materials.isNotEmpty
              ? () => _edit(context, null)
              : null,
          icon: const Icon(Icons.water),
          label: const Text('Enter water coordinates'),
        ),
      ],
    ),
  );

  Future<void> _edit(BuildContext context, WaterRegionData? existing) async {
    final result = await showDialog<WaterRegionData>(
      context: context,
      builder: (_) =>
          _WaterDialog(chunk: chunk, materials: materials!, existing: existing),
    );
    if (result == null || !context.mounted) return;
    onCommit(
      ChunkWaterCommit(
        expectedRevision: chunk.revision,
        regions: [
          ...chunk.waterRegions.where((water) => water.id != existing?.id),
          result,
        ],
      ),
    );
  }
}

class _WaterDialog extends StatefulWidget {
  const _WaterDialog({
    required this.chunk,
    required this.materials,
    this.existing,
  });
  final ChunkV2FileData chunk;
  final TerrainMaterialCatalog materials;
  final WaterRegionData? existing;
  @override
  State<_WaterDialog> createState() => _WaterDialogState();
}

class _WaterDialogState extends State<_WaterDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late String _material;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final id = nextChunkWaterId(widget.chunk.waterRegions);
    final height = widget.chunk.height < 64 ? widget.chunk.height : 64;
    _fields = {
      'id': TextEditingController(text: existing?.id ?? id),
      'x': TextEditingController(text: '${existing?.x ?? 0}'),
      'y': TextEditingController(
        text: '${existing?.y ?? widget.chunk.height - height}',
      ),
      'width': TextEditingController(
        text: '${existing?.width ?? widget.chunk.width.clamp(1, 160)}',
      ),
      'height': TextEditingController(text: '${existing?.height ?? height}'),
    };
    _material =
        existing?.materialKey ??
        (widget.materials.byKey.containsKey('biome_water')
            ? 'biome_water'
            : widget.materials.materials.first.key);
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null ? 'Add water rectangle' : 'Edit water rectangle',
    ),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in _fields.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextFormField(
                    key: ValueKey('water_${entry.key}'),
                    controller: entry.value,
                    decoration: InputDecoration(
                      labelText: switch (entry.key) {
                        'id' => 'Water ID',
                        'x' => 'Left (px)',
                        'y' => 'Surface (px)',
                        'width' => 'Width (px)',
                        _ => 'Depth (px)',
                      },
                    ),
                    validator: (value) => entry.key == 'id'
                        ? (RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(value ?? '')
                              ? null
                              : 'Use a lowercase ID.')
                        : (int.tryParse(value ?? '') == null
                              ? 'Enter whole pixels.'
                              : null),
                  ),
                ),
              DropdownButtonFormField<String>(
                key: const ValueKey('water_material'),
                initialValue: _material,
                decoration: const InputDecoration(labelText: 'Water material'),
                items: [
                  for (final key in {...widget.materials.byKey.keys, _material})
                    DropdownMenuItem(
                      value: key,
                      child: Text(
                        widget.materials.byKey[key]?.displayName ?? key,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _material = value);
                },
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('water_apply'),
        onPressed: _apply,
        child: const Text('Apply'),
      ),
    ],
  );

  void _apply() {
    if (!_form.currentState!.validate()) return;
    try {
      final region = WaterRegionData(
        id: _fields['id']!.text,
        x: int.parse(_fields['x']!.text),
        y: int.parse(_fields['y']!.text),
        width: int.parse(_fields['width']!.text),
        height: int.parse(_fields['height']!.text),
        materialKey: _material,
      );
      final all = [
        ...widget.chunk.waterRegions.where(
          (water) => water.id != widget.existing?.id,
        ),
        region,
      ];
      final error = chunkWaterValidationMessage(widget.chunk, all);
      if (error != null) throw FormatException(error);
      if (!widget.materials.byKey.containsKey(_material)) {
        throw const FormatException('Choose an available material.');
      }
      Navigator.pop(context, region);
    } on Object catch (error) {
      setState(
        () => _error = error is FormatException
            ? error.message.toString()
            : error.toString(),
      );
    }
  }
}
