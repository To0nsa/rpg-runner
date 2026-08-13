import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:terrain_materials/terrain_materials.dart';

const XTypeGroup _terrainPngTypeGroup = XTypeGroup(
  label: 'Terrain PNG images',
  extensions: <String>['png'],
);

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
  TerrainMaterialDefinition? material,
  String? suggestedKey,
  bool allowKeyChange = true,
}) => showDialog<TerrainMaterialEditResult>(
  context: context,
  builder: (context) => _TerrainMaterialDialog(
    workspaceRootPath: workspaceRootPath,
    existingKeys: existingKeys,
    material: material,
    suggestedKey: suggestedKey,
    allowKeyChange: allowKeyChange,
  ),
);

class _TerrainMaterialDialog extends StatefulWidget {
  const _TerrainMaterialDialog({
    required this.workspaceRootPath,
    required this.existingKeys,
    required this.material,
    required this.suggestedKey,
    required this.allowKeyChange,
  });

  final String workspaceRootPath;
  final Set<String> existingKeys;
  final TerrainMaterialDefinition? material;
  final String? suggestedKey;
  final bool allowKeyChange;

  @override
  State<_TerrainMaterialDialog> createState() => _TerrainMaterialDialogState();
}

class _TerrainMaterialDialogState extends State<_TerrainMaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _key;
  late final TextEditingController _displayName;
  late final TextEditingController _fill;
  late final _EdgeProfileControllers _top;
  late final _EdgeProfileControllers _leftWall;
  late final _EdgeProfileControllers _rightWall;
  late final _EdgeProfileControllers _underside;
  late final _CapControllers _startCap;
  late final _CapControllers _endCap;
  late bool _hasLeftWall;
  late bool _hasRightWall;
  late bool _hasUnderside;
  late bool _hasCaps;
  String? _pickerError;

  @override
  void initState() {
    super.initState();
    final material = widget.material;
    _key = TextEditingController(text: material?.key ?? widget.suggestedKey);
    _displayName = TextEditingController(text: material?.displayName ?? '');
    _fill = TextEditingController(text: material?.fillAssetPath ?? '');
    _top = _EdgeProfileControllers.fromProfile(material?.top);
    _leftWall = _EdgeProfileControllers.fromProfile(material?.leftWall);
    _rightWall = _EdgeProfileControllers.fromProfile(material?.rightWall);
    _underside = _EdgeProfileControllers.fromProfile(material?.underside);
    _startCap = _CapControllers.fromCap(material?.topStartCap);
    _endCap = _CapControllers.fromCap(material?.topEndCap);
    _hasLeftWall = material?.leftWall != null;
    _hasRightWall = material?.rightWall != null;
    _hasUnderside = material?.underside != null;
    _hasCaps = material?.topStartCap != null || material?.topEndCap != null;
  }

  @override
  void dispose() {
    _key.dispose();
    _displayName.dispose();
    _fill.dispose();
    _top.dispose();
    _leftWall.dispose();
    _rightWall.dispose();
    _underside.dispose();
    _startCap.dispose();
    _endCap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.material != null;
    return AlertDialog(
      key: const ValueKey<String>('terrain_material_dialog'),
      title: Text(editing ? 'Edit terrain material' : 'New terrain material'),
      content: SizedBox(
        width: 820,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
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
                _AssetPathField(
                  label: 'Fill texture',
                  controller: _fill,
                  onBrowse: () => _pick(_fill),
                  validator: _requiredAssetPath,
                ),
                const SizedBox(height: 16),
                Text('Top / slope edges', style: _sectionStyle(context)),
                const Text(
                  'Repeated along every upward-facing horizontal or sloped edge.',
                ),
                const SizedBox(height: 8),
                _EdgeProfileFields(
                  controllers: _top,
                  onBrowseBase: () => _pick(_top.basePath),
                  onBrowseDetail: () => _pick(_top.detailPath),
                  requiredProfile: true,
                ),
                const Divider(height: 28),
                _optionalProfile(
                  label: 'Left wall edges',
                  value: _hasLeftWall,
                  onChanged: (value) => setState(() => _hasLeftWall = value),
                  controllers: _leftWall,
                ),
                const SizedBox(height: 10),
                _optionalProfile(
                  label: 'Right wall edges',
                  value: _hasRightWall,
                  onChanged: (value) => setState(() => _hasRightWall = value),
                  controllers: _rightWall,
                ),
                const SizedBox(height: 10),
                _optionalProfile(
                  label: 'Underside edges',
                  value: _hasUnderside,
                  onChanged: (value) => setState(() => _hasUnderside = value),
                  controllers: _underside,
                ),
                const Divider(height: 28),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Top cliff caps'),
                  subtitle: const Text(
                    'Paired endpoint images; smooth continuations never use caps.',
                  ),
                  value: _hasCaps,
                  onChanged: (value) => setState(() => _hasCaps = value),
                ),
                if (_hasCaps) ...<Widget>[
                  _CapFields(
                    label: 'Start / left cap',
                    controllers: _startCap,
                    onBrowse: () => _pick(_startCap.assetPath),
                  ),
                  const SizedBox(height: 10),
                  _CapFields(
                    label: 'End / right cap',
                    controllers: _endCap,
                    onBrowse: () => _pick(_endCap.assetPath),
                  ),
                ],
                if (_pickerError case final error?) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    error,
                    key: const ValueKey<String>(
                      'terrain_material_picker_error',
                    ),
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
      actions: <Widget>[
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
    required bool value,
    required ValueChanged<bool> onChanged,
    required _EdgeProfileControllers controllers,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: const Text('Disabled means this orientation uses fill only.'),
        value: value,
        onChanged: onChanged,
      ),
      if (value)
        _EdgeProfileFields(
          controllers: controllers,
          onBrowseBase: () => _pick(controllers.basePath),
          onBrowseDetail: () => _pick(controllers.detailPath),
          requiredProfile: true,
        ),
    ],
  );

  Future<void> _pick(TextEditingController controller) async {
    final terrainRoot = p.normalize(
      p.join(widget.workspaceRootPath, 'assets', 'images', 'terrain'),
    );
    final selected = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_terrainPngTypeGroup],
      initialDirectory: terrainRoot,
      confirmButtonText: 'Select terrain image',
    );
    if (selected == null || !mounted) return;
    final absolute = p.normalize(p.absolute(selected.path));
    final workspaceRoot = p.normalize(p.absolute(widget.workspaceRootPath));
    if (!p.isWithin(terrainRoot, absolute) ||
        p.extension(absolute).toLowerCase() != '.png') {
      setState(() {
        _pickerError =
            'Choose a PNG under assets/images/terrain in this workspace.';
      });
      return;
    }
    final relative = p
        .relative(absolute, from: workspaceRoot)
        .replaceAll('\\', '/');
    setState(() {
      controller.text = relative;
      _pickerError = null;
    });
  }

  void _accept() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final current = widget.material;
    final candidate = TerrainMaterialDefinition(
      key: _key.text.trim(),
      displayName: _displayName.text.trim(),
      revision: current?.revision ?? 1,
      fillAssetPath: _fill.text.trim(),
      top: _top.build(),
      leftWall: _hasLeftWall ? _leftWall.build() : null,
      rightWall: _hasRightWall ? _rightWall.build() : null,
      underside: _hasUnderside ? _underside.build() : null,
      topStartCap: _hasCaps ? _startCap.build() : null,
      topEndCap: _hasCaps ? _endCap.build() : null,
    );
    final result = current == candidate
        ? candidate
        : candidate.copyWith(revision: (current?.revision ?? 0) + 1);
    Navigator.of(context).pop(
      TerrainMaterialEditResult(
        previousKey: current?.key ?? '',
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
    if (key != widget.material?.key && widget.existingKeys.contains(key)) {
      return 'That material key already exists.';
    }
    return null;
  }
}

