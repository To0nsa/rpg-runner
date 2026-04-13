import 'package:flutter/material.dart';

import '../../../../prefabs/atlas/workspace_scoped_size_cache.dart';
import '../../../../prefabs/models/models.dart';
import '../shared/prefab_editor_page_contracts.dart';
import '../shared/prefab_editor_shell_state.dart';
import 'atlas_slicer_controller.dart';
import 'atlas_slicer_tab.dart';

/// Page-shell wiring for the atlas slicer workflow.
///
/// The page still owns app/session state, but this coordinator keeps atlas tab
/// widget composition and local selection/slice interactions out of the main
/// shell file.
class AtlasSlicerPageCoordinator {
  const AtlasSlicerPageCoordinator({
    required AtlasSlicerController atlasSlicer,
    required PrefabEditorShellState shellState,
    required WorkspaceScopedSizeCache atlasImageSizes,
    required void Function(String? previousSelectedSliceId)
    syncPrefabIdsWithSelectedSlice,
    required TextEditingController sliceIdController,
    required TextEditingController sliceTagsController,
    required TextEditingController selectionXController,
    required TextEditingController selectionYController,
    required TextEditingController selectionWController,
    required TextEditingController selectionHController,
    required ScrollController horizontalScrollController,
    required ScrollController verticalScrollController,
    required String Function() readWorkspaceRootPath,
    required PrefabEditorStateSetter updateState,
  }) : _atlasSlicer = atlasSlicer,
       _shellState = shellState,
       _atlasImageSizes = atlasImageSizes,
       _syncPrefabIdsWithSelectedSlice = syncPrefabIdsWithSelectedSlice,
       _sliceIdController = sliceIdController,
       _sliceTagsController = sliceTagsController,
       _selectionXController = selectionXController,
       _selectionYController = selectionYController,
       _selectionWController = selectionWController,
       _selectionHController = selectionHController,
       _horizontalScrollController = horizontalScrollController,
       _verticalScrollController = verticalScrollController,
       _readWorkspaceRootPath = readWorkspaceRootPath,
       _updateState = updateState;

  final AtlasSlicerController _atlasSlicer;
  final PrefabEditorShellState _shellState;
  final WorkspaceScopedSizeCache _atlasImageSizes;
  final void Function(String? previousSelectedSliceId)
  _syncPrefabIdsWithSelectedSlice;
  final TextEditingController _sliceIdController;
  final TextEditingController _sliceTagsController;
  final TextEditingController _selectionXController;
  final TextEditingController _selectionYController;
  final TextEditingController _selectionWController;
  final TextEditingController _selectionHController;
  final ScrollController _horizontalScrollController;
  final ScrollController _verticalScrollController;
  final String Function() _readWorkspaceRootPath;
  final PrefabEditorStateSetter _updateState;

