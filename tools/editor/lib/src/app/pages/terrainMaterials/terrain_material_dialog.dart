import 'package:flutter/material.dart';
import 'package:terrain_materials/terrain_materials.dart';

import '../../../atlas/atlas_grid_settings_cache.dart';
import '../../../atlas/atlas_pixel_rect.dart';
import '../../../workspace/repository_png_catalog.dart';
import '../shared/atlas_region_preview_tile.dart';
import '../shared/editor_scene_view_utils.dart';
import 'terrain_atlas_region_picker.dart';

/// Accepted create/edit result, including the stable key being replaced.
final class TerrainMaterialEditResult {
  const TerrainMaterialEditResult({
    required this.previousKey,
    required this.material,
  });

  final String previousKey;
  final TerrainMaterialDefinition material;
}

/// Opens the complete terrain-material definition form.
Future<TerrainMaterialEditResult?> showTerrainMaterialDialog(
  BuildContext context, {
  required String workspaceRootPath,
  required Set<String> existingKeys,
  required List<RepositoryPngImage> atlasImages,
  required AtlasGridSettingsCache gridSettingsCache,
  TerrainMaterialDefinition? material,
  String? suggestedKey,
  bool allowKeyChange = true,
  bool isNew = false,
}) => showDialog<TerrainMaterialEditResult>(
  context: context,
  builder: (context) => _TerrainMaterialDialog(
    workspaceRootPath: workspaceRootPath,
    existingKeys: existingKeys,
    atlasImages: atlasImages,
    gridSettingsCache: gridSettingsCache,
    material: material,
    suggestedKey: suggestedKey,
    allowKeyChange: allowKeyChange,
    isNew: isNew || material == null,
  ),
);

class _TerrainMaterialDialog extends StatefulWidget {
  const _TerrainMaterialDialog({
    required this.workspaceRootPath,
    required this.existingKeys,
    required this.atlasImages,
    required this.gridSettingsCache,
    required this.material,
    required this.suggestedKey,
    required this.allowKeyChange,
    required this.isNew,
  });

  final String workspaceRootPath;
  final Set<String> existingKeys;
  final List<RepositoryPngImage> atlasImages;
  final AtlasGridSettingsCache gridSettingsCache;
  final TerrainMaterialDefinition? material;
  final String? suggestedKey;
  final bool allowKeyChange;
  final bool isNew;

  @override
  State<_TerrainMaterialDialog> createState() => _TerrainMaterialDialogState();
}

