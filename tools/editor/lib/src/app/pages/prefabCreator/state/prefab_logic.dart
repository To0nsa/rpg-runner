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
    final sliceId = _selectedPrefabSliceId;
    if (id.isEmpty) {
      _setError('Prefab id is required.');
      return;
    }
    if (sliceId == null || sliceId.isEmpty) {
      _setError('Select a prefab slice for the prefab.');
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

    final tags = _prefabTagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    final nextPrefab = PrefabDef(
      id: id,
      sliceId: sliceId,
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
      tags: tags,
      zIndex: zIndex,
      snapToGrid: _prefabSnapToGrid,
    );
    final nextPrefabs = _data.prefabs
        .where((prefab) => prefab.id != id)
        .toList(growable: false);
    _updateState(() {
      _data = _data.copyWith(prefabs: [...nextPrefabs, nextPrefab]);
      _statusMessage = 'Upserted prefab "$id".';
      _errorMessage = null;
    });
  }

  void _loadPrefabIntoForm(PrefabDef prefab) {
    final collider = prefab.colliders.isEmpty
        ? const PrefabColliderDef(offsetX: 0, offsetY: 0, width: 16, height: 16)
        : prefab.colliders.first;
    _updateState(() {
      _prefabIdController.text = prefab.id;
      _selectedPrefabSliceId = prefab.sliceId;
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
    });
  }

  void _deletePrefab(String prefabId) {
    _updateState(() {
      _data = _data.copyWith(
        prefabs: _data.prefabs
            .where((prefab) => prefab.id != prefabId)
            .toList(growable: false),
      );
      _statusMessage = 'Deleted prefab "$prefabId".';
      _errorMessage = null;
    });
  }
}
