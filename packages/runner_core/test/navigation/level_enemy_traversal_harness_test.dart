import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';
import 'package:test/test.dart';

import '../fixtures/level_traversal_finish_fixture.dart';
import '../test_support/level_enemy_traversal.dart';

void main() {
  final level = LevelRegistry.byId(LevelId.field);
  final flat = LevelTraversalRoute.chunks(
    level: level,
    seed: 7,
    chunkKeys: List.filled(3, 'field_default_normal_001'),
    continuationChunkKey: 'field_default_normal_001',
  );

  for (final enemyId in EnemyId.values) {
    test('flat control ${enemyId.name} crosses every seam', () {
      final harness = EnemyTraversalHarness(flat, enemyId);
      expect(harness.traverse(), isNull);
      expect(harness.visitedChunks, containsAll([0, 1, 2]));
      expect(harness.finishX, 1800);
      expect(harness.enemyX, greaterThanOrEqualTo(1800));
      expect(harness.targetX, greaterThan(1800));
    });
  }

  final finishCatalog = levelTraversalFinishCatalog();
  for (final enemyId in EnemyId.values) {
    test('${enemyId.name} crosses the clear single-chunk finish', () {
      final route = LevelTraversalRoute.chunks(
        level: level,
        seed: 7,
        chunkKeys: ['finish_clear'],
        continuationChunkKey: 'finish_clear',
        catalog: finishCatalog,
      );
      final harness = EnemyTraversalHarness(route, enemyId);
      expect(harness.traverse(), isNull);
      expect(harness.finishX, 600);
      expect(harness.enemyX, greaterThanOrEqualTo(600));
      expect(harness.targetX, greaterThan(600));
      expect(harness.visitedChunks, {0});
    });
  }
  for (final enemyId in groundNavigatingEnemyIds) {
    for (final chunkCount in [1, 3]) {
      test('${enemyId.name} rejects a blocked finish after $chunkCount chunks', () {
        final route = LevelTraversalRoute.chunks(
          level: level,
          seed: 7,
          chunkKeys: [
            ...List.filled(chunkCount - 1, 'finish_clear'),
            'finish_blocked',
          ],
          continuationChunkKey: 'finish_clear',
          catalog: finishCatalog,
        );
        final harness = EnemyTraversalHarness(route, enemyId);
        expect(harness.traverse(), contains('no forward progress'));
        expect(harness.finishX, chunkCount * 600);
        expect(harness.enemyX, lessThan(chunkCount * 600));
        if (chunkCount == 1) {
          // Visiting every chunk must never substitute for crossing the finish.
          expect(harness.visitedChunks, {0});
        } else {
          expect(harness.windowIndex, greaterThan(0));
        }
      });
    }
  }
  test('a larger waypoint tolerance cannot accept a blocked finish', () {
    final route = LevelTraversalRoute.chunks(
      level: level,
      seed: 7,
      chunkKeys: ['finish_blocked'],
      continuationChunkKey: 'finish_clear',
      catalog: finishCatalog,
    );
    final harness = EnemyTraversalHarness(
      route,
      EnemyId.grojib,
      arrivalDistance: 256,
    );
    expect(harness.traverse(), contains('no forward progress'));
    expect(harness.finishX, 600);
    expect(harness.enemyX, lessThan(600));
  });

  test('endless routes require a declared finite horizon', () {
    expect(
      () => LevelTraversalRoute.scheduled(level: level, seed: 7),
      throwsArgumentError,
    );
    expect(
      () => LevelTraversalRoute.scheduled(level: level, seed: 7, chunkCount: 0),
      throwsArgumentError,
    );
  });

  test('insufficient movement fails with reproducible stall evidence', () {
    final slowRoute = LevelTraversalRoute.chunks(
      level: level.copyWith(
        tuning: const CoreTuning(
          groundEnemy: GroundEnemyTuning(
            locomotion: GroundEnemyLocomotionTuning(speedX: 0.1),
          ),
        ),
      ),
      seed: 42,
      chunkKeys: flat.keys,
      continuationChunkKey: flat.continuationChunkKey,
    );
    final harness = EnemyTraversalHarness(slowRoute, EnemyId.grojib);
    expect(
      harness.traverse(),
      allOf(
        contains('level=field grojib seed=42'),
        contains('no forward progress for 600 ticks'),
        contains('field_default_normal_001'),
        contains('speedX=0.1'),
        contains('graph current='),
        contains(
          'route=field_default_normal_001 -> field_default_normal_001 -> field_default_normal_001',
        ),
      ),
    );
    expect(harness.visitedChunks, hasLength(1));
  });

  test('tick budget cannot turn an incomplete route into a pass', () {
    final harness = EnemyTraversalHarness(
      flat,
      EnemyId.grojib,
      ticksPerChunk: 1,
    );
    expect(harness.traverse(), contains('exceeded 3 tick budget'));
  });

  test('crossing the level kill plane fails the route', () {
    final lethalRoute = LevelTraversalRoute.chunks(
      level: level.copyWith(killPlaneY: 100),
      seed: 7,
      chunkKeys: flat.keys,
      continuationChunkKey: flat.continuationChunkKey,
    );
    expect(
      EnemyTraversalHarness(lethalRoute, EnemyId.grojib).traverse(),
      contains('fell below kill plane'),
    );
  });
}
