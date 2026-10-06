import 'dart:math' as math;

import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/combat/actor_combat_pose.dart';
import 'package:runner_core/combat/combat_geometry.dart';
import 'package:runner_core/ecs/actor_facing.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/melee_intent_store.dart';
import 'package:runner_core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:runner_core/ecs/systems/melee_strike_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/npcs/npc_catalog.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

import '../test_support/combat_pose.dart';

void main() {
  final attacks = <(EnemyId?, NpcId?, String)>[
    (EnemyId.grojib, null, 'grojib.strike'),
    (EnemyId.grojib, null, 'grojib.strike2'),
    (EnemyId.hashash, null, 'hashash.strike'),
    (EnemyId.hashash, null, 'hashash.ambush'),
    (EnemyId.unocoDemon, null, 'unoco.strike'),
    (null, NpcId.warrior, 'npc_warrior.slash'),
    (null, NpcId.huntress, 'npc_huntress.stab'),
    (null, NpcId.huntress, 'npc_huntress.slash'),
  ];
  for (final (enemyId, npcId, abilityId) in attacks) {
    for (final facing in Facing.values) {
      test('$abilityId stays upright when turning from $facing', () {
        final world = EcsWorld();
        final factory = EntityFactory(world);
        final actor = enemyId != null
            ? _enemy(world, enemyId, facing)
            : factory.createNpc(
                npcId: npcId!,
                posX: 0,
                posY: 0,
                chunkStartX: -200,
                chunkEndX: 200,
                facing: facing,
              );
        if (npcId != null) {
          world.worldContactCapsule.add(
            actor,
            const NpcCatalog().terrainContactProfile(npcId).capsule,
          );
        }
        final ability = AbilityCatalog.shared.resolve(abilityId)!;
        _commit(world, actor, ability, facing);
        final tick = 100 + ability.windupTicks;
        resolveCombatPoses(world, tick);
        MeleeStrikeSystem().step(world, currentTick: tick);
        final follow = HitboxFollowOwnerSystem();
        follow.step(world, currentTick: tick);

        final hi = world.combatHurtbox.indexOf(actor);
        final body = world.combatHurtbox.capsule[hi]!;
        final weapon = world.hitbox.capsules.single!;
        expect(weapon, isNotEmpty);
        expect(world.combatHurtbox.poseAngle[hi], 0);

        setActorFacing(
          world,
          actor,
          facing == Facing.left ? Facing.right : Facing.left,
        );
        resolveCombatPoses(world, tick);
        follow.step(world, currentTick: tick);

        expect(world.combatHurtbox.poseAngle[hi], 0);
        _expectHorizontalMirror(world.combatHurtbox.capsule[hi]!, body);
        final turnedWeapon = world.hitbox.capsules.single!;
        expect(turnedWeapon.length, weapon.length);
        for (var i = 0; i < weapon.length; i++) {
          _expectHorizontalMirror(turnedWeapon[i], weapon[i]);
        }
      });
    }
  }

  for (final facing in Facing.values) {
    for (final anim in [AnimKey.strike, AnimKey.backStrike]) {
      test('player $anim retains vertical aiming while facing $facing', () {
        final world = EcsWorld();
        final a = const EnemyCatalog().get(EnemyId.derf);
        final player = EntityFactory(world).createPlayer(
          posX: 0,
          posY: 0,
          velX: 0,
          velY: 0,
          facing: facing,
          grounded: true,
          body: a.body,
          collider: a.collider,
          health: a.health,
          mana: a.mana,
          stamina: a.stamina,
        );
        _commit(
          world,
          player,
          AbilityCatalog.shared.resolve('eloise.bloodletter_slash')!,
          facing,
        );
        final mi = world.meleeIntent.indexOf(player);
        world.meleeIntent.dirX[mi] = 0;
        world.meleeIntent.dirY[mi] = -1;
        final pointsRight =
            (facing == Facing.right) == (anim == AnimKey.strike);
        expect(
          actorCombatPoseAngle(world, player, anim),
          closeTo(pointsRight ? -math.pi / 2 : math.pi / 2, 1e-9),
        );
      });
    }
  }
}

int _enemy(EcsWorld world, EnemyId id, Facing facing) {
  const catalog = EnemyCatalog();
  final a = catalog.get(id);
  final actor = EntityFactory(world).createEnemy(
    enemyId: id,
    posX: 0,
    posY: 0,
    velX: 0,
    velY: 0,
    facing: facing,
    artFacing: a.artFacingDir,
    body: a.body,
    collider: a.collider,
    health: a.health,
    mana: a.mana,
    stamina: a.stamina,
  );
  world.worldContactCapsule.add(
    actor,
    catalog.terrainContactProfile(id).capsule,
  );
  return actor;
}

void _commit(EcsWorld world, int actor, AbilityDef ability, Facing facing) {
  final delivery = ability.hitDelivery as MeleeHitDelivery;
  world.meleeIntent.set(
    actor,
    MeleeIntentDef(
      abilityId: ability.id,
      profile: delivery.profile,
      slot: AbilitySlot.primary,
      damage100: ability.baseDamage,
      damageType: ability.baseDamageType,
      dirX: facing == Facing.right ? 1 : -1,
      dirY: 0,
      commitTick: 100,
      windupTicks: ability.windupTicks,
      activeTicks: ability.activeTicks,
      recoveryTicks: ability.recoveryTicks,
      cooldownTicks: ability.cooldownTicks,
      staminaCost100: 0,
      cooldownGroupId: 0,
      tick: 100 + ability.windupTicks,
    ),
  );
  world.activeAbility.set(
    actor,
    id: ability.id,
    slot: AbilitySlot.primary,
    commitTick: 100,
    windupTicks: ability.windupTicks,
    activeTicks: ability.activeTicks,
    recoveryTicks: ability.recoveryTicks,
    facingDir: facing,
  );
}

void _expectHorizontalMirror(CombatCapsule actual, CombatCapsule original) {
  expect(actual.ax, closeTo(-original.ax, 1e-9));
  expect(actual.ay, closeTo(original.ay, 1e-9));
  expect(actual.bx, closeTo(-original.bx, 1e-9));
  expect(actual.by, closeTo(original.by, 1e-9));
  expect(actual.radius, original.radius);
}
