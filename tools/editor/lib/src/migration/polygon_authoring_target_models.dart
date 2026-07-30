import '../chunks/chunk_domain_models.dart';
import '../prefabs/models/models.dart';
import '../prefabs/store/prefab_determinism.dart';
import '../terrain_authoring/terrain_source_models.dart';
import 'legacy_prefab_models.dart';

/// Polygon-authoring prefab source schema staged for the one-time cutover.
const int polygonPrefabSchemaVersion = prefabSchemaVersionV3;

/// Polygon-authoring chunk source schema staged for the one-time cutover.
const int polygonChunkSchemaVersion = 2;

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

/// One complete staged chunk-v2 file with direct chunk-local terrain source.
final class ChunkV2TargetDocument {
  ChunkV2TargetDocument({
    required this.chunkKey,
    required this.id,
    required this.revision,
    required this.status,
    required this.levelId,
    required this.tileSize,
    required this.width,
    required this.height,
    required this.difficulty,
    required this.assemblyGroupId,
    required Iterable<String> tags,
    required Iterable<TileLayerDef> tileLayers,
    required Iterable<PlacedPrefabDef> prefabs,
    required Iterable<PlacedMarkerDef> markers,
    required this.groundBandZIndex,
    required Iterable<TerrainSourceShapeDef> collisionShapes,
  }) : tags = List<String>.unmodifiable(_canonicalTags(tags)),
       tileLayers = List<TileLayerDef>.unmodifiable(
         List<TileLayerDef>.of(tileLayers)
           ..sort((left, right) => left.id.compareTo(right.id)),
       ),
       prefabs = List<PlacedPrefabDef>.unmodifiable(
         List<PlacedPrefabDef>.of(prefabs)
           ..sort(comparePlacedPrefabsDeterministic),
       ),
       markers = List<PlacedMarkerDef>.unmodifiable(
         List<PlacedMarkerDef>.of(markers)
           ..sort(comparePlacedMarkersDeterministic),
       ),
       collisionShapes = canonicalTerrainSourceShapes(collisionShapes);

  final String chunkKey;
  final String id;
  final int revision;
  final String status;
  final String levelId;
  final int tileSize;

  /// Closed chunk dimensions in whole source pixels.
  final int width;
  final int height;

  final String difficulty;
  final String assemblyGroupId;
  final List<String> tags;
  final List<TileLayerDef> tileLayers;
  final List<PlacedPrefabDef> prefabs;
  final List<PlacedMarkerDef> markers;

  /// Visual-only ground-band layer retained through the Phase 4 bridge.
  final int groundBandZIndex;

  /// Canonical direct chunk-local loops in half-pixel source units.
  final List<TerrainSourceShapeDef> collisionShapes;

  /// Preserves legacy chunk metadata while replacing flat ground and gaps.
  factory ChunkV2TargetDocument.fromLegacy({
    required LevelChunkDef legacy,
    required Iterable<TerrainSourceShapeDef> collisionShapes,
  }) => ChunkV2TargetDocument(
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
    tags: legacy.tags,
    tileLayers: legacy.tileLayers,
    prefabs: legacy.prefabs,
    markers: legacy.markers,
    groundBandZIndex: legacy.groundBandZIndex,
    collisionShapes: collisionShapes,
  );

  Map<String, Object> toJson() => <String, Object>{
    'schemaVersion': polygonChunkSchemaVersion,
    'chunkKey': chunkKey,
    'id': id,
    'revision': revision,
    'status': status,
    'levelId': levelId,
    'tileSize': tileSize,
    'width': width,
    'height': height,
    'difficulty': difficulty,
    'assemblyGroupId': assemblyGroupId,
    'tags': tags,
    'tileLayers': tileLayers
        .map((layer) => layer.toJson())
        .toList(growable: false),
    'prefabs': prefabs.map((prefab) => prefab.toJson()).toList(growable: false),
    'markers': markers.map((marker) => marker.toJson()).toList(growable: false),
    if (groundBandZIndex != 0) 'groundBandZIndex': groundBandZIndex,
    'collisionShapes': terrainSourceShapesToJson(collisionShapes),
  };
}

List<String> _canonicalTags(Iterable<String> tags) {
  return PrefabDeterminism.normalizeTags(tags.toList(growable: false));
}
