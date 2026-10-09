import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/combat/ai_cast_aim_policy.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';
import 'package:runner_core/ecs/systems/enemy_cast_system.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/enemy_melee_system.dart';
import 'package:runner_core/ecs/systems/hitbox_damage_system.dart';
import 'package:runner_core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:runner_core/ecs/systems/melee_strike_system.dart';
import 'package:runner_core/ecs/systems/target_point_impact_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/enemies/voidborn_goddess_render_catalog.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:test/test.dart';

import '../test_support/combat_pose.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    for (final (id, key, x, y, expectedHits) in [
      (EnemyId.voidbornGoddess, 'goddess.claw_combo', -21.33, -5.33, 4),
      (EnemyId.shoggoth, 'shoggoth.tentacle_sweep', -65.0, -10.0, 2),
      (EnemyId.shoggoth, 'shoggoth.spinning_charge', 0.0, -5.0, 2),
    ]) {
      test('$key strikes again only on a new swing at $hz Hz', () {
        final f = _Fixture(id, hz);
        expect(
          AiMeleeCommitter(tickHz: hz).commit(
            f.world,
            actor: f.boss,
            abilityId: key,
            targetX: -300,
            currentTick: 10,
          ),
          isNotNull,
        );
        final ai = f.world.activeAbility.indexOf(f.boss);
        final execute =
            f.world.meleeIntent.tick[f.world.meleeIntent.indexOf(f.boss)];
        resolveCombatPoses(f.world, execute, tickHz: hz);
        MeleeStrikeSystem().step(f.world, currentTick: execute);
        f.world.transform.setPosXY(f.player, x, y);
        for (
          var tick = execute;
          tick < execute + f.world.activeAbility.activeTicks[ai];
          tick++
        ) {
          f.hit(tick);
        }
        expect(f.world.damageQueue.target, List.filled(expectedHits, f.player));
        // A pose revisited after the final strike cannot reset its hit ledger.
        f.hit(execute);
        expect(f.world.damageQueue.length, expectedHits);
        f.expectAcceptedDamage(
          expectedHits * (key == 'shoggoth.spinning_charge' ? 600 : 700),
          tick: execute,
        );
      });
    }

    test(
      'hand warning matches its art then slaps once for 10 damage at $hz Hz',
      () {
        final f = _Fixture(EnemyId.voidbornGoddess, hz);
        final (execute, step) = f.spawnHand();
        final renderStep = VoidbornGoddessRenderCatalog
            .eruption
            .stepTimeSecondsByKey[AnimKey.hit]!;
        expect(step, (.06 * hz).round());
        expect((renderStep * hz).round(), step);
        final active = execute + 10 * step;
        f.world.transform.setPosXY(f.player, 300, 14);
        for (var tick = execute; tick < active; tick++) {
          f.hit(tick);
          expect(f.world.damageQueue.length, 0, reason: 'warning is harmless');
        }
        f.hit(active);
        expect(f.world.damageQueue.target, [f.player]);
        expect(f.world.damageQueue.amount100, [1000]);
        for (var tick = active + 1; tick < execute + 17 * step; tick++) {
          f.hit(tick);
        }
        expect(f.world.damageQueue.length, 1);
        f.expectAcceptedDamage(1000, tick: active);
      },
    );

    // Source-pixel samples from the upper finger and both palm edges of row 8.
    for (final (frame, tip, left, right) in [
      (10, (60.0, 58.0), (52.0, 87.0), (80.0, 88.0)),
      (11, (60.0, 56.0), (53.0, 87.0), (83.0, 88.0)),
      (12, (60.0, 51.0), (48.0, 68.0), (84.0, 89.0)),
      (13, (60.0, 56.0), (52.0, 88.0), (84.0, 89.0)),
      (14, (55.0, 67.0), (51.0, 82.0), (81.0, 88.0)),
    ]) {
      for (final facing in Facing.values) {
        test(
          'hand frame $frame covers its full silhouette at $hz Hz $facing',
          () {
            for (final (point, hits) in [
              (tip, true),
              (left, true),
              (right, true),
              ((30.0, 70.0), false),
              ((100.0, 70.0), false),
              (
                (80.0, 60.0),
                false,
              ), // Empty upper corner inside the broad bounds.
            ]) {
              final f = _Fixture(EnemyId.voidbornGoddess, hz);
              final (execute, step) = f.spawnHand(facing: facing);
              f.world.transform.setPosXY(
                f.player,
                300 + (point.$1 - 69) * 1.5,
                24 + (point.$2 - 92) * 1.5,
              );
              final tick = execute + frame * step;
              f.hit(tick);
              expect(
                f.world.damageQueue.target,
                hits ? [f.player] : isEmpty,
                reason: 'source pixel $point',
              );
              f.hit(tick + 1);
              expect(f.world.damageQueue.length, hits ? 1 : 0);
            }
          },
        );
      }
    }

    test('diagonal beam hits its visible upper-right slope at $hz Hz', () {
      final f = _Fixture(EnemyId.voidcaller, hz);
      expect(
        AiCastCommitter(
          tickHz: hz,
          projectiles: const ProjectileCatalog(),
          surfaceTarget: (x, y) => Vec2(x, 24),
        ).commit(
          f.world,
          actor: f.boss,
          castAbility: AbilityCatalog.shared.resolve(
            'voidcaller.diagonal_beam',
          )!,
          sourceX: 0,
          sourceY: 0,
          targetX: 300,
          targetY: 0,
          targetVelX: 0,
          targetVelY: 0,
          aimPolicy: AiCastAimPolicy.targetCenter,
          casterOriginOffset: 0,
          currentTick: 10,
        ),
        isTrue,
      );
      final i = f.world.targetPointIntent.indexOf(f.boss);
      final execute = f.world.targetPointIntent.tick[i];
      final active = execute + 5 * f.world.targetPointIntent.frameStepTicks[i];
      TargetPointImpactSystem().step(f.world, currentTick: execute);
      f.world.transform.setPosXY(f.player, 255, -72);
      f.hit(active);
      expect(
        f.world.damageQueue.length,
        0,
        reason: 'opposite diagonal is empty',
      );
      f.world.transform.setPosXY(f.player, 345, -72);
      f.hit(active);
      expect(f.world.damageQueue.target, [f.player]);
      expect(f.world.damageQueue.amount100, [700]);
      f.hit(active + 1);
      expect(f.world.damageQueue.length, 1);
      final step = f.world.targetPointIntent.frameStepTicks[i];
      for (var tick = active + 2; tick < execute + 10 * step; tick++) {
        f.hit(tick);
      }
      expect(f.world.damageQueue.target, List.filled(3, f.player));
      f.expectAcceptedDamage(2100, tick: active);
    });

    for (final facing in Facing.values) {
      for (final (frame, x, y) in [
        (4, -107.0, 8.0),
        (5, -83.0, -16.0),
        (6, 85.0, 12.0),
        (7, 62.0, 14.0),
      ]) {
        test('spin frame $frame hits the visible arc at $hz Hz $facing', () {
          final f = _Fixture(EnemyId.shoggoth, hz);
          final sign = facing == Facing.right ? 1.0 : -1.0;
          expect(
            AiMeleeCommitter(tickHz: hz).commit(
              f.world,
              actor: f.boss,
              abilityId: 'shoggoth.spinning_charge',
              targetX: 300 * sign,
              currentTick: 10,
            ),
            isNotNull,
          );
          final ai = f.world.activeAbility.indexOf(f.boss);
          final execute =
              f.world.meleeIntent.tick[f.world.meleeIntent.indexOf(f.boss)];
          resolveCombatPoses(f.world, execute, tickHz: hz);
          MeleeStrikeSystem().step(f.world, currentTick: execute);
          final tick =
              execute +
              ((frame - 3) * f.world.activeAbility.activeTicks[ai] / 6).ceil();
          f.world.transform.setPosXY(f.player, -sign * x, y);
          f.hit(tick);
          expect(f.world.damageQueue.target, [f.player]);
          expect(f.world.damageQueue.amount100, [600]);
          f.hit(tick + 1);
          expect(f.world.damageQueue.length, 1);
        });
      }
    }
  }
}