class _TerrainMaterialDialogState extends State<_TerrainMaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  final EditorUiImageCache _previewCache = EditorUiImageCache();
  late final TextEditingController _key;
  late final TextEditingController _displayName;
  TerrainMaterialImageRegion? _fill;
  late final _EdgeProfileDraft _top;
  late final _EdgeProfileDraft _leftWall;
  late final _EdgeProfileDraft _rightWall;
  late final _EdgeProfileDraft _underside;
  late final _CapDraft _startCap;
  late final _CapDraft _endCap;
  late bool _hasLeftWall;
  late bool _hasRightWall;
  late bool _hasUnderside;
  late bool _hasCaps;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final material = widget.material;
    _key = TextEditingController(text: material?.key ?? widget.suggestedKey);
    _displayName = TextEditingController(text: material?.displayName ?? '');
    _fill = material?.fill;
    _top = _EdgeProfileDraft.fromProfile(material?.top);
    _leftWall = _EdgeProfileDraft.fromProfile(material?.leftWall);
    _rightWall = _EdgeProfileDraft.fromProfile(material?.rightWall);
    _underside = _EdgeProfileDraft.fromProfile(material?.underside);
    _startCap = _CapDraft.fromCap(material?.topStartCap);
    _endCap = _CapDraft.fromCap(material?.topEndCap);
    _hasLeftWall = material?.leftWall != null;
    _hasRightWall = material?.rightWall != null;
    _hasUnderside = material?.underside != null;
    _hasCaps = material?.topStartCap != null || material?.topEndCap != null;
  }

  @override
  void dispose() {
    _key.dispose();
    _displayName.dispose();
    _top.dispose();
    _leftWall.dispose();
    _rightWall.dispose();
    _underside.dispose();
    _startCap.dispose();
    _endCap.dispose();
    _previewCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = !widget.isNew;
    return AlertDialog(
      key: const ValueKey<String>('terrain_material_dialog'),
      title: Text(editing ? 'Edit terrain material' : 'New terrain material'),
      content: SizedBox(
        width: 900,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 260,
                      child: TextFormField(
                        controller: _key,
                        readOnly: !widget.allowKeyChange,
                        decoration: const InputDecoration(
                          labelText: 'Material key',
                          helperText: 'Stable polygon reference',
                        ),
                        validator: _validateKey,
                      ),
                    ),
                    SizedBox(
                      width: 360,
                      child: TextFormField(
                        controller: _displayName,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                        ),
                        validator: _requiredText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _regionField(
                  label: 'Fill texture',
                  keySuffix: 'fill',
                  region: _fill,
                  onChanged: (region) => setState(() => _fill = region),
                ),
                const SizedBox(height: 16),
                Text('Top / slope edges', style: _sectionStyle(context)),
                const Text(
                  'Repeated along every upward-facing horizontal or sloped edge.',
                ),
                const SizedBox(height: 8),
                _profileFields(
                  'top',
                  _top,
                  orientation: TerrainMaterialEdgeOrientation.top,
                ),
                const Divider(height: 28),
                _optionalProfile(
                  label: 'Left wall edges',
                  keyPrefix: 'left_wall',
                  value: _hasLeftWall,
                  onChanged: (value) => setState(() => _hasLeftWall = value),
                  draft: _leftWall,
                  orientation: TerrainMaterialEdgeOrientation.leftWall,
                ),
                const SizedBox(height: 10),
                _optionalProfile(
                  label: 'Right wall edges',
                  keyPrefix: 'right_wall',
                  value: _hasRightWall,
                  onChanged: (value) => setState(() => _hasRightWall = value),
                  draft: _rightWall,
                  orientation: TerrainMaterialEdgeOrientation.rightWall,
                ),
                const SizedBox(height: 10),
                _optionalProfile(
                  label: 'Underside edges',
                  keyPrefix: 'underside',
                  value: _hasUnderside,
                  onChanged: (value) => setState(() => _hasUnderside = value),
                  draft: _underside,
                  orientation: TerrainMaterialEdgeOrientation.underside,
                ),
                const Divider(height: 28),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Top cliff caps'),
                  subtitle: const Text(
                    'Paired endpoint regions; smooth continuations never use caps.',
                  ),
                  value: _hasCaps,
                  onChanged: (value) => setState(() => _hasCaps = value),
                ),
                if (_hasCaps) ...[
                  _capFields('Start / left cap', 'start_cap', _startCap),
                  const SizedBox(height: 10),
                  _capFields('End / right cap', 'end_cap', _endCap),
                ],
                if (_formError case final error?) ...[
                  const SizedBox(height: 12),
                  Text(
                    error,
                    key: const ValueKey<String>('terrain_material_form_error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('terrain_material_dialog_apply'),
          onPressed: _accept,
          child: Text(editing ? 'Save material' : 'Create material'),
        ),
      ],
    );
  }

  Widget _optionalProfile({
    required String label,
    required String keyPrefix,
    required bool value,
    required ValueChanged<bool> onChanged,
    required _EdgeProfileDraft draft,
    required TerrainMaterialEdgeOrientation orientation,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: const Text('Disabled means this orientation uses fill only.'),
        value: value,
        onChanged: onChanged,
      ),
      if (value) _profileFields(keyPrefix, draft, orientation: orientation),
    ],
  );

  Widget _profileFields(
    String keyPrefix,
    _EdgeProfileDraft draft, {
    required TerrainMaterialEdgeOrientation orientation,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _regionField(
              label: 'Base region',
              keySuffix: '${keyPrefix}_base',
              region: draft.baseRegion,
              anchorY: double.tryParse(draft.baseAnchorY.text.trim()),
              edgeOrientation: orientation,
              onChanged: (region) => setState(() => draft.baseRegion = region),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: TextFormField(
              controller: draft.baseAnchorY,
              decoration: const InputDecoration(
                labelText: 'Edge anchor',
                helperText: 'After role orientation',
              ),
              validator: (value) => _anchor(
                value,
                maximum: _edgeAnchorMaximum(draft.baseRegion, orientation),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _regionField(
              label: 'Detail region (optional)',
              keySuffix: '${keyPrefix}_detail',
              region: draft.detailRegion,
              anchorY: double.tryParse(draft.detailAnchorY.text.trim()),
              edgeOrientation: orientation,
              optional: true,
              onChanged: (region) =>
                  setState(() => draft.detailRegion = region),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: TextFormField(
              controller: draft.detailAnchorY,
              enabled: draft.detailRegion != null,
              decoration: const InputDecoration(
                labelText: 'Edge anchor',
                helperText: 'After role orientation',
              ),
              validator: (value) => draft.detailRegion == null
                  ? null
                  : _anchor(
                      value,
                      maximum: _edgeAnchorMaximum(
                        draft.detailRegion,
                        orientation,
                      ),
                    ),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _capFields(String label, String keySuffix, _CapDraft draft) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: _regionField(
          label: label,
          keySuffix: keySuffix,
          region: draft.region,
          anchorX: double.tryParse(draft.anchorX.text.trim()),
          anchorY: double.tryParse(draft.anchorY.text.trim()),
          onChanged: (region) => setState(() => draft.region = region),
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 110,
        child: TextFormField(
          controller: draft.anchorX,
          decoration: const InputDecoration(labelText: 'Anchor X'),
          validator: (value) =>
              _anchor(value, maximum: draft.region?.width.toDouble()),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 110,
        child: TextFormField(
          controller: draft.anchorY,
          decoration: const InputDecoration(labelText: 'Anchor Y'),
          validator: (value) =>
              _anchor(value, maximum: draft.region?.height.toDouble()),
        ),
      ),
    ],
  );

  Widget _regionField({
    required String label,
    required String keySuffix,
    required TerrainMaterialImageRegion? region,
    required ValueChanged<TerrainMaterialImageRegion?> onChanged,
    bool optional = false,
    double? anchorX,
    double? anchorY,
    TerrainMaterialEdgeOrientation? edgeOrientation,
  }) => _TerrainRegionField(
    label: label,
    fieldKey: ValueKey<String>('terrain_material_${keySuffix}_region'),
    workspaceRootPath: widget.workspaceRootPath,
    region: region,
    optional: optional,
    imageCache: _previewCache,
    onSelect: () async {
      final selected = await showTerrainAtlasRegionPicker(
        context,
        workspaceRootPath: widget.workspaceRootPath,
        atlasImages: widget.atlasImages,
        gridSettingsCache: widget.gridSettingsCache,
        initialRegion: region,
        anchorX: anchorX,
        anchorY: anchorY,
        edgeOrientation: edgeOrientation,
      );
      if (selected != null && mounted) onChanged(selected);
    },
    onClear: optional ? () => onChanged(null) : null,
  );

  void _accept() {
    final regionsComplete =
        _fill != null &&
        _top.baseRegion != null &&
        (!_hasLeftWall || _leftWall.baseRegion != null) &&
        (!_hasRightWall || _rightWall.baseRegion != null) &&
        (!_hasUnderside || _underside.baseRegion != null) &&
        (!_hasCaps || (_startCap.region != null && _endCap.region != null));
    if (!regionsComplete) {
      setState(() {
        _formError = 'Assign every required atlas region before saving.';
      });
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final current = widget.material;
    final candidate = TerrainMaterialDefinition(
      key: _key.text.trim(),
      displayName: _displayName.text.trim(),
      revision: widget.isNew ? 1 : current!.revision,
      fill: _fill!,
      top: _top.build(),
      leftWall: _hasLeftWall ? _leftWall.build() : null,
      rightWall: _hasRightWall ? _rightWall.build() : null,
      underside: _hasUnderside ? _underside.build() : null,
      topStartCap: _hasCaps ? _startCap.build() : null,
      topEndCap: _hasCaps ? _endCap.build() : null,
    );
    if (!widget.isNew && candidate == current) {
      Navigator.of(context).pop();
      return;
    }
    final result = widget.isNew
        ? candidate
        : candidate.copyWith(revision: current!.revision + 1);
    Navigator.of(context).pop(
      TerrainMaterialEditResult(
        previousKey: widget.isNew ? '' : current!.key,
        material: result,
      ),
    );
  }

  String? _validateKey(String? value) {
    final key = value?.trim() ?? '';
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(key)) {
      return 'Use lower_snake_case.';
    }
    if (!widget.allowKeyChange && key != widget.material?.key) {
      return 'Referenced material keys cannot be renamed.';
    }
    if ((widget.isNew || key != widget.material?.key) &&
        widget.existingKeys.contains(key)) {
      return 'That material key already exists.';
    }
    return null;
  }
}

class _TerrainRegionField extends StatelessWidget {
  const _TerrainRegionField({
    required this.label,
    required this.fieldKey,
    required this.workspaceRootPath,
    required this.region,
    required this.optional,
    required this.imageCache,
    required this.onSelect,
    required this.onClear,
  });

  final String label;
  final Key fieldKey;
  final String workspaceRootPath;
  final TerrainMaterialImageRegion? region;
  final bool optional;
  final EditorUiImageCache imageCache;
  final VoidCallback onSelect;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final region = this.region;
    return Container(
      key: fieldKey,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          AtlasRegionPreviewTile(
            imageCache: imageCache,
            workspaceRootPath: workspaceRootPath,
            sourceImagePath: region?.assetPath,
            region: region == null
                ? null
                : AtlasPixelRect(
                    x: region.x,
                    y: region.y,
                    width: region.width,
                    height: region.height,
                  ),
            width: 64,
            height: 52,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 3),
                Text(
                  region == null
                      ? optional
                            ? 'Not configured'
                            : 'Required region not assigned'
                      : '${region.assetPath}\n'
                            '[${region.x}, ${region.y}, ${region.width}, ${region.height}]',
                ),
              ],
            ),
          ),
          if (onClear != null && region != null)
            IconButton(
              tooltip: 'Clear optional region',
              onPressed: onClear,
              icon: const Icon(Icons.clear),
            ),
          OutlinedButton(
            onPressed: onSelect,
            child: Text(region == null ? 'Select region' : 'Change region'),
          ),
        ],
      ),
    );
  }
}

