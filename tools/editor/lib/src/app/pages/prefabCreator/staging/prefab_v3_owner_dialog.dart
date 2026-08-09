import 'package:flutter/material.dart';

import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/domain/prefab_visual_bounds_resolver.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../prefabs/store/prefab_determinism.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';

/// Validated retained metadata returned by the Prefab-v3 owner form.
@immutable
final class PrefabV3OwnerDialogResult {
  const PrefabV3OwnerDialogResult({
    this.id,
    required this.status,
    required this.kind,
    required this.visualSource,
    required this.anchorXPx,
    required this.anchorYPx,
    required this.tags,
  });

  final String? id;
  final PrefabStatus status;
  final PrefabKind kind;
  final PrefabVisualSource visualSource;
  final int anchorXPx;
  final int anchorYPx;
  final List<String> tags;
}

/// Opens the retained Prefab-v3 owner form without exposing collision fields.
Future<PrefabV3OwnerDialogResult?> showPrefabV3OwnerDialog(
  BuildContext context, {
  required PrefabV3StagingDocument document,
  PrefabV3Def? prefab,
}) => showDialog<PrefabV3OwnerDialogResult>(
  context: context,
  builder: (context) =>
      _PrefabV3OwnerDialog(document: document, prefab: prefab),
);

/// Opens the stable-key-preserving human-ID rename form.
Future<String?> showPrefabV3RenameDialog(
  BuildContext context, {
  required PrefabV3StagingDocument document,
  required PrefabV3Def prefab,
}) => showDialog<String>(
  context: context,
  builder: (context) =>
      _PrefabV3RenameDialog(document: document, prefab: prefab),
);

final class _PrefabV3RenameDialog extends StatefulWidget {
  const _PrefabV3RenameDialog({required this.document, required this.prefab});

  final PrefabV3StagingDocument document;
  final PrefabV3Def prefab;

  @override
  State<_PrefabV3RenameDialog> createState() => _PrefabV3RenameDialogState();
}

final class _PrefabV3RenameDialogState extends State<_PrefabV3RenameDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.prefab.id);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rename prefab owner'),
    content: SizedBox(
      width: 420,
      child: TextField(
        key: const ValueKey<String>('prefab_v3_rename_id_field'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Human ID',
          errorText: _error,
          helperText: 'The stable prefab key is preserved.',
        ),
        onSubmitted: (_) => _submit(),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey<String>('prefab_v3_rename_apply'),
        onPressed: _submit,
        child: const Text('Rename'),
      ),
    ],
  );

  void _submit() {
    final value = _validOwnerId(
      _controller.text,
      document: widget.document,
      exceptPrefabKey: widget.prefab.prefabKey,
    );
    if (value != null) {
      Navigator.of(context).pop(value);
    } else {
      setState(() => _error = 'Enter a unique trimmed ID.');
    }
  }
}

final class _PrefabV3OwnerDialog extends StatefulWidget {
  const _PrefabV3OwnerDialog({required this.document, this.prefab});

  final PrefabV3StagingDocument document;
  final PrefabV3Def? prefab;

  @override
  State<_PrefabV3OwnerDialog> createState() => _PrefabV3OwnerDialogState();
}

