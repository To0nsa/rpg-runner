import '../../../../prefabs/models/models.dart';

/// Whether the Prefab kind participates in collision authoring.
bool canAuthorPrefabCollision(PrefabV3Def? prefab) =>
    prefab?.kind == PrefabKind.obstacle || prefab?.kind == PrefabKind.platform;

/// Stable UI ordering shared by Prefab catalogs and workspace selection.
int comparePrefabOwners(PrefabV3Def left, PrefabV3Def right) {
  final kindOrder = _prefabKindOrder(left.kind)
      .compareTo(_prefabKindOrder(right.kind));
  if (kindOrder != 0) return kindOrder;
  final idOrder = left.id.compareTo(right.id);
  return idOrder != 0 ? idOrder : left.prefabKey.compareTo(right.prefabKey);
}

int _prefabKindOrder(PrefabKind kind) => switch (kind) {
  PrefabKind.obstacle => 0,
  PrefabKind.platform => 1,
  PrefabKind.decoration => 2,
  PrefabKind.unknown => 3,
};
