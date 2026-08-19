import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/track/staged_terrain_data.dart';
import 'package:runner_core/track/staged_terrain_world_geometry.dart';
import 'package:test/test.dart';

const _digest =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

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
    expect(geometry.polygons, hasLength(10));
    expect(geometry.edges, hasLength(26));
    expect(
      geometry.polygons.map((polygon) => polygon.identity.chunkKey).toSet(),
      stagedAuthoredTerrain.chunks.map((chunk) => chunk.chunkKey).toSet(),
    );
    expect(
      geometry.polygons.where(
        (polygon) =>
            polygon.surfaceKind == 'ground' &&
            polygon.materialKey == 'grass_dirt',
      ),
      hasLength(9),
    );
    expect(
      geometry.polygons.where(
        (polygon) =>
            polygon.identity.shapeId == 'wood_pile_perch_001' &&
            polygon.surfaceKind == 'obstacle' &&
            polygon.materialKey == 'grass_dirt',
      ),
      hasLength(1),
    );
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
          compilerGeometryVersion: 2,
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
    expect(
      () => StagedTerrainArtifactCatalog(
        artifact: _artifact(
          sourceSignatureFormat: 'source-v2',
          chunks: <StagedTerrainChunkData>[],
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => StagedTerrainArtifactCatalog(
        artifact: _artifact(
          authoringSeamSignature: 'not-a-digest',
          chunks: <StagedTerrainChunkData>[],
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => StagedTerrainArtifactCatalog(
        artifact: _artifact(
          chunks: <StagedTerrainChunkData>[
            _chunk(
              'alpha',
              triangles: <StagedTerrainTriangleData>[
                StagedTerrainTriangleData(
                  sourceId: StagedTerrainSourceId(
                    chunkKey: 'alpha',
                    shapeId: 'foreign',
                  ),
                  first: 0,
                  second: 1,
                  third: 2,
                ),
              ],
            ),
          ],
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

  test(
    'overlay replaces exactly one admitted key and preserves base lookup',
    () {
      final alpha = _chunk('alpha');
      final beta = _chunk('beta');
      final base = StagedTerrainArtifactCatalog(
        artifact: _artifact(chunks: <StagedTerrainChunkData>[alpha, beta]),
      );
      final draft = _chunk('alpha', revision: 2);
      final overlay = StagedTerrainOverlayCatalog(
        base: base,
        replacement: draft,
      );

      expect(overlay.requireChunk('alpha'), same(draft));
      expect(overlay.requireChunk('beta'), same(beta));
      expect(base.requireChunk('alpha'), same(alpha));
      expect(
        overlay
            .bind(chunkKey: 'alpha', chunkIndex: 3, worldOriginXTicks: 1843200)
            .chunk,
        same(draft),
      );
      expect(
        overlay
            .bind(chunkKey: 'alpha', chunkIndex: 8, worldOriginXTicks: 4915200)
            .chunk,
        same(draft),
      );
    },
  );

  test('overlay rejects missing, malformed, or dimension-changing drafts', () {
    final base = StagedTerrainArtifactCatalog(
      artifact: _artifact(chunks: <StagedTerrainChunkData>[_chunk('alpha')]),
    );

    expect(
      () => StagedTerrainOverlayCatalog(
        base: base,
        replacement: _chunk('missing'),
      ),
      throwsStateError,
    );
    expect(
      () => StagedTerrainOverlayCatalog(
        base: base,
        replacement: _chunk('alpha', revision: 0),
      ),
      throwsArgumentError,
    );
    expect(
      () => StagedTerrainOverlayCatalog(
        base: base,
        replacement: _chunk('alpha', width: 601),
      ),
      throwsArgumentError,
    );
  });
}

StagedTerrainArtifactData _artifact({
  int formatVersion = stagedTerrainArtifactFormatVersion,
  int compilerGeometryVersion = stagedTerrainCompilerGeometryVersion,
  String sourceSignatureFormat = 'source-v1',
  String authoringSeamSignature = _digest,
  required List<StagedTerrainChunkData> chunks,
}) => StagedTerrainArtifactData(
  formatVersion: formatVersion,
  compilerGeometryVersion: compilerGeometryVersion,
  authoringPolygonSignatureFormat: 'authoring-polygons-v1',
  authoringSeamSignatureFormat: 'authoring-seams-v1',
  authoringSeamSignature: authoringSeamSignature,
  sourceSignatureFormat: sourceSignatureFormat,
  edgeSignatureFormat: 'edges-v1',
  placementSignatureFormat: 'authoring-placement-v1',
  triangleSignatureFormat: 'authoring-triangles-v1',
  chunks: chunks,
);

StagedTerrainChunkData _chunk(
  String chunkKey, {
  int revision = 1,
  int width = 600,
  List<StagedTerrainTriangleData> triangles =
      const <StagedTerrainTriangleData>[],
}) => StagedTerrainChunkData(
  chunkKey: chunkKey,
  id: chunkKey,
  revision: revision,
  status: 'active',
  levelId: 'field',
  tileSize: 16,
  width: width,
  height: 270,
  difficulty: 'normal',
  assemblyGroupId: 'default',
  authoringPolygonSignature: _digest,
  sourceSignature: _digest,
  edgeSignature: _digest,
  placementSignature: _digest,
  triangleSignature: _digest,
  polygons: <StagedTerrainPolygonData>[_polygon(chunkKey)],
  edges: const <StagedTerrainEdgeData>[],
  triangles: triangles,
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
