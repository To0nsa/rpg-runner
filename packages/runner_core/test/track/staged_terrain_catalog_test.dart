import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/track/staged_terrain_data.dart';
import 'package:runner_core/track/staged_terrain_world_geometry.dart';
import 'package:test/test.dart';

void main() {
  test('the checked-in generated artifact remains catalog-admissible', () {
    final catalog = StagedTerrainArtifactCatalog(
      artifact: stagedAuthoredTerrain,
    );
    final bindings = <StagedTerrainChunkBinding>[
      for (
        var index = 0;
        index < stagedAuthoredTerrain.chunks.length;
        index += 1
      )
        catalog.bind(
          chunkKey: stagedAuthoredTerrain.chunks[index].chunkKey,
          chunkIndex: index,
          worldOriginXTicks: index * 614400,
        ),
    ];

    final geometry = const StagedTerrainWorldGeometryBuilder().build(
      bindings: bindings,
      geometryVersion: 1,
    );

    expect(catalog.chunksByKey, hasLength(stagedAuthoredTerrain.chunks.length));
    expect(geometry.polygons, isEmpty);
    expect(geometry.edges, isEmpty);
  });

  test(
    'admits canonical generated chunks and binds repeat selections locally',
    () {
      final catalog = StagedTerrainArtifactCatalog(
        artifact: _artifact(
          chunks: <StagedTerrainChunkData>[
            _chunk('field_flat'),
            _chunk('forest_early_00'),
          ],
        ),
      );

      final first = catalog.bind(
        chunkKey: 'field_flat',
        chunkIndex: 4,
        worldOriginXTicks: 2457600,
      );
      final repeat = catalog.bind(
        chunkKey: 'field_flat',
        chunkIndex: 7,
        worldOriginXTicks: 4300800,
      );
      final source = StagedTerrainSourceId(
        chunkKey: 'field_flat',
        shapeId: 'ground',
      );

      expect(first.chunk, same(catalog.requireChunk('field_flat')));
      expect(first.worldOriginXTicks, 2457600);
      expect(first.sourceIdentity(source).chunkIndex, 4);
      expect(repeat.sourceIdentity(source).chunkIndex, 7);
      expect(first.sourceIdentity(source).chunkKey, 'field_flat');
      expect(first.sourceIdentity(source).placementKey, isNull);
    },
  );

  test('rejects stale, ambiguous, and malformed artifact admission', () {
    expect(
      () => StagedTerrainArtifactCatalog(
        artifact: _artifact(
          formatVersion: 99,
          chunks: <StagedTerrainChunkData>[],
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => StagedTerrainArtifactCatalog(
        artifact: _artifact(
          chunks: <StagedTerrainChunkData>[_chunk('zeta'), _chunk('alpha')],
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => StagedTerrainArtifactCatalog(
        artifact: _artifact(
          chunks: <StagedTerrainChunkData>[_chunk('alpha'), _chunk('alpha')],
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => StagedTerrainArtifactCatalog(
        artifact: _artifact(
          chunks: <StagedTerrainChunkData>[_chunk('alpha', revision: 0)],
        ),
      ),
      throwsArgumentError,
    );
  });

  test('fails closed for missing or foreign chunk identities', () {
    final catalog = StagedTerrainArtifactCatalog(
      artifact: _artifact(
        chunks: <StagedTerrainChunkData>[_chunk('field_flat')],
      ),
    );
    final binding = catalog.bind(
      chunkKey: 'field_flat',
      chunkIndex: 0,
      worldOriginXTicks: 0,
    );

    expect(() => catalog.requireChunk('missing'), throwsStateError);
    expect(
      () => catalog.bind(
        chunkKey: 'field_flat',
        chunkIndex: -1,
        worldOriginXTicks: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => binding.sourceIdentity(
        StagedTerrainSourceId(chunkKey: 'other', shapeId: 'ground'),
      ),
      throwsArgumentError,
    );
    expect(
      () => binding.sourceIdentity(
        StagedTerrainSourceId(chunkKey: 'field_flat', shapeId: 'missing'),
      ),
      throwsArgumentError,
    );
  });
}

StagedTerrainArtifactData _artifact({
  int formatVersion = stagedTerrainArtifactFormatVersion,
  required List<StagedTerrainChunkData> chunks,
}) => StagedTerrainArtifactData(
  formatVersion: formatVersion,
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

StagedTerrainChunkData _chunk(String chunkKey, {int revision = 1}) =>
    StagedTerrainChunkData(
      chunkKey: chunkKey,
      id: chunkKey,
      revision: revision,
      status: 'active',
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 270,
      difficulty: 'normal',
      assemblyGroupId: 'default',
      authoringPolygonSignature: 'authoring',
      sourceSignature: 'source',
      edgeSignature: 'edges',
      placementSignature: 'placements',
      triangleSignature: 'triangles',
      polygons: <StagedTerrainPolygonData>[_polygon(chunkKey)],
      edges: const <StagedTerrainEdgeData>[],
      triangles: const <StagedTerrainTriangleData>[],
      placementLineage: const <StagedTerrainPlacementLineageData>[],
    );

StagedTerrainPolygonData _polygon(String chunkKey) => StagedTerrainPolygonData(
  sourcePath: 'assets/authoring/level/chunks/$chunkKey.json#direct=ground',
  id: StagedTerrainSourceId(chunkKey: chunkKey, shapeId: 'ground'),
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
  surfaceKind: null,
  materialKey: null,
);
