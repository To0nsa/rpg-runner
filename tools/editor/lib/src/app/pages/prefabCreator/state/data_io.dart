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
    _atlasImageSizes.ensureWorkspace(workspacePath);

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
    _atlasImageSizes.ensureWorkspace(workspacePath);

    _updateState(() {
      _isSaving = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      await _ensureSliceAtlasSizesLoaded(workspacePath);
      final validationErrors = _validateDataBeforeSave();
      if (validationErrors.isNotEmpty) {
        _updateState(() {
          _errorMessage = validationErrors.join('\n');
          _statusMessage = null;
        });
        return;
      }
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
    return validatePrefabData(
      data: _data,
      atlasImageSizes: _atlasImageSizes.snapshot(),
    );
  }

  Future<void> _ensureSliceAtlasSizesLoaded(String workspacePath) async {
    final sourcePaths = <String>{};
    for (final slice in _data.prefabSlices) {
      final sourcePath = slice.sourceImagePath.trim();
      if (sourcePath.isEmpty) {
        continue;
      }
      sourcePaths.add(sourcePath);
    }
    for (final slice in _data.tileSlices) {
      final sourcePath = slice.sourceImagePath.trim();
      if (sourcePath.isEmpty) {
        continue;
      }
      sourcePaths.add(sourcePath);
    }
    for (final sourcePath in sourcePaths) {
      await _ensureAtlasSizeLoaded(workspacePath, sourcePath);
    }
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
    _atlasImageSizes.ensureWorkspace(workspacePath);
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
