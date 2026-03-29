part of '../prefab_creator_page.dart';

extension _PrefabCreatorSelectionLogic on _PrefabCreatorPageState {
  Offset _toImagePosition(Offset localPosition, Size imageSize) {
    final x = (localPosition.dx / _atlasZoom).clamp(0.0, imageSize.width);
    final y = (localPosition.dy / _atlasZoom).clamp(0.0, imageSize.height);
    return Offset(x, y);
  }

  Rect? _selectionRectInImagePixels() {
    final start = _selectionStartImagePx;
    final current = _selectionCurrentImagePx;
    if (start == null || current == null) {
      return null;
    }
    final rect = Rect.fromPoints(start, current);
    final left = rect.left.floorToDouble();
    final top = rect.top.floorToDouble();
    final right = rect.right.ceilToDouble();
    final bottom = rect.bottom.ceilToDouble();
    final width = right - left;
    final height = bottom - top;
    if (width <= 0 || height <= 0) {
      return null;
    }
    return Rect.fromLTWH(left, top, width, height);
  }

  void _setSelectionFromPoints(
    Offset start,
    Offset current, {
    bool syncInputs = true,
  }) {
    _selectionStartImagePx = start;
    _selectionCurrentImagePx = current;
    if (syncInputs) {
      _syncSelectionInputsFromRect(_selectionRectInImagePixels());
    }
  }

