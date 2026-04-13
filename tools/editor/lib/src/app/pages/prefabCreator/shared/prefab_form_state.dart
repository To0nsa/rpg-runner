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
        other.tags == tags &&
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
    autoManagePlatformModule = snapshot.autoManagePlatformModule;
    selectedKind = snapshot.selectedKind;
    editingPrefabKey = snapshot.editingPrefabKey;
  }

  PrefabSceneValues? tryParseSceneValues() {
    final anchor = tryParseAnchorValues();
    if (anchor == null) {
      return null;
    }
    final colliderOffsetX = int.tryParse(colliderOffsetXController.text.trim());
    final colliderOffsetY = int.tryParse(colliderOffsetYController.text.trim());
    final colliderWidth = int.tryParse(colliderWidthController.text.trim());
    final colliderHeight = int.tryParse(colliderHeightController.text.trim());
    if (colliderOffsetX == null ||
        colliderOffsetY == null ||
        colliderWidth == null ||
        colliderHeight == null) {
      return null;
    }
    if (colliderWidth <= 0 || colliderHeight <= 0) {
      return null;
    }
    return PrefabSceneValues(
      anchorX: anchor.anchorX,
      anchorY: anchor.anchorY,
      colliderOffsetX: colliderOffsetX,
      colliderOffsetY: colliderOffsetY,
      colliderWidth: colliderWidth,
      colliderHeight: colliderHeight,
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
    colliderOffsetXController.text = values.colliderOffsetX.toString();
    colliderOffsetYController.text = values.colliderOffsetY.toString();
    colliderWidthController.text = values.colliderWidth.toString();
    colliderHeightController.text = values.colliderHeight.toString();
  }

  void applyAnchorValues(PrefabAnchorValues values) {
    anchorXController.text = values.anchorX.toString();
    anchorYController.text = values.anchorY.toString();
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
    autoManagePlatformModule = true;
    selectedKind = PrefabKind.platform;
    editingPrefabKey = null;
  }

  void resetDecorationDefaults() {
    prefabIdController.clear();
    anchorXController.text = '0';
    anchorYController.text = '0';
    // Decoration prefabs intentionally do not export colliders.
    colliderOffsetXController.text = '0';
    colliderOffsetYController.text = '0';
    colliderWidthController.text = '16';
    colliderHeightController.text = '16';
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
}
