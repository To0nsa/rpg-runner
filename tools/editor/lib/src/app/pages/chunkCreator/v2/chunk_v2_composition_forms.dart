import 'package:flutter/material.dart';

import '../../../../chunks/chunk_domain_models.dart';
import '../../../../chunks/chunk_marker_authoring_catalog.dart';
import '../../../../chunks/chunk_scene_coordinate_policy.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../prefabs/models/models.dart';

/// Edits one prefab placement without owning persistence or modal navigation.
///
/// The caller must provide at least one active Prefab-v3 owner, or the retained
/// owner of [placement]. Submitted coordinates use the Chunk whole-pixel
/// policy before the candidate is returned to the caller.
class ChunkV2PlacementForm extends StatefulWidget {
  ChunkV2PlacementForm({
    super.key,
    required Iterable<PrefabV3Def> prefabs,
    this.placement,
    required this.submitKey,
    required this.submitLabel,
    required this.onSubmit,
    this.fieldKeyPrefix = 'chunk_v2_placement',
    this.onCancel,
    this.enabled = true,
  }) : prefabs = List<PrefabV3Def>.unmodifiable(prefabs);

  final List<PrefabV3Def> prefabs;
  final PlacedPrefabDef? placement;
  final String submitKey;
  final String submitLabel;
  final ValueChanged<PlacedPrefabDef> onSubmit;
  final String fieldKeyPrefix;
  final VoidCallback? onCancel;
  final bool enabled;

  @override
  State<ChunkV2PlacementForm> createState() => _ChunkV2PlacementFormState();
}

class _ChunkV2PlacementFormState extends State<ChunkV2PlacementForm> {
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
    final current = widget.placement == null
        ? null
        : resolveChunkV2PlacementPrefab(widget.prefabs, widget.placement!);
    _availablePrefabs =
        widget.prefabs
            .where(
              (prefab) =>
                  prefab.status == PrefabStatus.active ||
                  prefab.prefabKey == current?.prefabKey,
            )
            .toList(growable: false)
          ..sort(_comparePrefabs);
    assert(
      _availablePrefabs.isNotEmpty,
      'A placement form needs an active or retained prefab owner.',
    );
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
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DropdownButtonFormField<String>(
          key: ValueKey<String>('${widget.fieldKeyPrefix}_prefab_$_prefabKey'),
          initialValue: _prefabKey,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Prefab',
            border: OutlineInputBorder(),
          ),
          items: _availablePrefabs
              .map(
                (prefab) => DropdownMenuItem<String>(
                  value: prefab.prefabKey,
                  child: Text('${prefab.id} · ${prefab.kind.jsonValue}'),
                ),
              )
              .toList(growable: false),
          onChanged: !widget.enabled
              ? null
              : (value) {
                  if (value != null) setState(() => _prefabKey = value);
                },
        ),
        const SizedBox(height: 10),
        _IntegerField(
          fieldKey: '${widget.fieldKeyPrefix}_x_field',
          label: 'X (px)',
          controller: _xController,
          enabled: widget.enabled,
        ),
        const SizedBox(height: 10),
        _IntegerField(
          fieldKey: '${widget.fieldKeyPrefix}_y_field',
          label: 'Y (px)',
          controller: _yController,
          enabled: widget.enabled,
        ),
        const SizedBox(height: 10),
        _IntegerField(
          fieldKey: '${widget.fieldKeyPrefix}_z_field',
          label: 'Z-index',
          controller: _zIndexController,
          enabled: widget.enabled,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<double>(
          key: ValueKey<String>('${widget.fieldKeyPrefix}_scale_$_scale'),
          initialValue: _scale,
          decoration: const InputDecoration(
            labelText: 'Scale',
            border: OutlineInputBorder(),
          ),
          items: _placementScales
              .map(
                (scale) => DropdownMenuItem<double>(
                  value: scale,
                  child: Text('×${scale.toStringAsFixed(1)}'),
                ),
              )
              .toList(growable: false),
          onChanged: !widget.enabled
              ? null
              : (value) {
                  if (value != null) setState(() => _scale = value);
                },
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          key: ValueKey<String>('${widget.fieldKeyPrefix}_snap_field'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Snap to grid'),
          value: _snapToGrid,
          onChanged: widget.enabled
              ? (value) => setState(() => _snapToGrid = value)
              : null,
        ),
        CheckboxListTile(
          key: ValueKey<String>('${widget.fieldKeyPrefix}_flip_x_field'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Flip X'),
          value: _flipX,
          onChanged: widget.enabled
              ? (value) => setState(() => _flipX = value ?? false)
              : null,
        ),
        CheckboxListTile(
          key: ValueKey<String>('${widget.fieldKeyPrefix}_flip_y_field'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Flip Y'),
          value: _flipY,
          onChanged: widget.enabled
              ? (value) => setState(() => _flipY = value ?? false)
              : null,
        ),
        const SizedBox(height: 8),
        _FormActions(
          submitKey: widget.submitKey,
          submitLabel: widget.submitLabel,
          enabled: widget.enabled,
          onCancel: widget.onCancel,
          onSubmit: _submit,
        ),
      ],
    ),
  );

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final prefab = _availablePrefabs.singleWhere(
      (prefab) => prefab.prefabKey == _prefabKey,
    );
    widget.onSubmit(
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

/// Edits one enemy marker without owning persistence or modal navigation.
///
/// Coordinates are constrained to the supplied Chunk bounds and normalized to
/// the Chunk whole-pixel policy before submission.
class ChunkV2MarkerForm extends StatefulWidget {
  const ChunkV2MarkerForm({
    super.key,
    required this.chunk,
    this.marker,
    required this.submitKey,
    required this.submitLabel,
    required this.onSubmit,
    this.fieldKeyPrefix = 'chunk_v2_marker',
    this.onCancel,
    this.enabled = true,
  });

  final ChunkV2FileData chunk;
  final PlacedMarkerDef? marker;
  final String submitKey;
  final String submitLabel;
  final ValueChanged<PlacedMarkerDef> onSubmit;
  final String fieldKeyPrefix;
  final VoidCallback? onCancel;
  final bool enabled;

  @override
  State<ChunkV2MarkerForm> createState() => _ChunkV2MarkerFormState();
}

class _ChunkV2MarkerFormState extends State<ChunkV2MarkerForm> {
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
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DropdownButtonFormField<String>(
          key: ValueKey<String>('${widget.fieldKeyPrefix}_enemy_$_markerId'),
          initialValue: _markerId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Enemy ID',
            border: OutlineInputBorder(),
          ),
          items: chunkMarkerEnemyIds
              .map((id) => DropdownMenuItem<String>(value: id, child: Text(id)))
              .toList(growable: false),
          onChanged: !widget.enabled
              ? null
              : (value) {
                  if (value != null) setState(() => _markerId = value);
                },
        ),
        const SizedBox(height: 10),
        _IntegerField(
          fieldKey: '${widget.fieldKeyPrefix}_x_field',
          label: 'X (px)',
          controller: _xController,
          enabled: widget.enabled,
          min: 0,
          max: widget.chunk.width,
        ),
        const SizedBox(height: 10),
        _IntegerField(
          fieldKey: '${widget.fieldKeyPrefix}_y_field',
          label: 'Y (px)',
          controller: _yController,
          enabled: widget.enabled,
          min: 0,
          max: widget.chunk.height,
        ),
        const SizedBox(height: 10),
        _IntegerField(
          fieldKey: '${widget.fieldKeyPrefix}_chance_field',
          label: 'Chance %',
          controller: _chanceController,
          enabled: widget.enabled,
          min: 0,
          max: 100,
        ),
        const SizedBox(height: 10),
        _IntegerField(
          fieldKey: '${widget.fieldKeyPrefix}_salt_field',
          label: 'Salt',
          controller: _saltController,
          enabled: widget.enabled,
          min: 0,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey<String>(
            '${widget.fieldKeyPrefix}_placement_$_placement',
          ),
          initialValue: _placement,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Placement',
            border: OutlineInputBorder(),
          ),
          items: chunkMarkerPlacementModes
              .map(
                (placement) => DropdownMenuItem<String>(
                  value: placement,
                  child: Text(placement),
                ),
              )
              .toList(growable: false),
          onChanged: !widget.enabled
              ? null
              : (value) {
                  if (value != null) setState(() => _placement = value);
                },
        ),
        const SizedBox(height: 10),
        _FormActions(
          submitKey: widget.submitKey,
          submitLabel: widget.submitLabel,
          enabled: widget.enabled,
          onCancel: widget.onCancel,
          onSubmit: _submit,
        ),
      ],
    ),
  );

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSubmit(
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

class _FormActions extends StatelessWidget {
  const _FormActions({
    required this.submitKey,
    required this.submitLabel,
    required this.enabled,
    required this.onCancel,
    required this.onSubmit,
  });

  final String submitKey;
  final String submitLabel;
  final bool enabled;
  final VoidCallback? onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.end,
    spacing: 8,
    runSpacing: 8,
    children: <Widget>[
      if (onCancel != null)
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
      FilledButton.icon(
        key: ValueKey<String>(submitKey),
        onPressed: enabled ? onSubmit : null,
        icon: Icon(onCancel == null ? Icons.add : Icons.save_outlined),
        label: Text(submitLabel),
      ),
    ],
  );
}

