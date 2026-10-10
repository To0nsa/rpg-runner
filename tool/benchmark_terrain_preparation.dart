/// AOT-friendly terrain publication benchmark using production compiled levels.
///
/// Run with `dart run tool/benchmark_terrain_preparation.dart [--realtime] [--forest]`.
/// Default mode awaits each window between transitions to isolate publication
/// cost. Real-time mode advances at 60 Hz and allows refills only their actual
/// lead time, exposing cache starvation. Neither mode simulates/render actors.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:runner_core/contracts/render_contract.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/navigation/actor_navigation_profiles.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/track/connected_chunk_pattern_source.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_preparer.dart';
import 'package:runner_core/track/staged_terrain_stream_candidate.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:runner_core/util/cooperative_work_yield.dart';

Future<void> main(List<String> args) async {
  stdout.writeln(
    jsonEncode(
      await benchmarkTerrainPreparation(
        realTime: args.contains('--realtime'),
        seed: _integerOption(args, 'seed', 42),
        seconds: _integerOption(args, 'seconds', 180),
        levelIds: args.contains('--forest') ? const [LevelId.forest] : null,
      ),
    ),
  );
}

/// Returns main-isolate publication/refill-dispatch timing and cache coverage
/// for connected production selections at 200 world units/second.
/// Includes all enemy and allied navigation profiles from the level tuning.
/// Initial preparation and the synchronous initial world are outside play time.
Future<Map<String, Object?>> benchmarkTerrainPreparation({
  bool realTime = false,
  Iterable<LevelId>? levelIds,
  int seed = 42,
  int seconds = 180,
  void Function(LevelId)? onMeasurementStart,
}) async {
  if (seconds <= 0) throw ArgumentError.value(seconds, 'seconds');
  final catalog = StagedTerrainArtifactCatalog(artifact: stagedAuthoredTerrain);
  final levels = <Map<String, Object?>>[];
  for (final id in levelIds ?? LevelRegistry.compiledLevelIds) {
    final level = LevelRegistry.byId(id);
    final profiles = buildActorNavigationProfiles(
      enemyCatalog: const EnemyCatalog(),
      locomotion: level.tuning.groundEnemy.locomotion,
      physics: level.tuning.physics,
      tickHz: 60,
    );
    final streamer = TrackStreamer(
      seed: seed,
      tuning: level.tuning.track,
      groundTopY: level.groundTopY,
      patternSource: ConnectedChunkPatternSource.forLevel(
        level: level,
        catalog: catalog,
      ),
      earlyPatternChunks: level.earlyPatternChunks,
      easyPatternChunks: level.easyPatternChunks,
      normalPatternChunks: level.normalPatternChunks,
      noEnemyChunks: level.noEnemyChunks,
    );
    final preparer = StagedTerrainPreparer(
      catalog: catalog,
      groundEnemyProfiles: profiles,
    );
    try {
      Future<void> prepare() => preparer.prepare(
        streamer.upcomingSelections(
          viewWidth: virtualWidth.toDouble(),
          count: StagedTerrainPreparer.selectionCapacity,
        ),
      );
      streamer.step(
        cameraLeft: 0,
        cameraRight: virtualWidth.toDouble(),
        spawnEnemy: (_) {},
      );
      const StagedTerrainStreamCandidateBuilder().build(
        catalog: catalog,
        activeChunks: streamer.activeChunks,
        geometryVersion: 1,
        groundEnemyProfiles: profiles,
      );
      final loading = Stopwatch()..start();
      await prepare();
      loading.stop();
      onMeasurementStart?.call(id);
      final wall = Stopwatch()..start();
      final watch = Stopwatch();
      final rows = <Map<String, Object?>>[];
      var version = 1;
      var discardedWallTimeUs = 0;
      for (var tick = 1; tick <= seconds * 60; tick += 1) {
        if (realTime) {
          final now = wall.elapsedMicroseconds;
          final targetUs = tick * 1000000 ~/ 60 + discardedWallTimeUs;
          final lagUs = now - targetUs;
          // Match the controller's 100 ms catch-up cap. A stall must not create
          // an unbounded synchronous replay of overdue transitions.
          if (lagUs > 100000) discardedWallTimeUs += lagUs - 100000;
          final waitUs = tick * 1000000 ~/ 60 + discardedWallTimeUs - now;
          if (waitUs > 0) {
            await Future<void>.delayed(Duration(microseconds: waitUs));
          } else {
            await yieldCooperativeWork();
          }
        }
        watch
          ..reset()
          ..start();
        final x = tick * 200.0 / 60;
        final result = streamer.step(
          cameraLeft: x,
          cameraRight: x + virtualWidth,
          spawnEnemy: (_) {},
        );
        if (!result.changed) continue;
        version += 1;
        final prepared = preparer.take(
          streamer.activeChunks,
          geometryVersion: version,
        );
        final candidate =
            prepared ??
            const StagedTerrainStreamCandidateBuilder().build(
              catalog: catalog,
              activeChunks: streamer.activeChunks,
              geometryVersion: version,
              groundEnemyProfiles: profiles,
            );
        final publicationUs = watch.elapsedMicroseconds;
        final refill = prepare();
        watch.stop();
        rows.add({
          'tick': tick,
          'publicationUs': publicationUs,
          'updateUs': watch.elapsedMicroseconds,
          'cached': prepared != null,
          'surfaces': candidate.runtimeBundle.surfaceSet.surfaces.length,
          'graphEdges': candidate.runtimeBundle.graphPublication.graphs
              .fold<int>(0, (count, graph) => count + graph.edges.length),
          'ready': preparer.stats.ready,
          'lastPreparationMs': preparer.stats.lastPreparationMicros / 1000,
          'chunks': [for (final chunk in streamer.activeChunks) chunk.chunkKey],
        });
        if (!realTime) await refill;
      }
      final times = rows.map((row) => row['updateUs']! as int).toList()..sort();
      final stats = preparer.stats;
      final summary = {
        'level': id.name,
        'seed': seed,
        'seconds': seconds,
        'wallSeconds': wall.elapsedMicroseconds / 1000000,
        'discardedWallTimeMs': discardedWallTimeUs / 1000,
        'profiles': [for (final profile in profiles) profile.profileKey],
        'transitions': rows.length,
        'initialPreparationMs': loading.elapsedMicroseconds / 1000,
        'medianMs': times.isEmpty ? 0 : times[times.length ~/ 2] / 1000,
        'p95Ms': times.isEmpty
            ? 0
            : times[(times.length * .95).ceil() - 1] / 1000,
        'maxMs': times.isEmpty ? 0 : times.last / 1000,
        'hits': stats.hits,
        'misses': stats.misses,
        'completed': stats.completed,
        'discarded': stats.discarded,
        'maxPreparationMs': stats.maxPreparationMicros / 1000,
        'error': stats.lastError,
      };
      levels.add({'summary': summary, 'rows': rows});
    } finally {
      preparer.dispose();
    }
  }
  return {'mode': realTime ? 'realtime' : 'awaited', 'levels': levels};
}

int _integerOption(List<String> args, String name, int fallback) {
  final prefix = '--$name=';
  final matches = args.where((arg) => arg.startsWith(prefix)).toList();
  if (matches.isEmpty) return fallback;
  if (matches.length != 1) throw ArgumentError('Duplicate --$name.');
  return int.parse(matches.single.substring(prefix.length));
}
