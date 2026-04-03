part of '../prefab_creator_page.dart';

extension _PrefabCreatorPrefabLogic on _PrefabCreatorPageState {
  AtlasSliceDef? _findSliceById({
    required List<AtlasSliceDef> slices,
    required String? sliceId,
  }) {
    if (sliceId == null) {
      return null;
    }
    for (final slice in slices) {
      if (slice.id == sliceId) {
        return slice;
      }
    }
    return null;
  }

  PrefabSceneValues? _prefabSceneValuesFromInputs() {
    final anchorX = int.tryParse(_anchorXController.text.trim());
    final anchorY = int.tryParse(_anchorYController.text.trim());
    final colliderOffsetX = int.tryParse(
      _colliderOffsetXController.text.trim(),
    );
    final colliderOffsetY = int.tryParse(
      _colliderOffsetYController.text.trim(),
    );
    final colliderWidth = int.tryParse(_colliderWidthController.text.trim());
    final colliderHeight = int.tryParse(_colliderHeightController.text.trim());
    if (anchorX == null ||
        anchorY == null ||
        colliderOffsetX == null ||
        colliderOffsetY == null ||
        colliderWidth == null ||
        colliderHeight == null) {
      return null;
    }
    if (colliderWidth <= 0 || colliderHeight <= 0) {
      return null;
    }
    return PrefabSceneValues(
      anchorX: anchorX,
      anchorY: anchorY,
      colliderOffsetX: colliderOffsetX,
      colliderOffsetY: colliderOffsetY,
      colliderWidth: colliderWidth,
      colliderHeight: colliderHeight,
    );
  }

  void _onPrefabSceneValuesChanged(PrefabSceneValues values) {
    _updateState(() {
      _anchorXController.text = values.anchorX.toString();
      _anchorYController.text = values.anchorY.toString();
      _colliderOffsetXController.text = values.colliderOffsetX.toString();
      _colliderOffsetYController.text = values.colliderOffsetY.toString();
      _colliderWidthController.text = values.colliderWidth.toString();
      _colliderHeightController.text = values.colliderHeight.toString();
      _errorMessage = null;
    });
  }

  void _upsertPrefabFromForm() {
    final id = _prefabIdController.text.trim();
    if (id.isEmpty) {
      _setError('Prefab id is required.');
      return;
    }
    if (_selectedPrefabKind == PrefabKind.unknown) {
      _setError('Prefab kind must be obstacle or platform.');
      return;
    }

    final anchorX = int.tryParse(_anchorXController.text.trim());
    final anchorY = int.tryParse(_anchorYController.text.trim());
    final colliderOffsetX = int.tryParse(
      _colliderOffsetXController.text.trim(),
    );
    final colliderOffsetY = int.tryParse(
      _colliderOffsetYController.text.trim(),
    );
    final colliderWidth = int.tryParse(_colliderWidthController.text.trim());
    final colliderHeight = int.tryParse(_colliderHeightController.text.trim());
    final zIndex = int.tryParse(_prefabZIndexController.text.trim());

    if (anchorX == null ||
        anchorY == null ||
        colliderOffsetX == null ||
        colliderOffsetY == null ||
        colliderWidth == null ||
        colliderHeight == null ||
        zIndex == null) {
      _setError('Anchor/collider/z-index fields must be valid integers.');
      return;
    }
    if (colliderWidth <= 0 || colliderHeight <= 0) {
      _setError('Collider width/height must be positive.');
      return;
    }

    final existingPrefab = _findExistingPrefabForUpsert(id);
    if (_hasIdCollisionForUpsert(id: id, existingPrefab: existingPrefab)) {
      _setError('Prefab id "$id" already exists.');
      return;
    }

    final normalizedTags = _normalizedTags(
      _prefabTagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false),
    );

