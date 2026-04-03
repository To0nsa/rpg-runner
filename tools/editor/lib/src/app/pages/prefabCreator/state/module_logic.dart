part of '../prefab_creator_page.dart';

extension _PrefabCreatorModuleLogic on _PrefabCreatorPageState {
  void _upsertModuleFromForm() {
    final id = _moduleIdController.text.trim();
    final tileSize = int.tryParse(_moduleTileSizeController.text.trim());
    if (id.isEmpty) {
      _setError('Platform module id is required.');
      return;
    }
    if (tileSize == null || tileSize <= 0) {
      _setError('Module tileSize must be a positive integer.');
      return;
    }

    final existing = _data.platformModules
        .where((m) => m.id == id)
        .toList(growable: false);
    final previous = existing.isEmpty ? null : existing.first;
    var nextModule = previous == null
        ? TileModuleDef(
            id: id,
            revision: 1,
            status: TileModuleStatus.active,
            tileSize: tileSize,
            cells: const [],
          )
        : previous.copyWith(tileSize: tileSize);
    if (previous != null &&
        _dataReducer.didModulePayloadChange(previous, nextModule)) {
      nextModule = nextModule.copyWith(revision: previous.revision + 1);
    }
    final nextModules = _dataReducer.sortedModulesForUi(
      _data.platformModules
          .where((m) => m.id != id)
          .followedBy([nextModule])
          .toList(growable: false),
    );
    _updateState(() {
      _data = _data.copyWith(platformModules: nextModules);
      _selectedModuleId = id;
      _selectedPrefabPlatformModuleId ??= id;
      _statusMessage =
          'Upserted platform module "$id" '
          '(rev=${nextModule.revision} status=${nextModule.status.jsonValue}).';
      _errorMessage = null;
    });
  }

  TileModuleDef? _moduleById(String moduleId) {
    for (final module in _data.platformModules) {
      if (module.id == moduleId) {
        return module;
      }
    }
    return null;
  }

  TileModuleDef? _selectedModule() {
    final moduleId = _selectedModuleId;
    if (moduleId == null) {
      return null;
    }
    return _moduleById(moduleId);
  }

  void _duplicateSelectedModule() {
    final source = _selectedModule();
    if (source == null) {
      _setError('Load/select a module before duplicating.');
      return;
    }
    var nextId = _moduleIdController.text.trim();
    if (nextId.isEmpty || nextId == source.id) {
      nextId = _dataReducer.allocateModuleIdForDuplicate(_data, source.id);
    }
    if (_data.platformModules.any((module) => module.id == nextId)) {
      _setError('Platform module id "$nextId" already exists.');
      return;
    }

    final duplicate = source.copyWith(
      id: nextId,
      revision: 1,
      status: TileModuleStatus.active,
    );
    final nextModules = _dataReducer.sortedModulesForUi(
      _data.platformModules.followedBy([duplicate]).toList(growable: false),
    );
    _updateState(() {
      _data = _data.copyWith(platformModules: nextModules);
      _selectedModuleId = duplicate.id;
      _selectedPrefabPlatformModuleId ??= duplicate.id;
      _moduleIdController.text = duplicate.id;
      _moduleTileSizeController.text = duplicate.tileSize.toString();
      _statusMessage =
          'Duplicated module "${source.id}" -> "${duplicate.id}" '
          '(rev=${duplicate.revision}).';
      _errorMessage = null;
    });
  }

