import 'package:flutter/foundation.dart';

import '../../../../prefabs/models/models.dart';

/// UI-facing projection of prefab-local anchor/collider authoring values.
///
/// Collider offsets remain center offsets relative to the prefab anchor.
@immutable
class PrefabSceneValues {
  const PrefabSceneValues({
    required this.anchorX,
    required this.anchorY,
    required this.colliderOffsetX,
    required this.colliderOffsetY,
    required this.colliderWidth,
    required this.colliderHeight,
  });

  final int anchorX;
  final int anchorY;
  final int colliderOffsetX;
  final int colliderOffsetY;
  final int colliderWidth;
  final int colliderHeight;
}

PrefabSceneValues? prefabSceneValuesFromPrefab(PrefabDef prefab) {
  if (prefab.colliders.isEmpty) {
    return null;
  }
  final collider = prefab.colliders.first;
  return PrefabSceneValues(
    anchorX: prefab.anchorXPx,
    anchorY: prefab.anchorYPx,
    colliderOffsetX: collider.offsetX,
    colliderOffsetY: collider.offsetY,
    colliderWidth: collider.width,
    colliderHeight: collider.height,
  );
}
