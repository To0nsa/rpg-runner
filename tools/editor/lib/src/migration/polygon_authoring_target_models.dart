import '../chunks/chunk_domain_models.dart';
import '../chunks/chunk_v2_file_data.dart';
import '../prefabs/models/models.dart';
import '../prefabs/store/prefab_determinism.dart';
import '../terrain_authoring/terrain_source_models.dart';
import 'legacy_prefab_models.dart';

/// Polygon-authoring prefab source schema staged for the one-time cutover.
const int polygonPrefabSchemaVersion = prefabSchemaVersionV3;

/// Polygon-authoring chunk source schema staged for the one-time cutover.
const int polygonChunkSchemaVersion = chunkSchemaVersionV2;

/// Migration-facing alias for the normal prefab-v3 polygon record.
typedef PrefabV3TargetDef = PrefabV3Def;

/// Migration-facing alias for the normal prefab-v3 source-file record.
typedef PrefabV3TargetDocument = PrefabV3FileData;

/// Preserves all rectangle-era metadata while replacing only collision source.
PrefabV3TargetDef prefabV3TargetFromLegacy({
  required LegacyPrefabDef legacy,
  required Iterable<TerrainSourceShapeDef> collisionShapes,
}) => PrefabV3Def(
  prefabKey: legacy.prefabKey,
  id: legacy.id,
  revision: legacy.revision,
  status: legacy.status,
  kind: legacy.kind,
  visualSource: legacy.visualSource,
  anchorXPx: legacy.anchorXPx,
  anchorYPx: legacy.anchorYPx,
  collisionShapes: canonicalTerrainSourceShapes(collisionShapes),
  tags: _canonicalTags(legacy.tags),
);

/// Migration-facing alias for the normal chunk-v2 polygon file record.
typedef ChunkV2TargetDocument = ChunkV2FileData;

/// Preserves legacy chunk metadata while replacing flat ground and gaps.
ChunkV2TargetDocument chunkV2TargetFromLegacy({
  required LevelChunkDef legacy,
  required Iterable<TerrainSourceShapeDef> collisionShapes,
}) => ChunkV2FileData(
  chunkKey: legacy.chunkKey,
  id: legacy.id,
  revision: legacy.revision,
  status: legacy.status,
  levelId: legacy.levelId,
  tileSize: legacy.tileSize,
  width: legacy.width,
  height: legacy.height,
  difficulty: legacy.difficulty,
  assemblyGroupId: legacy.assemblyGroupId,
  tags: _canonicalTags(legacy.tags),
  tileLayers: List<TileLayerDef>.of(legacy.tileLayers)
    ..sort((left, right) => left.id.compareTo(right.id)),
  prefabs: List<PlacedPrefabDef>.of(legacy.prefabs)
    ..sort(comparePlacedPrefabsDeterministic),
  markers: List<PlacedMarkerDef>.of(legacy.markers)
    ..sort(comparePlacedMarkersDeterministic),
  groundBandZIndex: legacy.groundBandZIndex,
  collisionShapes: canonicalTerrainSourceShapes(collisionShapes),
);

List<String> _canonicalTags(Iterable<String> tags) {
  return PrefabDeterminism.normalizeTags(tags.toList(growable: false));
}