class _Fixture {
  _Fixture(EnemyId id, this.hz) {
    boss = actor(id, 0);
    player = actor(EnemyId.grojib, 300);
    world.faction.faction[world.faction.indexOf(player)] = Faction.player;
    final hi = world.health.indexOf(player);
    world.health.hp[hi] = 10000;
    world.health.hpMax[hi] = 10000;
  }
  final int hz;
  final world = EcsWorld(seed: 7);
  final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64));
  late final int boss, player;

  (int, int) spawnHand({Facing facing = Facing.right}) {
    final sourceX = facing == Facing.right ? 0.0 : 600.0;
    world.transform.setPosXY(boss, sourceX, 0);
    expect(
      AiCastCommitter(
        tickHz: hz,
        projectiles: const ProjectileCatalog(),
        surfaceTarget: (x, y) => Vec2(x, 24),
      ).commit(
        world,
        actor: boss,
        castAbility: AbilityCatalog.shared.resolve('goddess.eruption')!,
        sourceX: sourceX,
        sourceY: 0,
        targetX: 300,
        targetY: 0,
        targetVelX: 0,
        targetVelY: 0,
        aimPolicy: AiCastAimPolicy.targetCenter,
        casterOriginOffset: 0,
        currentTick: 10,
      ),
      isTrue,
    );
    final i = world.targetPointIntent.indexOf(boss);
    final execute = world.targetPointIntent.tick[i];
    final step = world.targetPointIntent.frameStepTicks[i];
    TargetPointImpactSystem().step(world, currentTick: execute);
    return (execute, step);
  }

  int actor(EnemyId id, double x) {
    final a = const EnemyCatalog().get(id);
    final collider = id == EnemyId.grojib
        ? const ColliderAabbDef(halfX: 8, halfY: 8)
        : a.collider;
    final entity = EntityFactory(world).createEnemy(
      enemyId: id,
      posX: x,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      body: a.body,
      collider: collider,
      health: a.health,
      mana: a.mana,
      stamina: a.stamina,
    );
    world.worldContactCapsule.add(
      entity,
      WorldContactCapsuleDef.fromAabb(collider),
    );
    return entity;
  }

  void hit(int tick) {
    resolveCombatPoses(world, tick, tickHz: hz);
    HitboxFollowOwnerSystem(tickHz: hz).step(world, currentTick: tick);
    grid.rebuild(world);
    HitboxDamageSystem().step(world, grid, currentTick: tick);
  }

  void expectAcceptedDamage(int damage100, {required int tick}) {
    world.invulnerability.add(player);
    DamageSystem(
      invulnerabilityTicksOnHit: (hz * .25).ceil(),
      rngSeed: 7,
      tickHz: hz,
    ).step(world, currentTick: tick);
    expect(world.health.hp[world.health.indexOf(player)], 10000 - damage100);
    expect(world.invulnerability.ticksLeft.single, (hz * .25).ceil());
  }
}