class _AssetPathField extends StatelessWidget {
  const _AssetPathField({
    required this.label,
    required this.controller,
    required this.onBrowse,
    required this.validator,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onBrowse;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          validator: validator,
        ),
      ),
      const SizedBox(width: 8),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: OutlinedButton.icon(
          onPressed: onBrowse,
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Browse'),
        ),
      ),
    ],
  );
}

class _EdgeProfileFields extends StatelessWidget {
  const _EdgeProfileFields({
    required this.controllers,
    required this.onBrowseBase,
    required this.onBrowseDetail,
    required this.requiredProfile,
  });

  final _EdgeProfileControllers controllers;
  final VoidCallback onBrowseBase;
  final VoidCallback onBrowseDetail;
  final bool requiredProfile;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: _AssetPathField(
              label: 'Base image',
              controller: controllers.basePath,
              onBrowse: onBrowseBase,
              validator: requiredProfile ? _requiredAssetPath : (_) => null,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: TextFormField(
              controller: controllers.baseAnchorY,
              decoration: const InputDecoration(labelText: 'Edge anchor Y'),
              validator: _nonNegativeNumber,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: _AssetPathField(
              label: 'Detail image (optional)',
              controller: controllers.detailPath,
              onBrowse: onBrowseDetail,
              validator: _optionalAssetPath,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: TextFormField(
              controller: controllers.detailAnchorY,
              decoration: const InputDecoration(labelText: 'Edge anchor Y'),
              validator: (value) => controllers.detailPath.text.trim().isEmpty
                  ? null
                  : _nonNegativeNumber(value),
            ),
          ),
        ],
      ),
    ],
  );
}

