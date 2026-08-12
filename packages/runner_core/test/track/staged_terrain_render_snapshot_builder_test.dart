import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_data.dart';
import 'package:runner_core/track/staged_terrain_render_snapshot_builder.dart';
import 'package:runner_core/track/staged_terrain_world_geometry.dart';
import 'package:test/test.dart';

const _digest =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

void main() {
  const builder = StagedTerrainRenderSnapshotBuilder();

  test(
    'uses collision-backed world vertices with generated triangle indices',
    () {
      final catalog = StagedTerrainArtifactCatalog(
        artifact: _artifact(_chunk('field_flat')),
      );
      final bindings = <StagedTerrainChunkBinding>[
        catalog.bind(
          chunkKey: 'field_flat',
          chunkIndex: 3,
          worldOriginXTicks: 4096,
        ),
      ];
      final geometry = const StagedTerrainWorldGeometryBuilder().build(
        bindings: bindings,
        geometryVersion: 17,
      );
      final render = builder.build(bindings: bindings, geometry: geometry);

      final polygon = render.polygons.single;
      expect(render.geometryVersion, 17);
      expect(polygon.sourceId.chunkIndex, 3);
      expect(polygon.vertices.map((vertex) => vertex.xTicks), <int>[
        4096,
        5120,
        5120,
      ]);
      expect(polygon.triangles.single.first, 0);
      expect(polygon.triangles.single.second, 1);
      expect(polygon.triangles.single.third, 2);
      final edge = render.edges.single;
      expect(identical(edge, geometry.edges.single), isTrue);
      expect(edge.id.chunkIndex, 3);
      expect(edge.id.chunkKey, 'field_flat');
      expect(edge.id.shapeId, 'ground');
      expect(edge.start.xTicks, 4096);
      expect(edge.end.xTicks, 5120);
    },
  );

  test('fails closed when generated triangles are missing or invalid', () {
    final missing = StagedTerrainArtifactCatalog(
      artifact: _artifact(
        _chunk('missing', triangles: const <StagedTerrainTriangleData>[]),
      ),
    ).bind(chunkKey: 'missing', chunkIndex: 0, worldOriginXTicks: 0);
    final invalid = StagedTerrainArtifactCatalog(
      artifact: _artifact(
        _chunk(
          'invalid',
          triangles: <StagedTerrainTriangleData>[
            StagedTerrainTriangleData(
              sourceId: StagedTerrainSourceId(
                chunkKey: 'invalid',
                shapeId: 'ground',
              ),
              first: 0,
              second: 1,
              third: 3,
            ),
          ],
        ),
      ),
    ).bind(chunkKey: 'invalid', chunkIndex: 0, worldOriginXTicks: 0);

    expect(
      () => builder.build(
        bindings: <StagedTerrainChunkBinding>[missing],
        geometry: const StagedTerrainWorldGeometryBuilder().build(
          bindings: <StagedTerrainChunkBinding>[missing],
          geometryVersion: 1,
        ),
      ),
      throwsStateError,
    );
    expect(
      () => builder.build(
        bindings: <StagedTerrainChunkBinding>[invalid],
        geometry: const StagedTerrainWorldGeometryBuilder().build(
          bindings: <StagedTerrainChunkBinding>[invalid],
          geometryVersion: 1,
        ),
      ),
      throwsArgumentError,
    );
  });
}

StagedTerrainArtifactData _artifact(StagedTerrainChunkData chunk) =>
    StagedTerrainArtifactData(
      formatVersion: stagedTerrainArtifactFormatVersion,
      compilerGeometryVersion: 1,
      authoringPolygonSignatureFormat: 'authoring-polygons-v1',
      authoringSeamSignatureFormat: 'authoring-seams-v1',
      authoringSeamSignature: _digest,
      sourceSignatureFormat: 'source-v1',
      edgeSignatureFormat: 'edges-v1',
      placementSignatureFormat: 'authoring-placement-v1',
      triangleSignatureFormat: 'authoring-triangles-v1',
      chunks: <StagedTerrainChunkData>[chunk],
    );

StagedTerrainChunkData _chunk(
  String chunkKey, {
  List<StagedTerrainTriangleData>? triangles,
}) {
  final sourceId = StagedTerrainSourceId(chunkKey: chunkKey, shapeId: 'ground');
  return StagedTerrainChunkData(
    chunkKey: chunkKey,
    id: chunkKey,
    revision: 1,
    status: 'active',
    levelId: 'field',
    tileSize: 16,
    width: 600,
    height: 270,
    difficulty: 'normal',
    assemblyGroupId: 'default',
    authoringPolygonSignature: _digest,
    sourceSignature: _digest,
    edgeSignature: _digest,
    placementSignature: _digest,
    triangleSignature: _digest,
    polygons: <StagedTerrainPolygonData>[
      StagedTerrainPolygonData(
        sourcePath:
            'assets/authoring/level/chunks/$chunkKey.json#direct=ground',
        id: sourceId,
        sourceVertices: const <StagedTerrainPoint>[
          StagedTerrainPoint(0, 0),
          StagedTerrainPoint(2, 0),
          StagedTerrainPoint(2, 2),
        ],
        vertices: const <StagedTerrainPoint>[
          StagedTerrainPoint(0, 0),
          StagedTerrainPoint(1024, 0),
          StagedTerrainPoint(1024, 1024),
        ],
        collisionMode: StagedTerrainCollisionMode.solid,
        surfaceKind: 'ground',
        materialKey: 'earth',
      ),
    ],
    edges: <StagedTerrainEdgeData>[
      StagedTerrainEdgeData(
        id: StagedTerrainEdgeId(
          sourceId: sourceId,
          localEdgeIndex: 0,
          subEdgeIndex: 0,
        ),
        start: const StagedTerrainPoint(0, 0),
        end: const StagedTerrainPoint(1024, 0),
        tangent: const StagedTerrainPoint(1024, 0),
        outwardNormal: const StagedTerrainPoint(0, -1024),
        collisionMode: StagedTerrainCollisionMode.solid,
        surfaceKind: 'ground',
        materialKey: 'earth',
        previousId: null,
        nextId: null,
        startJoin: StagedTerrainVertexJoin.exposed,
        endJoin: StagedTerrainVertexJoin.exposed,
      ),
    ],
    triangles:
        triangles ??
        <StagedTerrainTriangleData>[
          StagedTerrainTriangleData(
            sourceId: sourceId,
            first: 0,
            second: 1,
            third: 2,
          ),
        ],
    placementLineage: const <StagedTerrainPlacementLineageData>[],
  );
}
