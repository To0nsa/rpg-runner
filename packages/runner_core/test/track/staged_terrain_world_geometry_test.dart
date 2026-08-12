import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_data.dart';
import 'package:runner_core/track/staged_terrain_world_geometry.dart';
import 'package:test/test.dart';

const _digest =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

void main() {
  const builder = StagedTerrainWorldGeometryBuilder();

  test(
    'translates local physics coordinates and rehydrates streamed identity',
    () {
      final catalog = StagedTerrainArtifactCatalog(
        artifact: _artifact(<StagedTerrainChunkData>[_chunk('field_flat')]),
      );

      final geometry = builder.build(
        bindings: <StagedTerrainChunkBinding>[
          catalog.bind(
            chunkKey: 'field_flat',
            chunkIndex: 3,
            worldOriginXTicks: 4096,
          ),
        ],
        geometryVersion: 12,
      );

      expect(geometry.version, 12);
      expect(geometry.polygons.single.vertices.first.xTicks, 4096);
      expect(geometry.edges.single.start.xTicks, 4096);
      expect(geometry.edges.single.end.xTicks, 5120);
      expect(geometry.edges.single.id.chunkIndex, 3);
      expect(geometry.edges.single.id.chunkKey, 'field_flat');
      expect(geometry.edges.single.id.shapeId, 'ground');
      expect(geometry.edges.single.bounds.minX, 4096);
      expect(geometry.edges.single.bounds.maxX, 5120);
    },
  );

  test('keeps repeated chunk selection distinct and canonical', () {
    final catalog = StagedTerrainArtifactCatalog(
      artifact: _artifact(<StagedTerrainChunkData>[_chunk('field_flat')]),
    );

    final geometry = builder.build(
      bindings: <StagedTerrainChunkBinding>[
        catalog.bind(
          chunkKey: 'field_flat',
          chunkIndex: 8,
          worldOriginXTicks: 8192,
        ),
        catalog.bind(
          chunkKey: 'field_flat',
          chunkIndex: 2,
          worldOriginXTicks: 2048,
        ),
      ],
      geometryVersion: 1,
    );

    expect(geometry.edges.map((edge) => edge.id.chunkIndex), <int>[2, 8]);
    expect(geometry.edges.map((edge) => edge.start.xTicks), <int>[2048, 8192]);
  });

  test('fails closed for duplicate instances and malformed records', () {
    final catalog = StagedTerrainArtifactCatalog(
      artifact: _artifact(<StagedTerrainChunkData>[_chunk('field_flat')]),
    );
    final binding = catalog.bind(
      chunkKey: 'field_flat',
      chunkIndex: 2,
      worldOriginXTicks: 0,
    );

    expect(
      () => builder.build(
        bindings: <StagedTerrainChunkBinding>[binding, binding],
        geometryVersion: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => builder.build(
        bindings: <StagedTerrainChunkBinding>[binding],
        geometryVersion: -1,
      ),
      throwsArgumentError,
    );

    final broken = StagedTerrainArtifactCatalog(
      artifact: _artifact(<StagedTerrainChunkData>[
        _chunk('broken', polygonVertices: const <StagedTerrainPoint>[]),
      ]),
    ).bind(chunkKey: 'broken', chunkIndex: 0, worldOriginXTicks: 0);
    expect(
      () => builder.build(
        bindings: <StagedTerrainChunkBinding>[broken],
        geometryVersion: 1,
      ),
      throwsArgumentError,
    );
  });
}

StagedTerrainArtifactData _artifact(List<StagedTerrainChunkData> chunks) =>
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
      chunks: chunks,
    );

StagedTerrainChunkData _chunk(
  String chunkKey, {
  List<StagedTerrainPoint>? polygonVertices,
}) {
  final sourceId = StagedTerrainSourceId(chunkKey: chunkKey, shapeId: 'ground');
  final vertices =
      polygonVertices ??
      const <StagedTerrainPoint>[
        StagedTerrainPoint(0, 0),
        StagedTerrainPoint(2, 0),
        StagedTerrainPoint(2, 2),
      ];
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
        sourceVertices: vertices,
        vertices: vertices.map(
          (point) => StagedTerrainPoint(point.xTicks * 512, point.yTicks * 512),
        ),
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
    triangles: const <StagedTerrainTriangleData>[],
    placementLineage: const <StagedTerrainPlacementLineageData>[],
  );
}
