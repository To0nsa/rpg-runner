import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_preparer.dart';
import 'package:runner_core/track/staged_terrain_stream_candidate.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:test/test.dart';

void main() {
  for (final id in LevelRegistry.compiledLevelIds) {
    for (final tuning in const [
      TrackTuning(),
      TrackTuning(spawnAheadMargin: 137, cullBehindMargin: 83),
      TrackTuning(spawnAheadMargin: 0, cullBehindMargin: 0),
    ]) {
      test('${id.name} projection matches live selection without spawns '
          '(${tuning.spawnAheadMargin}, ${tuning.cullBehindMargin})', () {
        final projected = _streamer(id, tuning: tuning);
        final untouched = _streamer(id, tuning: tuning);
        var future = <List<ActiveTrackChunkSnapshot>>[];
        for (var tick = 0; tick <= 3600; tick += 1) {
          final x = tick * 200 / 60;
          final actualSpawns = <SpawnEnemyRequest>[];
          final expectedSpawns = <SpawnEnemyRequest>[];
          final result = projected.step(
            cameraLeft: x,
            cameraRight: x + 600,
            spawnEnemy: actualSpawns.add,
          );
          untouched.step(
            cameraLeft: x,
            cameraRight: x + 600,
            spawnEnemy: expectedSpawns.add,
          );
          expect(
            _selection(projected.activeChunks),
            _selection(untouched.activeChunks),
            reason: 'tick $tick',
          );
          expect(actualSpawns.map(_spawn), expectedSpawns.map(_spawn));
          if (!result.changed) continue;
          if (tick > 0) {
            expect(
              future.map(_selection),
              contains(_selection(projected.activeChunks)),
              reason: 'tick $tick',
            );
          }
          final before = projected.activeChunks;
          future = projected.upcomingSelections(viewWidth: 600, count: 8);
          expect(identical(before, projected.activeChunks), isTrue);
          expect(() => future.first.clear(), throwsUnsupportedError);
        }
      });
    }
  }

  test('prepared Forest publications exactly match synchronous builds', () async {
    final streamer = _streamer(LevelId.forest);
    _step(streamer, 0);
    final preparer = _preparer();
    addTearDown(preparer.dispose);
    await preparer.prepare(
      streamer.upcomingSelections(viewWidth: 600, count: 8),
    );
    var version = 1;
    // Both sides of each shared spawn/cull boundary, including the measured
    // worst-case 42-second Forest selection and a tick skipping that boundary.
    for (final x in [
      600.0,
      1200.0,
      1200.5,
      1800.5,
      2400.0,
      2400.5,
      3000.5,
      3600.0,
      3600.5,
      4200.5,
      4800.5,
      5400.5,
      6000.5,
      6600.5,
      7200.5,
      7800.5,
      8400.0,
      8400.5,
    ]) {
      _step(streamer, x);
      version += 1;
      final prepared = preparer.take(
        streamer.activeChunks,
        geometryVersion: version,
      );
      expect(prepared, isNotNull, reason: 'camera $x, ${preparer.stats}');
      final synchronous = _build(streamer.activeChunks, version);
      _expectSamePublication(prepared!, synchronous);
      await preparer.prepare(
        streamer.upcomingSelections(viewWidth: 600, count: 8),
      );
      expect(preparer.stats.ready, lessThanOrEqualTo(8));
    }
    expect(preparer.stats.hits, version - 1);
    expect(preparer.stats.misses, 0);
    expect(preparer.stats.lastError, isNull);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test(
    'cold, skipped, stale and disposed windows cannot supply wrong terrain',
    () async {
      final streamer = _streamer(LevelId.field);
      _step(streamer, 0);
      final preparer = _preparer();
      final first = streamer.upcomingSelections(viewWidth: 600, count: 8);
      final pending = preparer.prepare(first);
      expect(preparer.take(first.first, geometryVersion: 2), isNull);
      // Move beyond the entire in-flight window and request replacement while
      // the first worker is running. Only the latest targets may be retained.
      _step(streamer, 12000);
      expect(preparer.take(streamer.activeChunks, geometryVersion: 3), isNull);
      final replacement = streamer.upcomingSelections(viewWidth: 600, count: 8);
      await preparer.prepare(replacement);
      await pending;
      expect(preparer.stats.ready, 8);
      expect(preparer.take(first.first, geometryVersion: 4), isNull);
      final prepared = preparer.take(replacement.first, geometryVersion: 5)!;
      _expectSamePublication(prepared, _build(replacement.first, 5));
      final last = preparer.prepare(replacement);
      preparer.dispose();
      await last;
      expect(preparer.stats.ready, 0);
      expect(preparer.take(replacement.first, geometryVersion: 6), isNull);
    },
  );

  test(
    'speculative admission failure is retained without publishing terrain',
    () async {
      final preparer = _preparer();
      addTearDown(preparer.dispose);
      const invalid = [
        ActiveTrackChunkSnapshot(
          index: 9,
          startX: 5400,
          endX: 6000,
          patternName: 'missing',
          chunkKey: 'missing',
        ),
      ];
      await preparer.prepare([invalid]);
      expect(preparer.stats.lastError, contains('missing'));
      expect(preparer.stats.ready, 0);
      expect(preparer.take(invalid, geometryVersion: 2), isNull);
      expect(() => _build(invalid, 2), throwsStateError);
    },
  );
}

TrackStreamer _streamer(LevelId id, {TrackTuning? tuning}) {
  final level = LevelRegistry.byId(id);
  return TrackStreamer(
    seed: 42,
    tuning: tuning ?? level.tuning.track,
    groundTopY: level.groundTopY,
    patternSource: level.chunkPatternSource,
    earlyPatternChunks: level.earlyPatternChunks,
    easyPatternChunks: level.easyPatternChunks,
    normalPatternChunks: level.normalPatternChunks,
    noEnemyChunks: level.noEnemyChunks,
  );
}

void _step(TrackStreamer streamer, double x) =>
    streamer.step(cameraLeft: x, cameraRight: x + 600, spawnEnemy: (_) {});

String _selection(List<ActiveTrackChunkSnapshot> chunks) => chunks
    .map(
      (chunk) =>
          '${chunk.index}:${chunk.chunkKey}:${chunk.startX}:${chunk.endX}',
    )
    .join('|');

Object _spawn(SpawnEnemyRequest spawn) => (
  spawn.enemyId,
  spawn.x,
  spawn.fallbackSupportY,
  spawn.source,
  spawn.placement,
);

StagedTerrainPreparer _preparer() => StagedTerrainPreparer(
  catalog: StagedTerrainArtifactCatalog(artifact: stagedAuthoredTerrain),
  groundEnemyProfiles: buildDefaultGroundEnemyTerrainGraphProfiles(),
);

StagedTerrainStreamCandidate _build(
  List<ActiveTrackChunkSnapshot> chunks,
  int version,
) => const StagedTerrainStreamCandidateBuilder().build(
  catalog: StagedTerrainArtifactCatalog(artifact: stagedAuthoredTerrain),
  activeChunks: chunks,
  geometryVersion: version,
  groundEnemyProfiles: buildDefaultGroundEnemyTerrainGraphProfiles(),
);

void _expectSamePublication(
  StagedTerrainStreamCandidate actual,
  StagedTerrainStreamCandidate expected,
) {
  expect(actual.geometry.version, expected.geometry.version);
  expect(
    actual.geometry.canonicalEdgeRecords(),
    expected.geometry.canonicalEdgeRecords(),
  );
  expect(
    actual.runtimeBundle.surfaceSignature(),
    expected.runtimeBundle.surfaceSignature(),
  );
  expect(
    actual.runtimeBundle.graphSignature(),
    expected.runtimeBundle.graphSignature(),
  );
  final bundle = actual.runtimeBundle;
  expect(identical(bundle.geometry, actual.geometry), isTrue);
  expect(identical(bundle.surfaceSet, bundle.surfaceIndex.surfaceSet), isTrue);
  expect(
    identical(bundle.surfaceSet, bundle.graphPublication.surfaceSet),
    isTrue,
  );
  expect(bundle.surfaceIndex.geometryVersion, actual.geometry.version);
  expect(bundle.graphPublication.geometryVersion, actual.geometry.version);
  expect(actual.renderSnapshot.geometryVersion, actual.geometry.version);
  expect(
    actual.renderSnapshot.polygons.map((p) => p.sourceId),
    expected.renderSnapshot.polygons.map((p) => p.sourceId),
  );
}
