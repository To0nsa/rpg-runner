import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';
import 'package:runner_core/ecs/systems/bringer_combat_system.dart';
import 'package:runner_core/ecs/systems/enemy_cast_system.dart';
import 'package:runner_core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/hitbox_damage_system.dart';
import 'package:runner_core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:runner_core/ecs/systems/melee_strike_system.dart';
import 'package:runner_core/ecs/systems/target_point_impact_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/spell_impacts/spell_impact_id.dart';
import 'package:runner_core/spell_impacts/spell_impact_render_catalog.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:test/test.dart';

import '../test_support/combat_pose.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    test('pillar warning, larger edge hit and single damage at $hz Hz', () {
      final f = _Fixture(hz, playerX: 300);
      f.selectAttack(10);
      final intents = f.world.targetPointIntent;
      final ii = intents.indexOf(f.boss);
      final executeTick = intents.tick[ii];
      final targetX = intents.targetX[ii];
      expect(intents.targetY[ii], 24);
      final step = intents.frameStepTicks[ii];
      final firstDamageTick = executeTick + 6 * step;
      final oldDelay = (.6 * hz).ceil() + 6 * (.08 * hz).round();
      expect(firstDamageTick - 10, lessThanOrEqualTo(oldDelay / 1.5));
      final render = const SpellImpactRenderCatalog().get(
        SpellImpactId.deathPillar,
      );
      expect((render.stepTimeSecondsByKey[AnimKey.hit]! * hz).round(), step);

      // Moving or jumping during windup cannot move the captured terrain mark.
      f.world.transform.setPosXY(f.player, targetX + 100, -100);
      TargetPointImpactSystem().step(f.world, currentTick: executeTick);
      final box = f.world.hitbox.denseEntities.single;
      expect(f.world.transform.posX[f.world.transform.indexOf(box)], targetX);
      expect(f.world.transform.posY[f.world.transform.indexOf(box)], 24);
      f.world.transform.setPosXY(f.player, targetX + 22, 0);
      for (var tick = executeTick; tick < firstDamageTick; tick++) {
        f.resolveHits(tick);
        expect(
          f.world.damageQueue.length,
          0,
          reason: 'harmless warning tick $tick',
        );
      }
      f.world.transform.setPosXY(f.player, targetX + 26, 0);
      f.resolveHits(firstDamageTick);
      expect(f.world.damageQueue.length, 0);
      f.world.transform.setPosXY(f.player, targetX + 22, 0);
      f.resolveHits(firstDamageTick);
      expect(f.world.damageQueue.target, [f.player]);
      expect(f.world.damageQueue.amount100, [700]);
      for (
        var tick = firstDamageTick + 1;
        tick < executeTick + 16 * step;
        tick++
      ) {
        f.resolveHits(tick);
      }
      expect(f.world.damageQueue.length, 1);
    });

    for (final facing in Facing.values) {
      test('larger scythe hits only its committed side at $hz Hz $facing', () {
        final sign = facing == Facing.right ? 1.0 : -1.0;
        final f = _Fixture(hz, playerX: 120 * sign);
        f.selectAttack(10);
        final ii = f.world.meleeIntent.indexOf(f.boss);
        final executeTick = f.world.meleeIntent.tick[ii];
        expect(executeTick - 10, lessThanOrEqualTo((.4 * hz).ceil() / 1.5));
        resolveCombatPoses(f.world, executeTick, tickHz: hz);
        MeleeStrikeSystem().step(f.world, currentTick: executeTick);
        f.world.transform.setPosXY(f.player, -120 * sign, 0);
        f.resolveHits(executeTick);
        expect(f.world.damageQueue.length, 0);
        f.world.transform.setPosXY(f.player, 120 * sign, 0);
        f.resolveHits(executeTick);
        expect(f.world.damageQueue.target, [f.player]);
        expect(f.world.damageQueue.amount100, [800]);
        f.resolveHits(executeTick + 1);
        expect(f.world.damageQueue.length, 1);
      });
    }

    for (final planned in [false, true]) {
      test('boss pursuit is 20% faster at $hz Hz directPlan=$planned', () {
        final f = _Fixture(hz, playerX: 500);
        f.world.cooldown.startCooldown(f.boss, 0, hz * 2);
        final ni = f.world.navIntent.indexOf(f.boss);
        f.world.navIntent.navTargetX[ni] = 500;
        final locomotion = GroundEnemyLocomotionSystem(
          groundEnemyTuning: GroundEnemyTuningDerived.from(
            const GroundEnemyTuning(),
            tickHz: hz,
          ),
        );
        for (var tick = 1; tick <= hz; tick++) {
          // Navigation republishes its direct plan before boss steering each tick.
          f.world.navIntent.hasPlan[ni] = planned;
          f.world.navIntent.canWalkDirectlyToTarget[ni] = planned;
          f.selectAttack(tick);
          locomotion.step(
            f.world,
            player: f.player,
            dtSeconds: 1 / hz,
            currentTick: tick,
          );
        }
        final ti = f.world.transform.indexOf(f.boss);
        final oldMultiplier = planned ? 1.0 : .6;
        expect(
          f.world.transform.velX[ti],
          closeTo(300 * oldMultiplier * 1.2, 1e-9),
        );
        expect(f.world.transform.velY[ti], 0);
      });
    }
    test(
      'boss keeps blade spacing instead of crowding its target at $hz Hz',
      () {
        final f = _Fixture(hz, playerX: 40);
        f.world.cooldown.startCooldown(f.boss, 0, hz);
        final ni = f.world.navIntent.indexOf(f.boss);
        f.world.navIntent.navTargetX[ni] = 40;
        f.world.navIntent.canWalkDirectlyToTarget[ni] = true;
        f.world.navIntent.hasPlan[ni] = true;
        f.selectAttack(1);
        final ei = f.world.engagementIntent.indexOf(f.boss);
        expect(f.world.engagementIntent.desiredTargetX[ei], lessThan(0));
        GroundEnemyLocomotionSystem(
          groundEnemyTuning: GroundEnemyTuningDerived.from(
            const GroundEnemyTuning(),
            tickHz: hz,
          ),
        ).step(f.world, player: f.player, dtSeconds: 1 / hz, currentTick: 1);
        expect(
          f.world.transform.velX[f.world.transform.indexOf(f.boss)],
          lessThan(0),
        );
        expect(f.world.activeAbility.hasActiveAbility(f.boss), isFalse);
      },
    );
  }
  test('pillar cannot commit without a surface beneath its target', () {
    final f = _Fixture(60, playerX: 300, hasSurface: false);
    f.selectAttack(10);
    expect(f.world.activeAbility.hasActiveAbility(f.boss), isFalse);
    expect(f.world.cooldown.isOnCooldown(f.boss, 0), isFalse);
    expect(
      f.world.targetPointIntent.tick[f.world.targetPointIntent.indexOf(f.boss)],
      -1,
    );
  });
}