  void _renameSelectedModuleFromForm() {
    final source = _selectedModule();
    if (source == null) {
      _setError('Load/select a module before renaming.');
      return;
    }
    final nextId = _moduleIdController.text.trim();
    if (nextId.isEmpty) {
      _setError('Platform module id is required.');
      return;
    }
    if (nextId == source.id) {
      _setError('Rename target must differ from current module id.');
      return;
    }
    if (_data.platformModules.any((module) => module.id == nextId)) {
      _setError('Platform module id "$nextId" already exists.');
      return;
    }

    final renamed = source.copyWith(id: nextId, revision: source.revision + 1);
    final rewrittenPrefabs = _dataReducer.rewritePrefabsForModuleRename(
      prefabs: _data.prefabs,
      fromModuleId: source.id,
      toModuleId: nextId,
    );
    final rewrittenCount = rewrittenPrefabs
        .where(
          (prefab) => prefab.usesPlatformModule && prefab.moduleId == nextId,
        )
        .length;
    final nextModules = _dataReducer.sortedModulesForUi(
      _data.platformModules
          .where((module) => module.id != source.id)
          .followedBy([renamed])
          .toList(growable: false),
    );
    _updateState(() {
      _data = _data.copyWith(
        platformModules: nextModules,
        prefabs: rewrittenPrefabs,
      );
      _selectedModuleId = renamed.id;
      if (_selectedPrefabPlatformModuleId == source.id) {
        _selectedPrefabPlatformModuleId = renamed.id;
      }
      _moduleIdController.text = renamed.id;
      _statusMessage =
          'Renamed module "${source.id}" -> "${renamed.id}" '
          '(rev=${renamed.revision}, updatedPrefabs=$rewrittenCount).';
      _errorMessage = null;
    });
  }

  void _toggleDeprecateSelectedModule() {
    final source = _selectedModule();
    if (source == null) {
      _setError('Load/select a module before changing status.');
      return;
    }
    final nextStatus = source.status == TileModuleStatus.deprecated
        ? TileModuleStatus.active
        : TileModuleStatus.deprecated;
    if (nextStatus == source.status) {
      return;
    }
    final updated = source.copyWith(
      status: nextStatus,
      revision: source.revision + 1,
    );
    final nextModules = _dataReducer.sortedModulesForUi(
      _data.platformModules
          .map((module) => module.id == source.id ? updated : module)
          .toList(growable: false),
    );
    _updateState(() {
      _data = _data.copyWith(platformModules: nextModules);
      _selectedModuleId = updated.id;
      _statusMessage =
          '${nextStatus == TileModuleStatus.deprecated ? 'Deprecated' : 'Reactivated'} '
          'module "${updated.id}" (rev=${updated.revision}).';
      _errorMessage = null;
    });
  }

  void _deleteModule(String moduleId) {
    final referencedPrefabs = _data.prefabs
        .where(
          (prefab) => prefab.usesPlatformModule && prefab.moduleId == moduleId,
        )
        .toList(growable: false);
    if (referencedPrefabs.isNotEmpty) {
      _setError(
        'Cannot delete module "$moduleId": '
        '${referencedPrefabs.length} prefab(s) still reference it.',
      );
      return;
    }

    _updateState(() {
      _data = _data.copyWith(
        platformModules: _data.platformModules
            .where((module) => module.id != moduleId)
            .toList(growable: false),
      );
      if (_selectedModuleId == moduleId) {
        _selectedModuleId = _data.platformModules.isEmpty
            ? null
            : _preferredModuleIdForPicker(_data.platformModules);
      }
      if (_selectedPrefabPlatformModuleId == moduleId) {
        _selectedPrefabPlatformModuleId = _data.platformModules.isEmpty
            ? null
            : _preferredModuleIdForPicker(_data.platformModules);
      }
      _statusMessage = 'Deleted module "$moduleId".';
      _errorMessage = null;
    });
  }

  void _deleteModuleCell({required String moduleId, required int cellIndex}) {
    final module = _data.platformModules
        .where((m) => m.id == moduleId)
        .toList(growable: false);
    if (module.isEmpty) {
      return;
    }
    final current = module.first;
    if (cellIndex < 0 || cellIndex >= current.cells.length) {
      return;
    }
    final nextCells = List<TileModuleCellDef>.from(current.cells)
      ..removeAt(cellIndex);
    final nextModule = current.copyWith(
      revision: current.revision + 1,
      cells: nextCells,
    );
    final nextModules = _dataReducer.sortedModulesForUi(
      _data.platformModules
          .map((m) => m.id == moduleId ? nextModule : m)
          .toList(growable: false),
    );
    _updateState(() {
      _data = _data.copyWith(platformModules: nextModules);
      _statusMessage =
          'Removed cell from module "$moduleId" (rev=${nextModule.revision}).';
      _errorMessage = null;
    });
  }