  void _setSelectionRect(Rect rect, {bool syncInputs = true}) {
    _setSelectionFromPoints(
      rect.topLeft,
      rect.bottomRight,
      syncInputs: syncInputs,
    );
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

  void _applySelectionFromInputs({bool silent = false}) {
    final selectedAtlasPath = _selectedAtlasPath;
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
    final x = int.tryParse(_selectionXController.text.trim());
    final y = int.tryParse(_selectionYController.text.trim());
    final w = int.tryParse(_selectionWController.text.trim());
    final h = int.tryParse(_selectionHController.text.trim());
    if (x == null || y == null || w == null || h == null) {
      if (!silent) {
        _setError('Selection X/Y/W/H must be valid integers.');
      }
      return;
    }
    if (w <= 0 || h <= 0) {
      if (!silent) {
        _setError('Selection width/height must be positive.');
      }
      return;
    }
    final maxWidth = atlasSize.width.toInt();
    final maxHeight = atlasSize.height.toInt();
    if (maxWidth <= 0 || maxHeight <= 0) {
      if (!silent) {
        _setError('Atlas has invalid size.');
      }
      return;
    }
    final clampedX = x.clamp(0, maxWidth - 1);
    final clampedY = y.clamp(0, maxHeight - 1);
    final availableWidth = maxWidth - clampedX;
    final availableHeight = maxHeight - clampedY;
    final clampedW = w.clamp(1, availableWidth);
    final clampedH = h.clamp(1, availableHeight);

    _updateState(() {
      _setSelectionRect(
        Rect.fromLTWH(
          clampedX.toDouble(),
          clampedY.toDouble(),
          clampedW.toDouble(),
          clampedH.toDouble(),
        ),
        syncInputs: !silent,
      );
      if (!silent) {
        _statusMessage = 'Selection updated from input values.';
        _errorMessage = null;
      }
    });
  }

  void _clearSelection() {
    _selectionStartImagePx = null;
    _selectionCurrentImagePx = null;
    _syncSelectionInputsFromRect(null);
  }

  void _addSliceFromSelection() {
    final selectedAtlasPath = _selectedAtlasPath;
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

    final selectionFromInputs = _selectionRectFromInputsForAdd(atlasSize);
    if (selectionFromInputs.error != null) {
      _setError(selectionFromInputs.error!);
      return;
    }
    if (selectionFromInputs.rect != null) {
      _setSelectionRect(selectionFromInputs.rect!);
    }

    final selection = selectionFromInputs.rect ?? _selectionRectInImagePixels();
    if (selection == null) {
      _setError(
        'Define a valid selection (drag on atlas or fill Selection X/Y/W/H).',
      );
      return;
    }
    final sourceList = _selectedSliceKind == AtlasSliceKind.prefab
        ? _data.prefabSlices
        : _data.tileSlices;
    if (sourceList.any((slice) => slice.id == id)) {
      _setError(
        'Slice id "$id" already exists for ${_selectedSliceKind.name} slices.',
      );
      return;
    }
    final newSlice = AtlasSliceDef(
      id: id,
      sourceImagePath: selectedAtlasPath,
      x: selection.left.toInt(),
      y: selection.top.toInt(),
      width: selection.width.toInt(),
      height: selection.height.toInt(),
    );

    _updateState(() {
      if (_selectedSliceKind == AtlasSliceKind.prefab) {
        _data = _data.copyWith(prefabSlices: [..._data.prefabSlices, newSlice]);
        _selectedPrefabSliceId ??= newSlice.id;
      } else {
        _data = _data.copyWith(tileSlices: [..._data.tileSlices, newSlice]);
        _selectedTileSliceId ??= newSlice.id;
      }
      _sliceIdController.clear();
      _clearSelection();
      _statusMessage = 'Added ${_selectedSliceKind.name} slice "$id".';
      _errorMessage = null;
    });
  }

  _SelectionInputResult _selectionRectFromInputsForAdd(Size atlasSize) {
    final rawX = _selectionXController.text.trim();
    final rawY = _selectionYController.text.trim();
    final rawW = _selectionWController.text.trim();
    final rawH = _selectionHController.text.trim();
    final hasAnyInput =
        rawX.isNotEmpty ||
        rawY.isNotEmpty ||
        rawW.isNotEmpty ||
        rawH.isNotEmpty;
    if (!hasAnyInput) {
      return const _SelectionInputResult(rect: null, error: null);
    }

    final x = int.tryParse(rawX);
    final y = int.tryParse(rawY);
    final w = int.tryParse(rawW);
    final h = int.tryParse(rawH);
    if (x == null || y == null || w == null || h == null) {
      return const _SelectionInputResult(
        rect: null,
        error: 'Selection X/Y/W/H must be valid integers.',
      );
    }
    if (w <= 0 || h <= 0) {
      return const _SelectionInputResult(
        rect: null,
        error: 'Selection width/height must be positive.',
      );
    }
    final maxWidth = atlasSize.width.toInt();
    final maxHeight = atlasSize.height.toInt();
    if (x < 0 || y < 0 || x >= maxWidth || y >= maxHeight) {
      return const _SelectionInputResult(
        rect: null,
        error: 'Selection X/Y must stay inside atlas bounds.',
      );
    }
    if (x + w > maxWidth || y + h > maxHeight) {
      return const _SelectionInputResult(
        rect: null,
        error: 'Selection rectangle exceeds atlas bounds.',
      );
    }
    return _SelectionInputResult(
      rect: Rect.fromLTWH(
        x.toDouble(),
        y.toDouble(),
        w.toDouble(),
        h.toDouble(),
      ),
      error: null,
    );
  }

  void _deleteSlice(String sliceId, AtlasSliceKind kind) {
    _updateState(() {
      if (kind == AtlasSliceKind.prefab) {
        _data = _data.copyWith(
          prefabSlices: _data.prefabSlices
              .where((slice) => slice.id != sliceId)
              .toList(growable: false),
          prefabs: _data.prefabs
              .where((prefab) => prefab.sliceId != sliceId)
              .toList(growable: false),
        );
        if (_selectedPrefabSliceId == sliceId) {
          _selectedPrefabSliceId = _data.prefabSlices.isEmpty
              ? null
              : _data.prefabSlices.first.id;
        }
      } else {
        final nextModules = _data.platformModules
            .map(
              (module) => module.copyWith(
                cells: module.cells
                    .where((cell) => cell.sliceId != sliceId)
                    .toList(growable: false),
              ),
            )
            .toList(growable: false);
        _data = _data.copyWith(
          tileSlices: _data.tileSlices
              .where((slice) => slice.id != sliceId)
              .toList(growable: false),
          platformModules: nextModules,
        );
        if (_selectedTileSliceId == sliceId) {
          _selectedTileSliceId = _data.tileSlices.isEmpty
              ? null
              : _data.tileSlices.first.id;
        }
      }
      _statusMessage = 'Deleted $kind slice "$sliceId".';
      _errorMessage = null;
    });
  }
}

class _SelectionInputResult {
  const _SelectionInputResult({required this.rect, required this.error});

  final Rect? rect;
  final String? error;
}