class _Fixture {
  _Fixture(this.hz, {required double playerX, this.hasSurface = true}) {
    final a = const EnemyCatalog().get(EnemyId.bringerOfDeath);
    final factory = EntityFactory(world);
    player = factory.createPlayer(
      posX: playerX,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: a.body,
      collider: const ColliderAabbDef(halfX: 8, halfY: 24),
      health: a.health,
      mana: a.mana,
      stamina: a.stamina,
    );
    boss = factory.createEnemy(
      enemyId: EnemyId.bringerOfDeath,
      posX: 0,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: Facing.left,
      artFacing: a.artFacingDir,
      body: a.body,
      collider: a.collider,
      health: a.health,
      mana: a.mana,
      stamina: a.stamina,
    );
    world.worldContactCapsule.add(
      player,
      WorldContactCapsuleDef(radius: 8, verticalHalfSegment: 16),
    );
    world.worldContactCapsule.add(
      boss,
      WorldContactCapsuleDef.fromAabb(a.collider),
    );
  }

  final int hz;
  final bool hasSurface;
  final world = EcsWorld();
  late final int player;
  late final int boss;
  late final combat = BringerCombatSystem(
    tickHz: hz,
    castCommitter: AiCastCommitter(
      tickHz: hz,
      projectiles: const ProjectileCatalog(),
      surfaceTarget: (x, y) => hasSurface ? Vec2(x, 24) : null,
    ),
    groundEnemyTuning: GroundEnemyTuningDerived.from(
      const GroundEnemyTuning(),
      tickHz: hz,
    ),
  );
  final broadphase = BroadphaseGrid(index: GridIndex2D(cellSize: 64));

  void selectAttack(int tick) =>
      combat.step(world, player: player, currentTick: tick);

  void resolveHits(int tick) {
    resolveCombatPoses(world, tick, tickHz: hz);
    HitboxFollowOwnerSystem(tickHz: hz).step(world, currentTick: tick);
    broadphase.rebuild(world);
    HitboxDamageSystem().step(world, broadphase, currentTick: tick);
  }
}
