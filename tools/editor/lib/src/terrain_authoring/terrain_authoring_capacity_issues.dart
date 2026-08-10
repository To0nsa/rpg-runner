import 'package:runner_core/collision/terrain/terrain_authoring_capacity.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_issue.dart';

/// Builds the non-blocking finding for a prefab above its normal shape target.
TerrainAuthoringIssue? prefabShapeSoftTargetIssue({
  required String prefabLabel,
  required int shapeCount,
  required String sourcePath,
  required String ownerKey,
}) {
  if (shapeCount <= TerrainAuthoringCapacityTargets.shapesPerPrefab) {
    return null;
  }
  return TerrainAuthoringIssue(
    severity: TerrainAuthoringIssueSeverity.warning,
    code: 'prefab_shape_soft_target_exceeded',
    message:
        'Prefab $prefabLabel has $shapeCount collision shapes; the normal '
        'authoring target is at most '
        '${TerrainAuthoringCapacityTargets.shapesPerPrefab}. Geometry is '
        'preserved.',
    sourcePath: sourcePath,
    ownerKey: ownerKey,
    placementKey: null,
    shapeId: null,
    elementIndex: null,
  );
}

/// Builds the non-blocking finding for a polygon above its vertex target.
TerrainAuthoringIssue? polygonVertexSoftTargetIssue({
  required String ownerLabel,
  required String shapeId,
  required int vertexCount,
  required String sourcePath,
  required String ownerKey,
}) {
  if (vertexCount <= TerrainAuthoringCapacityTargets.verticesPerShape) {
    return null;
  }
  return TerrainAuthoringIssue(
    severity: TerrainAuthoringIssueSeverity.warning,
    code: 'polygon_vertex_soft_target_exceeded',
    message:
        '$ownerLabel shape $shapeId has $vertexCount vertices; the normal '
        'authoring target is at most '
        '${TerrainAuthoringCapacityTargets.verticesPerShape}. Geometry is '
        'preserved.',
    sourcePath: sourcePath,
    ownerKey: ownerKey,
    placementKey: null,
    shapeId: shapeId,
    elementIndex: null,
  );
}

/// Builds the non-blocking finding for a chunk above its exposed-edge target.
TerrainAuthoringIssue? chunkExposedEdgeSoftTargetIssue({
  required String chunkKey,
  required int exposedEdgeCount,
  required String sourcePath,
}) {
  if (exposedEdgeCount <=
      TerrainAuthoringCapacityTargets.exposedEdgesPerChunk) {
    return null;
  }
  return TerrainAuthoringIssue(
    severity: TerrainAuthoringIssueSeverity.warning,
    code: 'chunk_exposed_edge_soft_target_exceeded',
    message:
        'Chunk $chunkKey compiles to $exposedEdgeCount exposed edges; the '
        'normal authoring target is at most '
        '${TerrainAuthoringCapacityTargets.exposedEdgesPerChunk}. Geometry is '
        'preserved.',
    sourcePath: sourcePath,
    ownerKey: chunkKey,
    placementKey: null,
    shapeId: null,
    elementIndex: null,
  );
}