  Widget buildTab({
    required double zoomMin,
    required double zoomMax,
    required double zoomStep,
  }) {
    final atlasState = _shellState.atlasState;
    final selectionRect = selectionRectInImagePixels();
    final selectionLabel = selectionRect == null
        ? 'Selection: none'
        : 'Selection: x=${selectionRect.left.toInt()} '
              'y=${selectionRect.top.toInt()} '
              'w=${selectionRect.width.toInt()} '
              'h=${selectionRect.height.toInt()}';
    final selectedAtlasPath = atlasState.selectedAtlasPath;
    final atlasSize = selectedAtlasPath == null
        ? null
        : _atlasImageSizes[selectedAtlasPath];
    final slicesForKind = _atlasSlicer.slicesForKind(
      _shellState.data,
      atlasState.selectedSliceKind,
    );
    final filteredSlices = _atlasSlicer.slicesForKindAndSource(
      data: _shellState.data,
      kind: atlasState.selectedSliceKind,
      sourceImagePath: selectedAtlasPath,
    );
    final selectedSliceId = _selectedSliceIdForKind(
      atlasState.selectedSliceKind,
    );
    final selectedSlice = _atlasSlicer.findSliceById(
      data: _shellState.data,
      kind: atlasState.selectedSliceKind,
      sliceId: selectedSliceId,
    );

    return AtlasSlicerTab(
      atlasImagePaths: _shellState.atlasImagePaths,
      selectedAtlasPath: selectedAtlasPath,
      selectedSliceKind: atlasState.selectedSliceKind,
      sliceIdController: _sliceIdController,
      sliceTagsController: _sliceTagsController,
      atlasZoom: atlasState.zoom,
      zoomMin: zoomMin,
      zoomMax: zoomMax,
      zoomStep: zoomStep,
      selectionLabel: selectionLabel,
      selectionXController: _selectionXController,
      selectionYController: _selectionYController,
      selectionWController: _selectionWController,
      selectionHController: _selectionHController,
      atlasSize: atlasSize,
      slices: filteredSlices,
      existingSliceIds: slicesForKind.map((slice) => slice.id).toSet(),
      selectedSliceId: selectedSliceId,
      selectedSlice: selectedSlice,
      workspaceRootPath: _readWorkspaceRootPath(),
      selectionRectInImagePixels: selectionRect,
      horizontalScrollController: _horizontalScrollController,
      verticalScrollController: _verticalScrollController,
      onSelectedAtlasChanged: (value) {
        _updateState(() {
          _shellState.atlasState = _shellState.atlasState.withSelectedAtlasPath(
            value,
          );
          clearSelection();
        });
      },
      onSelectedSliceKindChanged: (value) {
        _updateState(() {
          _shellState.atlasState = _shellState.atlasState.withSelectedSliceKind(
            value,
          );
          _syncSliceDraftForCurrentKind(clearIfMissing: true);
        });
      },
      onAtlasZoomChanged: (value) {
        _updateState(() {
          _shellState.atlasState = _shellState.atlasState.withZoom(value);
        });
      },
      onSelectedSliceChanged: (sliceId) {
        _updateState(() {
          final previousPrefabSliceId = _shellState.selectedPrefabSliceId;
          switch (_shellState.atlasState.selectedSliceKind) {
            case AtlasSliceKind.prefab:
              _shellState.selectedPrefabSliceId = sliceId;
              _syncPrefabIdsWithSelectedSlice(previousPrefabSliceId);
              break;
            case AtlasSliceKind.tile:
              _shellState.selectedTileSliceId = sliceId;
              break;
          }
          _syncSliceDraft(
            _atlasSlicer.findSliceById(
              data: _shellState.data,
              kind: _shellState.atlasState.selectedSliceKind,
              sliceId: sliceId,
            ),
          );
          _shellState.errorMessage = null;
        });
      },
      onSelectionInputsChanged: () => applySelectionFromInputs(silent: true),
      onSaveSlice: saveSliceFromSelection,
      onDeleteSlice: (sliceId) =>
          deleteSlice(sliceId, _shellState.atlasState.selectedSliceKind),
      onSelectionDragStart: (localPosition, imageSize) {
        _updateState(() {
          final start = toImagePosition(localPosition, imageSize);
          _setSelectionFromPoints(start, start);
        });
      },
      onSelectionDragUpdate: (localPosition, imageSize) {
        _updateState(() {
          final current = toImagePosition(localPosition, imageSize);
          final start = _shellState.atlasState.selectionStartImagePx ?? current;
          _setSelectionFromPoints(start, current);
        });
      },
    );
  }

  String? _selectedSliceIdForKind(AtlasSliceKind kind) {
    switch (kind) {
      case AtlasSliceKind.prefab:
        return _shellState.selectedPrefabSliceId;
      case AtlasSliceKind.tile:
        return _shellState.selectedTileSliceId;
    }
  }

  Rect? selectionRectInImagePixels() {
    return _atlasSlicer.selectionRectInImagePixels(_shellState.atlasState);
  }

  Offset toImagePosition(Offset localPosition, Size imageSize) {
    return _atlasSlicer.toImagePosition(
      state: _shellState.atlasState,
      localPosition: localPosition,
      imageSize: imageSize,
    );
  }

  void clearSelection() {
    _shellState.atlasState = _shellState.atlasState.clearedSelection();
    _syncSelectionInputsFromRect(null);
  }

  void clearSliceDraft() {
    _sliceIdController.clear();
    _sliceTagsController.clear();
    clearSelection();
  }

  void applySelectionFromInputs({bool silent = false}) {
    final selectedAtlasPath = _shellState.atlasState.selectedAtlasPath;
    if (selectedAtlasPath == null) {
      if (!silent) {
        _setError('Select an atlas/tileset image first.');
      }
      return;
    }
    final atlasSize = _atlasImageSizes[selectedAtlasPath];
    if (atlasSize == null) {
      if (!silent) {
        _setError('Atlas metadata is not loaded yet.');
      }
      return;
    }

    final selection = _atlasSlicer.clampedSelectionFromInputs(
      atlasSize: atlasSize,
      rawX: _selectionXController.text,
      rawY: _selectionYController.text,
      rawW: _selectionWController.text,
      rawH: _selectionHController.text,
    );
    if (selection.error != null) {
      if (!silent) {
        _setError(selection.error!);
      }
      return;
    }

    _updateState(() {
      _setSelectionRect(selection.rect!, syncInputs: !silent);
      if (!silent) {
        _shellState.statusMessage = 'Selection updated from input values.';
        _shellState.errorMessage = null;
      }
    });
  }

