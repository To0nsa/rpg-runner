import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../atlas/atlas_grid.dart';
import '../../../../atlas/atlas_grid_settings_cache.dart';
import '../../../../atlas/atlas_pixel_rect.dart';
import '../../../../atlas/atlas_selection.dart';
import '../../../../domain/authoring_types.dart';
import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/domain/prefab_domain_plugin.dart';
import '../../../../prefabs/domain/prefab_slice_id_convention.dart';
import '../../../../prefabs/domain/prefab_v3_catalog_commit.dart';
import '../../../../prefabs/models/models.dart';
import '../../../../prefabs/store/prefab_determinism.dart';
import '../../../../session/editor_session_controller.dart';
import '../../../../workspace/editor_workspace.dart';
import '../atlas_slicer/atlas_image_file_picker.dart';
import '../atlas_slicer/atlas_slicer_tab.dart';

typedef _AtlasSliceDraft = ({
  String id,
  String tags,
  String x,
  String y,
  String width,
  String height,
  bool createPrefabAutomatically,
  PrefabKind correspondingPrefabKind,
});

/// Adapts the retained atlas-slicer UI to typed Prefab-v3 commands.
///
/// Selection and form drafts remain local. Only a validated slice upsert or an
/// explicitly confirmed unreferenced delete crosses the plugin/session seam.
class PrefabV3AtlasCatalogWorkspace extends StatefulWidget {
  const PrefabV3AtlasCatalogWorkspace({
    super.key,
    required this.controller,
    required this.document,
    required this.atlasImageFilePicker,
    required this.onPrefabCreated,
  });

  final EditorSessionController controller;
  final PrefabV3Document document;
  final AtlasImageFilePicker atlasImageFilePicker;
  final ValueChanged<PrefabV3Def> onPrefabCreated;

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

  final AtlasGridSettingsCache _gridSettingsCache = AtlasGridSettingsCache();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _xController = TextEditingController();
  final TextEditingController _yController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  AtlasSelectionState _atlasState = const AtlasSelectionState();
  AtlasSliceKind _selectedSliceKind = AtlasSliceKind.prefab;
  bool _createPrefabAutomatically = false;
  PrefabKind _correspondingPrefabKind = PrefabKind.decoration;
  bool _autoSliceEnabled = false;
  String? _selectedPrefabSliceId;
  String? _selectedTileSliceId;
  int _formEpoch = 0;
  int _draftSyncDepth = 0;
  _AtlasSliceDraft? _draftBaseline;
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
    final kind = _selectedSliceKind;
    final allSlices = _slicesForKind(document, kind);
    final selectedId = _selectedId(kind);
    final selectedSlice = _findSlice(allSlices, selectedId);
    final selectedPath = _atlasState.selectedSourcePath;
    final visibleSlices = selectedPath == null
        ? const <AtlasSliceDef>[]
        : allSlices
              .where((slice) => slice.sourceImagePath == selectedPath)
              .toList(growable: false);
    final selection = _atlasState.selectionRect;
    final selectionLabel = selection == null
        ? 'Selection: none'
        : 'Selection: x=${selection.x} '
              'y=${selection.y} '
              'w=${selection.width} '
              'h=${selection.height}';