class _IntegerField extends StatelessWidget {
  const _IntegerField({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.enabled,
    this.min,
    this.max,
  });

  final String fieldKey;
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final int? min;
  final int? max;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: ValueKey<String>(fieldKey),
    controller: controller,
    enabled: enabled,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    validator: (value) {
      final parsed = int.tryParse(value?.trim() ?? '');
      if (parsed == null) return 'Enter a whole number.';
      if (min != null && parsed < min!) return 'Minimum $min.';
      if (max != null && parsed > max!) return 'Maximum $max.';
      return null;
    },
  );
}

/// Resolves a placed Prefab reference without coercing an unknown owner.
///
/// Stable `prefabKey` matching takes precedence when present; legacy ID
/// matching remains available only when that key is absent or unmatched.
PrefabV3Def? resolveChunkV2PlacementPrefab(
  Iterable<PrefabV3Def> prefabs,
  PlacedPrefabDef placement,
) {
  if (placement.prefabKey.isNotEmpty) {
    final keyMatch = prefabs
        .where((prefab) => prefab.prefabKey == placement.prefabKey)
        .firstOrNull;
    if (keyMatch != null) return keyMatch;
  }
  if (placement.prefabId.isEmpty) return null;
  return prefabs.where((prefab) => prefab.id == placement.prefabId).firstOrNull;
}

int _comparePrefabs(PrefabV3Def left, PrefabV3Def right) {
  final kindOrder = left.kind.jsonValue.compareTo(right.kind.jsonValue);
  if (kindOrder != 0) return kindOrder;
  final idOrder = left.id.compareTo(right.id);
  return idOrder != 0 ? idOrder : left.prefabKey.compareTo(right.prefabKey);
}

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
