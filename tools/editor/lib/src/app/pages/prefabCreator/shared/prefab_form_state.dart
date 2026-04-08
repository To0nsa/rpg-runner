import 'package:flutter/material.dart';

import '../../../../prefabs/models/models.dart';
import 'prefab_scene_values.dart';

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
    required this.tags,
    required this.zIndex,
    required this.snapToGrid,
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
  final String tags;
  final String zIndex;
  final bool snapToGrid;
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
        other.tags == tags &&
        other.zIndex == zIndex &&
        other.snapToGrid == snapToGrid &&
        other.autoManagePlatformModule == autoManagePlatformModule &&
        other.selectedKind == selectedKind &&
        other.editingPrefabKey == editingPrefabKey;
  }

  @override
  int get hashCode => Object.hashAll([
    prefabId,
    anchorX,
    anchorY,
    colliderOffsetX,
    colliderOffsetY,
    colliderWidth,
    colliderHeight,
    tags,
    zIndex,
    snapToGrid,
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
  final TextEditingController zIndexController = TextEditingController();

  bool snapToGrid = true;
  bool autoManagePlatformModule = true;
  PrefabKind selectedKind = PrefabKind.unknown;
  String? editingPrefabKey;

  PrefabFormDraftSnapshot captureDraftSnapshot() {
    return PrefabFormDraftSnapshot(
      prefabId: prefabIdController.text,
      anchorX: anchorXController.text,
      anchorY: anchorYController.text,
      colliderOffsetX: colliderOffsetXController.text,
      colliderOffsetY: colliderOffsetYController.text,
      colliderWidth: colliderWidthController.text,
      colliderHeight: colliderHeightController.text,
      tags: tagsController.text,
      zIndex: zIndexController.text,
      snapToGrid: snapToGrid,
      autoManagePlatformModule: autoManagePlatformModule,
      selectedKind: selectedKind,
      editingPrefabKey: editingPrefabKey,
    );
  }

  void restoreDraftSnapshot(PrefabFormDraftSnapshot snapshot) {
    prefabIdController.text = snapshot.prefabId;
    anchorXController.text = snapshot.anchorX;
    anchorYController.text = snapshot.anchorY;
    colliderOffsetXController.text = snapshot.colliderOffsetX;
    colliderOffsetYController.text = snapshot.colliderOffsetY;
    colliderWidthController.text = snapshot.colliderWidth;
    colliderHeightController.text = snapshot.colliderHeight;
    tagsController.text = snapshot.tags;
    zIndexController.text = snapshot.zIndex;
    snapToGrid = snapshot.snapToGrid;
    autoManagePlatformModule = snapshot.autoManagePlatformModule;
    selectedKind = snapshot.selectedKind;
    editingPrefabKey = snapshot.editingPrefabKey;
  }

  PrefabSceneValues? tryParseSceneValues() {
    final anchorX = int.tryParse(anchorXController.text.trim());
    final anchorY = int.tryParse(anchorYController.text.trim());
    final colliderOffsetX = int.tryParse(colliderOffsetXController.text.trim());
    final colliderOffsetY = int.tryParse(colliderOffsetYController.text.trim());
    final colliderWidth = int.tryParse(colliderWidthController.text.trim());
    final colliderHeight = int.tryParse(colliderHeightController.text.trim());
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

  void applySceneValues(PrefabSceneValues values) {
    anchorXController.text = values.anchorX.toString();
    anchorYController.text = values.anchorY.toString();
    colliderOffsetXController.text = values.colliderOffsetX.toString();
    colliderOffsetYController.text = values.colliderOffsetY.toString();
    colliderWidthController.text = values.colliderWidth.toString();
    colliderHeightController.text = values.colliderHeight.toString();
  }

  void resetObstacleDefaults() {
    prefabIdController.clear();
    anchorXController.text = '0';
    anchorYController.text = '0';
    colliderOffsetXController.text = '0';
    colliderOffsetYController.text = '0';
    colliderWidthController.text = '16';
    colliderHeightController.text = '16';
    tagsController.clear();
    zIndexController.text = '0';
    snapToGrid = true;
    autoManagePlatformModule = true;
    selectedKind = PrefabKind.obstacle;
    editingPrefabKey = null;
  }

  void resetPlatformDefaults({int tileSize = 16}) {
    final size = tileSize > 0 ? tileSize : 16;
    final tileSizeText = size.toString();
    prefabIdController.clear();
    anchorXController.text = '0';
    anchorYController.text = '0';
    colliderOffsetXController.text = '0';
    colliderOffsetYController.text = '0';
    colliderWidthController.text = tileSizeText;
    colliderHeightController.text = tileSizeText;
    tagsController.clear();
    zIndexController.text = '0';
    snapToGrid = true;
    autoManagePlatformModule = true;
    selectedKind = PrefabKind.platform;
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
    zIndexController.dispose();
  }
}