  void saveSliceFromSelection() {
    final atlasState = _shellState.atlasState;
    final selectedAtlasPath = atlasState.selectedAtlasPath;
    if (selectedAtlasPath == null) {
      _setError('Select an atlas/tileset image first.');
      return;
    }
    final id = _sliceIdController.text.trim();
    if (id.isEmpty) {
      _setError('Slice id is required.');
      return;
    }
    final atlasSize = _atlasImageSizes[selectedAtlasPath];
    if (atlasSize == null) {
      _setError('Atlas metadata is not loaded yet.');
      return;
    }

    final selectionFromInputs = _atlasSlicer.strictSelectionFromInputs(
      atlasSize: atlasSize,
      rawX: _selectionXController.text,
      rawY: _selectionYController.text,
      rawW: _selectionWController.text,
      rawH: _selectionHController.text,
    );
    if (selectionFromInputs.error != null) {
      _setError(selectionFromInputs.error!);
      return;
    }
    if (selectionFromInputs.rect != null) {
      _setSelectionRect(selectionFromInputs.rect!);
    }

    final selection = selectionFromInputs.rect ?? selectionRectInImagePixels();
    if (selection == null) {
      _setError(
        'Define a valid selection (drag on atlas or fill Selection X/Y/W/H).',
      );
      return;
    }
    final tags = _parseTagInput(_sliceTagsController.text);

    _updateState(() {
      final result = _atlasSlicer.upsertSlice(
        data: _shellState.data,
        state: atlasState,
        id: id,
        selection: selection,
        tags: tags,
      );
      _applySliceMutation(result);
      _syncSliceDraftForCurrentKind(clearIfMissing: false);
    });
  }

  void deleteSlice(String sliceId, AtlasSliceKind kind) {
    _updateState(() {
      final result = _atlasSlicer.deleteSlice(
        data: _shellState.data,
        kind: kind,
        sliceId: sliceId,
        currentPrefabSliceId: _shellState.selectedPrefabSliceId,
        currentTileSliceId: _shellState.selectedTileSliceId,
      );
      _applySliceMutation(result);
      _syncSliceDraftForCurrentKind(clearIfMissing: true);
    });
  }

  void _applySliceMutation(AtlasSlicerSliceMutationResult result) {
    // The shell remains the source of truth for unsaved page-local prefab data.
    _shellState.data = result.data;
    final previousPrefabSliceId = _shellState.selectedPrefabSliceId;
    if (result.selectedPrefabSliceId != null ||
        _shellState.atlasState.selectedSliceKind == AtlasSliceKind.prefab) {
      _shellState.selectedPrefabSliceId = result.selectedPrefabSliceId;
      _syncPrefabIdsWithSelectedSlice(previousPrefabSliceId);
    }
    if (result.selectedTileSliceId != null ||
        _shellState.atlasState.selectedSliceKind == AtlasSliceKind.tile) {
      _shellState.selectedTileSliceId = result.selectedTileSliceId;
    }
    _shellState.statusMessage = result.statusMessage;
    _shellState.errorMessage = null;
  }

  void _syncSliceDraftForCurrentKind({required bool clearIfMissing}) {
    _syncSliceDraft(
      _atlasSlicer.findSliceById(
        data: _shellState.data,
        kind: _shellState.atlasState.selectedSliceKind,
        sliceId: _selectedSliceIdForKind(
          _shellState.atlasState.selectedSliceKind,
        ),
      ),
      clearIfMissing: clearIfMissing,
    );
  }

  void _syncSliceDraft(AtlasSliceDef? slice, {bool clearIfMissing = false}) {
    if (slice == null) {
      if (clearIfMissing) {
        clearSliceDraft();
      }
      return;
    }
    _sliceIdController.text = slice.id;
    _sliceTagsController.text = slice.tags.join(', ');
    _setSelectionRect(
      Rect.fromLTWH(
        slice.x.toDouble(),
        slice.y.toDouble(),
        slice.width.toDouble(),
        slice.height.toDouble(),
      ),
    );
  }

  void _setSelectionFromPoints(
    Offset start,
    Offset current, {
    bool syncInputs = true,
  }) {
    _shellState.atlasState = _shellState.atlasState.withSelection(
      start,
      current,
    );
    if (syncInputs) {
      _syncSelectionInputsFromRect(selectionRectInImagePixels());
    }
  }

  void _setSelectionRect(Rect rect, {bool syncInputs = true}) {
    _shellState.atlasState = _shellState.atlasState.withSelectionRect(rect);
    if (syncInputs) {
      _syncSelectionInputsFromRect(rect);
    }
  }

  void _syncSelectionInputsFromRect(Rect? rect) {
    if (rect == null) {
      _selectionXController.text = '';
      _selectionYController.text = '';
      _selectionWController.text = '';
      _selectionHController.text = '';
      return;
    }
    _selectionXController.text = rect.left.toInt().toString();
    _selectionYController.text = rect.top.toInt().toString();
    _selectionWController.text = rect.width.toInt().toString();
    _selectionHController.text = rect.height.toInt().toString();
  }

  void _setError(String message) {
    _updateState(() {
      _shellState.setError(message);
    });
  }

  List<String> _parseTagInput(String rawTags) {
    return rawTags
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
  }
}