    final existingKey = existingPrefab?.prefabKey;
    final prefabKey = existingKey?.isNotEmpty == true
        ? existingKey!
        : _allocatePrefabKeyForId(id);
    var nextData = _data;
    String? forcedPlatformModuleId;
    if (_selectedPrefabKind == PrefabKind.platform &&
        _autoManagePlatformModule) {
      final ensuredModule = _ensureAutoManagedPlatformModule(
        data: nextData,
        prefabKey: prefabKey,
      );
      if (ensuredModule == null) {
        return;
      }
      nextData = ensuredModule.data;
      forcedPlatformModuleId = ensuredModule.module.id;
    }

    final visualSource = _selectedVisualSourceForKind(
      platformModuleIdOverride: forcedPlatformModuleId,
    );
    if (visualSource == null) {
      return;
    }

    var nextPrefab = PrefabDef(
      prefabKey: prefabKey,
      id: id,
      revision: existingPrefab?.revision ?? 1,
      status: existingPrefab?.status ?? PrefabStatus.active,
      kind: _selectedPrefabKind,
      visualSource: visualSource,
      anchorXPx: anchorX,
      anchorYPx: anchorY,
      colliders: [
        PrefabColliderDef(
          offsetX: colliderOffsetX,
          offsetY: colliderOffsetY,
          width: colliderWidth,
          height: colliderHeight,
        ),
      ],
      tags: normalizedTags,
      zIndex: zIndex,
      snapToGrid: _prefabSnapToGrid,
    );

    if (existingPrefab != null &&
        _didPrefabPayloadChange(existingPrefab, nextPrefab)) {
      nextPrefab = nextPrefab.copyWith(revision: existingPrefab.revision + 1);
    }

