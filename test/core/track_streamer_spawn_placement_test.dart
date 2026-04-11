import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:runner_core/tuning/track_tuning.dart';

void main() {
  test(
    'obstacleTop falls back to highest surface when no obstacle matches X',
    () {
      const pattern = ChunkPattern(
        name: 'obstacle-top-fallback',
        platforms: <PlatformRel>[
          PlatformRel(
            x: 160.0,
            width: 80.0,
            aboveGroundTop: 64.0,
            thickness: 16.0,
          ),
        ],
        spawnMarkers: <SpawnMarker>[
          SpawnMarker(
            enemyId: EnemyId.derf,
            x: 200.0,
            chancePercent: 100,
            salt: 0x1,
            placement: SpawnPlacementMode.obstacleTop,
          ),
        ],
      );

      const source = ChunkPatternListSource(
        easyPatterns: <ChunkPattern>[pattern],
        hardPatterns: <ChunkPattern>[pattern],
      );

      final streamer = TrackStreamer(
        seed: 99,
        tuning: const TrackTuning(spawnAheadMargin: 0.0),
        groundTopY: 220.0,
        patternSource: source,
        earlyPatternChunks: 0,
        noEnemyChunks: 0,
      );

      final spawns = <SpawnEnemyRequest>[];
      streamer.step(cameraLeft: 0.0, cameraRight: 0.0, spawnEnemy: spawns.add);

      expect(spawns.length, 1);
      expect(spawns.single.enemyId, EnemyId.derf);
      expect(spawns.single.surfaceTopY, closeTo(156.0, 1e-9)); // 220 - 64
    },
  );

  test('obstacleTop prefers obstacle surfaces over platform surfaces', () {
    const pattern = ChunkPattern(
      name: 'obstacle-top-preference',
      platforms: <PlatformRel>[
        PlatformRel(
          x: 160.0,
          width: 128.0,
          aboveGroundTop: 96.0,
          thickness: 16.0,
        ),
      ],
      obstacles: <ObstacleRel>[
        ObstacleRel(x: 176.0, width: 80.0, height: 64.0),
      ],
      spawnMarkers: <SpawnMarker>[
        SpawnMarker(
          enemyId: EnemyId.derf,
          x: 200.0,
          chancePercent: 100,
          salt: 0x2,
          placement: SpawnPlacementMode.obstacleTop,
        ),
      ],
    );

    const source = ChunkPatternListSource(
      easyPatterns: <ChunkPattern>[pattern],
      hardPatterns: <ChunkPattern>[pattern],
    );

    final streamer = TrackStreamer(
      seed: 77,
      tuning: const TrackTuning(spawnAheadMargin: 0.0),
      groundTopY: 220.0,
      patternSource: source,
      earlyPatternChunks: 0,
      noEnemyChunks: 0,
    );

    final spawns = <SpawnEnemyRequest>[];
    streamer.step(cameraLeft: 0.0, cameraRight: 0.0, spawnEnemy: spawns.add);

    expect(spawns.length, 1);
    expect(spawns.single.enemyId, EnemyId.derf);
    expect(spawns.single.surfaceTopY, closeTo(156.0, 1e-9)); // 220 - 64
  });
}
