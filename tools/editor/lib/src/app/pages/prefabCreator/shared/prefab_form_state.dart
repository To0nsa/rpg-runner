import 'package:flutter/material.dart';

import '../../../../prefabs/models/models.dart';
import 'prefab_scene_values.dart';

@immutable
class PrefabAnchorValues {
  const PrefabAnchorValues({required this.anchorX, required this.anchorY});

  final int anchorX;
  final int anchorY;
}

@immutable
class PrefabFormDraftSnapshot {
  const PrefabFormDraftSnapshot({
    required this.prefabId,
    required this.anchorX,
    required this.anchorY,
    required this.colliderOffsetX,
    required this.colliderOffsetY,
    required this.colliderWidth,
    required this.colliderHeight,
    required this.colliders,
    required this.selectedColliderIndex,
    required this.tags,
    required this.autoManagePlatformModule,
    required this.selectedKind,
    required this.editingPrefabKey,
  });

  final String prefabId;
  final String anchorX;
  final String anchorY;
  final String colliderOffsetX;
  final String colliderOffsetY;
  final String colliderWidth;
  final String colliderHeight;
  final List<PrefabColliderDef> colliders;
  final int? selectedColliderIndex;
  final String tags;
  final bool autoManagePlatformModule;
  final PrefabKind selectedKind;
  final String? editingPrefabKey;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PrefabFormDraftSnapshot &&
        other.prefabId == prefabId &&
        other.anchorX == anchorX &&
        other.anchorY == anchorY &&
        other.colliderOffsetX == colliderOffsetX &&
        other.colliderOffsetY == colliderOffsetY &&
        other.colliderWidth == colliderWidth &&
        other.colliderHeight == colliderHeight &&
        _colliderListsEqual(other.colliders, colliders) &&
        other.selectedColliderIndex == selectedColliderIndex &&
        other.tags == tags &&
        other.autoManagePlatformModule == autoManagePlatformModule &&
        other.selectedKind == selectedKind &&
        other.editingPrefabKey == editingPrefabKey;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    prefabId,
    anchorX,
    anchorY,
    colliderOffsetX,
    colliderOffsetY,
    colliderWidth,
    colliderHeight,
    _colliderListHash(colliders),
    selectedColliderIndex,
    tags,
    autoManagePlatformModule,
    selectedKind,
    editingPrefabKey,
  ]);
}

class PrefabFormState {
  PrefabFormState.obstacle() {
    resetObstacleDefaults();
  }

  PrefabFormState.platform({int tileSize = 16}) {
    resetPlatformDefaults(tileSize: tileSize);
  }

  PrefabFormState.decoration() {
    resetDecorationDefaults();
  }

  final TextEditingController prefabIdController = TextEditingController();
  final TextEditingController anchorXController = TextEditingController();
  final TextEditingController anchorYController = TextEditingController();
  final TextEditingController colliderOffsetXController =
      TextEditingController();
  final TextEditingController colliderOffsetYController =
      TextEditingController();
  final TextEditingController colliderWidthController = TextEditingController();
  final TextEditingController colliderHeightController =
      TextEditingController();
  final TextEditingController tagsController = TextEditingController();
  bool autoManagePlatformModule = true;
  PrefabKind selectedKind = PrefabKind.unknown;
  String? editingPrefabKey;

  List<PrefabColliderDef> _colliderDrafts = const <PrefabColliderDef>[];
  int? _selectedColliderIndex;

  List<PrefabColliderDef> get colliderDrafts =>
      List<PrefabColliderDef>.unmodifiable(_colliderDrafts);

  int? get selectedColliderIndex => _normalizedColliderSelectionIndex(
    _colliderDrafts,
    _selectedColliderIndex,
  );

  bool get canDeleteSelectedCollider => _colliderDrafts.length > 1;

  PrefabFormDraftSnapshot captureDraftSnapshot() {
    _syncSelectedColliderDraftFromControllers();
    return PrefabFormDraftSnapshot(
      prefabId: prefabIdController.text,
      anchorX: anchorXController.text,
      anchorY: anchorYController.text,
      colliderOffsetX: colliderOffsetXController.text,
      colliderOffsetY: colliderOffsetYController.text,
      colliderWidth: colliderWidthController.text,
      colliderHeight: colliderHeightController.text,
      colliders: List<PrefabColliderDef>.unmodifiable(_colliderDrafts),
      selectedColliderIndex: selectedColliderIndex,
      tags: tagsController.text,
      autoManagePlatformModule: autoManagePlatformModule,
      selectedKind: selectedKind,
      editingPrefabKey: editingPrefabKey,
    );
  }