    final nextPrefabs = _sortedPrefabsForUi(
      nextData.prefabs
          .where((prefab) => prefab.prefabKey != nextPrefab.prefabKey)
          .followedBy([nextPrefab])
          .toList(growable: false),
    );
    _updateState(() {
      _data = nextData.copyWith(prefabs: nextPrefabs);
      _editingPrefabKey = nextPrefab.prefabKey;
      if (forcedPlatformModuleId != null) {
        _selectedPrefabPlatformModuleId = forcedPlatformModuleId;
        _selectedModuleId = forcedPlatformModuleId;
      }
      _statusMessage =
          'Upserted ${nextPrefab.kind.jsonValue} prefab "$id" '
          '(rev=${nextPrefab.revision} source='
          '${nextPrefab.visualSource.type.jsonValue}:${nextPrefab.sourceRefId}).';
      _errorMessage = null;
    });
  }

  PrefabVisualSource? _selectedVisualSourceForKind({
    String? platformModuleIdOverride,
  }) {
    switch (_selectedPrefabKind) {
      case PrefabKind.obstacle:
        final sliceId = _selectedPrefabSliceId;
        if (sliceId == null || sliceId.isEmpty) {
          _setError('Select an atlas slice for obstacle prefab source.');
          return null;
        }
        return PrefabVisualSource.atlasSlice(sliceId);
      case PrefabKind.platform:
        final moduleId =
            platformModuleIdOverride ?? _selectedPrefabPlatformModuleId;
        if (moduleId == null || moduleId.isEmpty) {
          _setError(
            _autoManagePlatformModule
                ? 'Initialize backing module before saving platform prefab.'
                : 'Select a platform module for platform prefab source.',
          );
          return null;
        }
        return PrefabVisualSource.platformModule(moduleId);
      case PrefabKind.unknown:
        _setError('Prefab kind must be obstacle or platform.');
        return null;
    }
  }

  PrefabDef? _findExistingPrefabForUpsert(String id) {
    final editingKey = _editingPrefabKey?.trim();
    if (editingKey != null && editingKey.isNotEmpty) {
      for (final prefab in _data.prefabs) {
        if (prefab.prefabKey == editingKey &&
            prefab.kind == _selectedPrefabKind) {
          return prefab;
        }
      }
    }
    for (final prefab in _data.prefabs) {
      if (prefab.id == id) {
        return prefab;
      }
    }
    return null;
  }

  bool _hasIdCollisionForUpsert({
    required String id,
    required PrefabDef? existingPrefab,
  }) {
    for (final prefab in _data.prefabs) {
      if (prefab.id != id) {
        continue;
      }
      if (existingPrefab == null) {
        return true;
      }
      if (prefab.prefabKey != existingPrefab.prefabKey) {
        return true;
      }
    }
    return false;
  }

  bool _didPrefabPayloadChange(PrefabDef previous, PrefabDef next) {
    if (previous.kind != next.kind) {
      return true;
    }
    if (previous.visualSource.type != next.visualSource.type) {
      return true;
    }
    if (previous.sourceRefId != next.sourceRefId) {
      return true;
    }
    if (previous.anchorXPx != next.anchorXPx ||
        previous.anchorYPx != next.anchorYPx) {
      return true;
    }
    if (previous.zIndex != next.zIndex ||
        previous.snapToGrid != next.snapToGrid) {
      return true;
    }
    if (previous.status != next.status) {
      return true;
    }
    if (!_stringListsEqual(previous.tags, next.tags)) {
      return true;
    }
    if (!_collidersEqual(previous.colliders, next.colliders)) {
      return true;
    }
    return false;
  }

  bool _collidersEqual(List<PrefabColliderDef> a, List<PrefabColliderDef> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i += 1) {
      if (a[i].offsetX != b[i].offsetX ||
          a[i].offsetY != b[i].offsetY ||
          a[i].width != b[i].width ||
          a[i].height != b[i].height) {
        return false;
      }
    }
    return true;
  }

  bool _stringListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i += 1) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  List<String> _normalizedTags(List<String> tags) {
    final normalized =
        tags
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return normalized;
  }

  List<PrefabDef> _sortedPrefabsForUi(List<PrefabDef> prefabs) {
    final sorted = List<PrefabDef>.from(prefabs)
      ..sort((a, b) {
        final idCompare = a.id.compareTo(b.id);
        if (idCompare != 0) {
          return idCompare;
        }
        return a.prefabKey.compareTo(b.prefabKey);
      });
    return sorted;
  }

  String _allocatePrefabKeyForId(String id) {
    final used = <String>{};
    for (final prefab in _data.prefabs) {
      final key = prefab.prefabKey.trim();
      if (key.isEmpty) {
        continue;
      }
      used.add(key);
    }

    var base = _slugToPrefabKey(id);
    if (base.isEmpty) {
      base = 'prefab';
    }
    var candidate = base;
    var suffix = 2;
    while (used.contains(candidate)) {
      candidate = '${base}_$suffix';
      suffix += 1;
    }
    return candidate;
  }

  String _slugToPrefabKey(String raw) {
    final lowered = raw.trim().toLowerCase();
    if (lowered.isEmpty) {
      return '';
    }
    final replaced = lowered.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    final collapsed = replaced.replaceAll(RegExp(r'_+'), '_');
    return collapsed.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String _autoManagedModuleIdForPrefabKey(String prefabKey) {
    return 'vm_$prefabKey';
  }

  bool _isAutoManagedModuleForPrefab({
    required String prefabKey,
    required String moduleId,
  }) {
    return moduleId == _autoManagedModuleIdForPrefabKey(prefabKey);
  }

  int? _platformTileSizeFromForm({bool reportError = true}) {
    final tileSize = int.tryParse(_moduleTileSizeController.text.trim());
    if (tileSize != null && tileSize > 0) {
      return tileSize;
    }
    if (reportError) {
      _setError('Platform tile size must be a positive integer.');
    }
    return null;
  }

  _AutoManagedModuleResult? _ensureAutoManagedPlatformModule({
    required PrefabData data,
    required String prefabKey,
  }) {
    final tileSize = _platformTileSizeFromForm();
    if (tileSize == null) {
      return null;
    }
    final moduleId = _autoManagedModuleIdForPrefabKey(prefabKey);
    final existing = data.platformModules
        .where((module) => module.id == moduleId)
        .toList(growable: false);
    final previous = existing.isEmpty ? null : existing.first;
    final nextModule = _buildAutoManagedModule(
      previous: previous,
      moduleId: moduleId,
      tileSize: tileSize,
    );
    if (previous == null || _didModulePayloadChange(previous, nextModule)) {
      final nextModules = _sortedModulesForUi(
        data.platformModules
            .where((module) => module.id != moduleId)
            .followedBy([nextModule])
            .toList(growable: false),
      );
      return _AutoManagedModuleResult(
        data: data.copyWith(platformModules: nextModules),
        module: nextModule,
      );
    }
    return _AutoManagedModuleResult(data: data, module: previous);
  }

  TileModuleDef _buildAutoManagedModule({
    required TileModuleDef? previous,
    required String moduleId,
    required int tileSize,
  }) {
    if (previous == null) {
      return TileModuleDef(
        id: moduleId,
        revision: 1,
        status: TileModuleStatus.active,
        tileSize: tileSize,
        cells: const <TileModuleCellDef>[],
      );
    }
    var next = previous;
    if (previous.status != TileModuleStatus.active) {
      next = next.copyWith(
        status: TileModuleStatus.active,
        revision: next.revision + 1,
      );
    }
    if (next.tileSize != tileSize) {
      next = next.copyWith(tileSize: tileSize, revision: next.revision + 1);
    }
    return next;
  }

  void _loadPrefabIntoForm(PrefabDef prefab) {
    final collider = prefab.colliders.isEmpty
        ? const PrefabColliderDef(offsetX: 0, offsetY: 0, width: 16, height: 16)
        : prefab.colliders.first;
    _updateState(() {
      _editingPrefabKey = prefab.prefabKey;
      _prefabIdController.text = prefab.id;
      _selectedPrefabKind = prefab.kind == PrefabKind.platform
          ? PrefabKind.platform
          : PrefabKind.obstacle;
      if (_selectedPrefabKind == PrefabKind.obstacle) {
        _autoManagePlatformModule = true;
      }
      if (prefab.usesAtlasSlice) {
        _selectedPrefabSliceId = prefab.sliceId;
      }
      if (prefab.usesPlatformModule) {
        _selectedPrefabPlatformModuleId = prefab.moduleId;
        _selectedModuleId = prefab.moduleId;
        _autoManagePlatformModule = _isAutoManagedModuleForPrefab(
          prefabKey: prefab.prefabKey,
          moduleId: prefab.moduleId,
        );
        final backingModule = _moduleById(prefab.moduleId);
        if (backingModule != null) {
          _moduleTileSizeController.text = backingModule.tileSize.toString();
        }
      } else if (_selectedPrefabKind == PrefabKind.platform) {
        _autoManagePlatformModule = true;
      }
      _anchorXController.text = prefab.anchorXPx.toString();
      _anchorYController.text = prefab.anchorYPx.toString();
      _colliderOffsetXController.text = collider.offsetX.toString();
      _colliderOffsetYController.text = collider.offsetY.toString();
      _colliderWidthController.text = collider.width.toString();
      _colliderHeightController.text = collider.height.toString();
      _prefabTagsController.text = prefab.tags.join(', ');
      _prefabZIndexController.text = prefab.zIndex.toString();
      _prefabSnapToGrid = prefab.snapToGrid;
      _errorMessage = null;
      _statusMessage =
          'Loaded prefab "${prefab.id}" (key=${prefab.prefabKey} rev=${prefab.revision} '
          'status=${prefab.status.jsonValue}).';
    });
  }

  PrefabDef? _editingPrefab() {
    final key = _editingPrefabKey?.trim();
    if (key == null || key.isEmpty) {
      return null;
    }
    for (final prefab in _data.prefabs) {
      if (prefab.prefabKey == key) {
        return prefab;
      }
    }
    return null;
  }

  void _duplicateLoadedPrefab() {
    final source = _editingPrefab();
    if (source == null) {
      _setError('Load a prefab before duplicating.');
      return;
    }
    final requestedId = _prefabIdController.text.trim();
    if (requestedId.isEmpty) {
      _setError('Set a new Prefab ID before duplicating.');
      return;
    }
    if (requestedId == source.id) {
      _setError('Duplicate Prefab ID must differ from the source prefab id.');
      return;
    }
    if (_data.prefabs.any((prefab) => prefab.id == requestedId)) {
      _setError('Prefab id "$requestedId" already exists.');
      return;
    }

    final duplicate = source.copyWith(
      prefabKey: _allocatePrefabKeyForId(requestedId),
      id: requestedId,
      revision: 1,
      status: PrefabStatus.active,
    );
    final nextPrefabs = _sortedPrefabsForUi(
      _data.prefabs.followedBy([duplicate]).toList(growable: false),
    );
    _updateState(() {
      _data = _data.copyWith(prefabs: nextPrefabs);
      _editingPrefabKey = duplicate.prefabKey;
      _statusMessage =
          'Duplicated prefab "${source.id}" -> "$requestedId" '
          '(key=${duplicate.prefabKey}).';
      _errorMessage = null;
    });
  }

  void _deprecateLoadedPrefab() {
    final source = _editingPrefab();
    if (source == null) {
      _setError('Load a prefab before deprecating.');
      return;
    }
    if (source.status == PrefabStatus.deprecated) {
      _updateState(() {
        _statusMessage = 'Prefab "${source.id}" is already deprecated.';
        _errorMessage = null;
      });
      return;
    }
    final deprecated = source.copyWith(
      status: PrefabStatus.deprecated,
      revision: source.revision + 1,
    );
    final nextPrefabs = _sortedPrefabsForUi(
      _data.prefabs
          .where((prefab) => prefab.prefabKey != source.prefabKey)
          .followedBy([deprecated])
          .toList(growable: false),
    );
    _updateState(() {
      _data = _data.copyWith(prefabs: nextPrefabs);
      _editingPrefabKey = deprecated.prefabKey;
      _statusMessage =
          'Deprecated prefab "${deprecated.id}" (rev=${deprecated.revision}).';
      _errorMessage = null;
    });
  }

  void _clearPrefabForm() {
    _updateState(() {
      _editingPrefabKey = null;
      _prefabIdController.clear();
      _anchorXController.text = '0';
      _anchorYController.text = '0';
      _colliderOffsetXController.text = '0';
      _colliderOffsetYController.text = '0';
      _colliderWidthController.text = '16';
      _colliderHeightController.text = '16';
      _prefabTagsController.clear();
      _prefabZIndexController.text = '0';
      _prefabSnapToGrid = true;
      _moduleTileSizeController.text = '16';
      _autoManagePlatformModule = true;
      _selectedPrefabKind = PrefabKind.obstacle;
      if (_data.prefabSlices.isNotEmpty) {
        _selectedPrefabSliceId = _data.prefabSlices.first.id;
      }
      if (_data.platformModules.isNotEmpty) {
        _selectedPrefabPlatformModuleId = _preferredModuleIdForPicker(
          _data.platformModules,
        );
      }
      _statusMessage = 'Cleared prefab form.';
      _errorMessage = null;
    });
  }

  void _deletePrefab(String prefabId) {
    PrefabDef? deleted;
    for (final prefab in _data.prefabs) {
      if (prefab.id == prefabId) {
        deleted = prefab;
        break;
      }
    }

    _updateState(() {
      _data = _data.copyWith(
        prefabs: _data.prefabs
            .where((prefab) => prefab.id != prefabId)
            .toList(growable: false),
      );
      if (deleted != null && deleted.prefabKey == _editingPrefabKey) {
        _editingPrefabKey = null;
      }
      _statusMessage = 'Deleted prefab "$prefabId".';
      _errorMessage = null;
    });
  }

  String _preferredModuleIdForPicker(List<TileModuleDef> modules) {
    for (final module in modules) {
      if (module.status != TileModuleStatus.deprecated) {
        return module.id;
      }
    }
    return modules.first.id;
  }
}

class _AutoManagedModuleResult {
  const _AutoManagedModuleResult({required this.data, required this.module});

  final PrefabData data;
  final TileModuleDef module;
}
