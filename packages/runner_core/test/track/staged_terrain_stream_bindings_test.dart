import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_data.dart';
import 'package:runner_core/track/staged_terrain_stream_bindings.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:test/test.dart';

const _digest =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

void main() {
  const builder = StagedTerrainStreamBindingBuilder();

  test('binds the existing scheduler selection without reselecting chunks', () {
    const pattern = ChunkPattern(name: 'field', chunkKey: 'field_flat');
    const source = ChunkPatternListSource(
      easyPatterns: <ChunkPattern>[pattern],
      hardPatterns: <ChunkPattern>[pattern],
    );
    final streamer = TrackStreamer(
      seed: 42,
      tuning: const TrackTuning(spawnAheadMargin: 0.0),
      groundTopY: 220.0,
      patternSource: source,
      earlyPatternChunks: 0,
      noEnemyChunks: 0,
    );
    final catalog = StagedTerrainArtifactCatalog(
      artifact: _artifact(<StagedTerrainChunkData>[_chunk('field_flat')]),
    );

    streamer.step(cameraLeft: 0.0, cameraRight: 600.0, spawnEnemy: (_) {});
    final bindings = builder.build(
      catalog: catalog,
      activeChunks: streamer.activeChunks,
    );

    expect(bindings.map((binding) => binding.chunkIndex), <int>[0, 1]);
    expect(bindings.map((binding) => binding.worldOriginXTicks), <int>[
      0,
      614400,
    ]);
    expect(() => bindings.clear(), throwsUnsupportedError);
  });

  test(
    'fails closed for absent keys, mismatched widths, and duplicate indices',
    () {
      final catalog = StagedTerrainArtifactCatalog(
        artifact: _artifact(<StagedTerrainChunkData>[_chunk('field_flat')]),
      );
      const missingKey = ActiveTrackChunkSnapshot(
        index: 0,
        startX: 0.0,
        endX: 600.0,
        patternName: 'legacy',
        chunkKey: null,
      );
      const wrongWidth = ActiveTrackChunkSnapshot(
        index: 0,
        startX: 0.0,
        endX: 599.0,
        patternName: 'field',
        chunkKey: 'field_flat',
      );
      const duplicateA = ActiveTrackChunkSnapshot(
        index: 1,
        startX: 0.0,
        endX: 600.0,
        patternName: 'field',
        chunkKey: 'field_flat',
      );
      const duplicateB = ActiveTrackChunkSnapshot(
        index: 1,
        startX: 600.0,
        endX: 1200.0,
        patternName: 'field',
        chunkKey: 'field_flat',
      );

      expect(
        () => builder.build(
          catalog: catalog,
          activeChunks: <ActiveTrackChunkSnapshot>[missingKey],
        ),
        throwsStateError,
      );
      expect(
        () => builder.build(
          catalog: catalog,
          activeChunks: <ActiveTrackChunkSnapshot>[wrongWidth],
        ),
        throwsStateError,
      );
      expect(
        () => builder.build(
          catalog: catalog,
          activeChunks: <ActiveTrackChunkSnapshot>[duplicateA, duplicateB],
        ),
        throwsArgumentError,
      );
    },
  );
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

StagedTerrainChunkData _chunk(String chunkKey) => StagedTerrainChunkData(
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
  polygons: const <StagedTerrainPolygonData>[],
  edges: const <StagedTerrainEdgeData>[],
  renderEdges: const <StagedTerrainEdgeData>[],
  triangles: const <StagedTerrainTriangleData>[],
  placementLineage: const <StagedTerrainPlacementLineageData>[],
);
