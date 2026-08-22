import 'package:flutter/material.dart';

import '../../../../chunks/chunk_domain_models.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import 'chunk_enemy_catalog_browser.dart';
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

/// Opens a strict enemy-marker edit form using Core IDs and accepted intents.
///
/// [workspaceRootPath] is used only to resolve Core-declared preview art. Enemy
/// library selection stays dialog-local until the returned candidate is
/// accepted; cancellation returns `null` without changing source.
Future<PlacedMarkerDef?> showChunkV2MarkerEditDialog(
  BuildContext context, {
  required ChunkV2FileData chunk,
  required PlacedMarkerDef marker,
  required String workspaceRootPath,
}) => showDialog<PlacedMarkerDef>(
  context: context,
  builder: (context) => _ChunkV2MarkerEditDialog(
    chunk: chunk,
    marker: marker,
    workspaceRootPath: workspaceRootPath,
  ),
);

final class _ChunkV2MarkerEditDialog extends StatefulWidget {
  const _ChunkV2MarkerEditDialog({
    required this.chunk,
    required this.marker,
    required this.workspaceRootPath,
  });

  final ChunkV2FileData chunk;
  final PlacedMarkerDef marker;
  final String workspaceRootPath;

  @override
  State<_ChunkV2MarkerEditDialog> createState() =>
      _ChunkV2MarkerEditDialogState();
}

final class _ChunkV2MarkerEditDialogState
    extends State<_ChunkV2MarkerEditDialog> {
  late String _selectedEnemyId;

  @override
  void initState() {
    super.initState();
    _selectedEnemyId = widget.marker.markerId;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit marker'),
    content: SizedBox(
      width: 680,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ChunkEnemyCatalogBrowser(
              workspaceRootPath: widget.workspaceRootPath,
              selectedEnemyId: _selectedEnemyId,
              usedEnemyIds: widget.chunk.markers.map(
                (marker) => marker.markerId,
              ),
              gridHeight: 220,
              keyPrefix: 'chunk_v2_marker_dialog_catalog',
              onSelected: (enemyId) =>
                  setState(() => _selectedEnemyId = enemyId),
            ),
            const Divider(height: 32),
            ChunkV2MarkerForm(
              chunk: widget.chunk,
              enemyId: _selectedEnemyId,
              marker: widget.marker,
              submitKey: 'chunk_v2_marker_dialog_apply',
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