  void _paintCellInSelectedModuleAt({
    required int gridX,
    required int gridY,
    required String sliceId,
  }) {
    final module = _selectedModule();
    if (module == null) {
      return;
    }
    _paintCellInModuleAt(
      moduleId: module.id,
      gridX: gridX,
      gridY: gridY,
      sliceId: sliceId,
    );
  }

  void _paintCellInModuleAt({
    required String moduleId,
    required int gridX,
    required int gridY,
    required String sliceId,
  }) {
    final module = _moduleById(moduleId);
    if (module == null) {
      return;
    }
    var changed = false;
    final nextCells = <TileModuleCellDef>[];
    var found = false;
    for (final cell in module.cells) {
      if (cell.gridX == gridX && cell.gridY == gridY) {
        found = true;
        if (cell.sliceId == sliceId) {
          nextCells.add(cell);
        } else {
          changed = true;
          nextCells.add(
            TileModuleCellDef(sliceId: sliceId, gridX: gridX, gridY: gridY),
          );
        }
      } else {
        nextCells.add(cell);
      }
    }
    if (!found) {
      changed = true;
      nextCells.add(
        TileModuleCellDef(sliceId: sliceId, gridX: gridX, gridY: gridY),
      );
    }
    if (!changed) {
      return;
    }

    final nextModule = module.copyWith(
      revision: module.revision + 1,
      cells: nextCells,
    );
    final nextModules = _dataReducer.sortedModulesForUi(
      _data.platformModules
          .map((m) => m.id == module.id ? nextModule : m)
          .toList(growable: false),
    );
    _updateState(() {
      _data = _data.copyWith(platformModules: nextModules);
      _statusMessage =
          'Painted cell ($gridX,$gridY) in "${module.id}" '
          '(rev=${nextModule.revision}).';
      _errorMessage = null;
    });
  }

  void _eraseCellInSelectedModuleAt({required int gridX, required int gridY}) {
    final module = _selectedModule();
    if (module == null) {
      return;
    }
    _eraseCellInModuleAt(moduleId: module.id, gridX: gridX, gridY: gridY);
  }

  void _moveCellInSelectedModuleAt({
    required int sourceGridX,
    required int sourceGridY,
    required int targetGridX,
    required int targetGridY,
  }) {
    final module = _selectedModule();
    if (module == null) {
      return;
    }
    _moveCellInModuleAt(
      moduleId: module.id,
      sourceGridX: sourceGridX,
      sourceGridY: sourceGridY,
      targetGridX: targetGridX,
      targetGridY: targetGridY,
    );
  }

  void _eraseCellInModuleAt({
    required String moduleId,
    required int gridX,
    required int gridY,
  }) {
    final module = _moduleById(moduleId);
    if (module == null) {
      return;
    }
    var removed = false;
    final nextCells = <TileModuleCellDef>[];
    for (final cell in module.cells) {
      if (cell.gridX == gridX && cell.gridY == gridY) {
        removed = true;
        continue;
      }
      nextCells.add(cell);
    }
    if (!removed) {
      return;
    }

    final nextModule = module.copyWith(
      revision: module.revision + 1,
      cells: nextCells,
    );
    final nextModules = _dataReducer.sortedModulesForUi(
      _data.platformModules
          .map((m) => m.id == module.id ? nextModule : m)
          .toList(growable: false),
    );
    _updateState(() {
      _data = _data.copyWith(platformModules: nextModules);
      _statusMessage =
          'Erased cell ($gridX,$gridY) from "${module.id}" '
          '(rev=${nextModule.revision}).';
      _errorMessage = null;
    });
  }

