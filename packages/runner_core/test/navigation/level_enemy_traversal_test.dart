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
// Arena bosses are confined; boss_arena_test covers their actual combat bounds.
const _mobileEnemies = [
  EnemyId.unocoDemon,
  EnemyId.grojib,
  EnemyId.hashash,
  EnemyId.derf,
];

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
              'forest_default_early_001',
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

  for (final regression in [
    (
      seed: 7,
      previous: 'forest_trainingcamp_hard_001',
      next: 'forest_trainingcamp_hard_004',
    ),
    (
      seed: 42,
      previous: 'forest_trainingcamp_hard_002',
      next: 'forest_trainingcamp_hard_004',
    ),
    (seed: 42, previous: 'forest_ruin_hard_001', next: 'forest_ruin_hard_005'),
    (
      seed: 2026,
      previous: 'forest_rocky_grove_hard_009',
      next: 'forest_ruin_hard_005',
    ),
  ]) {
    for (final enemy in [EnemyId.grojib, EnemyId.hashash, EnemyId.derf]) {
      test('hard obstacle clearance after ${regression.previous} reaches '
          '${regression.next} exit for ${enemy.name}', () {
        final route = LevelTraversalRoute.chunks(
          level: LevelRegistry.byId(LevelId.forest),
          seed: regression.seed,
          chunkKeys: [
            'forest_default_early_001',
            regression.previous,
            regression.next,
          ],
          continuationChunkKey: 'forest_rocky_grove_hard_003',
        );
        final harness = EnemyTraversalHarness(route, enemy);
        expect(harness.traverse(), isNull);
        expect(harness.enemyX, greaterThanOrEqualTo(harness.finishX));
        expect(harness.visitedChunks, containsAll([0, 1, 2]));
      });
    }
  }

  for (final regression in [
    (
      seed: 7,
      name: 'normal camp crate approach after boss sequence',
      keys: [
        'forest_default_early_001',
        'forest_trainingcamp_normal_001',
        'forest_trainingcamp_normal_004',
        'forest_trainingcamp_normal_003',
        'forest_trainingcamp_normal_002',
      ],
      continuation: 'forest_rocky_grove_normal_007',
    ),
    (
      seed: 7,
      name: 'normal grove into hard gap after boss sequence',
      keys: [
        'forest_default_early_001',
        'forest_rocky_grove_normal_001',
        'forest_rocky_grove_normal_007',
        'forest_rocky_grove_normal_008',
        'forest_rocky_grove_hard_008',
      ],
      continuation: 'forest_rocky_grove_hard_009',
    ),
    (
      seed: 7,
      name: 'hard camp and grove foothold',
      keys: [
        'forest_default_early_001',
        'forest_rocky_grove_hard_007',
        'forest_rocky_grove_hard_006',
        'forest_trainingcamp_hard_001',
        'forest_trainingcamp_hard_004',
        'forest_trainingcamp_hard_003',
        'forest_trainingcamp_hard_002',
        'forest_rocky_grove_hard_007',
        'forest_rocky_grove_hard_008',
      ],
      continuation: 'forest_rocky_grove_hard_005',
    ),
    (
      seed: 42,
      name: 'hard ruin into grove gap',
      keys: [
        'forest_default_early_001',
        'forest_ruin_hard_005',
        'forest_rocky_grove_hard_002',
        'forest_rocky_grove_hard_003',
      ],
      continuation: 'forest_rocky_grove_hard_004',
    ),
    (
      seed: 2026,
      name: 'hard woodcamp entrance rock',
      keys: [
        'forest_default_early_001',
        'forest_woodcamp_hard_003',
        'forest_woodcamp_hard_002',
        'forest_woodcamp_hard_001',
      ],
      continuation: 'forest_rocky_grove_hard_002',
    ),
  ]) {
    for (final enemy in [EnemyId.grojib, EnemyId.hashash, EnemyId.derf]) {
      test('${regression.name} preserves continuous ${enemy.name} pursuit', () {
        final route = LevelTraversalRoute.chunks(
          level: LevelRegistry.byId(LevelId.forest),
          seed: regression.seed,
          chunkKeys: regression.keys,
          continuationChunkKey: regression.continuation,
        );
        final harness = EnemyTraversalHarness(route, enemy);
        expect(harness.traverse(), isNull);
        expect(harness.enemyX, greaterThanOrEqualTo(harness.finishX));
        expect(
          harness.visitedChunks,
          containsAll(List.generate(regression.keys.length, (index) => index)),
        );
      });
    }
  }

  test('Derf lands on the descending grove slope before its gap', () {
    final route = LevelTraversalRoute.chunks(
      level: LevelRegistry.byId(LevelId.forest),
      seed: 42,
      chunkKeys: [
        'forest_default_early_001',
        'forest_rocky_grove_normal_005',
        'forest_rocky_grove_normal_008',
        'forest_rocky_grove_hard_006',
      ],
      continuationChunkKey: 'forest_rocky_grove_hard_003',
    );
    final harness = EnemyTraversalHarness(route, EnemyId.derf);
    expect(harness.traverse(), isNull);
    expect(harness.enemyX, greaterThanOrEqualTo(harness.finishX));
    expect(harness.visitedChunks, containsAll([0, 1, 2, 3]));
  });

  for (final enemy in [EnemyId.grojib, EnemyId.hashash]) {
    test('hard grove rock foothold preserves pursuit for ${enemy.name}', () {
      final route = LevelTraversalRoute.chunks(
        level: LevelRegistry.byId(LevelId.forest),
        seed: 42,
        chunkKeys: [
          'forest_default_early_001',
          'forest_rocky_grove_hard_001',
          'forest_rocky_grove_hard_004',
        ],
        continuationChunkKey: 'forest_rocky_grove_hard_005',
      );
      final harness = EnemyTraversalHarness(route, enemy);
      expect(harness.traverse(), isNull);
      expect(harness.enemyX, greaterThanOrEqualTo(harness.finishX));
      expect(harness.visitedChunks, containsAll([0, 1, 2]));
    });
  }

  test('finish target finds support beyond a continuation midpoint gap', () {
    final route = LevelTraversalRoute.chunks(
      level: LevelRegistry.byId(LevelId.forest),
      seed: 2026,
      chunkKeys: ['forest_default_early_001', 'forest_rocky_grove_hard_007'],
      // Hard 008 now has a wide midpoint foothold; keep a real gap control.
      continuationChunkKey: 'forest_rocky_grove_normal_009',
    );
    final harness = EnemyTraversalHarness(route, EnemyId.unocoDemon);
    expect(harness.traverse(), isNull);
    expect(harness.finishX, 1200);
    expect(harness.enemyX, greaterThanOrEqualTo(harness.finishX));
    expect(harness.targetX, greaterThan(1500));
  });
}