final class _EdgeProfileDraft {
  _EdgeProfileDraft({
    required this.baseRegion,
    required double baseAnchorY,
    required this.detailRegion,
    required double detailAnchorY,
  }) : baseAnchorY = TextEditingController(text: _number(baseAnchorY)),
       detailAnchorY = TextEditingController(text: _number(detailAnchorY));

  factory _EdgeProfileDraft.fromProfile(TerrainMaterialEdgeProfile? profile) =>
      _EdgeProfileDraft(
        baseRegion: profile?.base.region,
        baseAnchorY: profile?.base.anchorY ?? 0,
        detailRegion: profile?.detail?.region,
        detailAnchorY: profile?.detail?.anchorY ?? 0,
      );

  TerrainMaterialImageRegion? baseRegion;
  TerrainMaterialImageRegion? detailRegion;
  final TextEditingController baseAnchorY;
  final TextEditingController detailAnchorY;

  TerrainMaterialEdgeProfile build() => TerrainMaterialEdgeProfile(
    base: TerrainMaterialEdgeLayer(
      region: baseRegion!,
      anchorY: double.parse(baseAnchorY.text.trim()),
    ),
    detail: detailRegion == null
        ? null
        : TerrainMaterialEdgeLayer(
            region: detailRegion!,
            anchorY: double.parse(detailAnchorY.text.trim()),
          ),
  );

