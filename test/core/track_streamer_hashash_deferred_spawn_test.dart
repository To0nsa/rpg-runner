import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:runner_core/tuning/track_tuning.dart';

void main() {
  test('defers hashash spawns until chunk becomes camera-right', () {
    const pattern = ChunkPattern(
      name: 'hashash-deferred',
      spawnMarkers: <SpawnMarker>[
        SpawnMarker(
          enemyId: EnemyId.hashash,
          x: 160.0,
          chancePercent: 100,
          salt: 0x1,
        ),
        SpawnMarker(
          enemyId: EnemyId.unocoDemon,
          x: 160.0,
          chancePercent: 100,
          salt: 0x2,
        ),
      ],
    );

    const source = ChunkPatternListSource(
      easyPatterns: <ChunkPattern>[pattern],
      hardPatterns: <ChunkPattern>[pattern],
    );

    final streamer = TrackStreamer(
      seed: 123,
      tuning: const TrackTuning(),
      groundTopY: 220.0,
      patternSource: source,
      earlyPatternChunks: 0,
      noEnemyChunks: 0,
    );

    final spawns = <({EnemyId enemyId, double x, double surfaceTopY})>[];
    void onSpawn(SpawnEnemyRequest request) {
      spawns.add((
        enemyId: request.enemyId,
        x: request.x,
        surfaceTopY: request.surfaceTopY,
      ));
    }

    streamer.step(cameraLeft: 0.0, cameraRight: 650.0, spawnEnemy: onSpawn);
    final firstHashash = spawns
        .where((spawn) => spawn.enemyId == EnemyId.hashash)
        .toList();
    final firstUnoco = spawns
        .where((spawn) => spawn.enemyId == EnemyId.unocoDemon)
        .toList();
    expect(firstHashash.length, 1);
    expect(firstHashash.single.x, closeTo(600.0, 1e-9));
    expect(firstUnoco.length, 3);
    expect(firstUnoco[0].x, closeTo(160.0, 1e-9));
    expect(firstUnoco[1].x, closeTo(760.0, 1e-9));
    expect(firstUnoco[2].x, closeTo(1360.0, 1e-9));

    spawns.clear();
    streamer.step(cameraLeft: 0.0, cameraRight: 650.0, spawnEnemy: onSpawn);
    expect(spawns.where((spawn) => spawn.enemyId == EnemyId.hashash), isEmpty);

    spawns.clear();
    streamer.step(cameraLeft: 0.0, cameraRight: 1250.0, spawnEnemy: onSpawn);
    final secondHashash = spawns
        .where((spawn) => spawn.enemyId == EnemyId.hashash)
        .toList();
    expect(secondHashash.length, 1);
    expect(secondHashash.single.x, closeTo(1200.0, 1e-9));
  });
}
