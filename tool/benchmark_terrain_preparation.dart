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
import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_preparer.dart';
import 'package:runner_core/track/staged_terrain_stream_candidate.dart';
import 'package:runner_core/track/track_streamer.dart';

Future<void> main(List<String> args) async {
  stdout.writeln(
    jsonEncode(
      await benchmarkTerrainPreparation(
        realTime: args.contains('--realtime'),
        levelIds: args.contains('--forest') ? const [LevelId.forest] : null,
      ),
    ),
  );
}

/// Returns main-isolate publication/refill-dispatch timing and cache coverage
/// for seed 42, 60 seconds per level, at the baseline 200 world units/second.
/// Initial preparation and the synchronous initial world are outside play time.
Future<Map<String, Object?>> benchmarkTerrainPreparation({
  bool realTime = false,
  Iterable<LevelId>? levelIds,
}) async {
  final catalog = StagedTerrainArtifactCatalog(artifact: stagedAuthoredTerrain);
  final profiles = buildDefaultGroundEnemyTerrainGraphProfiles();
  final levels = <Map<String, Object?>>[];
  for (final id in levelIds ?? LevelRegistry.compiledLevelIds) {
    final level = LevelRegistry.byId(id);
    final streamer = TrackStreamer(
      seed: 42,
      tuning: level.tuning.track,
      groundTopY: level.groundTopY,
      patternSource: level.chunkPatternSource,
      earlyPatternChunks: level.earlyPatternChunks,
      easyPatternChunks: level.easyPatternChunks,
      normalPatternChunks: level.normalPatternChunks,
      noEnemyChunks: level.noEnemyChunks,
    );
    final preparer = StagedTerrainPreparer(
      catalog: catalog,
      groundEnemyProfiles: profiles,
    );
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
    final wall = Stopwatch()..start();
    final watch = Stopwatch();
    final rows = <Map<String, Object?>>[];
    var version = 1;
    for (var tick = 1; tick <= 3600; tick += 1) {
      if (realTime) {
        final waitUs = tick * 1000000 ~/ 60 - wall.elapsedMicroseconds;
        if (waitUs > 0) {
          await Future<void>.delayed(Duration(microseconds: waitUs));
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
        'graphEdges':
            candidate.runtimeBundle.grojibGraph.edges.length +
            candidate.runtimeBundle.hashashGraph.edges.length,
      });
      if (!realTime) await refill;
    }
    final times = rows.map((row) => row['updateUs']! as int).toList()..sort();
    final stats = preparer.stats;
    final summary = {
      'level': id.name,
      'transitions': rows.length,
      'initialPreparationMs': loading.elapsedMicroseconds / 1000,
      'medianMs': times[times.length ~/ 2] / 1000,
      'p95Ms': times[(times.length * .95).ceil() - 1] / 1000,
      'maxMs': times.last / 1000,
      'hits': stats.hits,
      'misses': stats.misses,
      'error': stats.lastError,
    };
    levels.add({'summary': summary, 'rows': rows});
    preparer.dispose();
  }
  return {'mode': realTime ? 'realtime' : 'awaited', 'levels': levels};
}
