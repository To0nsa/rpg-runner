import 'package:flutter/material.dart';

import '../../../../prefabs/prefab_models.dart';

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
