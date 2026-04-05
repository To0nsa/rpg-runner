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
      _ensurePrefabPluginSelection();
      await widget.controller.loadWorkspace();
      if (!mounted) {
        return;
      }
      final loadError = widget.controller.loadError;
      if (loadError != null) {
        throw StateError(loadError);
      }
      final scene = widget.controller.scene;
      if (scene is! PrefabScene) {
        throw StateError(
          'Prefab scene is not loaded. Active plugin must be "${PrefabDomainPlugin.pluginId}".',
        );
      }
      final loaded = scene.data;
      final atlasPaths = scene.atlasImagePaths.isEmpty
          ? _discoverAtlasImages(workspacePath)
          : scene.atlasImagePaths;

      final selectedAtlas = _resolveSelectedAtlas(
        previousSelection: _selectedAtlasPath,
        available: atlasPaths,
      );

      for (final entry in scene.atlasImageSizes.entries) {
        _atlasImageSizes[entry.key] = entry.value;
      }
      for (final atlasPath in atlasPaths) {
        await _ensureAtlasSizeLoaded(workspacePath, atlasPath);
      }

      _updateState(() {
        String? firstActiveModuleId;
        for (final module in loaded.platformModules) {
          if (module.status == TileModuleStatus.deprecated) {
            continue;
          }
          firstActiveModuleId = module.id;
          break;
        }
        _data = loaded;
        _atlasImagePaths = atlasPaths;
        _selectedAtlasPath = selectedAtlas;
        _clearSelection();
        _selectedPrefabSliceId = loaded.prefabSlices.isEmpty
            ? null
            : loaded.prefabSlices.first.id;
        final defaultPlatformModuleId = loaded.platformModules.isEmpty
            ? null
            : (firstActiveModuleId ?? loaded.platformModules.first.id);
        var defaultPlatformTileSize = 16;
        if (defaultPlatformModuleId != null) {
          for (final module in loaded.platformModules) {
            if (module.id == defaultPlatformModuleId) {
              defaultPlatformTileSize = module.tileSize;
              break;
            }
          }
        }
        _resetPrefabFormsForLoadedData(
          defaultPlatformModuleId: defaultPlatformModuleId,
          defaultPlatformTileSize: defaultPlatformTileSize,
        );
        _selectedTileSliceId = loaded.tileSlices.isEmpty
            ? null
            : loaded.tileSlices.first.id;
        _selectedModuleId = loaded.platformModules.isEmpty
            ? null
            : (firstActiveModuleId ?? loaded.platformModules.first.id);
        _syncSelectedModuleInputs();
        _syncFormDraftBaseline();
        final hints = scene.migrationHints;
        _statusMessage = hints.isEmpty
            ? 'Loaded prefab/tile authoring data.'
            : 'Loaded prefab/tile authoring data. ${hints.join(' ')}';
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
      _ensurePrefabPluginSelection();
      if (widget.controller.document == null ||
          widget.controller.workspace == null) {
        await widget.controller.loadWorkspace();
        if (!mounted) {
          return;
        }
      }
      final loadError = widget.controller.loadError;
      if (loadError != null) {
        throw StateError(loadError);
      }
      await _ensureSliceAtlasSizesLoaded(workspacePath);
      final validationErrors = _validateDataBeforeSave();
      if (validationErrors.isNotEmpty) {
        _updateState(() {
          _errorMessage = validationErrors.join('\n');
          _statusMessage = null;
        });
        return;
      }
      widget.controller.applyCommand(
        AuthoringCommand(
          kind: PrefabDomainPlugin.replacePrefabDataCommandKind,
          payload: <String, Object?>{'data': _data},
        ),
      );
      await widget.controller.exportDirectWrite();
      if (!mounted) {
        return;
      }
      final exportError = widget.controller.exportError;
      if (exportError != null) {
        throw StateError(exportError);
      }
      _syncStateFromControllerScene();
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
    final issues = validatePrefabDataIssues(
      data: _data,
      atlasImageSizes: _atlasImageSizes.snapshot(),
    );
    return issues
        .map((issue) => '[${issue.code}] ${issue.message}')
        .toList(growable: false);
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

  void _commitPrefabDataChange({
    required PrefabData nextData,
    required String statusMessage,
    VoidCallback? beforeSync,
  }) {
    if (widget.controller.document == null || _currentPrefabScene() == null) {
      _setError('Reload prefab data before applying edits.');
      return;
    }

    widget.controller.applyCommand(
      AuthoringCommand(
        kind: PrefabDomainPlugin.replacePrefabDataCommandKind,
        payload: <String, Object?>{'data': nextData},
      ),
    );
    final scene = _currentPrefabScene();
    if (scene == null) {
      _setError('Prefab scene is not loaded. Reload and try again.');
      return;
    }

    _updateState(() {
      beforeSync?.call();
      _applySceneSnapshot(scene);
      _statusMessage = statusMessage;
      _errorMessage = null;
    });
  }

  void _undoCommittedEdit() {
    if (!widget.controller.canUndo) {
      return;
    }
    widget.controller.undo();
    _syncStateFromControllerScene(statusMessage: 'Undid prefab/module edit.');
  }

  void _redoCommittedEdit() {
    if (!widget.controller.canRedo) {
      return;
    }
    widget.controller.redo();
    _syncStateFromControllerScene(statusMessage: 'Redid prefab/module edit.');
  }

  PrefabScene? _currentPrefabScene() {
    final scene = widget.controller.scene;
    return scene is PrefabScene ? scene : null;
  }

  void _syncStateFromControllerScene({String? statusMessage}) {
    final scene = _currentPrefabScene();
    if (scene == null) {
      _setError('Prefab scene is not loaded. Reload and try again.');
      return;
    }
    _updateState(() {
      _applySceneSnapshot(scene);
      _statusMessage = statusMessage;
      _errorMessage = null;
    });
  }

  void _applySceneSnapshot(PrefabScene scene) {
    _data = scene.data;
    _atlasImagePaths = scene.atlasImagePaths;
    _selectedAtlasPath = _resolveSelectedAtlas(
      previousSelection: _selectedAtlasPath,
      available: _atlasImagePaths,
    );
    for (final entry in scene.atlasImageSizes.entries) {
      _atlasImageSizes[entry.key] = entry.value;
    }

    _selectedPrefabSliceId = _resolveAtlasSliceSelection(
      currentSelection: _selectedPrefabSliceId,
      slices: _data.prefabSlices,
    );
    _selectedTileSliceId = _resolveAtlasSliceSelection(
      currentSelection: _selectedTileSliceId,
      slices: _data.tileSlices,
    );

    final preferredModuleId = _data.platformModules.isEmpty
        ? null
        : _preferredModuleIdForPicker(_data.platformModules);
    _selectedModuleId = _resolveModuleSelection(
      currentSelection: _selectedModuleId,
      fallbackSelection: preferredModuleId,
    );
    _selectedPrefabPlatformModuleId = _resolveModuleSelection(
      currentSelection: _selectedPrefabPlatformModuleId,
      fallbackSelection: preferredModuleId,
    );
    _syncSelectedModuleInputs();

    final editingPrefab = _editingPrefab();
    if (editingPrefab != null) {
      _applyPrefabToForm(editingPrefab, setStatusMessage: false);
    } else {
      _editingPrefabKey = null;
    }
    _syncFormDraftBaseline();
  }

  String? _resolveAtlasSliceSelection({
    required String? currentSelection,
    required List<AtlasSliceDef> slices,
  }) {
    if (currentSelection != null &&
        slices.any((slice) => slice.id == currentSelection)) {
      return currentSelection;
    }
    if (slices.isEmpty) {
      return null;
    }
    return slices.first.id;
  }

  String? _resolveModuleSelection({
    required String? currentSelection,
    required String? fallbackSelection,
  }) {
    if (currentSelection != null &&
        _data.platformModules.any((module) => module.id == currentSelection)) {
      return currentSelection;
    }
    return fallbackSelection;
  }

  void _syncSelectedModuleInputs() {
    final selectedModule = _selectedModule();
    if (selectedModule == null) {
      _moduleIdController.clear();
      _moduleTileSizeController.text = '16';
      return;
    }
    _moduleIdController.text = selectedModule.id;
    _moduleTileSizeController.text = selectedModule.tileSize.toString();
  }

  bool _hasLocalDataDraftChanges() {
    final scene = _currentPrefabScene();
    if (scene == null) {
      return false;
    }
    final current = _prefabStore.serializeCanonicalFiles(_data);
    final baseline = _prefabStore.serializeCanonicalFiles(scene.data);
    return current.prefabContents != baseline.prefabContents ||
        current.tileContents != baseline.tileContents;
  }

  _PrefabCreatorFormDraftSnapshot _captureFormDraftSnapshot() {
    return _PrefabCreatorFormDraftSnapshot(
      sliceId: _sliceIdController.text,
      selectionX: _selectionXController.text,
      selectionY: _selectionYController.text,
      selectionW: _selectionWController.text,
      selectionH: _selectionHController.text,
      selectedPrefabSliceId: _selectedPrefabSliceId,
      selectedPrefabPlatformModuleId: _selectedPrefabPlatformModuleId,
      moduleId: _moduleIdController.text,
      moduleTileSize: _moduleTileSizeController.text,
      obstaclePrefabId: _obstaclePrefabForm.prefabIdController.text,
      obstacleAnchorX: _obstaclePrefabForm.anchorXController.text,
      obstacleAnchorY: _obstaclePrefabForm.anchorYController.text,
      obstacleColliderOffsetX:
          _obstaclePrefabForm.colliderOffsetXController.text,
      obstacleColliderOffsetY:
          _obstaclePrefabForm.colliderOffsetYController.text,
      obstacleColliderWidth: _obstaclePrefabForm.colliderWidthController.text,
      obstacleColliderHeight: _obstaclePrefabForm.colliderHeightController.text,
      obstacleTags: _obstaclePrefabForm.tagsController.text,
      obstacleZIndex: _obstaclePrefabForm.zIndexController.text,
      obstacleSnapToGrid: _obstaclePrefabForm.snapToGrid,
      obstacleAutoManagePlatformModule:
          _obstaclePrefabForm.autoManagePlatformModule,
      obstacleSelectedKind: _obstaclePrefabForm.selectedKind,
      obstacleEditingPrefabKey: _obstaclePrefabForm.editingPrefabKey,
      platformPrefabId: _platformPrefabForm.prefabIdController.text,
      platformAnchorX: _platformPrefabForm.anchorXController.text,
      platformAnchorY: _platformPrefabForm.anchorYController.text,
      platformColliderOffsetX:
          _platformPrefabForm.colliderOffsetXController.text,
      platformColliderOffsetY:
          _platformPrefabForm.colliderOffsetYController.text,
      platformColliderWidth: _platformPrefabForm.colliderWidthController.text,
      platformColliderHeight: _platformPrefabForm.colliderHeightController.text,
      platformTags: _platformPrefabForm.tagsController.text,
      platformZIndex: _platformPrefabForm.zIndexController.text,
      platformSnapToGrid: _platformPrefabForm.snapToGrid,
      platformAutoManagePlatformModule:
          _platformPrefabForm.autoManagePlatformModule,
      platformSelectedKind: _platformPrefabForm.selectedKind,
      platformEditingPrefabKey: _platformPrefabForm.editingPrefabKey,
    );
  }

  void _syncFormDraftBaseline() {
    _formDraftBaseline = _captureFormDraftSnapshot();
  }

  void _setError(String message) {
    _updateState(() {
      _errorMessage = message;
      _statusMessage = null;
    });
  }
}
