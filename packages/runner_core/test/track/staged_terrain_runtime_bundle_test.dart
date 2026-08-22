import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_data.dart';
import 'package:runner_core/track/staged_terrain_runtime_bundle.dart';
import 'package:test/test.dart';

const _digest =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

void main() {
  test('builds one version-coherent collision and navigation candidate', () {
    final catalog = StagedTerrainArtifactCatalog(
      artifact: _artifact(<StagedTerrainChunkData>[_chunk('field_flat')]),
    );
    final bundle = const StagedTerrainRuntimeBundleBuilder().build(
      bindings: <StagedTerrainChunkBinding>[
        catalog.bind(
          chunkKey: 'field_flat',
          chunkIndex: 5,
          worldOriginXTicks: 4096,
        ),
      ],
      geometryVersion: 23,
      groundEnemyProfiles: buildDefaultGroundEnemyTerrainGraphProfiles(),
    );

    expect(bundle.version, 23);
    expect(bundle.geometry.edges.single.start.xTicks, 4096);
    expect(bundle.edgeIndex.edges.single, bundle.geometry.edges.single);
    expect(bundle.surfaceSet.geometryVersion, 23);
    expect(bundle.surfaceIndex.geometryVersion, 23);
    expect(bundle.grojibGraph.geometryVersion, 23);
    expect(bundle.hashashGraph.geometryVersion, 23);
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
      renderEdgeSignatureFormat: 'edges-v1',
      placementSignatureFormat: 'authoring-placement-v1',
      triangleSignatureFormat: 'authoring-triangles-v1',
      chunks: chunks,
    );

StagedTerrainChunkData _chunk(String chunkKey) {
  final sourceId = StagedTerrainSourceId(chunkKey: chunkKey, shapeId: 'ground');
  final edge = StagedTerrainEdgeData(
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
  );
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
    renderEdgeSignature: _digest,
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
    edges: <StagedTerrainEdgeData>[edge],
    renderEdges: <StagedTerrainEdgeData>[edge],
    triangles: const <StagedTerrainTriangleData>[],
    placementLineage: const <StagedTerrainPlacementLineageData>[],
  );
}
