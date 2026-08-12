import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:runner_core/tuning/track_tuning.dart';

void main() {
  test('retains authored placement intent without resolving collision', () {
    const pattern = ChunkPattern(
      name: 'terrain-placement-intent',
      spawnMarkers: <SpawnMarker>[
        SpawnMarker(
          enemyId: EnemyId.derf,
          x: 200,
          chancePercent: 100,
          salt: 1,
          placement: SpawnPlacementMode.obstacleTop,
        ),
        SpawnMarker(
          enemyId: EnemyId.grojib,
          x: 300,
          chancePercent: 100,
          salt: 2,
          placement: SpawnPlacementMode.highestSurfaceAtX,
        ),
      ],
    );
    const source = ChunkPatternListSource(
      easyPatterns: <ChunkPattern>[pattern],
      hardPatterns: <ChunkPattern>[pattern],
    );
    final streamer = TrackStreamer(
      seed: 77,
      tuning: const TrackTuning(spawnAheadMargin: 0),
      groundTopY: 220,
      patternSource: source,
      earlyPatternChunks: 0,
      noEnemyChunks: 0,
    );
    final spawns = <SpawnEnemyRequest>[];

    streamer.step(cameraLeft: 0, cameraRight: 0, spawnEnemy: spawns.add);

    expect(spawns, hasLength(2));
    expect(spawns[0].placement, SpawnPlacementMode.obstacleTop);
    expect(spawns[1].placement, SpawnPlacementMode.highestSurfaceAtX);
    expect(spawns.every((spawn) => spawn.fallbackSupportY == 220), isTrue);
  });
}
