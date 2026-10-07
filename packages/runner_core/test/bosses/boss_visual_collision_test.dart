import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/combat/ai_cast_aim_policy.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';
import 'package:runner_core/ecs/systems/enemy_cast_system.dart';
import 'package:runner_core/ecs/systems/enemy_melee_system.dart';
import 'package:runner_core/ecs/systems/hitbox_damage_system.dart';
import 'package:runner_core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:runner_core/ecs/systems/melee_strike_system.dart';
import 'package:runner_core/ecs/systems/target_point_impact_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:test/test.dart';

import '../test_support/combat_pose.dart';

void main() {
  for (final hz in [30, 60, 90]) {
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
  }
  final int hz;
  final world = EcsWorld(seed: 7);
  final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64));
  late final int boss, player;
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
}
