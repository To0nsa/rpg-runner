import 'package:flutter/material.dart';

import '../../../../chunks/chunk_domain_models.dart';
import '../../../../chunks/chunk_marker_authoring_catalog.dart';
import '../../../../chunks/chunk_scene_coordinate_policy.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../prefabs/models/models.dart';

/// Opens a strict tile-layer form for one Chunk-v2 composition record.
Future<TileLayerDef?> showChunkV2TileLayerDialog(
  BuildContext context, {
  required ChunkV2FileData chunk,
  TileLayerDef? layer,
}) => showDialog<TileLayerDef>(
  context: context,
  builder: (context) => _ChunkV2TileLayerDialog(chunk: chunk, layer: layer),
);

/// Opens a strict prefab-placement form using current Prefab-v3 owners.
///
/// Returns null without opening when neither a retained placement owner nor an
/// active creation owner is available.
Future<PlacedPrefabDef?> showChunkV2PlacementDialog(
  BuildContext context, {
  required Iterable<PrefabV3Def> prefabs,
  PlacedPrefabDef? placement,
}) {
  final owners = List<PrefabV3Def>.unmodifiable(prefabs);
  final current = _resolvePrefab(owners, placement);
  if (current == null &&
      !owners.any((prefab) => prefab.status == PrefabStatus.active)) {
    return Future<PlacedPrefabDef?>.value();
  }
  return showDialog<PlacedPrefabDef>(
    context: context,
    builder: (context) =>
        _ChunkV2PlacementDialog(prefabs: owners, placement: placement),
  );
}