    return KeyedSubtree(
      key: ValueKey<String>('prefab_v3_atlas_form_$_formEpoch'),
      child: AtlasSlicerTab(
        selectedAtlasPath: selectedPath,
        selectedSliceKind: kind,
        sliceIdController: _idController,
        sliceTagsController: _tagsController,
        sliceIdValidationMessage: (id) =>
            _sliceIdValidationMessage(document, id),
        createPrefabAutomatically: _createPrefabAutomatically,
        correspondingPrefabKind: _correspondingPrefabKind,
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
        autoSliceEnabled: _autoSliceEnabled,
        gridSettings: selectedPath == null
            ? const AtlasGridSettings()
            : _gridSettingsCache.settingsFor(selectedPath),
        horizontalScrollController: _horizontalScrollController,
        verticalScrollController: _verticalScrollController,
        onBrowseAtlasSource: () => unawaited(_pickAtlasSource(document)),
        onSelectedSliceKindChanged: (nextKind) =>
            _selectKind(document, nextKind),
        onSelectedSliceChanged: (sliceId) =>
            _selectSlice(document, kind, sliceId),
        onCreatePrefabAutomaticallyChanged: _setCreatePrefabAutomatically,
        onCorrespondingPrefabKindChanged: _setCorrespondingPrefabKind,
        onAtlasZoomChanged: (zoom) =>
            setState(() => _atlasState = _atlasState.withZoom(zoom)),
        onSelectionInputsChanged: () => _applySelectionInputs(document),
        onAutoSliceEnabledChanged: (enabled) =>
            setState(() => _autoSliceEnabled = enabled),
        onGridSettingsChanged: (settings) {
          final path = _atlasState.selectedSourcePath;
          if (path == null) return;
          setState(() => _gridSettingsCache.setSettings(path, settings));
        },
        onSaveSlice: () => _saveSlice(document),
        onDeleteSlice: (sliceId) => _deleteSlice(document, kind, sliceId),
        hasLocalDraftChanges: _hasDraftChanges,
        onSelectionChanged: (rect) {
          setState(() {
            _atlasState = _atlasState.withRect(rect);
            _syncSelectionInputs(rect);
            _hasDraftChanges = _currentDraft != _draftBaseline;
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

  _AtlasSliceDraft get _currentDraft => (
    id: _idController.text,
    tags: _tagsController.text,
    x: _xController.text,
    y: _yController.text,
    width: _widthController.text,
    height: _heightController.text,
    createPrefabAutomatically: _createPrefabAutomatically,
    correspondingPrefabKind: _correspondingPrefabKind,
  );

  void _initialize(PrefabV3Document document) {
    _gridSettingsCache.ensureWorkspace(widget.controller.workspacePath);
    _atlasState = AtlasSelectionState(
      selectedSourcePath: document.atlasImagePaths.firstOrNull,
    );
    _syncSelectedDraft(document);
  }

  void _reconcile(PrefabV3Document document) {
    _selectedPrefabSliceId = _retainedId(
      document.data.slices,
      _selectedPrefabSliceId,
    );
    _selectedTileSliceId = _retainedId(
      document.tileData.tileSlices,
      _selectedTileSliceId,
    );
    final selected = _findSlice(
      _slicesForKind(document, _selectedSliceKind),
      _selectedId(_selectedSliceKind),
    );
    final availablePaths = document.atlasImagePaths.toSet();
    final path = selected?.sourceImagePath;
    if (path != null && availablePaths.contains(path)) {
      _atlasState = _atlasState.withSelectedSourcePath(path);
    } else if (!availablePaths.contains(_atlasState.selectedSourcePath)) {
      _atlasState = _atlasState.withSelectedSourcePath(
        document.atlasImagePaths.firstOrNull,
      );
    }
    _syncSelectedDraft(document);
  }

  void _selectAtlas(String? path) {
    if (!_canNavigateCatalog()) return;
    if (path == _atlasState.selectedSourcePath) return;
    setState(() {
      _atlasState = _atlasState.withSelectedSourcePath(path);
      _setSelectedId(_selectedSliceKind, null);
      _syncDraft(null);
    });
  }

  Future<void> _pickAtlasSource(PrefabV3Document document) async {
    String? selectedPath;
    try {
      selectedPath = await widget.atlasImageFilePicker(
        initialDirectory: _atlasPickerInitialDirectory(document),
      );
    } catch (_) {
      if (mounted) {
        _showMessage('Could not open the atlas source selector.');
      }
      return;
    }
    if (!mounted || selectedPath == null) return;

    final catalogPath = _catalogPathForAbsoluteSelection(
      document,
      selectedPath,
    );
    if (catalogPath == null) {
      _showMessage('Choose a PNG from the current prefab atlas catalog.');
      return;
    }
    _selectAtlas(catalogPath);
  }

  String _atlasPickerInitialDirectory(PrefabV3Document document) {
    final workspace = EditorWorkspace(
      rootPath: widget.controller.workspacePath,
    );
    final sourcePath =
        _atlasState.selectedSourcePath ?? document.atlasImagePaths.firstOrNull;
    if (sourcePath != null) {
      try {
        final parent = File(workspace.resolve(sourcePath)).parent;
        if (parent.existsSync()) return parent.path;
      } on ArgumentError {
        // A stale catalog path falls back to the workspace root.
      }
    }
    return workspace.rootPath;
  }

  String? _catalogPathForAbsoluteSelection(
    PrefabV3Document document,
    String selectedPath,
  ) {
    final absoluteSelection = p.normalize(p.absolute(selectedPath));
    if (!File(absoluteSelection).existsSync()) return null;
    final workspace = EditorWorkspace(
      rootPath: widget.controller.workspacePath,
    );
    for (final catalogPath in document.atlasImagePaths) {
      try {
        if (p.equals(workspace.resolve(catalogPath), absoluteSelection)) {
          return catalogPath;
        }
      } on ArgumentError {
        // Ignore stale catalog entries that no longer resolve in the workspace.
      }
    }
    return null;
  }

  void _selectKind(PrefabV3Document document, AtlasSliceKind kind) {
    if (!_canNavigateCatalog()) return;
    final slices = _slicesForKind(document, kind);
    final selected = _findSlice(slices, _selectedId(kind));
    setState(() {
      _setSelectedId(kind, selected?.id);
      _selectedSliceKind = kind;
      _atlasState = _atlasState.withSelectedSourcePath(
        selected?.sourceImagePath ??
            _atlasState.selectedSourcePath ??
            document.atlasImagePaths.firstOrNull,
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
      _atlasState = _atlasState.withSelectedSourcePath(slice.sourceImagePath);
      _syncDraft(slice);
    });
  }

  void _applySelectionInputs(PrefabV3Document document) {
    _refreshDraftChanged();
    final path = _atlasState.selectedSourcePath;
    final size = path == null ? null : document.atlasImageSizes[path];
    if (size == null) return;
    final result = parseAtlasPixelRect(
      rawX: _xController.text,
      rawY: _yController.text,
      rawWidth: _widthController.text,
      rawHeight: _heightController.text,
      imageWidth: size.width.toInt(),
      imageHeight: size.height.toInt(),
    );
    if (result.rect != null) {
      setState(() => _atlasState = _atlasState.withRect(result.rect!));
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
    final path = _atlasState.selectedSourcePath;
    if (path == null) {
      _showMessage('Select an atlas/tileset image first.');
      return;
    }
    final current = _findSlice(
      _slicesForKind(document, _selectedSliceKind),
      id,
    );
    if (_selectedSliceKind == AtlasSliceKind.prefab && current == null) {
      final namingIssue = PrefabSliceIdConvention.validate(
        id: id,
        sourceImagePath: path,
      );
      if (namingIssue != null) {
        _showMessage(namingIssue);
        return;
      }
    }
    final size = document.atlasImageSizes[path];
    if (size == null) {
      _showMessage('Atlas metadata is unavailable for $path.');
      return;
    }
    final parsed = parseAtlasPixelRect(
      rawX: _xController.text,
      rawY: _yController.text,
      rawWidth: _widthController.text,
      rawHeight: _heightController.text,
      imageWidth: size.width.toInt(),
      imageHeight: size.height.toInt(),
    );
    if (parsed.error != null) {
      _showMessage(parsed.error!);
      return;
    }
    final rect = parsed.rect ?? _atlasState.selectionRect;
    if (rect == null) {
      _showMessage('Define a valid selection before saving the slice.');
      return;
    }
    final slice = AtlasSliceDef(
      id: id,
      sourceImagePath: path,
      x: rect.x,
      y: rect.y,
      width: rect.width,
      height: rect.height,
      tags: PrefabDeterminism.normalizeTags(<String>[
        ..._tagsController.text.split(','),
        ..._atlasSourceTags(path),
      ]),
    );
    if (_createPrefabAutomatically &&
        _selectedSliceKind != AtlasSliceKind.prefab) {
      _showMessage('Automatic prefab creation requires a Prefab Slice.');
      return;
    }
    if (_createPrefabAutomatically && current != null) {
      _showMessage(
        'Automatic prefab creation is available only for a new slice. '
        'Choose a new Slice ID or turn it off.',
      );
      return;
    }
    if (_createPrefabAutomatically &&
        document.data.prefabs.any(
          (prefab) => prefab.id.toLowerCase() == id.toLowerCase(),
        )) {
      _showMessage(
        'Prefab ID "$id" already exists. Choose another Slice ID or turn '
        'off automatic prefab creation.',
      );
      return;
    }
    if (current != null && _slicesEqual(current, slice)) {
      setState(() {
        _draftBaseline = _currentDraft;
        _hasDraftChanges = false;
      });
      return;
    }
    final next = _dispatch(
      document,
      PrefabV3UpsertSliceOperation(
        kind: _selectedSliceKind,
        slice: slice,
        createPrefabKind: _createPrefabAutomatically
            ? _correspondingPrefabKind
            : null,
      ),
    );
    if (next == null) return;
    final createdPrefab = _createPrefabAutomatically
        ? next.data.prefabs.where((prefab) => prefab.id == id).firstOrNull
        : null;
    setState(() {
      _setSelectedId(_selectedSliceKind, id);
      _atlasState = _atlasState.withSelectedSourcePath(path);
      _syncDraft(slice);
    });
    if (createdPrefab != null) widget.onPrefabCreated(createdPrefab);
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
      final selected = _findSlice(
        slices,
        _retainedId(slices, _selectedId(kind)),
      );
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
        _slicesForKind(document, _selectedSliceKind),
        _selectedId(_selectedSliceKind),
      ),
    );
  }

  void _syncDraft(AtlasSliceDef? slice) {
    _runDraftSync(() {
      _createPrefabAutomatically = false;
      _correspondingPrefabKind = PrefabKind.decoration;
      _idController.text =
          slice?.id ??
          PrefabSliceIdConvention.collectionPrefix(
            _atlasState.selectedSourcePath,
          );
      _tagsController.text = slice == null
          ? _atlasSourceTags(_atlasState.selectedSourcePath).join(', ')
          : slice.tags.join(', ');
      final rect = slice == null
          ? null
          : AtlasPixelRect(
              x: slice.x,
              y: slice.y,
              width: slice.width,
              height: slice.height,
            );
      _atlasState = rect == null
          ? _atlasState.clearedSelection()
          : _atlasState.withRect(rect);
      _syncSelectionInputs(rect);
      _draftBaseline = _currentDraft;
      _hasDraftChanges = false;
    });
  }

  List<String> _atlasSourceTags(String? sourcePath) {
    if (sourcePath == null) return const <String>[];
    final normalizedPath = p.normalize(sourcePath.trim());
    if (normalizedPath.isEmpty || normalizedPath == '.') {
      return const <String>[];
    }
    final parentPath = p.dirname(normalizedPath);
    return PrefabDeterminism.normalizeTags(<String>[
      if (parentPath != '.') p.basename(parentPath),
      p.basenameWithoutExtension(normalizedPath),
    ]);
  }

  String? _sliceIdValidationMessage(PrefabV3Document document, String id) {
    if (_selectedSliceKind != AtlasSliceKind.prefab) return null;
    if (_findSlice(document.data.slices, id) != null) return null;
    final path = _atlasState.selectedSourcePath;
    if (path == null) return null;
    final prefix = PrefabSliceIdConvention.collectionPrefix(path);
    if (id.isEmpty || id == prefix) return null;
    return PrefabSliceIdConvention.validate(id: id, sourceImagePath: path);
  }

  void _setCreatePrefabAutomatically(bool value) {
    setState(() {
      _createPrefabAutomatically = value;
      _hasDraftChanges = _currentDraft != _draftBaseline;
    });
  }

  void _setCorrespondingPrefabKind(PrefabKind value) {
    if (value != PrefabKind.decoration && value != PrefabKind.obstacle) return;
    setState(() {
      _correspondingPrefabKind = value;
      _hasDraftChanges = _currentDraft != _draftBaseline;
    });
  }

  void _syncSelectionInputs(AtlasPixelRect? rect) {
    _runDraftSync(() {
      _xController.text = rect?.x.toString() ?? '';
      _yController.text = rect?.y.toString() ?? '';
      _widthController.text = rect?.width.toString() ?? '';
      _heightController.text = rect?.height.toString() ?? '';
    });
  }

  void _runDraftSync(VoidCallback action) {
    _draftSyncDepth += 1;
    try {
      action();
    } finally {
      _draftSyncDepth -= 1;
    }
  }

  void _markDraftChanged() {
    _refreshDraftChanged();
  }

  void _refreshDraftChanged() {
    if (_draftSyncDepth > 0) return;
    final hasChanges = _currentDraft != _draftBaseline;
    if (hasChanges == _hasDraftChanges) return;
    setState(() => _hasDraftChanges = hasChanges);
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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

String? _retainedId(Iterable<AtlasSliceDef> slices, String? currentId) {
  if (currentId != null && slices.any((slice) => slice.id == currentId)) {
    return currentId;
  }
  return null;
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