  void _moveCellInModuleAt({
    required String moduleId,
    required int sourceGridX,
    required int sourceGridY,
    required int targetGridX,
    required int targetGridY,
  }) {
    if (sourceGridX == targetGridX && sourceGridY == targetGridY) {
      return;
    }
    final module = _moduleById(moduleId);
    if (module == null) {
      return;
    }
    TileModuleCellDef? sourceCell;
    final nextCells = <TileModuleCellDef>[];
    for (final cell in module.cells) {
      if (cell.gridX == sourceGridX && cell.gridY == sourceGridY) {
        sourceCell ??= cell;
        continue;
      }
      if (cell.gridX == targetGridX && cell.gridY == targetGridY) {
        continue;
      }
      nextCells.add(cell);
    }
    if (sourceCell == null) {
      return;
    }
    nextCells.add(
      TileModuleCellDef(
        sliceId: sourceCell.sliceId,
        gridX: targetGridX,
        gridY: targetGridY,
      ),
    );

    final nextModule = module.copyWith(
      revision: module.revision + 1,
      cells: nextCells,
    );
    final nextModules = _dataReducer.sortedModulesForUi(
      _data.platformModules
          .map((m) => m.id == module.id ? nextModule : m)
          .toList(growable: false),
    );
    _updateState(() {
      _data = _data.copyWith(platformModules: nextModules);
      _statusMessage =
          'Moved cell ($sourceGridX,$sourceGridY) -> '
          '($targetGridX,$targetGridY) in "${module.id}" '
          '(rev=${nextModule.revision}).';
      _errorMessage = null;
    });
  }

  void _loadPlatformPrefabForSelectedModule() {
    final module = _selectedModule();
    if (module == null) {
      _setError('Select a module before loading prefab defaults.');
      return;
    }
    final existing = _dataReducer.firstPlatformPrefabForModuleId(
      _data.prefabs,
      module.id,
    );
    if (existing != null) {
      _loadPrefabIntoForm(existing);
      _updateState(() {
        _selectedPrefabKind = PrefabKind.platform;
        _autoManagePlatformModule = false;
        _selectedPrefabPlatformModuleId = module.id;
        _statusMessage =
            'Loaded platform prefab "${existing.id}" for module "${module.id}".';
        _errorMessage = null;
      });
      return;
    }

    _updateState(() {
      _editingPrefabKey = null;
      _selectedPrefabKind = PrefabKind.platform;
      _autoManagePlatformModule = false;
      _selectedPrefabPlatformModuleId = module.id;
      _prefabIdController.text = _prefabIdController.text.trim().isEmpty
          ? '${module.id}_platform'
          : _prefabIdController.text.trim();
      if (_anchorXController.text.trim().isEmpty) {
        _anchorXController.text = '0';
      }
      if (_anchorYController.text.trim().isEmpty) {
        _anchorYController.text = '0';
      }
      if (_colliderOffsetXController.text.trim().isEmpty) {
        _colliderOffsetXController.text = '0';
      }
      if (_colliderOffsetYController.text.trim().isEmpty) {
        _colliderOffsetYController.text = '0';
      }
      if (_colliderWidthController.text.trim().isEmpty) {
        _colliderWidthController.text = module.tileSize.toString();
      }
      if (_colliderHeightController.text.trim().isEmpty) {
        _colliderHeightController.text = module.tileSize.toString();
      }
      if (_prefabZIndexController.text.trim().isEmpty) {
        _prefabZIndexController.text = '0';
      }
      _statusMessage =
          'Initialized platform prefab form for module "${module.id}".';
      _errorMessage = null;
    });
  }

  void _upsertPlatformPrefabForSelectedModule() {
    final module = _selectedModule();
    if (module == null) {
      _setError('Select a module before saving a platform prefab.');
      return;
    }
    final existing = _dataReducer.firstPlatformPrefabForModuleId(
      _data.prefabs,
      module.id,
    );
    final editing = _editingPrefab();

    _updateState(() {
      _selectedPrefabKind = PrefabKind.platform;
      _autoManagePlatformModule = false;
      _selectedPrefabPlatformModuleId = module.id;
      if (existing != null) {
        _editingPrefabKey = existing.prefabKey;
      } else if (editing?.kind != PrefabKind.platform) {
        // Prevent cross-kind upserts from mutating a previously loaded obstacle.
        _editingPrefabKey = null;
      }
      _prefabIdController.text = _prefabIdController.text.trim().isEmpty
          ? (existing?.id ?? '${module.id}_platform')
          : _prefabIdController.text.trim();
      if (_colliderWidthController.text.trim().isEmpty) {
        _colliderWidthController.text = module.tileSize.toString();
      }
      if (_colliderHeightController.text.trim().isEmpty) {
        _colliderHeightController.text = module.tileSize.toString();
      }
      if (_prefabZIndexController.text.trim().isEmpty) {
        _prefabZIndexController.text = '0';
      }
    });
    _upsertPrefabFromForm();
  }
}
