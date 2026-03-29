part of '../prefab_creator_page.dart';

extension _PrefabCreatorDataIo on _PrefabCreatorPageState {
  Future<void> _reloadData() async {
    final workspacePath = widget.controller.workspacePath.trim();
    if (workspacePath.isEmpty) {
      _updateState(() {
        _errorMessage =
            'Workspace path is empty. Set workspace path then reload.';
        _statusMessage = null;
      });
      return;
    }

    _updateState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final atlasPaths = _discoverAtlasImages(workspacePath);
      final loaded = await _store.load(workspacePath);

      final selectedAtlas = _resolveSelectedAtlas(
        previousSelection: _selectedAtlasPath,
        available: atlasPaths,
      );

      for (final atlasPath in atlasPaths) {
        await _ensureAtlasSizeLoaded(workspacePath, atlasPath);
      }

      _updateState(() {
        _data = loaded;
        _atlasImagePaths = atlasPaths;
        _selectedAtlasPath = selectedAtlas;
        _clearSelection();
        _selectedPrefabSliceId = loaded.prefabSlices.isEmpty
            ? null
            : loaded.prefabSlices.first.id;
        _selectedTileSliceId = loaded.tileSlices.isEmpty
            ? null
            : loaded.tileSlices.first.id;
        _selectedModuleId = loaded.platformModules.isEmpty
            ? null
            : loaded.platformModules.first.id;
        _statusMessage = 'Loaded phase-0 prefab/tile authoring data.';
      });
    } catch (error) {
      _updateState(() {
        _errorMessage = 'Reload failed: $error';
      });
    } finally {
      _updateState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveData() async {
    final workspacePath = widget.controller.workspacePath.trim();
    if (workspacePath.isEmpty) {
      _updateState(() {
        _errorMessage = 'Workspace path is empty. Cannot save.';
        _statusMessage = null;
      });
      return;
    }

    final validationErrors = _validateDataBeforeSave();
    if (validationErrors.isNotEmpty) {
      _updateState(() {
        _errorMessage = validationErrors.join('\n');
        _statusMessage = null;
      });
      return;
    }

    _updateState(() {
      _isSaving = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      await _store.save(workspacePath, data: _data);
      _updateState(() {
        _statusMessage =
            'Saved ${PrefabStore.prefabDefsPath} and ${PrefabStore.tileDefsPath}.';
      });
    } catch (error) {
      _updateState(() {
        _errorMessage = 'Save failed: $error';
      });
    } finally {
      _updateState(() {
        _isSaving = false;
      });
    }
  }

  List<String> _validateDataBeforeSave() {
    final errors = <String>[];
    final prefabSliceIds = <String>{};
    final tileSliceIds = <String>{};
    final allSliceIds = <String>{};

    for (final slice in _data.prefabSlices) {
      if (slice.id.isEmpty) {
        errors.add('Prefab slice with empty id.');
      } else if (!prefabSliceIds.add(slice.id)) {
        errors.add('Duplicate prefab slice id: ${slice.id}');
      }
      if (!allSliceIds.add(slice.id)) {
        errors.add('Slice id reused across prefab/tile slices: ${slice.id}');
      }
      if (slice.width <= 0 || slice.height <= 0) {
        errors.add('Prefab slice ${slice.id} has non-positive size.');
      }
    }

    for (final slice in _data.tileSlices) {
      if (slice.id.isEmpty) {
        errors.add('Tile slice with empty id.');
      } else if (!tileSliceIds.add(slice.id)) {
        errors.add('Duplicate tile slice id: ${slice.id}');
      }
      if (!allSliceIds.add(slice.id)) {
        errors.add('Slice id reused across prefab/tile slices: ${slice.id}');
      }
      if (slice.width <= 0 || slice.height <= 0) {
        errors.add('Tile slice ${slice.id} has non-positive size.');
      }
    }

    final prefabIds = <String>{};
    for (final prefab in _data.prefabs) {
      if (prefab.id.isEmpty) {
        errors.add('Prefab with empty id.');
      } else if (!prefabIds.add(prefab.id)) {
        errors.add('Duplicate prefab id: ${prefab.id}');
      }
      if (!prefabSliceIds.contains(prefab.sliceId)) {
        errors.add(
          'Prefab ${prefab.id} references missing prefab slice ${prefab.sliceId}.',
        );
      }
      if (prefab.colliders.isEmpty) {
        errors.add('Prefab ${prefab.id} must include at least one collider.');
      }
      for (final collider in prefab.colliders) {
        if (collider.width <= 0 || collider.height <= 0) {
          errors.add(
            'Prefab ${prefab.id} has collider with non-positive size.',
          );
        }
      }
    }

    final moduleIds = <String>{};
    for (final module in _data.platformModules) {
      if (module.id.isEmpty) {
        errors.add('Platform module with empty id.');
      } else if (!moduleIds.add(module.id)) {
        errors.add('Duplicate platform module id: ${module.id}');
      }
      if (module.tileSize <= 0) {
        errors.add('Platform module ${module.id} has non-positive tileSize.');
      }
      final cellKeys = <String>{};
      for (final cell in module.cells) {
        if (!tileSliceIds.contains(cell.sliceId)) {
          errors.add(
            'Platform module ${module.id} references missing tile slice ${cell.sliceId}.',
          );
        }
        final cellKey = '${cell.gridX}:${cell.gridY}';
        if (!cellKeys.add(cellKey)) {
          errors.add(
            'Platform module ${module.id} has duplicate cell at ($cellKey).',
          );
        }
      }
    }

    return errors;
  }

  List<String> _discoverAtlasImages(String workspacePath) {
    final levelAssets = Directory(
      p.join(workspacePath, _PrefabCreatorPageState._levelAssetsPath),
    );
    if (!levelAssets.existsSync()) {
      return const <String>[];
    }
    final pngPaths = <String>[];
    for (final entity in levelAssets.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final ext = p.extension(entity.path).toLowerCase();
      if (ext != '.png') {
        continue;
      }
      final relative = p.normalize(
        p.relative(entity.path, from: workspacePath),
      );
      pngPaths.add(relative.replaceAll('\\', '/'));
    }
    pngPaths.sort();
    return pngPaths;
  }

  String? _resolveSelectedAtlas({
    required String? previousSelection,
    required List<String> available,
  }) {
    if (previousSelection != null && available.contains(previousSelection)) {
      return previousSelection;
    }
    if (available.isEmpty) {
      return null;
    }
    return available.first;
  }

  Future<void> _ensureAtlasSizeLoaded(
    String workspacePath,
    String atlasRelativePath,
  ) async {
    if (_atlasImageSizes.containsKey(atlasRelativePath)) {
      return;
    }
    final absolute = p.normalize(p.join(workspacePath, atlasRelativePath));
    final file = File(absolute);
    if (!file.existsSync()) {
      return;
    }

    final bytes = await file.readAsBytes();
    final image = await _decodeImage(bytes);
    _atlasImageSizes[atlasRelativePath] = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );
    image.dispose();
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  void _setError(String message) {
    _updateState(() {
      _errorMessage = message;
      _statusMessage = null;
    });
  }
}
