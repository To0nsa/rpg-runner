import 'package:flutter/material.dart';

import '../../../terrain_authoring/terrain_source_models.dart';

/// Result of one accepted polygon metadata dialog edit.
@immutable
class TerrainPolygonMetadataEdit {
  const TerrainPolygonMetadataEdit({
    required this.collisionMode,
    required this.surfaceKind,
    required this.materialKey,
  });

  final TerrainSourceCollisionMode collisionMode;
  final String? surfaceKind;
  final String? materialKey;
}

/// Shows the shared collision-mode/surface/material editor for one source loop.
///
/// Empty optional values normalize to `null`. The dialog never mutates an
/// owner; callers route the returned semantic edit through their own policy.
Future<TerrainPolygonMetadataEdit?> showTerrainPolygonMetadataDialog(
  BuildContext context, {
  required String keyPrefix,
  required TerrainSourceShapeDef shape,
}) => showDialog<TerrainPolygonMetadataEdit>(
  context: context,
  builder: (context) =>
      _TerrainPolygonMetadataDialog(keyPrefix: keyPrefix, shape: shape),
);

class _TerrainPolygonMetadataDialog extends StatefulWidget {
  const _TerrainPolygonMetadataDialog({
    required this.keyPrefix,
    required this.shape,
  });

  final String keyPrefix;
  final TerrainSourceShapeDef shape;

  @override
  State<_TerrainPolygonMetadataDialog> createState() =>
      _TerrainPolygonMetadataDialogState();
}

class _TerrainPolygonMetadataDialogState
    extends State<_TerrainPolygonMetadataDialog> {
  late TerrainSourceCollisionMode _collisionMode;
  late final TextEditingController _surfaceController;
  late final TextEditingController _materialController;

  @override
  void initState() {
    super.initState();
    _collisionMode = widget.shape.collisionMode;
    _surfaceController = TextEditingController(
      text: widget.shape.surfaceKind ?? '',
    );
    _materialController = TextEditingController(
      text: widget.shape.materialKey ?? '',
    );
  }

  @override
  void dispose() {
    _surfaceController.dispose();
    _materialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyPrefix = widget.keyPrefix;
    return AlertDialog(
      key: ValueKey<String>('${keyPrefix}_metadata_dialog'),
      title: Text('Edit ${widget.shape.shapeId} metadata'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DropdownButtonFormField<TerrainSourceCollisionMode>(
            key: ValueKey<String>('${keyPrefix}_metadata_mode'),
            initialValue: _collisionMode,
            decoration: const InputDecoration(labelText: 'Collision mode'),
            items: TerrainSourceCollisionMode.values
                .map(
                  (mode) => DropdownMenuItem<TerrainSourceCollisionMode>(
                    value: mode,
                    child: Text(mode.name),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) setState(() => _collisionMode = value);
            },
          ),
          TextField(
            key: ValueKey<String>('${keyPrefix}_metadata_surface_field'),
            controller: _surfaceController,
            decoration: const InputDecoration(labelText: 'Surface kind'),
          ),
          TextField(
            key: ValueKey<String>('${keyPrefix}_metadata_material_field'),
            controller: _materialController,
            decoration: const InputDecoration(labelText: 'Material key'),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: ValueKey<String>('${keyPrefix}_metadata_apply'),
          onPressed: () => Navigator.of(context).pop(
            TerrainPolygonMetadataEdit(
              collisionMode: _collisionMode,
              surfaceKind: _nullableText(_surfaceController.text),
              materialKey: _nullableText(_materialController.text),
            ),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

String? _nullableText(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
