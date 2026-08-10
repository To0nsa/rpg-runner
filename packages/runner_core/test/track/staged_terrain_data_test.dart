import 'package:runner_core/track/staged_terrain_data.dart';
import 'package:test/test.dart';

void main() {
  test('staged artifact contract freezes its repository output identity', () {
    expect(
      stagedTerrainArtifactRepositoryPath,
      'packages/runner_core/lib/track/staged_authored_terrain.dart',
    );
  });

  test('staged identities are local, validated, and totally ordered', () {
    final direct = StagedTerrainSourceId(chunkKey: 'chunk', shapeId: 'ground');
    final placed = StagedTerrainSourceId(
      chunkKey: 'chunk',
      placementKey: 'ramp|0|0|0',
      shapeId: 'ramp',
    );
    final edges = <StagedTerrainEdgeId>[
      StagedTerrainEdgeId(sourceId: placed, localEdgeIndex: 0, subEdgeIndex: 0),
      StagedTerrainEdgeId(sourceId: direct, localEdgeIndex: 1, subEdgeIndex: 0),
      StagedTerrainEdgeId(sourceId: direct, localEdgeIndex: 0, subEdgeIndex: 1),
    ]..sort();

    expect(edges.map((edge) => edge.sourceId), <StagedTerrainSourceId>[
      direct,
      direct,
      placed,
    ]);
    expect(edges.first.localEdgeIndex, 0);
    expect(
      () => StagedTerrainSourceId(chunkKey: '', shapeId: 'ground'),
      throwsArgumentError,
    );
    expect(
      () => StagedTerrainEdgeId(
        sourceId: direct,
        localEdgeIndex: -1,
        subEdgeIndex: 0,
      ),
      throwsArgumentError,
    );
  });

  test('staged generated collections snapshot caller-owned iterables', () {
    final sourceId = StagedTerrainSourceId(
      chunkKey: 'chunk',
      shapeId: 'ground',
    );
    final vertices = <StagedTerrainPoint>[
      const StagedTerrainPoint(0, 0),
      const StagedTerrainPoint(2, 0),
      const StagedTerrainPoint(2, 2),
    ];
    final polygon = StagedTerrainPolygonData(
      sourcePath: 'chunk.json#direct=ground',
      id: sourceId,
      sourceVertices: vertices,
      vertices: vertices,
      collisionMode: StagedTerrainCollisionMode.solid,
      surfaceKind: 'ground',
      materialKey: 'earth',
    );
    final polygons = <StagedTerrainPolygonData>[polygon];
    final chunk = StagedTerrainChunkData(
      chunkKey: 'chunk',
      id: 'chunk',
      revision: 1,
      status: 'active',
      levelId: 'forest',
      tileSize: 16,
      width: 100,
      height: 100,
      difficulty: 'normal',
      assemblyGroupId: 'default',
      authoringPolygonSignature: 'authoring-polygons',
      sourceSignature: 'source',
      edgeSignature: 'edges',
      placementSignature: 'placements',
      triangleSignature: 'triangles',
      polygons: polygons,
      edges: const <StagedTerrainEdgeData>[],
      triangles: <StagedTerrainTriangleData>[
        StagedTerrainTriangleData(
          sourceId: sourceId,
          first: 0,
          second: 1,
          third: 2,
        ),
      ],
      placementLineage: const <StagedTerrainPlacementLineageData>[],
    );
    final chunks = <StagedTerrainChunkData>[chunk];
    final artifact = StagedTerrainArtifactData(
      formatVersion: stagedTerrainArtifactFormatVersion,
      compilerGeometryVersion: 1,
      authoringPolygonSignatureFormat: 'authoring-polygons-v1',
      authoringSeamSignatureFormat: 'authoring-seams-v1',
      authoringSeamSignature: 'seams',
      sourceSignatureFormat: 'source-v1',
      edgeSignatureFormat: 'edges-v1',
      placementSignatureFormat: 'authoring-placement-v1',
      triangleSignatureFormat: 'authoring-triangles-v1',
      chunks: chunks,
    );

    vertices.clear();
    polygons.clear();
    chunks.clear();

    expect(polygon.vertices, hasLength(3));
    expect(chunk.polygons, <StagedTerrainPolygonData>[polygon]);
    expect(artifact.chunks, <StagedTerrainChunkData>[chunk]);
    expect(() => polygon.vertices.clear(), throwsUnsupportedError);
    expect(() => chunk.polygons.clear(), throwsUnsupportedError);
    expect(() => artifact.chunks.clear(), throwsUnsupportedError);
    expect(
      () => StagedTerrainTriangleData(
        sourceId: sourceId,
        first: -1,
        second: 1,
        third: 2,
      ),
      throwsArgumentError,
    );
  });
}
