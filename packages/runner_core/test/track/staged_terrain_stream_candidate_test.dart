import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_data.dart';
import 'package:runner_core/track/staged_terrain_stream_candidate.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:test/test.dart';

const _digest =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

void main() {
  test(
    'builds collision navigation and render outputs from one geometry object',
    () {
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
      final candidate = const StagedTerrainStreamCandidateBuilder().build(
        catalog: catalog,
        activeChunks: streamer.activeChunks,
        geometryVersion: 9,
        groundEnemyProfiles: buildDefaultGroundEnemyTerrainGraphProfiles(),
      );

      expect(candidate.bindings.map((binding) => binding.chunkIndex), <int>[
        0,
        1,
      ]);
      expect(candidate.geometry.version, 9);
      expect(
        identical(candidate.runtimeBundle.geometry, candidate.geometry),
        isTrue,
      );
      expect(
        candidate.renderSnapshot.geometryVersion,
        candidate.geometry.version,
      );
      expect(candidate.renderSnapshot.polygons, isEmpty);
    },
  );

  test(
    'reconstructs identical staged edge records after culling a selection',
    () {
      final catalog = StagedTerrainArtifactCatalog(
        artifact: stagedAuthoredTerrain,
      );
      final originalStreamer = _fieldStreamer();
      originalStreamer.step(
        cameraLeft: 0.0,
        cameraRight: 0.0,
        spawnEnemy: (_) {},
      );
      final original = _buildCandidate(
        catalog: catalog,
        streamer: originalStreamer,
      );

      originalStreamer.step(
        cameraLeft: 601.0,
        cameraRight: 1200.0,
        spawnEnemy: (_) {},
      );
      final afterCull = _buildCandidate(
        catalog: catalog,
        streamer: originalStreamer,
      );

      final readdedStreamer = _fieldStreamer();
      readdedStreamer.step(
        cameraLeft: 0.0,
        cameraRight: 0.0,
        spawnEnemy: (_) {},
      );
      final readded = _buildCandidate(
        catalog: catalog,
        streamer: readdedStreamer,
      );

      expect(original.geometry.edges, hasLength(4));
      expect(afterCull.geometry.edges, hasLength(6));
      expect(
        afterCull.geometry.edges.every(
          (edge) =>
              edge.id.chunkIndex != original.geometry.edges.first.id.chunkIndex,
        ),
        isTrue,
      );
      expect(
        readded.geometry.canonicalEdgeRecords(),
        original.geometry.canonicalEdgeRecords(),
      );
      expect(
        readded.geometry.edgeSignature(),
        original.geometry.edgeSignature(),
      );
      expect(
        readded.renderSnapshot.polygons
            .map((polygon) => polygon.sourceId)
            .toList(),
        original.renderSnapshot.polygons
            .map((polygon) => polygon.sourceId)
            .toList(),
      );
    },
  );
}

TrackStreamer _fieldStreamer() {
  const pattern = ChunkPattern(name: 'field', chunkKey: 'field_flat');
  const source = ChunkPatternListSource(
    easyPatterns: <ChunkPattern>[pattern],
    hardPatterns: <ChunkPattern>[pattern],
  );
  return TrackStreamer(
    seed: 42,
    tuning: const TrackTuning(spawnAheadMargin: 0.0, cullBehindMargin: 0.0),
    groundTopY: 220.0,
    patternSource: source,
    earlyPatternChunks: 0,
    noEnemyChunks: 0,
  );
}

StagedTerrainStreamCandidate _buildCandidate({
  required StagedTerrainArtifactCatalog catalog,
  required TrackStreamer streamer,
}) => const StagedTerrainStreamCandidateBuilder().build(
  catalog: catalog,
  activeChunks: streamer.activeChunks,
  geometryVersion: 9,
  groundEnemyProfiles: buildDefaultGroundEnemyTerrainGraphProfiles(),
);

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
