import 'package:meta/meta.dart';

import '../terrain_authoring/terrain_source_models.dart';
import 'chunk_domain_models.dart';

/// Polygon-authoring chunk source schema promoted for the Phase 4 cutover.
const int chunkSchemaVersionV2 = 2;

/// Immutable normal-layer representation of one chunk-schema-v2 source file.
///
/// One file owns one chunk, so this record carries both retained composition
/// metadata and direct chunk-local polygon source. Construction snapshots but
/// does not reorder supplied collections; strict decoding diagnoses
/// noncanonical source and [ChunkV2FileCodec] canonicalizes only export copies.
@immutable
final class ChunkV2FileData {
  ChunkV2FileData({
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
  }) : tags = List<String>.unmodifiable(tags),
       tileLayers = List<TileLayerDef>.unmodifiable(tileLayers),
       prefabs = List<PlacedPrefabDef>.unmodifiable(prefabs),
       markers = List<PlacedMarkerDef>.unmodifiable(markers),
       collisionShapes = List<TerrainSourceShapeDef>.unmodifiable(
         collisionShapes,
       );

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

  /// Direct chunk-local loops in exact half-pixel source ticks.
  final List<TerrainSourceShapeDef> collisionShapes;

  ChunkV2FileData copyWith({
    String? chunkKey,
    String? id,
    int? revision,
    String? status,
    String? levelId,
    int? tileSize,
    int? width,
    int? height,
    String? difficulty,
    String? assemblyGroupId,
    Iterable<String>? tags,
    Iterable<TileLayerDef>? tileLayers,
    Iterable<PlacedPrefabDef>? prefabs,
    Iterable<PlacedMarkerDef>? markers,
    int? groundBandZIndex,
    Iterable<TerrainSourceShapeDef>? collisionShapes,
  }) => ChunkV2FileData(
    chunkKey: chunkKey ?? this.chunkKey,
    id: id ?? this.id,
    revision: revision ?? this.revision,
    status: status ?? this.status,
    levelId: levelId ?? this.levelId,
    tileSize: tileSize ?? this.tileSize,
    width: width ?? this.width,
    height: height ?? this.height,
    difficulty: difficulty ?? this.difficulty,
    assemblyGroupId: assemblyGroupId ?? this.assemblyGroupId,
    tags: tags ?? this.tags,
    tileLayers: tileLayers ?? this.tileLayers,
    prefabs: prefabs ?? this.prefabs,
    markers: markers ?? this.markers,
    groundBandZIndex: groundBandZIndex ?? this.groundBandZIndex,
    collisionShapes: collisionShapes ?? this.collisionShapes,
  );

  Map<String, Object> toJson() => <String, Object>{
    'schemaVersion': chunkSchemaVersionV2,
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