  void restoreDraftSnapshot(PrefabFormDraftSnapshot snapshot) {
    _colliderDrafts = snapshot.colliders.toList(growable: true);
    _selectedColliderIndex = _normalizedColliderSelectionIndex(
      _colliderDrafts,
      snapshot.selectedColliderIndex,
    );
    prefabIdController.text = snapshot.prefabId;
    anchorXController.text = snapshot.anchorX;
    anchorYController.text = snapshot.anchorY;
    colliderOffsetXController.text = snapshot.colliderOffsetX;
    colliderOffsetYController.text = snapshot.colliderOffsetY;
    colliderWidthController.text = snapshot.colliderWidth;
    colliderHeightController.text = snapshot.colliderHeight;
    tagsController.text = snapshot.tags;
    autoManagePlatformModule = snapshot.autoManagePlatformModule;
    selectedKind = snapshot.selectedKind;
    editingPrefabKey = snapshot.editingPrefabKey;
  }

  List<PrefabColliderDef>? tryParseColliderDrafts() {
    if (!_syncSelectedColliderDraftFromControllers()) {
      return null;
    }
    return List<PrefabColliderDef>.unmodifiable(_colliderDrafts);
  }

  PrefabSceneValues? tryParseSceneValues() {
    final anchor = tryParseAnchorValues();
    if (anchor == null) {
      return null;
    }
    final colliders = tryParseColliderDrafts();
    if (colliders == null) {
      return null;
    }
    return PrefabSceneValues(
      anchorX: anchor.anchorX,
      anchorY: anchor.anchorY,
      colliders: colliders,
      selectedColliderIndex: selectedColliderIndex,
    );
  }

  PrefabAnchorValues? tryParseAnchorValues() {
    final anchorX = int.tryParse(anchorXController.text.trim());
    final anchorY = int.tryParse(anchorYController.text.trim());
    if (anchorX == null || anchorY == null) {
      return null;
    }
    return PrefabAnchorValues(anchorX: anchorX, anchorY: anchorY);
  }

  void applySceneValues(PrefabSceneValues values) {
    anchorXController.text = values.anchorX.toString();
    anchorYController.text = values.anchorY.toString();
    setColliderDrafts(
      values.colliders,
      selectedIndex: values.normalizedSelectedColliderIndex,
    );
  }

  void applyAnchorValues(PrefabAnchorValues values) {
    anchorXController.text = values.anchorX.toString();
    anchorYController.text = values.anchorY.toString();
  }

  void setColliderDrafts(
    List<PrefabColliderDef> colliders, {
    int? selectedIndex,
  }) {
    _colliderDrafts = colliders.toList(growable: true);
    _selectedColliderIndex = _normalizedColliderSelectionIndex(
      _colliderDrafts,
      selectedIndex,
    );
    _applySelectedColliderToControllers();
  }

  String? selectCollider(int index) {
    if (!_syncSelectedColliderDraftFromControllers()) {
      return 'Collider fields must be valid integers with positive width and height.';
    }
    final nextIndex = _normalizedColliderSelectionIndex(_colliderDrafts, index);
    if (nextIndex == null) {
      return 'Select or add a collider first.';
    }
    _selectedColliderIndex = nextIndex;
    _applySelectedColliderToControllers();
    return null;
  }

  String? addCollider({PrefabColliderDef? collider}) {
    if (!_syncSelectedColliderDraftFromControllers()) {
      return 'Collider fields must be valid integers with positive width and height.';
    }
    _colliderDrafts = <PrefabColliderDef>[
      ..._colliderDrafts,
      collider ??
          const PrefabColliderDef(
            offsetX: 0,
            offsetY: 0,
            width: 16,
            height: 16,
          ),
    ];
    _selectedColliderIndex = _colliderDrafts.length - 1;
    _applySelectedColliderToControllers();
    return null;
  }

  String? duplicateSelectedCollider() {
    if (!_syncSelectedColliderDraftFromControllers()) {
      return 'Collider fields must be valid integers with positive width and height.';
    }
    final collider = _selectedColliderDraft();
    if (collider == null) {
      return 'Select or add a collider first.';
    }
    _colliderDrafts = <PrefabColliderDef>[..._colliderDrafts, collider];
    _selectedColliderIndex = _colliderDrafts.length - 1;
    _applySelectedColliderToControllers();
    return null;
  }

  String? deleteSelectedCollider() {
    if (!_syncSelectedColliderDraftFromControllers()) {
      return 'Collider fields must be valid integers with positive width and height.';
    }
    final index = selectedColliderIndex;
    if (index == null) {
      return 'Select or add a collider first.';
    }
    if (_colliderDrafts.length <= 1) {
      return 'Obstacle and platform prefabs must keep at least one collider.';
    }
    final next = _colliderDrafts.toList(growable: true)..removeAt(index);
    _colliderDrafts = next;
    _selectedColliderIndex = index >= next.length ? next.length - 1 : index;
    _applySelectedColliderToControllers();
    return null;
  }

