import 'package:flutter/material.dart';

import '../../../../chunks/chunk_domain_models.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_models.dart';
import '../../../../prefabs/models/models.dart';
import 'chunk_prefab_catalog_browser.dart';
import 'chunk_v2_composition_forms.dart';

/// Opens a strict tile-layer form for one Chunk-v2 composition record.
Future<TileLayerDef?> showChunkV2TileLayerDialog(
  BuildContext context, {
  required ChunkV2FileData chunk,
  TileLayerDef? layer,
}) => showDialog<TileLayerDef>(
  context: context,
  builder: (context) => _ChunkV2TileLayerDialog(chunk: chunk, layer: layer),
);

/// Opens a strict prefab-placement edit form for one retained Prefab-v3 owner.
///
/// Returns null without opening when the placement's owner no longer exists.
Future<PlacedPrefabDef?> showChunkV2PlacementEditDialog(
  BuildContext context, {
  required ChunkV2Document document,
  required String workspaceRootPath,
  required PlacedPrefabDef placement,
}) {
  final owners = List<PrefabV3Def>.unmodifiable(document.prefabData.prefabs);
  final current = resolveChunkV2PlacementPrefab(owners, placement);
  if (current == null) return Future<PlacedPrefabDef?>.value();
  final selectableOwners = owners
      .where(
        (prefab) =>
            prefab.status == PrefabStatus.active ||
            prefab.prefabKey == current.prefabKey,
      )
      .toList(growable: false);
  return showDialog<PlacedPrefabDef>(
    context: context,
    builder: (context) => _ChunkV2PlacementEditDialog(
      document: document,
      workspaceRootPath: workspaceRootPath,
      selectableOwners: selectableOwners,
      initialOwner: current,
      placement: placement,
    ),
  );
}

final class _ChunkV2PlacementEditDialog extends StatefulWidget {
  const _ChunkV2PlacementEditDialog({
    required this.document,
    required this.workspaceRootPath,
    required this.selectableOwners,
    required this.initialOwner,
    required this.placement,
  });

  final ChunkV2Document document;
  final String workspaceRootPath;
  final List<PrefabV3Def> selectableOwners;
  final PrefabV3Def initialOwner;
  final PlacedPrefabDef placement;

  @override
  State<_ChunkV2PlacementEditDialog> createState() =>
      _ChunkV2PlacementEditDialogState();
}

final class _ChunkV2PlacementEditDialogState
    extends State<_ChunkV2PlacementEditDialog> {
  late String _selectedPrefabKey;

  @override
  void initState() {
    super.initState();
    _selectedPrefabKey = widget.initialOwner.prefabKey;
  }

  @override
  Widget build(BuildContext context) {
    final selectedOwner = widget.selectableOwners.singleWhere(
      (prefab) => prefab.prefabKey == _selectedPrefabKey,
    );
    return AlertDialog(
      title: const Text('Edit placement'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Choose the prefab visually, then adjust this placement.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              ChunkPrefabCatalogBrowser(
                prefabs: widget.selectableOwners,
                prefabData: widget.document.prefabData,
                tileData: widget.document.tileData,
                visualBoundsByPrefabKey:
                    widget.document.visualBoundsByPrefabKey,
                workspaceRootPath: widget.workspaceRootPath,
                selectedPrefabKey: _selectedPrefabKey,
                usedPrefabKeys: const <String>[],
                autofocusSearch: true,
                gridHeight: 248,
                keyPrefix: 'chunk_v2_placement_dialog_catalog',
                onSelected: (prefab) =>
                    setState(() => _selectedPrefabKey = prefab.prefabKey),
              ),
              const Divider(height: 32),
              ChunkV2PlacementForm(
                prefab: selectedOwner,
                placement: widget.placement,
                submitKey: 'chunk_v2_placement_dialog_apply',
                submitLabel: 'Apply',
                onCancel: () => Navigator.of(context).pop(),
                onSubmit: (candidate) => Navigator.of(context).pop(candidate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a strict enemy-marker edit form using Core IDs and accepted intents.
Future<PlacedMarkerDef?> showChunkV2MarkerEditDialog(
  BuildContext context, {
  required ChunkV2FileData chunk,
  required PlacedMarkerDef marker,
}) => showDialog<PlacedMarkerDef>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Edit marker'),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: ChunkV2MarkerForm(
          chunk: chunk,
          marker: marker,
          submitKey: 'chunk_v2_marker_dialog_apply',
          submitLabel: 'Apply',
          onCancel: () => Navigator.of(context).pop(),
          onSubmit: (candidate) => Navigator.of(context).pop(candidate),
        ),
      ),
    ),
  ),
);

final class _ChunkV2TileLayerDialog extends StatefulWidget {
  const _ChunkV2TileLayerDialog({required this.chunk, this.layer});

  final ChunkV2FileData chunk;
  final TileLayerDef? layer;

  @override
  State<_ChunkV2TileLayerDialog> createState() =>
      _ChunkV2TileLayerDialogState();
}

final class _ChunkV2TileLayerDialogState
    extends State<_ChunkV2TileLayerDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _kindController;
  late bool _visible;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.layer?.id ?? '');
    _kindController = TextEditingController(
      text: widget.layer?.kind ?? 'visual',
    );
    _visible = widget.layer?.visible ?? true;
  }

  @override
  void dispose() {
    _idController.dispose();
    _kindController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.layer == null ? 'Add tile layer' : 'Edit tile layer'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              key: const ValueKey<String>('chunk_v2_layer_id_field'),
              controller: _idController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Layer ID'),
              validator: (value) {
                final id = value ?? '';
                if (!_isTrimmedNonEmpty(id)) return 'Enter a trimmed ID.';
                final collision = widget.chunk.tileLayers.any(
                  (layer) => layer.id == id && layer.id != widget.layer?.id,
                );
                return collision ? 'This layer ID is already used.' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey<String>('chunk_v2_layer_kind_field'),
              controller: _kindController,
              decoration: const InputDecoration(labelText: 'Kind'),
              validator: (value) => _isTrimmedNonEmpty(value ?? '')
                  ? null
                  : 'Enter a trimmed kind.',
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              key: const ValueKey<String>('chunk_v2_layer_visible_field'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible'),
              value: _visible,
              onChanged: (value) => setState(() => _visible = value),
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
        key: const ValueKey<String>('chunk_v2_layer_dialog_apply'),
        onPressed: _submit,
        child: Text(widget.layer == null ? 'Add' : 'Apply'),
      ),
    ],
  );

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      TileLayerDef(
        id: _idController.text,
        kind: _kindController.text,
        visible: _visible,
      ),
    );
  }
}

bool _isTrimmedNonEmpty(String value) =>
    value.isNotEmpty && value == value.trim();