final class _PrefabV3OwnerDialogState extends State<_PrefabV3OwnerDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _anchorXController;
  late final TextEditingController _anchorYController;
  late final TextEditingController _tagsController;
  late final List<PrefabKind> _availableKinds;
  late PrefabStatus _status;
  late PrefabKind _kind;
  String? _sourceId;
  String? _submissionError;

  bool get _isCreating => widget.prefab == null;

  @override
  void initState() {
    super.initState();
    _availableKinds = _resolveAvailableKinds(widget.document, widget.prefab);
    final current = widget.prefab;
    _kind = current != null && _availableKinds.contains(current.kind)
        ? current.kind
        : _availableKinds.first;
    _status = current?.status ?? PrefabStatus.active;
    final sourceIds = _sourceIds(_kind);
    final currentSourceId = current?.visualSource.referenceId;
    _sourceId = currentSourceId != null && sourceIds.contains(currentSourceId)
        ? currentSourceId
        : sourceIds.firstOrNull;
    final bounds = _selectedBounds;
    _idController = TextEditingController(text: current?.id ?? '');
    _anchorXController = TextEditingController(
      text: (current?.anchorXPx ?? ((bounds?.widthPx ?? 0) ~/ 2)).toString(),
    );
    _anchorYController = TextEditingController(
      text: (current?.anchorYPx ?? ((bounds?.heightPx ?? 0) ~/ 2)).toString(),
    );
    _tagsController = TextEditingController(
      text: current?.tags.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _anchorXController.dispose();
    _anchorYController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sourceIds = _sourceIds(_kind);
    return AlertDialog(
      title: Text(_isCreating ? 'Create prefab owner' : 'Edit prefab metadata'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_isCreating) ...<Widget>[
                  TextFormField(
                    key: const ValueKey<String>('prefab_v3_owner_id_field'),
                    controller: _idController,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Human ID'),
                    validator: (value) =>
                        _validOwnerId(value ?? '', document: widget.document) ==
                            null
                        ? 'Enter a unique trimmed ID.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                if (!_isCreating) ...<Widget>[
                  DropdownButtonFormField<PrefabStatus>(
                    key: const ValueKey<String>('prefab_v3_owner_status_field'),
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items:
                        const <PrefabStatus>[
                              PrefabStatus.active,
                              PrefabStatus.deprecated,
                            ]
                            .map(
                              (status) => DropdownMenuItem<PrefabStatus>(
                                value: status,
                                child: Text(status.jsonValue),
                              ),
                            )
                            .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) setState(() => _status = value);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<PrefabKind>(
                  key: ValueKey<String>('prefab_v3_owner_kind_${_kind.name}'),
                  initialValue: _kind,
                  decoration: const InputDecoration(labelText: 'Kind'),
                  items: _availableKinds
                      .map(
                        (kind) => DropdownMenuItem<PrefabKind>(
                          value: kind,
                          child: Text(kind.jsonValue),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null || value == _kind) return;
                    setState(() {
                      _kind = value;
                      _sourceId = _sourceIds(value).firstOrNull;
                      _centerAnchorOnSelectedSource();
                      _submissionError = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey<String>(
                    'prefab_v3_owner_source_${_kind.name}_$_sourceId',
                  ),
                  initialValue: _sourceId,
                  decoration: InputDecoration(
                    labelText: _kind == PrefabKind.platform
                        ? 'Platform module'
                        : 'Atlas slice',
                  ),
                  items: sourceIds
                      .map(
                        (id) => DropdownMenuItem<String>(
                          value: id,
                          child: Text(id),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null || value == _sourceId) return;
                    setState(() {
                      _sourceId = value;
                      _centerAnchorOnSelectedSource();
                      _submissionError = null;
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Choose a visual source.' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey<String>(
                          'prefab_v3_owner_anchor_x_field',
                        ),
                        controller: _anchorXController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Anchor X (px)',
                        ),
                        validator: _integerValidator,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey<String>(
                          'prefab_v3_owner_anchor_y_field',
                        ),
                        controller: _anchorYController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Anchor Y (px)',
                        ),
                        validator: _integerValidator,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey<String>('prefab_v3_owner_tags_field'),
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    helperText:
                        'Comma-separated; saved uniquely in lexical order.',
                  ),
                ),
                if (_submissionError != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _submissionError!,
                    key: const ValueKey<String>('prefab_v3_owner_form_error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (widget.prefab?.collisionShapes.isNotEmpty ??
                    false) ...<Widget>[
                  const SizedBox(height: 12),
                  const Text(
                    'Kind choices are restricted by the committed polygon '
                    'collision modes. Edit shape metadata first to change '
                    'between obstacle and platform ownership.',
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
          key: const ValueKey<String>('prefab_v3_owner_dialog_apply'),
          onPressed: _submit,
          child: Text(_isCreating ? 'Create' : 'Apply'),
        ),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final sourceId = _sourceId;
    final bounds = _selectedBounds;
    final anchorX = int.parse(_anchorXController.text.trim());
    final anchorY = int.parse(_anchorYController.text.trim());
    if (sourceId == null || bounds == null) {
      setState(
        () => _submissionError = 'The visual source has no valid bounds.',
      );
      return;
    }
    if (anchorX < 0 ||
        anchorY < 0 ||
        anchorX > bounds.widthPx ||
        anchorY > bounds.heightPx) {
      setState(
        () => _submissionError =
            'Anchor must stay within 0..${bounds.widthPx} × '
            '0..${bounds.heightPx} px.',
      );
      return;
    }
    final tags = PrefabDeterminism.normalizeTags(
      _tagsController.text.split(','),
    );
    Navigator.of(context).pop(
      PrefabV3OwnerDialogResult(
        id: _isCreating ? _idController.text.trim() : null,
        status: _status,
        kind: _kind,
        visualSource: _kind == PrefabKind.platform
            ? PrefabVisualSource.platformModule(sourceId)
            : PrefabVisualSource.atlasSlice(sourceId),
        anchorXPx: anchorX,
        anchorYPx: anchorY,
        tags: tags,
      ),
    );
  }

  List<String> _sourceIds(PrefabKind kind) {
    final ids = kind == PrefabKind.platform
        ? widget.document.tileData.platformModules
              .map((module) => module.id)
              .toList(growable: false)
        : widget.document.data.slices
              .map((slice) => slice.id)
              .toList(growable: false);
    return ids..sort();
  }

  PrefabV3VisualBounds? get _selectedBounds {
    final sourceId = _sourceId;
    if (sourceId == null) return null;
    if (_kind != PrefabKind.platform) {
      final slice = widget.document.data.slices
          .where((candidate) => candidate.id == sourceId)
          .firstOrNull;
      return slice == null
          ? null
          : PrefabV3VisualBounds(widthPx: slice.width, heightPx: slice.height);
    }
    final module = widget.document.tileData.platformModules
        .where((candidate) => candidate.id == sourceId)
        .firstOrNull;
    return PrefabVisualBoundsResolver.resolvePlatformModule(
      module,
      tileSlicesById: <String, AtlasSliceDef>{
        for (final slice in widget.document.tileData.tileSlices)
          slice.id: slice,
      },
    );
  }

  void _centerAnchorOnSelectedSource() {
    final bounds = _selectedBounds;
    _anchorXController.text = ((bounds?.widthPx ?? 0) ~/ 2).toString();
    _anchorYController.text = ((bounds?.heightPx ?? 0) ~/ 2).toString();
  }
}

List<PrefabKind> _resolveAvailableKinds(
  PrefabV3StagingDocument document,
  PrefabV3Def? prefab,
) {
  final hasAtlas = document.data.slices.isNotEmpty;
  final hasModules = document.tileData.platformModules.isNotEmpty;
  final shapes = prefab?.collisionShapes ?? const <TerrainSourceShapeDef>[];
  final hasCollision = shapes.isNotEmpty;
  final allSolid = shapes.every(
    (shape) => shape.collisionMode == TerrainSourceCollisionMode.solid,
  );
  final allOneWay = shapes.every(
    (shape) => shape.collisionMode == TerrainSourceCollisionMode.oneWay,
  );
  return <PrefabKind>[
    if (hasAtlas && (!hasCollision || allSolid)) PrefabKind.obstacle,
    if (hasModules && (!hasCollision || allOneWay)) PrefabKind.platform,
    if (hasAtlas && !hasCollision) PrefabKind.decoration,
  ];
}

String? _validOwnerId(
  String raw, {
  required PrefabV3StagingDocument document,
  String? exceptPrefabKey,
}) {
  final id = raw.trim();
  if (id.isEmpty || id != raw) return null;
  final folded = id.toLowerCase();
  if (document.data.prefabs.any(
    (prefab) =>
        prefab.prefabKey != exceptPrefabKey &&
        prefab.id.toLowerCase() == folded,
  )) {
    return null;
  }
  return id;
}

String? _integerValidator(String? value) =>
    int.tryParse(value?.trim() ?? '') == null ? 'Enter a whole pixel.' : null;