  void resetObstacleDefaults() {
    prefabIdController.clear();
    anchorXController.text = '0';
    anchorYController.text = '0';
    setColliderDrafts(const <PrefabColliderDef>[
      PrefabColliderDef(offsetX: 0, offsetY: 0, width: 16, height: 16),
    ]);
    tagsController.clear();
    autoManagePlatformModule = true;
    selectedKind = PrefabKind.obstacle;
    editingPrefabKey = null;
  }

  void resetPlatformDefaults({int tileSize = 16}) {
    final size = tileSize > 0 ? tileSize : 16;
    prefabIdController.clear();
    anchorXController.text = '0';
    anchorYController.text = '0';
    setColliderDrafts(<PrefabColliderDef>[
      PrefabColliderDef(offsetX: 0, offsetY: 0, width: size, height: size),
    ]);
    tagsController.clear();
    autoManagePlatformModule = true;
    selectedKind = PrefabKind.platform;
    editingPrefabKey = null;
  }

  void resetDecorationDefaults() {
    prefabIdController.clear();
    anchorXController.text = '0';
    anchorYController.text = '0';
    _colliderDrafts = const <PrefabColliderDef>[];
    _selectedColliderIndex = null;
    _resetColliderTextControllers();
    tagsController.clear();
    autoManagePlatformModule = true;
    selectedKind = PrefabKind.decoration;
    editingPrefabKey = null;
  }

  void dispose() {
    prefabIdController.dispose();
    anchorXController.dispose();
    anchorYController.dispose();
    colliderOffsetXController.dispose();
    colliderOffsetYController.dispose();
    colliderWidthController.dispose();
    colliderHeightController.dispose();
    tagsController.dispose();
  }

  bool _syncSelectedColliderDraftFromControllers() {
    final index = selectedColliderIndex;
    if (index == null) {
      return true;
    }
    final colliderOffsetX = int.tryParse(colliderOffsetXController.text.trim());
    final colliderOffsetY = int.tryParse(colliderOffsetYController.text.trim());
    final colliderWidth = int.tryParse(colliderWidthController.text.trim());
    final colliderHeight = int.tryParse(colliderHeightController.text.trim());
    if (colliderOffsetX == null ||
        colliderOffsetY == null ||
        colliderWidth == null ||
        colliderHeight == null ||
        colliderWidth <= 0 ||
        colliderHeight <= 0) {
      return false;
    }
    _colliderDrafts[index] = PrefabColliderDef(
      offsetX: colliderOffsetX,
      offsetY: colliderOffsetY,
      width: colliderWidth,
      height: colliderHeight,
    );
    return true;
  }

  PrefabColliderDef? _selectedColliderDraft() {
    final index = selectedColliderIndex;
    if (index == null) {
      return null;
    }
    return _colliderDrafts[index];
  }

  void _applySelectedColliderToControllers() {
    final collider = _selectedColliderDraft();
    if (collider == null) {
      _resetColliderTextControllers();
      return;
    }
    colliderOffsetXController.text = collider.offsetX.toString();
    colliderOffsetYController.text = collider.offsetY.toString();
    colliderWidthController.text = collider.width.toString();
    colliderHeightController.text = collider.height.toString();
  }

  void _resetColliderTextControllers({int size = 16}) {
    colliderOffsetXController.text = '0';
    colliderOffsetYController.text = '0';
    colliderWidthController.text = size.toString();
    colliderHeightController.text = size.toString();
  }
}

int? _normalizedColliderSelectionIndex(
  List<PrefabColliderDef> colliders,
  int? selectedIndex,
) {
  if (colliders.isEmpty) {
    return null;
  }
  if (selectedIndex == null || selectedIndex < 0) {
    return 0;
  }
  if (selectedIndex >= colliders.length) {
    return colliders.length - 1;
  }
  return selectedIndex;
}

bool _colliderListsEqual(List<PrefabColliderDef> a, List<PrefabColliderDef> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i += 1) {
    final left = a[i];
    final right = b[i];
    if (left.offsetX != right.offsetX ||
        left.offsetY != right.offsetY ||
        left.width != right.width ||
        left.height != right.height) {
      return false;
    }
  }
  return true;
}

int _colliderListHash(List<PrefabColliderDef> colliders) {
  return Object.hashAll(
    colliders.map(
      (collider) => Object.hash(
        collider.offsetX,
        collider.offsetY,
        collider.width,
        collider.height,
      ),
    ),
  );
}
