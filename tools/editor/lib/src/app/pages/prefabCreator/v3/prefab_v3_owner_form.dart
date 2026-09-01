import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/domain/prefab_visual_bounds_resolver.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../prefabs/store/prefab_determinism.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';
import '../shared/ui/prefab_editor_atlas_slice_selector.dart';

/// Validated fields owned by Prefab-v3 creation or metadata editing.
///
/// Collision geometry and stable identity are absent. [id] is populated only
/// for creation so an existing-owner metadata command cannot rename its owner.
@immutable
final class PrefabV3OwnerFormValue {
  const PrefabV3OwnerFormValue({
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

typedef PrefabV3OwnerFormSubmit = FutureOr<bool> Function(
  PrefabV3OwnerFormValue value,
);

/// Reusable Prefab-v3 owner form for inline editing and retained creation.
///
/// Field changes remain local until [onSubmit] accepts the validated value.
/// [onDirtyChanged] reports divergence from the captured initial fields so the
/// containing workspace can protect navigation and source application.
class PrefabV3OwnerForm extends StatefulWidget {
  const PrefabV3OwnerForm({
    super.key,
    required this.document,
    required this.workspaceRootPath,
    required this.onSubmit,
    required this.onCancel,
    required this.submitLabel,
    required this.submitKey,
    this.prefab,
    this.cancelKey,
    this.onDirtyChanged,
    this.autofocusId = false,
  });

  final PrefabV3Document document;

  /// Repository root used only to decode visual-source thumbnails.
  final String workspaceRootPath;
  final PrefabV3Def? prefab;
  final PrefabV3OwnerFormSubmit onSubmit;
  final VoidCallback onCancel;
  final String submitLabel;
  final Key submitKey;
  final Key? cancelKey;
  final ValueChanged<bool>? onDirtyChanged;
  final bool autofocusId;

  @override
  State<PrefabV3OwnerForm> createState() => PrefabV3OwnerFormState();
}

/// Submission handle used by a parent when navigation requests Save.
class PrefabV3OwnerFormState extends State<PrefabV3OwnerForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _anchorXController;
  late final TextEditingController _anchorYController;
  late final TextEditingController _tagsController;
  late final List<PrefabKind> _availableKinds;
  late final PrefabStatus _initialStatus;
  late final PrefabKind _initialKind;
  late final String? _initialSourceId;
  late final String _initialId;
  late final String _initialAnchorX;
  late final String _initialAnchorY;
  late final String _initialTags;
  late PrefabStatus _status;
  late PrefabKind _kind;
  String? _sourceId;
  String? _submissionError;
  bool _reportedDirty = false;

  bool get _isCreating => widget.prefab == null;

  bool get isDirty =>
      _idController.text != _initialId ||
      _status != _initialStatus ||
      _kind != _initialKind ||
      _sourceId != _initialSourceId ||
      _anchorXController.text != _initialAnchorX ||
      _anchorYController.text != _initialAnchorY ||
      _tagsController.text != _initialTags;

  @override
  void initState() {
    super.initState();
    final current = widget.prefab;
    _availableKinds = _resolveAvailableKinds(widget.document, current);
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
    _initialStatus = _status;
    _initialKind = _kind;
    _initialSourceId = _sourceId;
    _initialId = _idController.text;
    _initialAnchorX = _anchorXController.text;
    _initialAnchorY = _anchorYController.text;
    _initialTags = _tagsController.text;
    for (final controller in _controllers) {
      controller.addListener(_handleFieldChanged);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller
        ..removeListener(_handleFieldChanged)
        ..dispose();
    }
    super.dispose();
  }

  /// Validates and submits the current local fields.
  ///
  /// Returns false without closing when validation or the captured optimistic
  /// command is rejected.
  Future<bool> submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    final sourceId = _sourceId;
    final bounds = _selectedBounds;
    final anchorX = int.parse(_anchorXController.text.trim());
    final anchorY = int.parse(_anchorYController.text.trim());
    if (sourceId == null || bounds == null) {
      setState(
        () => _submissionError = 'The visual source has no valid bounds.',
      );
      return false;
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
      return false;
    }
    final accepted = await widget.onSubmit(
      PrefabV3OwnerFormValue(
        id: _isCreating ? _idController.text.trim() : null,
        status: _status,
        kind: _kind,
        visualSource: _kind == PrefabKind.platform
            ? PrefabVisualSource.platformModule(sourceId)
            : PrefabVisualSource.atlasSlice(sourceId),
        anchorXPx: anchorX,
        anchorYPx: anchorY,
        tags: PrefabDeterminism.normalizeTags(_tagsController.text.split(',')),
      ),
    );
    if (!accepted && mounted) {
      setState(() {
        _submissionError =
            'The prefab changed or the metadata was rejected. Review the '
            'current diagnostics and retry without closing this draft.';
      });
    }
    return accepted;
  }

  @override
  Widget build(BuildContext context) {
    final sourceIds = _sourceIds(_kind);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_isCreating) ...<Widget>[
            TextFormField(
              key: const ValueKey<String>('prefab_v3_owner_id_field'),
              controller: _idController,
              autofocus: widget.autofocusId,
              decoration: const InputDecoration(labelText: 'Human ID'),
              validator: (value) => validatePrefabV3OwnerId(
                value ?? '',
                document: widget.document,
              ),
            ),
            const SizedBox(height: 12),
          ] else ...<Widget>[
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
                if (value == null || value == _status) return;
                setState(() {
                  _status = value;
                  _submissionError = null;
                });
                _reportDirty();
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
              _reportDirty();
            },
          ),
          const SizedBox(height: 12),
          if (_kind == PrefabKind.platform)
            DropdownButtonFormField<String>(
              key: ValueKey<String>(
                'prefab_v3_owner_source_${_kind.name}_$_sourceId',
              ),
              initialValue: _sourceId,
              decoration: const InputDecoration(labelText: 'Platform module'),
              items: sourceIds
                  .map(
                    (id) =>
                        DropdownMenuItem<String>(value: id, child: Text(id)),
                  )
                  .toList(growable: false),
              onChanged: _selectSource,
              validator: (value) =>
                  value == null ? 'Choose a visual source.' : null,
            )
          else
            PrefabEditorAtlasSliceSelector(
              slices: widget.document.data.slices,
              selectedSliceId: _sourceId,
              onSelectedSliceChanged: _selectSource,
              workspaceRootPath: widget.workspaceRootPath,
              labelText: 'Search atlas slices',
              hintText: 'Slice ID, atlas, dimensions, tags, or prefab owner',
              emptyStateMessage:
                  'Create an atlas slice before creating this owner.',
              defaultScopeTags: <String>[_kind.jsonValue],
              fieldKey: const ValueKey<String>(
                'prefab_v3_owner_atlas_slice_search',
              ),
              optionKeyPrefix: 'prefab_v3_owner_atlas_slice',
              optionPreviewKeyPrefix: 'prefab_v3_owner_atlas_slice_preview',
              presentation:
                  PrefabEditorAtlasSliceSelectorPresentation.visualCatalog,
              prefabOwnerIdsBySliceId: _prefabOwnerIdsBySliceId,
              showUsageFilters: true,
              gridHeight: 310,
            ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  key: const ValueKey<String>('prefab_v3_owner_anchor_x_field'),
                  controller: _anchorXController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Anchor X (px)'),
                  validator: _integerValidator,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: const ValueKey<String>('prefab_v3_owner_anchor_y_field'),
                  controller: _anchorYController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Anchor Y (px)'),
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
              helperText: 'Comma-separated; saved uniquely in lexical order.',
            ),
          ),
          if (_submissionError != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _submissionError!,
              key: const ValueKey<String>('prefab_v3_owner_form_error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (widget.prefab?.collisionShapes.isNotEmpty ?? false) ...<Widget>[
            const SizedBox(height: 12),
            const Text(
              'Kind choices are restricted by the committed polygon collision '
              'modes. Edit shape metadata first to change between obstacle and '
              'platform ownership.',
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              TextButton(
                key: widget.cancelKey,
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: widget.submitKey,
                onPressed: submit,
                child: Text(widget.submitLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<TextEditingController> get _controllers => <TextEditingController>[
    _idController,
    _anchorXController,
    _anchorYController,
    _tagsController,
  ];

  void _handleFieldChanged() {
    if (_submissionError != null && mounted) {
      setState(() => _submissionError = null);
    }
    _reportDirty();
  }

  void _reportDirty() {
    final dirty = isDirty;
    if (dirty == _reportedDirty) return;
    _reportedDirty = dirty;
    widget.onDirtyChanged?.call(dirty);
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

  Map<String, List<String>> get _prefabOwnerIdsBySliceId {
    final ownerIdsBySliceId = <String, List<String>>{};
    for (final prefab in widget.document.data.prefabs) {
      if (!prefab.usesAtlasSlice) continue;
      ownerIdsBySliceId
          .putIfAbsent(prefab.sliceId, () => <String>[])
          .add(prefab.id);
    }
    for (final ownerIds in ownerIdsBySliceId.values) {
      ownerIds.sort();
    }
    return ownerIdsBySliceId;
  }

  void _selectSource(String? value) {
    if (value == null || value == _sourceId) return;
    setState(() {
      _sourceId = value;
      _centerAnchorOnSelectedSource();
      _submissionError = null;
    });
    _reportDirty();
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
  PrefabV3Document document,
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
  final kinds = <PrefabKind>[
    if (hasAtlas && (!hasCollision || allSolid)) PrefabKind.obstacle,
    if (hasModules && (!hasCollision || allOneWay)) PrefabKind.platform,
    if (hasAtlas && !hasCollision) PrefabKind.decoration,
  ];
  if (kinds.isNotEmpty) return kinds;
  return <PrefabKind>[prefab?.kind ?? PrefabKind.decoration];
}

/// Returns the user-facing Prefab-v3 owner ID validation error, if any.
String? validatePrefabV3OwnerId(
  String raw, {
  required PrefabV3Document document,
  String? exceptPrefabKey,
}) {
  final id = raw.trim();
  if (id.isEmpty || id != raw) return 'Enter a unique trimmed ID.';
  final folded = id.toLowerCase();
  if (document.data.prefabs.any(
    (prefab) =>
        prefab.prefabKey != exceptPrefabKey &&
        prefab.id.toLowerCase() == folded,
  )) {
    return 'Enter a unique trimmed ID.';
  }
  return null;
}

String? _integerValidator(String? value) =>
    int.tryParse(value?.trim() ?? '') == null ? 'Enter a whole pixel.' : null;
