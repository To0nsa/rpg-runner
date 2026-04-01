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
    final nextModule = existing.isEmpty
        ? TileModuleDef(id: id, tileSize: tileSize, cells: const [])
        : existing.first.copyWith(tileSize: tileSize);
    final nextModules = _data.platformModules
        .where((m) => m.id != id)
        .toList(growable: false);
    _updateState(() {
      _data = _data.copyWith(platformModules: [...nextModules, nextModule]);
      _selectedModuleId = id;
      _selectedPrefabPlatformModuleId ??= id;
      _statusMessage = 'Upserted platform module "$id".';
      _errorMessage = null;
    });
  }

  TileModuleDef? _selectedModule() {
    final moduleId = _selectedModuleId;
    if (moduleId == null) {
      return null;
    }
    for (final module in _data.platformModules) {
      if (module.id == moduleId) {
        return module;
      }
    }
    return null;
  }

  void _addCellToSelectedModule() {
    final module = _selectedModule();
    if (module == null) {
      _setError('Select or create a platform module first.');
      return;
    }
    final sliceId = _selectedTileSliceId;
    if (sliceId == null || sliceId.isEmpty) {
      _setError('Select a tile slice first.');
      return;
    }
    final gridX = int.tryParse(_moduleCellGridXController.text.trim());
    final gridY = int.tryParse(_moduleCellGridYController.text.trim());
    if (gridX == null || gridY == null) {
      _setError('Grid X/Y must be valid integers.');
      return;
    }
    final duplicate = module.cells.any(
      (cell) => cell.gridX == gridX && cell.gridY == gridY,
    );
    if (duplicate) {
      _setError(
        'Module "${module.id}" already contains a cell at ($gridX,$gridY).',
      );
      return;
    }

    final nextCell = TileModuleCellDef(
      sliceId: sliceId,
      gridX: gridX,
      gridY: gridY,
    );
    final nextModule = module.copyWith(cells: [...module.cells, nextCell]);
    final nextModules = _data.platformModules
        .map((m) => m.id == module.id ? nextModule : m)
        .toList(growable: false);
    _updateState(() {
      _data = _data.copyWith(platformModules: nextModules);
      _statusMessage = 'Added cell to module "${module.id}".';
      _errorMessage = null;
    });
  }

  void _deleteModule(String moduleId) {
    final removedPrefabKeys = _data.prefabs
        .where(
          (prefab) => prefab.usesPlatformModule && prefab.moduleId == moduleId,
        )
        .map((prefab) => prefab.prefabKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    _updateState(() {
      _data = _data.copyWith(
        platformModules: _data.platformModules
            .where((module) => module.id != moduleId)
            .toList(growable: false),
        prefabs: _data.prefabs
            .where(
              (prefab) =>
                  !(prefab.usesPlatformModule && prefab.moduleId == moduleId),
            )
            .toList(growable: false),
      );
      if (_selectedModuleId == moduleId) {
        _selectedModuleId = _data.platformModules.isEmpty
            ? null
            : _data.platformModules.first.id;
      }
      if (_selectedPrefabPlatformModuleId == moduleId) {
        _selectedPrefabPlatformModuleId = _data.platformModules.isEmpty
            ? null
            : _data.platformModules.first.id;
      }
      if (_editingPrefabKey != null &&
          removedPrefabKeys.contains(_editingPrefabKey)) {
        _editingPrefabKey = null;
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
    final nextModule = current.copyWith(cells: nextCells);
    final nextModules = _data.platformModules
        .map((m) => m.id == moduleId ? nextModule : m)
        .toList(growable: false);
    _updateState(() {
      _data = _data.copyWith(platformModules: nextModules);
      _statusMessage = 'Removed cell from module "$moduleId".';
      _errorMessage = null;
    });
  }
}
