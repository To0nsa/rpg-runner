import 'package:flutter/material.dart';
import 'package:terrain_materials/terrain_materials.dart';

import '../../../atlas/atlas_pixel_rect.dart';
import '../../../terrain_authoring/terrain_source_models.dart';
import 'atlas_region_preview_tile.dart';
import 'editor_scene_view_utils.dart';
import 'terrain_material_preview.dart';
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
  late final TerrainMaterialCatalogDecodeResult _materialCatalogResult;
  final EditorUiImageCache _imageCache = EditorUiImageCache();

  @override
  void initState() {
    super.initState();
    _collisionMode = widget.shape.collisionMode;
    _surfaceKind = widget.shape.surfaceKind ?? '';
    _materialKey = widget.shape.materialKey ?? '';
    _materialCatalogResult = loadTerrainMaterialPreviewCatalog(
      widget.workspaceRootPath,
    );
  }

  @override
  void dispose() {
    _imageCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyPrefix = widget.keyPrefix;
    final surfaceOptions = _selectorOptions(
      current: _surfaceKind,
      known: terrainSurfaceKindOptions,
    );
    final catalog = _materialCatalogResult.catalog;
    final materialOptions = _selectorOptions(
      current: _materialKey,
      known:
          catalog?.materials.map((material) => material.key) ??
          const <String>[],
    );
    final selectedMaterial = terrainMaterialPreviewForKey(
      catalog,
      _materialKey,
    );
    return AlertDialog(
      key: ValueKey<String>('${keyPrefix}_metadata_dialog'),
      title: Text('Edit ${widget.shape.shapeId} metadata'),
      content: SizedBox(
        width: 680,
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
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Material key'),
                selectedItemBuilder: (context) => materialOptions
                    .map(
                      (value) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _materialSelectedLabel(catalog, value),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                items: materialOptions
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: _TerrainMaterialSelectorOption(
                          workspaceRootPath: widget.workspaceRootPath,
                          value: value,
                          material: terrainMaterialPreviewForKey(
                            catalog,
                            value,
                          ),
                          imageCache: _imageCache,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _materialKey = value);
                },
              ),
              const SizedBox(height: 12),
              if (selectedMaterial != null)
                TerrainMaterialPreview(
                  key: ValueKey<String>(
                    '${keyPrefix}_material_preview_${selectedMaterial.key}',
                  ),
                  workspaceRootPath: widget.workspaceRootPath,
                  material: selectedMaterial,
                  keyPrefix: keyPrefix,
                )
              else if (_materialKey.isEmpty)
                Text(
                  'No material selected.',
                  key: ValueKey<String>('${keyPrefix}_material_preview_empty'),
                )
              else
                Text(
                  'No preview assets are registered for $_materialKey.',
                  key: ValueKey<String>('${keyPrefix}_material_preview_empty'),
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

class _TerrainMaterialSelectorOption extends StatelessWidget {
  const _TerrainMaterialSelectorOption({
    required this.workspaceRootPath,
    required this.value,
    required this.material,
    required this.imageCache,
  });

  final String workspaceRootPath;
  final String value;
  final TerrainMaterialDefinition? material;
  final EditorUiImageCache imageCache;

  @override
  Widget build(BuildContext context) {
    final material = this.material;
    if (value.isEmpty) return const Text('None');
    if (material == null) return Text('$value · undefined');
    return Row(
      children: <Widget>[
        AtlasRegionPreviewTile(
          width: 52,
          height: 34,
          imageCache: imageCache,
          workspaceRootPath: workspaceRootPath,
          sourceImagePath: material.fill.assetPath,
          region: AtlasPixelRect(
            x: material.fill.x,
            y: material.fill.y,
            width: material.fill.width,
            height: material.fill.height,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(material.displayName, overflow: TextOverflow.ellipsis),
              Text(
                material.key,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
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

String _materialSelectedLabel(TerrainMaterialCatalog? catalog, String value) {
  if (value.isEmpty) return 'None';
  final material = terrainMaterialPreviewForKey(catalog, value);
  return material == null ? value : '${material.displayName} · ${material.key}';
}

String? _nullableSelection(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
