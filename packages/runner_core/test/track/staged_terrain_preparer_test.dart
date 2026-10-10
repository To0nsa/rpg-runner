import 'dart:async';

import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/navigation/actor_navigation_profiles.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/track/connected_chunk_pattern_source.dart';
import 'package:runner_core/navigation/types/terrain_surface_graph.dart';
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

  test(
    'publishes the nearest result while the following job is pending',
    () async {
      final worker = _ControlledPreparation();
      final preparer = _preparerWithWorker(worker);
      addTearDown(preparer.dispose);
      addTearDown(worker.close);
      final streamer = _streamer(LevelId.field);
      _step(streamer, 0);
      final window = streamer.upcomingSelections(viewWidth: 600, count: 2);
      final pending = preparer.prepare(window);
      expect(
        worker.started,
        0,
        reason: 'handoff stays outside the frame stack',
      );
      final first = await worker.next();
      first.complete();
      final second = await worker.next();
      expect(preparer.stats.ready, 1);
      final candidate = preparer.take(window.first, geometryVersion: 8);
      expect(candidate, isNotNull);
      _expectSamePublication(candidate!, _build(window.first, 8));
      final latest = preparer.prepare([window.last]);
      second.complete();
      await Future.wait([pending, latest]);
      expect(worker.started, 2);
      expect(preparer.stats.completed, 2);
      expect(preparer.stats.discarded, 0);
      expect(preparer.stats.ready, 1);
      expect(preparer.take(window.last, geometryVersion: 9), isNotNull);
    },
  );

  test(
    'replaces queued work after the current candidate, discarding stale output',
    () async {
      final worker = _ControlledPreparation();
      final preparer = _preparerWithWorker(worker);
      addTearDown(preparer.dispose);
      addTearDown(worker.close);
      final streamer = _streamer(LevelId.field);
      _step(streamer, 0);
      final old = streamer.upcomingSelections(viewWidth: 600, count: 8);
      final pending = preparer.prepare(old);
      final first = await worker.next();
      _step(streamer, 12000);
      final replacement = streamer.upcomingSelections(viewWidth: 600, count: 1);
      final latest = preparer.prepare(replacement);
      first.complete();
      final next = await worker.next();
      expect(preparer.stats.ready, 0);
      expect(next.bindings.first.chunkIndex, replacement.first.first.index);
      next.complete();
      await Future.wait([pending, latest]);
      expect(worker.started, 2);
      expect(preparer.stats.completed, 2);
      expect(preparer.stats.discarded, 1);
      expect(preparer.take(old.first, geometryVersion: 2), isNull);
      expect(preparer.take(replacement.first, geometryVersion: 3), isNotNull);
    },
  );

  for (final stop in ['dispose', 'disable', 'worker error']) {
    test('$stop prevents late publication and further jobs', () async {
      final worker = _ControlledPreparation();
      final preparer = _preparerWithWorker(worker);
      addTearDown(preparer.dispose);
      addTearDown(worker.close);
      final streamer = _streamer(LevelId.field);
      _step(streamer, 0);
      final window = streamer.upcomingSelections(viewWidth: 600, count: 8);
      final pending = preparer.prepare(window);
      final first = await worker.next();
      if (stop == 'dispose') preparer.dispose();
      if (stop == 'disable') preparer.disable(StateError('admission failed'));
      if (stop == 'worker error') {
        first.completer.completeError(StateError('worker failed'));
      } else {
        first.complete();
      }
      await pending;
      await preparer.prepare(window);
      expect(worker.started, 1);
      expect(preparer.stats.ready, 0);
      expect(preparer.take(window.first, geometryVersion: 2), isNull);
      if (stop != 'dispose') {
        expect(preparer.stats.lastError, contains('failed'));
      }
    });
  }

  for (final seed in [42, 857469563]) {
    test(
      'prepared Forest publications exactly match synchronous builds seed=$seed',
      () async {
        final streamer = _streamer(LevelId.forest, seed: seed);
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
          for (var x = 9000.5; x <= 18000.5; x += 600) x,
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
      },
      // This compares every publication with a full rebuild in browser debug
      // output as well as native; neither path skips the dense Forest windows.
      timeout: const Timeout(Duration(minutes: 10)),
    );
  }

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

TrackStreamer _streamer(LevelId id, {TrackTuning? tuning, int seed = 42}) {
  final level = LevelRegistry.byId(id);
  return TrackStreamer(
    seed: seed,
    tuning: tuning ?? level.tuning.track,
    groundTopY: level.groundTopY,
    patternSource: ConnectedChunkPatternSource.forLevel(
      level: level,
      catalog: StagedTerrainArtifactCatalog(artifact: stagedAuthoredTerrain),
    ),
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
  groundEnemyProfiles: _profiles(),
);

StagedTerrainStreamCandidate _build(
  List<ActiveTrackChunkSnapshot> chunks,
  int version,
) => const StagedTerrainStreamCandidateBuilder().build(
  catalog: StagedTerrainArtifactCatalog(artifact: stagedAuthoredTerrain),
  activeChunks: chunks,
  geometryVersion: version,
  groundEnemyProfiles: _profiles(),
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

StagedTerrainPreparer _preparerWithWorker(_ControlledPreparation worker) =>
    StagedTerrainPreparer(
      catalog: StagedTerrainArtifactCatalog(artifact: stagedAuthoredTerrain),
      groundEnemyProfiles: _profiles(),
      prepareCandidate: worker.prepare,
    );

class _ControlledPreparation {
  final _requests = StreamController<_PendingCandidate>();
  late final _iterator = StreamIterator(_requests.stream);
  int started = 0;

  Future<StagedTerrainStreamCandidate> prepare(
    List<StagedTerrainChunkBinding> bindings,
    List<TerrainSurfaceGraphBuildProfile> profiles,
  ) {
    started += 1;
    final request = _PendingCandidate(bindings, profiles);
    _requests.add(request);
    return request.completer.future;
  }

  Future<_PendingCandidate> next() async {
    if (!await _iterator.moveNext()) throw StateError('worker closed');
    return _iterator.current;
  }

  Future<void> close() async {
    await _iterator.cancel();
    await _requests.close();
  }
}

class _PendingCandidate {
  _PendingCandidate(this.bindings, this.profiles);
  final List<StagedTerrainChunkBinding> bindings;
  final List<TerrainSurfaceGraphBuildProfile> profiles;
  final completer = Completer<StagedTerrainStreamCandidate>();

  void complete() => completer.complete(
    const StagedTerrainStreamCandidateBuilder().buildFromBindings(
      bindings: bindings,
      geometryVersion: 0,
      groundEnemyProfiles: profiles,
    ),
  );
}

List<TerrainSurfaceGraphBuildProfile> _profiles() {
  final tuning = LevelRegistry.byId(LevelId.forest).tuning;
  return buildActorNavigationProfiles(
    enemyCatalog: const EnemyCatalog(),
    locomotion: tuning.groundEnemy.locomotion,
    physics: tuning.physics,
    tickHz: 60,
  );
}
