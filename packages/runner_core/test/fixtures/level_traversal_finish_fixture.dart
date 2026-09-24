import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_triangulator.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_data.dart';

/// Compiles a 600-unit ground chunk with a 222-unit wall at X=500..520,
/// followed by flat ground. Ground enemies cannot jump over this finish blocker.
/// The clear variant differs only by the wall, keeping spawn and exit identical.
StagedTerrainCatalog levelTraversalFinishCatalog() => StagedTerrainChunkCatalog(
  chunks: [
    _chunk('finish_clear', blocked: false),
    _chunk('finish_blocked', blocked: true),
  ],
);

StagedTerrainChunkData _chunk(String key, {required bool blocked}) {
  final geometry = const TerrainCompiler().compile([
    TerrainPolygonInput.fromWorld(
      sourcePath: 'test/finish/$key',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: key,
        shapeId: 'ground',
      ),
      vertices: [
        (0, 222),
        if (blocked) ...[(500, 222), (500, 0), (520, 0), (520, 222)],
        (600, 222),
        (600, 270),
        (0, 270),
      ],
      surfaceKind: 'ground',
    ),
  ], geometryVersion: 1);
  final sourceId = StagedTerrainSourceId(chunkKey: key, shapeId: 'ground');
  StagedTerrainEdgeId? edgeId(TerrainEdgeId? id) => id == null
      ? null
      : StagedTerrainEdgeId(
          sourceId: sourceId,
          localEdgeIndex: id.localEdgeIndex,
          subEdgeIndex: id.subEdgeIndex,
        );
  final edges = [
    for (final edge in geometry.edges)
      StagedTerrainEdgeData(
        id: edgeId(edge.id)!,
        start: StagedTerrainPoint(edge.start.xTicks, edge.start.yTicks),
        end: StagedTerrainPoint(edge.end.xTicks, edge.end.yTicks),
        tangent: StagedTerrainPoint(edge.tangent.xTicks, edge.tangent.yTicks),
        outwardNormal: StagedTerrainPoint(
          edge.outwardNormal.xTicks,
          edge.outwardNormal.yTicks,
        ),
        collisionMode: StagedTerrainCollisionMode.solid,
        surfaceKind: edge.surfaceKind,
        materialKey: edge.materialKey,
        previousId: edgeId(edge.previousId),
        nextId: edgeId(edge.nextId),
        startJoin: StagedTerrainVertexJoin.values.byName(edge.startJoin.name),
        endJoin: StagedTerrainVertexJoin.values.byName(edge.endJoin.name),
      ),
  ];
  // This fixture has no authored source/placement artifacts. Their unused
  // signature slots satisfy catalog structure admission only.
  final digest = geometry.sourceSignature();
  final polygon = geometry.polygons.single;
  return StagedTerrainChunkData(
    chunkKey: key,
    id: key,
    revision: 1,
    status: 'active',
    levelId: 'field',
    tileSize: 16,
    width: 600,
    height: 270,
    difficulty: 'normal',
    assemblyGroupId: 'default',
    authoringPolygonSignature: digest,
    sourceSignature: digest,
    edgeSignature: geometry.edgeSignature(),
    renderEdgeSignature: geometry.edgeSignature(),
    placementSignature: digest,
    triangleSignature: digest,
    polygons: [
      StagedTerrainPolygonData(
        sourcePath: polygon.sourcePath,
        id: sourceId,
        sourceVertices: polygon.sourceVertices.map(
          (point) => StagedTerrainPoint(point.xTicks, point.yTicks),
        ),
        vertices: polygon.vertices.map(
          (point) => StagedTerrainPoint(point.xTicks, point.yTicks),
        ),
        collisionMode: StagedTerrainCollisionMode.solid,
        surfaceKind: polygon.surfaceKind,
        materialKey: polygon.materialKey,
      ),
    ],
    edges: edges,
    renderEdges: edges,
    triangles: [
      for (final triangle in const TerrainTriangulator().triangulate(polygon))
        StagedTerrainTriangleData(
          sourceId: sourceId,
          first: triangle.first,
          second: triangle.second,
          third: triangle.third,
        ),
    ],
    placementLineage: [],
  );
}
