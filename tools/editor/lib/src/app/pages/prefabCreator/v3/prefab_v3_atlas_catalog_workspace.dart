import 'package:flutter/material.dart';

import '../../../../domain/authoring_types.dart';
import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/domain/prefab_domain_plugin.dart';
import '../../../../prefabs/domain/prefab_v3_catalog_commit.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../prefabs/store/prefab_determinism.dart';
import '../../../../session/editor_session_controller.dart';
import '../atlas_slicer/atlas_slicer_controller.dart';
import '../atlas_slicer/atlas_slicer_tab.dart';

/// Adapts the retained atlas-slicer UI to typed Prefab-v3 commands.
///
/// Selection and form drafts remain local. Only a validated slice upsert or an
/// explicitly confirmed unreferenced delete crosses the plugin/session seam.
class PrefabV3AtlasCatalogWorkspace extends StatefulWidget {
  const PrefabV3AtlasCatalogWorkspace({
    super.key,
    required this.controller,
    required this.document,
  });

  final EditorSessionController controller;
  final PrefabV3Document document;

  @override
  State<PrefabV3AtlasCatalogWorkspace> createState() =>
      PrefabV3AtlasCatalogWorkspaceState();
}

/// Local-draft contract used by the containing Prefab-v3 workspace shortcuts.
class PrefabV3AtlasCatalogWorkspaceState
    extends State<PrefabV3AtlasCatalogWorkspace> {
  static const double _zoomMin = 0.2;
  static const double _zoomMax = 24;
  static const double _zoomStep = 0.2;

  final AtlasSlicerController _slicer = const AtlasSlicerController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _xController = TextEditingController();
  final TextEditingController _yController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  AtlasSlicerState _atlasState = const AtlasSlicerState();
  String? _selectedPrefabSliceId;
  String? _selectedTileSliceId;
  int _formEpoch = 0;
  bool _syncingDraft = false;
  bool _hasDraftChanges = false;

  bool get hasLocalDraftChanges => _hasDraftChanges;

  @override
  void initState() {
    super.initState();
    for (final controller in _draftControllers) {
      controller.addListener(_markDraftChanged);
    }
    _initialize(widget.document);
  }

  @override
  void didUpdateWidget(covariant PrefabV3AtlasCatalogWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.document, widget.document)) {
      _reconcile(widget.document);
    }
  }

  @override
  void dispose() {
    for (final controller in _draftControllers) {
      controller.removeListener(_markDraftChanged);
      controller.dispose();
    }
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  /// Discards an unsaved slice form/selection edit before session undo.
  bool cancelLocalDraft() {
    if (!_hasDraftChanges) return false;
    setState(() => _syncSelectedDraft(widget.document));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final kind = _atlasState.selectedSliceKind;
    final allSlices = _slicesForKind(document, kind);
    final selectedId = _selectedId(kind);
    final selectedSlice = _findSlice(allSlices, selectedId);
    final selectedPath = _atlasState.selectedAtlasPath;
    final visibleSlices = selectedPath == null
        ? const <AtlasSliceDef>[]
        : allSlices
              .where((slice) => slice.sourceImagePath == selectedPath)
              .toList(growable: false);
    final selection = _slicer.selectionRectInImagePixels(_atlasState);
    final selectionLabel = selection == null
        ? 'Selection: none'
        : 'Selection: x=${selection.left.toInt()} '
              'y=${selection.top.toInt()} '
              'w=${selection.width.toInt()} '
              'h=${selection.height.toInt()}';

    return KeyedSubtree(
      key: ValueKey<String>('prefab_v3_atlas_form_$_formEpoch'),
      child: AtlasSlicerTab(
        atlasImagePaths: document.atlasImagePaths,
        selectedAtlasPath: selectedPath,
        selectedSliceKind: kind,
        sliceIdController: _idController,
        sliceTagsController: _tagsController,
        atlasZoom: _atlasState.zoom,
        zoomMin: _zoomMin,
        zoomMax: _zoomMax,
        zoomStep: _zoomStep,
        selectionLabel: selectionLabel,
        selectionXController: _xController,
        selectionYController: _yController,
        selectionWController: _widthController,
        selectionHController: _heightController,
        atlasSize: selectedPath == null
            ? null
            : document.atlasImageSizes[selectedPath],
        slices: visibleSlices,
        existingSliceIds: allSlices.map((slice) => slice.id).toSet(),
        selectedSliceId: selectedId,
        selectedSlice: selectedSlice,
        workspaceRootPath: widget.controller.workspacePath,
        selectionRectInImagePixels: selection,
        horizontalScrollController: _horizontalScrollController,
        verticalScrollController: _verticalScrollController,
        onSelectedAtlasChanged: (path) => _selectAtlas(document, path),
        onSelectedSliceKindChanged: (nextKind) =>
            _selectKind(document, nextKind),
        onSelectedSliceChanged: (sliceId) =>
            _selectSlice(document, kind, sliceId),
        onAtlasZoomChanged: (zoom) =>
            setState(() => _atlasState = _atlasState.withZoom(zoom)),
        onSelectionInputsChanged: () => _applySelectionInputs(document),
        onSaveSlice: () => _saveSlice(document),
        onDeleteSlice: (sliceId) => _deleteSlice(document, kind, sliceId),
        onSelectionDragStart: (localPosition, imageSize) {
          final start = _slicer.toImagePosition(
            state: _atlasState,
            localPosition: localPosition,
            imageSize: imageSize,
          );
          setState(() {
            _atlasState = _atlasState.withSelection(start, start);
            _syncSelectionInputs(
              _slicer.selectionRectInImagePixels(_atlasState),
            );
            _hasDraftChanges = true;
          });
        },
        onSelectionDragUpdate: (localPosition, imageSize) {
          final current = _slicer.toImagePosition(
            state: _atlasState,
            localPosition: localPosition,
            imageSize: imageSize,
          );
          setState(() {
            final start = _atlasState.selectionStartImagePx ?? current;
            _atlasState = _atlasState.withSelection(start, current);
            _syncSelectionInputs(
              _slicer.selectionRectInImagePixels(_atlasState),
            );
            _hasDraftChanges = true;
          });
        },
      ),
    );
  }

  List<TextEditingController> get _draftControllers => <TextEditingController>[
    _idController,
    _tagsController,
    _xController,
    _yController,
    _widthController,
    _heightController,
  ];

  void _initialize(PrefabV3Document document) {
    _selectedPrefabSliceId = document.data.slices.firstOrNull?.id;
    _selectedTileSliceId = document.tileData.tileSlices.firstOrNull?.id;
    final selected = _findSlice(document.data.slices, _selectedPrefabSliceId);
    final path =
        selected?.sourceImagePath ?? document.atlasImagePaths.firstOrNull;
    _atlasState = AtlasSlicerState(selectedAtlasPath: path);
    _syncSelectedDraft(document);
  }

  void _reconcile(PrefabV3Document document) {
    _selectedPrefabSliceId = _retainedOrFirstId(
      document.data.slices,
      _selectedPrefabSliceId,
    );
    _selectedTileSliceId = _retainedOrFirstId(
      document.tileData.tileSlices,
      _selectedTileSliceId,
    );
    final selected = _findSlice(
      _slicesForKind(document, _atlasState.selectedSliceKind),
      _selectedId(_atlasState.selectedSliceKind),
    );
    final availablePaths = document.atlasImagePaths.toSet();
    final path = selected?.sourceImagePath;
    if (path != null && availablePaths.contains(path)) {
      _atlasState = _atlasState.withSelectedAtlasPath(path);
    } else if (!availablePaths.contains(_atlasState.selectedAtlasPath)) {
      _atlasState = _atlasState.withSelectedAtlasPath(
        document.atlasImagePaths.firstOrNull,
      );
    }
    _syncSelectedDraft(document);
  }

  void _selectAtlas(PrefabV3Document document, String? path) {
    if (!_canNavigateCatalog()) return;
    final slices = _slicesForKind(document, _atlasState.selectedSliceKind);
    final selected = slices
        .where((slice) => slice.sourceImagePath == path)
        .firstOrNull;
    setState(() {
      _atlasState = _atlasState.withSelectedAtlasPath(path);
      _setSelectedId(_atlasState.selectedSliceKind, selected?.id);
      _syncDraft(selected);
    });
  }

  void _selectKind(PrefabV3Document document, AtlasSliceKind kind) {
    if (!_canNavigateCatalog()) return;
    final slices = _slicesForKind(document, kind);
    var selected = _findSlice(slices, _selectedId(kind));
    selected ??= slices.firstOrNull;
    setState(() {
      _setSelectedId(kind, selected?.id);
      _atlasState = _atlasState
          .withSelectedSliceKind(kind)
          .withSelectedAtlasPath(
            selected?.sourceImagePath ?? document.atlasImagePaths.firstOrNull,
          );
      _syncDraft(selected);
    });
  }

  void _selectSlice(
    PrefabV3Document document,
    AtlasSliceKind kind,
    String sliceId,
  ) {
    if (!_canNavigateCatalog()) return;
    final slice = _findSlice(_slicesForKind(document, kind), sliceId);
    if (slice == null) return;
    setState(() {
      _setSelectedId(kind, sliceId);
      _atlasState = _atlasState.withSelectedAtlasPath(slice.sourceImagePath);
      _syncDraft(slice);
    });
  }

  void _applySelectionInputs(PrefabV3Document document) {
    _hasDraftChanges = true;
    final path = _atlasState.selectedAtlasPath;
    final size = path == null ? null : document.atlasImageSizes[path];
    if (size == null) return;
    final result = _slicer.clampedSelectionFromInputs(
      atlasSize: size,
      rawX: _xController.text,
      rawY: _yController.text,
      rawW: _widthController.text,
      rawH: _heightController.text,
    );
    if (result.rect != null) {
      setState(() => _atlasState = _atlasState.withSelectionRect(result.rect!));
    }
  }

  void _saveSlice(PrefabV3Document document) {
    final id = _idController.text;
    if (id.isEmpty || id != id.trim()) {
      _showMessage(
        'Slice ID must be non-empty with no surrounding whitespace.',
      );
      return;
    }
    final path = _atlasState.selectedAtlasPath;
    if (path == null) {
      _showMessage('Select an atlas/tileset image first.');
      return;
    }
    final size = document.atlasImageSizes[path];
    if (size == null) {
      _showMessage('Atlas metadata is unavailable for $path.');
      return;
    }
    final parsed = _slicer.strictSelectionFromInputs(
      atlasSize: size,
      rawX: _xController.text,
      rawY: _yController.text,
      rawW: _widthController.text,
      rawH: _heightController.text,
    );
    if (parsed.error != null) {
      _showMessage(parsed.error!);
      return;
    }
    final rect = parsed.rect ?? _slicer.selectionRectInImagePixels(_atlasState);
    if (rect == null) {
      _showMessage('Define a valid selection before saving the slice.');
      return;
    }
    final slice = AtlasSliceDef(
      id: id,
      sourceImagePath: path,
      x: rect.left.toInt(),
      y: rect.top.toInt(),
      width: rect.width.toInt(),
      height: rect.height.toInt(),
      tags: PrefabDeterminism.normalizeTags(_tagsController.text.split(',')),
    );
    final current = _findSlice(
      _slicesForKind(document, _atlasState.selectedSliceKind),
      id,
    );
    if (current != null && _slicesEqual(current, slice)) {
      setState(() => _hasDraftChanges = false);
      return;
    }
    final next = _dispatch(
      document,
      PrefabV3UpsertSliceOperation(
        kind: _atlasState.selectedSliceKind,
        slice: slice,
      ),
    );
    if (next == null) return;
    setState(() {
      _setSelectedId(_atlasState.selectedSliceKind, id);
      _atlasState = _atlasState.withSelectedAtlasPath(path);
      _syncDraft(slice);
    });
  }

  Future<void> _deleteSlice(
    PrefabV3Document document,
    AtlasSliceKind kind,
    String sliceId,
  ) async {
    if (_hasDraftChanges) {
      _showMessage('Apply or undo the slice form before deleting.');
      return;
    }
    final references = kind == AtlasSliceKind.prefab
        ? document.data.prefabs
              .where(
                (prefab) => prefab.usesAtlasSlice && prefab.sliceId == sliceId,
              )
              .map((prefab) => prefab.id)
              .toList(growable: false)
        : document.tileData.platformModules
              .where(
                (module) => module.cells.any((cell) => cell.sliceId == sliceId),
              )
              .map((module) => module.id)
              .toList(growable: false);
    if (references.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Cannot delete $sliceId'),
          content: Text(
            'Update or remove these references first: '
            '${references.join(', ')}. Automatic cascade is intentionally '
            'not exposed by this current form.',
          ),
          actions: <Widget>[
            FilledButton(
              key: const ValueKey<String>('prefab_v3_slice_delete_blocked'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete slice $sliceId?'),
        content: const Text('This removes the unreferenced retained slice.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey<String>('prefab_v3_slice_delete_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete slice'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final next = _dispatch(
      document,
      PrefabV3DeleteSliceOperation(kind: kind, sliceId: sliceId),
    );
    if (next == null) return;
    setState(() {
      final slices = _slicesForKind(next, kind);
      final selected = slices
          .where(
            (slice) => slice.sourceImagePath == _atlasState.selectedAtlasPath,
          )
          .firstOrNull;
      _setSelectedId(kind, selected?.id);
      _syncDraft(selected);
    });
  }

  PrefabV3Document? _dispatch(
    PrefabV3Document document,
    PrefabV3CatalogOperation operation,
  ) {
    final beforeDocument = widget.controller.document;
    widget.controller.applyCommand(
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabV3CatalogCommandKind,
        payload: <String, Object?>{
          'commit': PrefabV3CatalogCommit(
            before: PrefabV3CatalogSnapshot.fromDocument(document),
            operation: operation,
          ),
        },
      ),
    );
    final next = widget.controller.document;
    if (identical(next, beforeDocument) || next is! PrefabV3Document) {
      _showMessage(
        'Slice change was rejected. Review validation diagnostics and retry '
        'from the current catalog state.',
      );
      return null;
    }
    return next;
  }

  void _syncSelectedDraft(PrefabV3Document document) {
    _syncDraft(
      _findSlice(
        _slicesForKind(document, _atlasState.selectedSliceKind),
        _selectedId(_atlasState.selectedSliceKind),
      ),
    );
  }

  void _syncDraft(AtlasSliceDef? slice) {
    _syncingDraft = true;
    try {
      _idController.text = slice?.id ?? '';
      _tagsController.text = slice?.tags.join(', ') ?? '';
      final rect = slice == null
          ? null
          : Rect.fromLTWH(
              slice.x.toDouble(),
              slice.y.toDouble(),
              slice.width.toDouble(),
              slice.height.toDouble(),
            );
      _atlasState = rect == null
          ? _atlasState.clearedSelection()
          : _atlasState.withSelectionRect(rect);
      _syncSelectionInputs(rect);
      _hasDraftChanges = false;
    } finally {
      _syncingDraft = false;
    }
  }

  void _syncSelectionInputs(Rect? rect) {
    _syncingDraft = true;
    try {
      _xController.text = rect?.left.toInt().toString() ?? '';
      _yController.text = rect?.top.toInt().toString() ?? '';
      _widthController.text = rect?.width.toInt().toString() ?? '';
      _heightController.text = rect?.height.toInt().toString() ?? '';
    } finally {
      _syncingDraft = false;
    }
  }

  void _markDraftChanged() {
    if (_syncingDraft || _hasDraftChanges) return;
    setState(() => _hasDraftChanges = true);
  }

  bool _canNavigateCatalog() {
    if (!_hasDraftChanges) return true;
    setState(() => _formEpoch += 1);
    _showMessage('Apply or undo the slice form before changing selection.');
    return false;
  }

  String? _selectedId(AtlasSliceKind kind) => switch (kind) {
    AtlasSliceKind.prefab => _selectedPrefabSliceId,
    AtlasSliceKind.tile => _selectedTileSliceId,
  };

  void _setSelectedId(AtlasSliceKind kind, String? id) {
    switch (kind) {
      case AtlasSliceKind.prefab:
        _selectedPrefabSliceId = id;
      case AtlasSliceKind.tile:
        _selectedTileSliceId = id;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

List<AtlasSliceDef> _slicesForKind(
  PrefabV3Document document,
  AtlasSliceKind kind,
) => switch (kind) {
  AtlasSliceKind.prefab => document.data.slices,
  AtlasSliceKind.tile => document.tileData.tileSlices,
};

AtlasSliceDef? _findSlice(Iterable<AtlasSliceDef> slices, String? id) {
  if (id == null) return null;
  for (final slice in slices) {
    if (slice.id == id) return slice;
  }
  return null;
}

String? _retainedOrFirstId(Iterable<AtlasSliceDef> slices, String? currentId) {
  if (currentId != null && slices.any((slice) => slice.id == currentId)) {
    return currentId;
  }
  return slices.firstOrNull?.id;
}

bool _slicesEqual(AtlasSliceDef left, AtlasSliceDef right) =>
    left.id == right.id &&
    left.sourceImagePath == right.sourceImagePath &&
    left.x == right.x &&
    left.y == right.y &&
    left.width == right.width &&
    left.height == right.height &&
    _stringListsEqual(left.tags, right.tags);

bool _stringListsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
