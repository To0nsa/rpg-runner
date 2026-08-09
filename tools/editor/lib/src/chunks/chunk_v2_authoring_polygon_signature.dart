import 'package:runner_core/collision/terrain/terrain_authoring_polygon_signature.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';

import '../prefabs/models/models.dart';
import '../terrain_authoring/terrain_source_models.dart';
import 'chunk_v2_collision_expansion.dart';
import 'chunk_v2_file_data.dart';

/// Builds exact source records from one accepted Chunk-v2 collision expansion.
///
/// Only prefab owners proven to contribute expanded collision are included.
/// Placement count and transforms remain covered by `authoring-placement-v1`.
/// Stale chunk/prefab evidence fails before a digest can be reported.
List<TerrainAuthoringPolygonRecord> chunkV2AuthoringPolygonRecords({
  required ChunkV2FileData chunk,
  required Iterable<PrefabV3Def> prefabs,
  required ChunkV2CollisionExpansion expansion,
}) {
  if (expansion.chunkKey != chunk.chunkKey ||
      expansion.directShapeCount != chunk.collisionShapes.length) {
    throw StateError(
      'Accepted collision expansion does not match chunk ${chunk.chunkKey}.',
    );
  }

  final prefabByKey = <String, PrefabV3Def>{};
  for (final prefab in prefabs) {
    if (prefabByKey.containsKey(prefab.prefabKey)) {
      throw StateError('Duplicate prefab key ${prefab.prefabKey}.');
    }
    prefabByKey[prefab.prefabKey] = prefab;
  }
  final referencedPrefabKeys = <String>{};
  for (final expanded in expansion.expandedPrefabShapes) {
    final prefab = prefabByKey[expanded.prefabKey];
    if (prefab == null ||
        prefab.id != expanded.prefabId ||
        prefab.revision != expanded.prefabRevision ||
        !prefab.collisionShapes.any(
          (shape) => shape.shapeId == expanded.shapeId,
        )) {
      throw StateError(
        'Accepted placement ${expanded.placementKey} has stale prefab '
        'evidence for ${expanded.prefabKey}/${expanded.shapeId}.',
      );
    }
    referencedPrefabKeys.add(prefab.prefabKey);
  }

  return List<TerrainAuthoringPolygonRecord>.unmodifiable(
    <TerrainAuthoringPolygonRecord>[
      for (final shape in chunk.collisionShapes)
        _record(
          ownerKind: TerrainAuthoringPolygonOwnerKind.chunk,
          ownerKey: chunk.chunkKey,
          ownerId: chunk.id,
          ownerRevision: chunk.revision,
          shape: shape,
        ),
      for (final prefabKey in referencedPrefabKeys)
        for (final shape in prefabByKey[prefabKey]!.collisionShapes)
          _record(
            ownerKind: TerrainAuthoringPolygonOwnerKind.prefab,
            ownerKey: prefabKey,
            ownerId: prefabByKey[prefabKey]!.id,
            ownerRevision: prefabByKey[prefabKey]!.revision,
            shape: shape,
          ),
    ]..sort(),
  );
}

/// Shared `authoring-polygons-v1` digest for an accepted editor preview.
String chunkV2AuthoringPolygonSignature({
  required ChunkV2FileData chunk,
  required Iterable<PrefabV3Def> prefabs,
  required ChunkV2CollisionExpansion expansion,
}) => terrainAuthoringPolygonSignature(
  chunkV2AuthoringPolygonRecords(
    chunk: chunk,
    prefabs: prefabs,
    expansion: expansion,
  ),
);

TerrainAuthoringPolygonRecord _record({
  required TerrainAuthoringPolygonOwnerKind ownerKind,
  required String ownerKey,
  required String ownerId,
  required int ownerRevision,
  required TerrainSourceShapeDef shape,
}) => TerrainAuthoringPolygonRecord(
  ownerKind: ownerKind,
  ownerKey: ownerKey,
  ownerId: ownerId,
  ownerRevision: ownerRevision,
  shapeId: shape.shapeId,
  vertices: shape.vertices.map(
    (vertex) => SourceTerrainPoint(vertex.xHalfPixels, vertex.yHalfPixels),
  ),
  collisionMode: switch (shape.collisionMode) {
    TerrainSourceCollisionMode.solid => TerrainCollisionMode.solid,
    TerrainSourceCollisionMode.oneWay => TerrainCollisionMode.oneWay,
  },
  surfaceKind: shape.surfaceKind,
  materialKey: shape.materialKey,
);
