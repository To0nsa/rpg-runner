import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:test/test.dart';

import '../test_support/level_enemy_traversal.dart';

// Keep route horizons explicit: null means the complete non-looping assembly.
// Endless levels cover 32 chunks, including their configured difficulty ramps.
const _scenarios = [
  (levelId: LevelId.forest, chunkCount: null),
  (levelId: LevelId.field, chunkCount: 32),
  (levelId: LevelId.new_level, chunkCount: 32),
];
const _seeds = [7, 42, 2026];
// Derf is stationary; its spawn/clearance behavior has separate tests.
const _mobileEnemies = [EnemyId.grojib, EnemyId.hashash, EnemyId.unocoDemon];

void main() {
  test('every compiled level has an explicit traversal scenario', () {
    expect(
      _scenarios.map((scenario) => scenario.levelId).toSet(),
      LevelRegistry.compiledLevelIds,
    );
  });

  for (final previous in [
    'forest_rocky_grove_easy_004',
    'forest_rocky_grove_easy_007',
  ]) {
    for (final enemy in [EnemyId.grojib, EnemyId.hashash]) {
      test(
        'rock foothold after $previous continuously reaches route exit for ${enemy.name}',
        () {
          final route = LevelTraversalRoute.chunks(
            level: LevelRegistry.byId(LevelId.forest),
            seed: 7,
            chunkKeys: [
              'forest_early_first_chunk_001',
              previous,
              'forest_rocky_grove_easy_008',
              'forest_rocky_grove_easy_009',
            ],
            continuationChunkKey: 'forest_rocky_grove_normal_001',
          );
          final harness = EnemyTraversalHarness(route, enemy);
          expect(harness.traverse(), isNull);
          expect(harness.enemyX, greaterThanOrEqualTo(harness.finishX));
          expect(harness.visitedChunks, containsAll([0, 1, 2, 3]));
        },
      );
    }
  }

  for (final scenario in _scenarios) {
    testLevelEnemyTraversal(
      levelId: scenario.levelId,
      chunkCount: scenario.chunkCount,
      seeds: _seeds,
      enemyIds: _mobileEnemies,
    );
  }
}
