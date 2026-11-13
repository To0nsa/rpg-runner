import 'package:runner_core/campaign/campaign_enemy_system.dart';
import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/ecs/stores/enemies/campaign_enemy_store.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

import '../test_support/level_enemy_traversal.dart';
import '../fixtures/level_traversal_finish_fixture.dart';

void main() {
  for (final enemy in [
    EnemyId.grojib,
    EnemyId.hashash,
    EnemyId.derf,
    EnemyId.unocoDemon,
  ]) {
    test(
      '${enemy.name}: jumps a 32-unit obstacle, crosses the seam and returns continuously',
      () {
        final route = LevelTraversalRoute.chunks(
          level: LevelRegistry.byId(LevelId.field),
          seed: 42,
          chunkKeys: ['finish_jump'],
          continuationChunkKey: 'finish_clear',
          catalog: levelTraversalFinishCatalog(),
        );
        final harness = EnemyTraversalHarness(route, enemy);
        _settle(harness);
        final homeX = harness.enemyX, homeY = harness.enemyY;
        expect(harness.traverse(), isNull);
        expect(harness.enemyX, greaterThanOrEqualTo(600));
        expect(
          _return(harness, homeX, homeY),
          isTrue,
          reason:
              'home=($homeX,$homeY), actual=(${harness.enemyX},${harness.enemyY})',
        );
        expect(harness.enemyX, closeTo(homeX, 4));
        expect(harness.enemyY, closeTo(homeY, 4));
      },
    );
  }

  // Preserve the isolated rocky route's observed failures as blocked controls.
  // These exact placements are not the production selector's multi-chunk route.
  for (final enemy in [
    EnemyId.grojib,
    EnemyId.hashash,
    EnemyId.derf,
    EnemyId.unocoDemon,
  ]) {
    final blockedOutward = enemy == EnemyId.grojib || enemy == EnemyId.hashash;
    test(
      '${enemy.name}: isolated rocky grove seed=42 ${blockedOutward
          ? 'reports blocked outward route'
          : enemy == EnemyId.derf
          ? 'retains blocked return without relocation'
          : 'returns continuously'}',
      () {
        final route = LevelTraversalRoute.chunks(
          level: LevelRegistry.byId(LevelId.forest),
          seed: 42,
          chunkKeys: ['forest_rocky_grove_easy_001'],
          continuationChunkKey: 'forest_rocky_grove_easy_001',
        );
        final harness = EnemyTraversalHarness(route, enemy);
        _settle(harness);
        final homeX = harness.enemyX, homeY = harness.enemyY;
        final outward = harness.traverse();
        if (blockedOutward) {
          expect(
            outward,
            allOf(contains('no forward progress'), contains('reachable=false')),
          );
          expect(harness.enemyX, lessThan(600));
          return;
        }
        expect(outward, isNull);
        expect(harness.enemyX, greaterThanOrEqualTo(600));
        final returned = _return(harness, homeX, homeY);
        if (enemy == EnemyId.derf) {
          expect(returned, isFalse);
          expect(
            harness.world.navIntent.hasPlan[harness.world.navIntent.indexOf(
              harness.enemy,
            )],
            isFalse,
          );
          expect(harness.enemyX, greaterThan(600));
        } else {
          expect(returned, isTrue);
          expect(harness.enemyX, closeTo(homeX, 4));
          expect(harness.enemyY, closeTo(homeY, 4));
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}

bool _return(EnemyTraversalHarness harness, double homeX, double homeY) {
  final world = harness.world;
  world.campaignEnemy.add(
    harness.enemy,
    x: homeX,
    y: homeY,
    facing: Facing.right,
    returns: true,
  );
  world.campaignEnemy.phase[0] = CampaignEnemyPhase.returning;
  world.actorMotionBounds.add(
    harness.enemy,
    TerrainHorizontalBounds(
      minXTicks: 0,
      maxXTicks: physicsCoordinateToTicks(
        homeX + CampaignEnemySystem.territoryRadius,
      ),
    ),
  );
  final system = CampaignEnemySystem();
  var previousX = harness.enemyX;
  for (var elapsed = 0; elapsed < 1800; elapsed++) {
    harness.tick++;
    harness.authority.prepareTick(
      world,
      player: harness.player,
      currentTick: harness.tick,
    );
    system.step(world, player: harness.player, tick: harness.tick);
    harness.stepMovement();
    expect((harness.enemyX - previousX).abs(), lessThan(12));
    previousX = harness.enemyX;
    if (world.campaignEnemy.phase[0] == CampaignEnemyPhase.waiting) return true;
  }
  return false;
}

void _settle(EnemyTraversalHarness harness) {
  // The generic harness seeds Y from its level reference. Let actual fixture
  // terrain resolve the home before retaining it, as production placement does.
  harness.authority.prepareTick(
    harness.world,
    player: harness.player,
    currentTick: 0,
  );
  harness.stepMovement();
}
