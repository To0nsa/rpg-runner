import 'chunk_domain_models.dart';

/// Canonicalizes Chunk-v2 tile-layer metadata for a composition commit.
List<TileLayerDef> canonicalizeChunkTileLayers(Iterable<TileLayerDef> layers) =>
    List<TileLayerDef>.of(layers)
      ..sort((left, right) => left.id.compareTo(right.id));

/// Canonicalizes Chunk-v2 prefab placements for a composition commit.
List<PlacedPrefabDef> canonicalizeChunkPrefabs(
  Iterable<PlacedPrefabDef> prefabs,
) => List<PlacedPrefabDef>.of(prefabs)..sort(comparePlacedPrefabsDeterministic);

/// Canonicalizes Chunk-v2 enemy markers for a composition commit.
List<PlacedMarkerDef> canonicalizeChunkMarkers(
  Iterable<PlacedMarkerDef> markers,
) => List<PlacedMarkerDef>.of(markers)..sort(comparePlacedMarkersDeterministic);

/// Returns whether two tile-layer metadata records are semantically equal.
bool chunkTileLayersEqual(TileLayerDef left, TileLayerDef right) =>
    left.id == right.id &&
    left.kind == right.kind &&
    left.visible == right.visible;

/// Returns whether two prefab placement records are semantically equal.
bool chunkPrefabsEqual(PlacedPrefabDef left, PlacedPrefabDef right) =>
    left.prefabId == right.prefabId &&
    left.prefabKey == right.prefabKey &&
    left.x == right.x &&
    left.y == right.y &&
    left.zIndex == right.zIndex &&
    left.snapToGrid == right.snapToGrid &&
    left.scale == right.scale &&
    left.flipX == right.flipX &&
    left.flipY == right.flipY;

/// Returns whether two enemy marker records are semantically equal.
bool chunkMarkersEqual(PlacedMarkerDef left, PlacedMarkerDef right) =>
    left.markerId == right.markerId &&
    left.x == right.x &&
    left.y == right.y &&
    left.chancePercent == right.chancePercent &&
    left.salt == right.salt &&
    left.placement == right.placement;

/// Compares two lists using one domain-specific semantic equality function.
bool chunkCompositionListsEqual<T>(
  List<T> left,
  List<T> right,
  bool Function(T left, T right) equals,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (!equals(left[index], right[index])) return false;
  }
  return true;
}