  void dispose() {
    baseAnchorY.dispose();
    detailAnchorY.dispose();
  }
}

final class _CapDraft {
  _CapDraft({
    required this.region,
    required double anchorX,
    required double anchorY,
  }) : anchorX = TextEditingController(text: _number(anchorX)),
       anchorY = TextEditingController(text: _number(anchorY));

  factory _CapDraft.fromCap(TerrainMaterialCap? cap) => _CapDraft(
    region: cap?.region,
    anchorX: cap?.anchorX ?? 0,
    anchorY: cap?.anchorY ?? 0,
  );

  TerrainMaterialImageRegion? region;
  final TextEditingController anchorX;
  final TextEditingController anchorY;

  TerrainMaterialCap build() => TerrainMaterialCap(
    region: region!,
    anchorX: double.parse(anchorX.text.trim()),
    anchorY: double.parse(anchorY.text.trim()),
  );

  void dispose() {
    anchorX.dispose();
    anchorY.dispose();
  }
}

TextStyle? _sectionStyle(BuildContext context) =>
    Theme.of(context).textTheme.titleSmall;

String? _requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;

String? _anchor(String? value, {required double? maximum}) {
  final parsed = double.tryParse(value?.trim() ?? '');
  if (parsed == null || !parsed.isFinite || parsed < 0) {
    return 'Use a non-negative number.';
  }
  if (maximum != null && parsed > maximum) {
    return 'Must be at most ${_number(maximum)}.';
  }
  return null;
}

double? _edgeAnchorMaximum(
  TerrainMaterialImageRegion? region,
  TerrainMaterialEdgeOrientation orientation,
) => region == null
    ? null
    : terrainMaterialEdgeTileHeight(
        orientation: orientation,
        sourceWidth: region.width,
        sourceHeight: region.height,
      ).toDouble();

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