class _CapFields extends StatelessWidget {
  const _CapFields({
    required this.label,
    required this.controllers,
    required this.onBrowse,
  });

  final String label;
  final _CapControllers controllers;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        child: _AssetPathField(
          label: label,
          controller: controllers.assetPath,
          onBrowse: onBrowse,
          validator: _requiredAssetPath,
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 100,
        child: TextFormField(
          controller: controllers.anchorX,
          decoration: const InputDecoration(labelText: 'Anchor X'),
          validator: _nonNegativeNumber,
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 100,
        child: TextFormField(
          controller: controllers.anchorY,
          decoration: const InputDecoration(labelText: 'Anchor Y'),
          validator: _nonNegativeNumber,
        ),
      ),
    ],
  );
}

class _EdgeProfileControllers {
  _EdgeProfileControllers({
    required String basePath,
    required double baseAnchorY,
    required String detailPath,
    required double detailAnchorY,
  }) : basePath = TextEditingController(text: basePath),
       baseAnchorY = TextEditingController(text: _number(baseAnchorY)),
       detailPath = TextEditingController(text: detailPath),
       detailAnchorY = TextEditingController(text: _number(detailAnchorY));

  factory _EdgeProfileControllers.fromProfile(
    TerrainMaterialEdgeProfile? profile,
  ) => _EdgeProfileControllers(
    basePath: profile?.base.assetPath ?? '',
    baseAnchorY: profile?.base.anchorY ?? 0,
    detailPath: profile?.detail?.assetPath ?? '',
    detailAnchorY: profile?.detail?.anchorY ?? 0,
  );

  final TextEditingController basePath;
  final TextEditingController baseAnchorY;
  final TextEditingController detailPath;
  final TextEditingController detailAnchorY;

  TerrainMaterialEdgeProfile build() => TerrainMaterialEdgeProfile(
    base: TerrainMaterialEdgeLayer(
      assetPath: basePath.text.trim(),
      anchorY: double.parse(baseAnchorY.text.trim()),
    ),
    detail: detailPath.text.trim().isEmpty
        ? null
        : TerrainMaterialEdgeLayer(
            assetPath: detailPath.text.trim(),
            anchorY: double.parse(detailAnchorY.text.trim()),
          ),
  );

  void dispose() {
    basePath.dispose();
    baseAnchorY.dispose();
    detailPath.dispose();
    detailAnchorY.dispose();
  }
}

class _CapControllers {
  _CapControllers({
    required String assetPath,
    required double anchorX,
    required double anchorY,
  }) : assetPath = TextEditingController(text: assetPath),
       anchorX = TextEditingController(text: _number(anchorX)),
       anchorY = TextEditingController(text: _number(anchorY));

  factory _CapControllers.fromCap(TerrainMaterialCap? cap) => _CapControllers(
    assetPath: cap?.assetPath ?? '',
    anchorX: cap?.anchorX ?? 0,
    anchorY: cap?.anchorY ?? 0,
  );

  final TextEditingController assetPath;
  final TextEditingController anchorX;
  final TextEditingController anchorY;

  TerrainMaterialCap build() => TerrainMaterialCap(
    assetPath: assetPath.text.trim(),
    anchorX: double.parse(anchorX.text.trim()),
    anchorY: double.parse(anchorY.text.trim()),
  );

  void dispose() {
    assetPath.dispose();
    anchorX.dispose();
    anchorY.dispose();
  }
}

TextStyle? _sectionStyle(BuildContext context) =>
    Theme.of(context).textTheme.titleSmall;

String? _requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;

String? _requiredAssetPath(String? value) {
  final required = _requiredText(value);
  return required ?? _optionalAssetPath(value);
}

String? _optionalAssetPath(String? value) {
  final path = value?.trim() ?? '';
  if (path.isEmpty) return null;
  if (!RegExp(
        r'^assets/images/terrain/[a-zA-Z0-9_./-]+\.png$',
      ).hasMatch(path) ||
      path.contains('..') ||
      path.contains('\\')) {
    return 'Use a PNG under assets/images/terrain/.';
  }
  return null;
}

String? _nonNegativeNumber(String? value) {
  final parsed = double.tryParse(value?.trim() ?? '');
  return parsed == null || !parsed.isFinite || parsed < 0
      ? 'Use a non-negative number.'
      : null;
}

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
