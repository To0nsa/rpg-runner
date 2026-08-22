import 'package:flutter/material.dart';

import '../../../../chunks/chunk_domain_models.dart';
import '../../../../chunks/chunk_marker_authoring_catalog.dart';
import '../../../../chunks/chunk_prefab_surface_snap.dart';
import '../../../../chunks/chunk_scene_coordinate_policy.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../prefabs/models/models.dart';

/// Edits one prefab placement without owning persistence or modal navigation.
///
/// The surrounding catalog owns Prefab selection; changing that selection does
/// not reset coordinates, z-index, grid preference, or reflection. Scale alone
/// reconciles to the nearest exact-contact option when the new collision owner
/// cannot use the retained value. Submitted coordinates use the Chunk whole-
/// pixel policy before the candidate is returned to the caller.
class ChunkV2PlacementForm extends StatefulWidget {
  const ChunkV2PlacementForm({
    super.key,
    required this.prefab,
    this.placement,
    required this.submitKey,
    required this.submitLabel,
    required this.onSubmit,
    this.fieldKeyPrefix = 'chunk_v2_placement',
    this.onCancel,
    this.enabled = true,
  });

  /// Stable owner selected by the surrounding Prefab catalog browser.
  ///
  /// Changing this record preserves the placement draft except for an
  /// incompatible contact scale, while submission writes the new owner's exact
  /// ID and stable key together.
  final PrefabV3Def prefab;
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
  late final TextEditingController _xController;
  late final TextEditingController _yController;
  late final TextEditingController _zIndexController;
  late double _scale;
  late bool _snapToGrid;
  late bool _flipX;
  late bool _flipY;

  @override
  void initState() {
    super.initState();
    final placement = widget.placement;
    _xController = TextEditingController(text: '${placement?.x ?? 0}');
    _yController = TextEditingController(text: '${placement?.y ?? 0}');
    _zIndexController = TextEditingController(
      text: '${placement?.zIndex ?? 0}',
    );
    _snapToGrid = placement?.snapToGrid ?? true;
    _flipX = placement?.flipX ?? false;
    _flipY = placement?.flipY ?? false;
    final requestedScale = placement?.scale ?? defaultPrefabPlacementScale;
    _scale = placement == null
        ? ChunkPrefabSurfaceSnap.preferredCompatibleScale(
            widget.prefab,
            flipY: _flipY,
            preferred: requestedScale,
          )
        : requestedScale;
  }

  @override
  void didUpdateWidget(covariant ChunkV2PlacementForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prefab.prefabKey == widget.prefab.prefabKey) return;
    _scale = ChunkPrefabSurfaceSnap.preferredCompatibleScale(
      widget.prefab,
      flipY: _flipY,
      preferred: _scale,
    );
  }

  @override
  void dispose() {
    _xController.dispose();
    _yController.dispose();
    _zIndexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compatibleScales = ChunkPrefabSurfaceSnap.compatibleScales(
      widget.prefab,
      flipY: _flipY,
    );
    final scaleOptions = _scaleOptions(compatibleScales);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InputDecorator(
            key: ValueKey<String>(
              '${widget.fieldKeyPrefix}_selected_prefab_'
              '${widget.prefab.prefabKey}',
            ),
            decoration: const InputDecoration(
              labelText: 'Selected prefab',
              border: OutlineInputBorder(),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.inventory_2_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.prefab.id} · ${widget.prefab.kind.jsonValue}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
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
          _PlacementScaleControl(
            key: ValueKey<String>('${widget.fieldKeyPrefix}_scale_control'),
            fieldKey: '${widget.fieldKeyPrefix}_scale_field',
            sliderKey: '${widget.fieldKeyPrefix}_scale_slider',
            value: _scale,
            options: scaleOptions,
            enabled: widget.enabled,
            onChanged: (value) => setState(() => _scale = value),
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
                ? (value) => setState(() {
                    _flipY = value ?? false;
                    _scale = ChunkPrefabSurfaceSnap.preferredCompatibleScale(
                      widget.prefab,
                      flipY: _flipY,
                      preferred: _scale,
                    );
                  })
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
  }

  List<double> _scaleOptions(List<double> compatibleScales) {
    final options = compatibleScales.isEmpty
        ? List<double>.of(_placementScales)
        : List<double>.of(compatibleScales);
    if (!options.contains(_scale)) options.add(_scale);
    options.sort();
    return options;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final prefab = widget.prefab;
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

/// Compact numeric field and discrete slider for valid placement scales.
///
/// Slider positions map to [options] instead of interpolating so filtered
/// exact-contact scales cannot be crossed accidentally while dragging.
class _PlacementScaleControl extends StatefulWidget {
  const _PlacementScaleControl({
    super.key,
    required this.fieldKey,
    required this.sliderKey,
    required this.value,
    required this.options,
    required this.enabled,
    required this.onChanged,
  }) : assert(options.length > 0);

  final String fieldKey;
  final String sliderKey;
  final double value;
  final List<double> options;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  State<_PlacementScaleControl> createState() => _PlacementScaleControlState();
}

class _PlacementScaleControlState extends State<_PlacementScaleControl> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _syncText();
  }

  @override
  void didUpdateWidget(covariant _PlacementScaleControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _syncText();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _nearestOptionIndex(widget.value);
    final lastIndex = widget.options.length - 1;
    return Row(
      children: <Widget>[
        SizedBox(
          width: 96,
          child: TextField(
            key: ValueKey<String>(widget.fieldKey),
            controller: _controller,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Scale',
              prefixText: '×',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _commit(),
            onEditingComplete: _commit,
            onTapOutside: (_) => _commit(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Slider(
            key: ValueKey<String>(widget.sliderKey),
            min: 0,
            max: lastIndex > 0 ? lastIndex.toDouble() : 1,
            divisions: lastIndex > 0 ? lastIndex : null,
            value: selectedIndex.toDouble(),
            label: '×${_formatScale(widget.options[selectedIndex])}',
            onChanged: widget.enabled && lastIndex > 0
                ? (index) => widget.onChanged(widget.options[index.round()])
                : null,
          ),
        ),
      ],
    );
  }

  void _commit() {
    final normalized = _controller.text
        .trim()
        .replaceAll('×', '')
        .replaceAll('x', '')
        .replaceAll('X', '')
        .replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (parsed == null || !parsed.isFinite) {
      _syncText();
      return;
    }
    final selected = widget.options[_nearestOptionIndex(parsed)];
    if (selected == widget.value) {
      _syncText();
      return;
    }
    widget.onChanged(selected);
  }

  int _nearestOptionIndex(double value) {
    var nearestIndex = 0;
    var nearestDistance = (widget.options.first - value).abs();
    for (var index = 1; index < widget.options.length; index += 1) {
      final distance = (widget.options[index] - value).abs();
      if (distance < nearestDistance) {
        nearestIndex = index;
        nearestDistance = distance;
      }
    }
    return nearestIndex;
  }

  String _formatScale(double value) => value.toStringAsFixed(1);

  void _syncText() {
    final text = _formatScale(widget.value);
    if (_controller.text == text) return;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
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