/// Opens a strict enemy-marker form using Core IDs and accepted intents.
Future<PlacedMarkerDef?> showChunkV2MarkerDialog(
  BuildContext context, {
  required ChunkV2FileData chunk,
  PlacedMarkerDef? marker,
}) => showDialog<PlacedMarkerDef>(
  context: context,
  builder: (context) => _ChunkV2MarkerDialog(chunk: chunk, marker: marker),
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

final class _ChunkV2PlacementDialog extends StatefulWidget {
  _ChunkV2PlacementDialog({
    required Iterable<PrefabV3Def> prefabs,
    this.placement,
  }) : prefabs = List<PrefabV3Def>.unmodifiable(prefabs);

  final List<PrefabV3Def> prefabs;
  final PlacedPrefabDef? placement;

  @override
  State<_ChunkV2PlacementDialog> createState() =>
      _ChunkV2PlacementDialogState();
}

final class _ChunkV2PlacementDialogState
    extends State<_ChunkV2PlacementDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final List<PrefabV3Def> _availablePrefabs;
  late final TextEditingController _xController;
  late final TextEditingController _yController;
  late final TextEditingController _zIndexController;
  late String _prefabKey;
  late double _scale;
  late bool _snapToGrid;
  late bool _flipX;
  late bool _flipY;

  @override
  void initState() {
    super.initState();
    final current = _resolvePrefab(widget.prefabs, widget.placement);
    _availablePrefabs =
        widget.prefabs
            .where(
              (prefab) =>
                  prefab.status == PrefabStatus.active ||
                  prefab.prefabKey == current?.prefabKey,
            )
            .toList(growable: false)
          ..sort(_comparePrefabs);
    _prefabKey = current?.prefabKey ?? _availablePrefabs.first.prefabKey;
    final placement = widget.placement;
    _xController = TextEditingController(text: '${placement?.x ?? 0}');
    _yController = TextEditingController(text: '${placement?.y ?? 0}');
    _zIndexController = TextEditingController(
      text: '${placement?.zIndex ?? 0}',
    );
    _scale = placement?.scale ?? defaultPrefabPlacementScale;
    _snapToGrid = placement?.snapToGrid ?? true;
    _flipX = placement?.flipX ?? false;
    _flipY = placement?.flipY ?? false;
  }

  @override
  void dispose() {
    _xController.dispose();
    _yController.dispose();
    _zIndexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.placement == null ? 'Add prefab placement' : 'Edit placement',
    ),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<String>(
                key: ValueKey<String>('chunk_v2_placement_prefab_$_prefabKey'),
                initialValue: _prefabKey,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Prefab'),
                items: _availablePrefabs
                    .map(
                      (prefab) => DropdownMenuItem<String>(
                        value: prefab.prefabKey,
                        child: Text('${prefab.id} · ${prefab.kind.jsonValue}'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _prefabKey = value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _IntegerField(
                      fieldKey: 'chunk_v2_placement_x_field',
                      label: 'X (px)',
                      controller: _xController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _IntegerField(
                      fieldKey: 'chunk_v2_placement_y_field',
                      label: 'Y (px)',
                      controller: _yController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _IntegerField(
                      fieldKey: 'chunk_v2_placement_z_field',
                      label: 'Z-index',
                      controller: _zIndexController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<double>(
                key: ValueKey<String>('chunk_v2_placement_scale_$_scale'),
                initialValue: _scale,
                decoration: const InputDecoration(labelText: 'Scale'),
                items: _placementScales
                    .map(
                      (scale) => DropdownMenuItem<double>(
                        value: scale,
                        child: Text('×${scale.toStringAsFixed(1)}'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _scale = value);
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const ValueKey<String>('chunk_v2_placement_snap_field'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Snap to grid'),
                value: _snapToGrid,
                onChanged: (value) => setState(() => _snapToGrid = value),
              ),
              CheckboxListTile(
                key: const ValueKey<String>('chunk_v2_placement_flip_x_field'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Flip X'),
                value: _flipX,
                onChanged: (value) => setState(() => _flipX = value ?? false),
              ),
              CheckboxListTile(
                key: const ValueKey<String>('chunk_v2_placement_flip_y_field'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Flip Y'),
                value: _flipY,
                onChanged: (value) => setState(() => _flipY = value ?? false),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey<String>('chunk_v2_placement_dialog_apply'),
        onPressed: _submit,
        child: Text(widget.placement == null ? 'Add' : 'Apply'),
      ),
    ],
  );

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final prefab = _availablePrefabs.singleWhere(
      (prefab) => prefab.prefabKey == _prefabKey,
    );
    Navigator.of(context).pop(
      PlacedPrefabDef(
        prefabId: prefab.id,
        prefabKey: prefab.prefabKey,
        x: preserveChunkExactPixelCoordinate(
          int.parse(_xController.text.trim()),
        ),
        y: preserveChunkExactPixelCoordinate(
          int.parse(_yController.text.trim()),
        ),
        zIndex: int.parse(_zIndexController.text.trim()),
        snapToGrid: _snapToGrid,
        scale: _scale,
        flipX: _flipX,
        flipY: _flipY,
      ),
    );
  }
}

final class _ChunkV2MarkerDialog extends StatefulWidget {
  const _ChunkV2MarkerDialog({required this.chunk, this.marker});

  final ChunkV2FileData chunk;
  final PlacedMarkerDef? marker;

  @override
  State<_ChunkV2MarkerDialog> createState() => _ChunkV2MarkerDialogState();
}

final class _ChunkV2MarkerDialogState extends State<_ChunkV2MarkerDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _xController;
  late final TextEditingController _yController;
  late final TextEditingController _chanceController;
  late final TextEditingController _saltController;
  late String _markerId;
  late String _placement;

  @override
  void initState() {
    super.initState();
    final marker = widget.marker;
    _markerId = marker?.markerId ?? chunkMarkerEnemyIds.first;
    _placement = marker?.placement ?? markerPlacementGround;
    _xController = TextEditingController(text: '${marker?.x ?? 0}');
    _yController = TextEditingController(text: '${marker?.y ?? 0}');
    _chanceController = TextEditingController(
      text: '${marker?.chancePercent ?? 100}',
    );
    _saltController = TextEditingController(text: '${marker?.salt ?? 0}');
  }

  @override
  void dispose() {
    _xController.dispose();
    _yController.dispose();
    _chanceController.dispose();
    _saltController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.marker == null ? 'Add enemy marker' : 'Edit marker'),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<String>(
                key: ValueKey<String>('chunk_v2_marker_enemy_$_markerId'),
                initialValue: _markerId,
                decoration: const InputDecoration(labelText: 'Enemy ID'),
                items: chunkMarkerEnemyIds
                    .map(
                      (id) =>
                          DropdownMenuItem<String>(value: id, child: Text(id)),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _markerId = value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _IntegerField(
                      fieldKey: 'chunk_v2_marker_x_field',
                      label: 'X (px)',
                      controller: _xController,
                      min: 0,
                      max: widget.chunk.width,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _IntegerField(
                      fieldKey: 'chunk_v2_marker_y_field',
                      label: 'Y (px)',
                      controller: _yController,
                      min: 0,
                      max: widget.chunk.height,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _IntegerField(
                      fieldKey: 'chunk_v2_marker_chance_field',
                      label: 'Chance %',
                      controller: _chanceController,
                      min: 0,
                      max: 100,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _IntegerField(
                      fieldKey: 'chunk_v2_marker_salt_field',
                      label: 'Salt',
                      controller: _saltController,
                      min: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey<String>('chunk_v2_marker_placement_$_placement'),
                initialValue: _placement,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Placement'),
                items: chunkMarkerPlacementModes
                    .map(
                      (placement) => DropdownMenuItem<String>(
                        value: placement,
                        child: Text(placement),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _placement = value);
                },
              ),
            ],
          ),
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey<String>('chunk_v2_marker_dialog_apply'),
        onPressed: _submit,
        child: Text(widget.marker == null ? 'Add' : 'Apply'),
      ),
    ],
  );

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      PlacedMarkerDef(
        markerId: _markerId,
        x: preserveChunkExactPixelCoordinate(
          int.parse(_xController.text.trim()),
        ),
        y: preserveChunkExactPixelCoordinate(
          int.parse(_yController.text.trim()),
        ),
        chancePercent: int.parse(_chanceController.text.trim()),
        salt: int.parse(_saltController.text.trim()),
        placement: _placement,
      ),
    );
  }
}

final class _IntegerField extends StatelessWidget {
  const _IntegerField({
    required this.fieldKey,
    required this.label,
    required this.controller,
    this.min,
    this.max,
  });

  final String fieldKey;
  final String label;
  final TextEditingController controller;
  final int? min;
  final int? max;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: ValueKey<String>(fieldKey),
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final parsed = int.tryParse(value?.trim() ?? '');
      if (parsed == null) return 'Enter a whole number.';
      if (min != null && parsed < min!) return 'Minimum $min.';
      if (max != null && parsed > max!) return 'Maximum $max.';
      return null;
    },
  );
}

PrefabV3Def? _resolvePrefab(
  Iterable<PrefabV3Def> prefabs,
  PlacedPrefabDef? placement,
) {
  if (placement == null) return null;
  return prefabs
      .where(
        (prefab) =>
            (placement.prefabKey.isNotEmpty &&
                prefab.prefabKey == placement.prefabKey) ||
            (placement.prefabId.isNotEmpty && prefab.id == placement.prefabId),
      )
      .firstOrNull;
}

int _comparePrefabs(PrefabV3Def left, PrefabV3Def right) {
  final kindOrder = left.kind.jsonValue.compareTo(right.kind.jsonValue);
  if (kindOrder != 0) return kindOrder;
  final idOrder = left.id.compareTo(right.id);
  return idOrder != 0 ? idOrder : left.prefabKey.compareTo(right.prefabKey);
}

bool _isTrimmedNonEmpty(String value) =>
    value.isNotEmpty && value == value.trim();

final List<double> _placementScales = List<double>.unmodifiable(
  List<double>.generate(
    ((maxPrefabPlacementScale - minPrefabPlacementScale) /
                prefabPlacementScaleStep)
            .round() +
        1,
    (index) => canonicalPrefabPlacementScale(
      minPrefabPlacementScale + index * prefabPlacementScaleStep,
    ),
  ),
);
