import 'package:flutter/material.dart';

import '../../../terrain_authoring/terrain_source_models.dart';
import 'terrain_material_preview_catalog.dart';

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
/// Known values are presented as selectors, while unknown existing values stay
/// selectable so opening and applying the dialog is non-destructive. Material
/// preview images are resolved relative to [workspaceRootPath].
Future<TerrainPolygonMetadataEdit?> showTerrainPolygonMetadataDialog(
  BuildContext context, {
  required String keyPrefix,
  required TerrainSourceShapeDef shape,
  required String workspaceRootPath,
}) => showDialog<TerrainPolygonMetadataEdit>(
  context: context,
  builder: (context) => _TerrainPolygonMetadataDialog(
    keyPrefix: keyPrefix,
    shape: shape,
    workspaceRootPath: workspaceRootPath,
  ),
);

class _TerrainPolygonMetadataDialog extends StatefulWidget {
  const _TerrainPolygonMetadataDialog({
    required this.keyPrefix,
    required this.shape,
    required this.workspaceRootPath,
  });

  final String keyPrefix;
  final TerrainSourceShapeDef shape;
  final String workspaceRootPath;

  @override
  State<_TerrainPolygonMetadataDialog> createState() =>
      _TerrainPolygonMetadataDialogState();
}

class _TerrainPolygonMetadataDialogState
    extends State<_TerrainPolygonMetadataDialog> {
  late TerrainSourceCollisionMode _collisionMode;
  late String _surfaceKind;
  late String _materialKey;

  @override
  void initState() {
    super.initState();
    _collisionMode = widget.shape.collisionMode;
    _surfaceKind = widget.shape.surfaceKind ?? '';
    _materialKey = widget.shape.materialKey ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final keyPrefix = widget.keyPrefix;
    final surfaceOptions = _selectorOptions(
      current: _surfaceKind,
      known: terrainSurfaceKindOptions,
    );
    final materialOptions = _selectorOptions(
      current: _materialKey,
      known: terrainMaterialPreviewCatalog.map(
        (material) => material.materialKey,
      ),
    );
    return AlertDialog(
      key: ValueKey<String>('${keyPrefix}_metadata_dialog'),
      title: Text('Edit ${widget.shape.shapeId} metadata'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey<String>('${keyPrefix}_metadata_surface_selector'),
                initialValue: _surfaceKind,
                decoration: const InputDecoration(labelText: 'Surface kind'),
                items: surfaceOptions
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(_selectorLabel(value)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _surfaceKind = value);
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey<String>(
                  '${keyPrefix}_metadata_material_selector',
                ),
                initialValue: _materialKey,
                decoration: const InputDecoration(labelText: 'Material key'),
                items: materialOptions
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(_selectorLabel(value)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _materialKey = value);
                },
              ),
              const SizedBox(height: 12),
              TerrainMaterialAssetPreview(
                workspaceRootPath: widget.workspaceRootPath,
                materialKey: _nullableSelection(_materialKey),
                keyPrefix: keyPrefix,
              ),
            ],
          ),
        ),
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
              surfaceKind: _nullableSelection(_surfaceKind),
              materialKey: _nullableSelection(_materialKey),
            ),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

List<String> _selectorOptions({
  required String current,
  required Iterable<String> known,
}) => <String>{
  '',
  ...known,
  if (current.isNotEmpty) current,
}.toList(growable: false);

String _selectorLabel(String value) {
  if (value.isEmpty) return 'None';
  return value;
}

String? _nullableSelection(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
