import '../prefabs/models/models.dart';
import 'chunk_domain_models.dart';

class RuntimePrefabCollider {
  const RuntimePrefabCollider({
    required this.offsetX,
    required this.offsetY,
    required this.width,
    required this.height,
  });

  final int offsetX;
  final int offsetY;
  final int width;
  final int height;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'offsetX': offsetX,
      'offsetY': offsetY,
      'width': width,
      'height': height,
    };
  }
}

class RuntimePrefabContract {
  const RuntimePrefabContract({
    required this.prefabKey,
    required this.prefabId,
    required this.revision,
    required this.status,
    required this.kind,
    required this.visualSourceType,
    required this.visualSourceRefId,
    required this.anchorXPx,
    required this.anchorYPx,
    required this.colliders,
    required this.tags,
  });

  final String prefabKey;
  final String prefabId;
  final int revision;
  final String status;
  final String kind;
  final String visualSourceType;
  final String visualSourceRefId;
  final int anchorXPx;
  final int anchorYPx;
  final List<RuntimePrefabCollider> colliders;
  final List<String> tags;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'prefabKey': prefabKey,
      'prefabId': prefabId,
      'revision': revision,
      'status': status,
      'kind': kind,
      'visualSourceType': visualSourceType,
      'visualSourceRefId': visualSourceRefId,
      'anchorXPx': anchorXPx,
      'anchorYPx': anchorYPx,
      'colliders': colliders
          .map((collider) => collider.toJson())
          .toList(growable: false),
      'tags': tags,
    };
  }
}

class RuntimeChunkPrefabRef {
  const RuntimeChunkPrefabRef({
    required this.prefabKey,
    required this.legacyPrefabId,
    required this.x,
    required this.y,
    required this.zIndex,
    required this.snapToGrid,
    required this.scale,
  });

  final String prefabKey;
  final String legacyPrefabId;
  final int x;
  final int y;
  final int zIndex;
  final bool snapToGrid;
  final double scale;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'prefabKey': prefabKey,
      'prefabId': legacyPrefabId,
      'x': x,
      'y': y,
      'zIndex': zIndex,
      'snapToGrid': snapToGrid,
      if ((scale - defaultPrefabPlacementScale).abs() >= 1e-9) 'scale': scale,
    };
  }
}

RuntimePrefabContract? mapPrefabToRuntimeContract(
  PrefabDef prefab, {
  bool includeDeprecated = false,
}) {
  if (!includeDeprecated && prefab.status == PrefabStatus.deprecated) {
    return null;
  }
  if (prefab.prefabKey.isEmpty || prefab.id.isEmpty || prefab.revision <= 0) {
    return null;
  }
  if (prefab.kind == PrefabKind.unknown) {
    return null;
  }
  if (prefab.visualSource.type == PrefabVisualSourceType.unknown) {
    return null;
  }

  final sourceRefId = prefab.sourceRefId;
  if (sourceRefId.isEmpty) {
    return null;
  }

  return RuntimePrefabContract(
    prefabKey: prefab.prefabKey,
    prefabId: prefab.id,
    revision: prefab.revision,
    status: prefab.status.jsonValue,
    kind: prefab.kind.jsonValue,
    visualSourceType: prefab.visualSource.type.jsonValue,
    visualSourceRefId: sourceRefId,
    anchorXPx: prefab.anchorXPx,
    anchorYPx: prefab.anchorYPx,
    colliders: prefab.colliders
        .map(
          (collider) => RuntimePrefabCollider(
            offsetX: collider.offsetX,
            offsetY: collider.offsetY,
            width: collider.width,
            height: collider.height,
          ),
        )
        .toList(growable: false),
    tags: List<String>.from(prefab.tags),
  );
}

List<RuntimePrefabContract> buildRuntimePrefabContracts(
  PrefabData data, {
  bool includeDeprecated = false,
}) {
  final mapped =
      data.prefabs
          .map(
            (prefab) => mapPrefabToRuntimeContract(
              prefab,
              includeDeprecated: includeDeprecated,
            ),
          )
          .whereType<RuntimePrefabContract>()
          .toList(growable: false)
        ..sort((a, b) {
          final keyCompare = a.prefabKey.compareTo(b.prefabKey);
          if (keyCompare != 0) {
            return keyCompare;
          }
          return a.prefabId.compareTo(b.prefabId);
        });
  return mapped;
}

RuntimeChunkPrefabRef mapPlacedPrefabToRuntimeRef(
  PlacedPrefabDef placedPrefab,
) {
  final prefabKey = placedPrefab.prefabKey.isNotEmpty
      ? placedPrefab.prefabKey
      : placedPrefab.prefabId;
  return RuntimeChunkPrefabRef(
    prefabKey: prefabKey,
    legacyPrefabId: placedPrefab.prefabId,
    x: placedPrefab.x,
    y: placedPrefab.y,
    zIndex: placedPrefab.zIndex,
    snapToGrid: placedPrefab.snapToGrid,
    scale: placedPrefab.scale,
  );
}
