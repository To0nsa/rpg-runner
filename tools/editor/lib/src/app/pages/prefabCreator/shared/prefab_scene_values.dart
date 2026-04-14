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
    required this.colliders,
    this.selectedColliderIndex,
  });

  final int anchorX;
  final int anchorY;
  final List<PrefabColliderDef> colliders;
  final int? selectedColliderIndex;

  int? get normalizedSelectedColliderIndex {
    if (colliders.isEmpty) {
      return null;
    }
    if (selectedColliderIndex == null || selectedColliderIndex! < 0) {
      return 0;
    }
    if (selectedColliderIndex! >= colliders.length) {
      return colliders.length - 1;
    }
    return selectedColliderIndex;
  }

  PrefabColliderDef? get selectedCollider {
    final index = normalizedSelectedColliderIndex;
    if (index == null) {
      return null;
    }
    return colliders[index];
  }

  int get colliderOffsetX => selectedCollider?.offsetX ?? 0;
  int get colliderOffsetY => selectedCollider?.offsetY ?? 0;
  int get colliderWidth => selectedCollider?.width ?? 0;
  int get colliderHeight => selectedCollider?.height ?? 0;
}

PrefabSceneValues prefabSceneValuesFromPrefab(PrefabDef prefab) {
  return PrefabSceneValues(
    anchorX: prefab.anchorXPx,
    anchorY: prefab.anchorYPx,
    colliders: prefab.colliders,
    selectedColliderIndex: prefab.colliders.isEmpty ? null : 0,
  );
}
