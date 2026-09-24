import 'dart:math';

import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../combat/control_lock.dart';
import '../../enemies/enemy_catalog.dart';
import '../../snapshots/enums.dart';
import '../../tuning/ground_enemy_tuning.dart';
import '../../util/ability_timing.dart';
import '../../util/fixed_math.dart';
import '../entity_id.dart';
import '../actor_facing.dart';
import 'ai_ability_commit.dart';
import '../combat_target.dart';
import '../stores/enemies/melee_engagement_store.dart';
import '../stores/melee_intent_store.dart';
import '../world.dart';

/// Handles enemy melee strike decisions and writes melee intents.
class EnemyMeleeSystem {
  EnemyMeleeSystem({
    required this.groundEnemyTuning,
    this.enemyCatalog = const EnemyCatalog(),
    this.abilities = AbilityCatalog.shared,
  });

  final GroundEnemyTuningDerived groundEnemyTuning;
  final EnemyCatalog enemyCatalog;
  final AbilityResolver abilities;
  late final _committer = AiMeleeCommitter(
    tickHz: groundEnemyTuning.tickHz,
    abilities: abilities,
  );

  /// Evaluates melee strikes for all enemies and writes melee intents.
  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    final meleeEngagement = world.meleeEngagement;
    for (var i = 0; i < meleeEngagement.denseEntities.length; i += 1) {
      final enemy = meleeEngagement.denseEntities[i];
      final target = combatTarget(world, enemy, player);
      if (target == null) continue;
      final targetX = world.transform.posX[world.transform.indexOf(target)];
      if (world.deathState.has(enemy)) continue;
      final enemyIndex = world.enemy.tryIndexOf(enemy);
      if (enemyIndex == null) {
        assert(
          false,
          'EnemyMeleeSystem requires EnemyStore on melee enemies; add it at spawn time.',
        );
        continue;
      }

      final archetype = enemyCatalog.get(world.enemy.enemyId[enemyIndex]);
      final primaryMeleeAbilityId = archetype.primaryMeleeAbilityId;
      if (primaryMeleeAbilityId == null) continue;

      if (!world.cooldown.has(enemy)) continue;

      final ti = world.transform.tryIndexOf(enemy);
      if (ti == null) continue;

      if (world.controlLock.isStunned(enemy, currentTick) ||
          world.controlLock.isLocked(enemy, LockFlag.strike, currentTick)) {
        continue;
      }
      if (world.activeAbility.hasActiveAbility(enemy)) continue;

      // Only write an intent on the first tick we enter the strike state.
      if (meleeEngagement.state[i] != MeleeEngagementState.strike) continue;
      if (meleeEngagement.strikeStartTick[i] != currentTick) continue;
      final plannedHitTick = meleeEngagement.plannedHitTick[i];
      if (plannedHitTick < 0) continue;

      if (!world.meleeIntent.has(enemy)) {
        assert(
          false,
          'EnemyMeleeSystem requires MeleeIntentStore on enemies; add it at spawn time.',
        );
        continue;
      }
      if (!world.colliderAabb.has(enemy)) {
        assert(
          false,
          'Enemy melee requires ColliderAabbStore on the enemy to compute hitbox offset.',
        );
        continue;
      }

      final abilityId =
          meleeEngagement.strikeAbilityId[i] ?? primaryMeleeAbilityId;
      final animationTicks = _committer.commit(
        world,
        actor: enemy,
        abilityId: abilityId,
        targetX: targetX,
        currentTick: currentTick,
        plannedHitTick: plannedHitTick,
      );
      if (animationTicks == null) continue;
      final facing = world.enemy.facing[enemyIndex];

      if (abilityId == archetype.comboMeleeAbilityId) {
        final comboIndex = world.meleeCombo.tryIndexOf(enemy);
        if (comboIndex != null) {
          world.meleeCombo.armed[comboIndex] = false;
        }
      }

      world.enemy.lastMeleeTick[enemyIndex] = currentTick;
      world.enemy.lastMeleeFacing[enemyIndex] = facing;
      world.enemy.lastMeleeAnimTicks[enemyIndex] = animationTicks;
    }
  }
}

/// Shared autonomous melee commit; decision systems choose when and whom to attack.
class AiMeleeCommitter {
  const AiMeleeCommitter({
    required this.tickHz,
    this.abilities = AbilityCatalog.shared,
  });
  final int tickHz;
  final AbilityResolver abilities;

  int? commit(
    EcsWorld world, {
    required EntityId actor,
    required AbilityKey abilityId,
    required double targetX,
    required int currentTick,
    int? plannedHitTick,
  }) {
    final ti = world.transform.tryIndexOf(actor);
    if (ti == null ||
        !world.meleeIntent.has(actor) ||
        !world.colliderAabb.has(actor)) {
      return null;
    }
    final ability = abilities.resolve(abilityId);
    if (ability == null) return null;
    final hitDelivery = ability.hitDelivery;
    if (hitDelivery is! MeleeHitDelivery) return null;

    final actionSpeedBp = _actionSpeedBpForEntity(world, actor);
    final abilityTiming = _resolveMeleeTiming(ability, actionSpeedBp);
    if (abilityTiming == null) return null;

    final commitTick = currentTick;
    final windupTicks = plannedHitTick != null && plannedHitTick > commitTick
        ? plannedHitTick - commitTick
        : abilityTiming.windupTicks;
    final activeTicks = abilityTiming.activeTicks;
    final recoveryTicks = max(
      0,
      abilityTiming.totalTicks - windupTicks - activeTicks,
    );
    final cooldownTicks = _scaleTicksForActionSpeed(
      _scaleAbilityTicks(ability.cooldownTicks),
      actionSpeedBp,
    );
    final cooldownGroupId = ability.effectiveCooldownGroup(AbilitySlot.primary);

    final cost = ability.resolveCostForWeaponType(null);
    if (!canCommitAiAbility(
      world,
      actor,
      currentTick: currentTick,
      lock: LockFlag.strike,
      cooldownGroupId: cooldownGroupId,
      cost: cost,
    )) {
      return null;
    }
    final ex = world.transform.posX[ti];
    final facing = targetX >= ex ? Facing.right : Facing.left;
    setActorFacing(world, actor, facing);
    final dirX = facing == Facing.right ? 1.0 : -1.0;

    final halfX = hitDelivery.sizeX * 0.5;
    final halfY = hitDelivery.sizeY * 0.5;
    final colliderIndex = world.colliderAabb.indexOf(actor);
    final ownerHalfX = world.colliderAabb.halfX[colliderIndex];
    final ownerHalfY = world.colliderAabb.halfY[colliderIndex];
    final maxHalfExtent = max(ownerHalfX, ownerHalfY);
    final forward =
        maxHalfExtent * 0.5 + max(halfX, halfY) + hitDelivery.offsetX;
    final offsetX = dirX * forward;
    final offsetY = hitDelivery.offsetY;

    world.meleeIntent.set(
      actor,
      MeleeIntentDef(
        abilityId: abilityId,
        slot: AbilitySlot.primary,
        damage100: ability.baseDamage,
        damageType: ability.baseDamageType,
        procs: ability.procs,
        halfX: halfX,
        halfY: halfY,
        offsetX: offsetX,
        offsetY: offsetY,
        dirX: dirX,
        dirY: 0.0,
        commitTick: commitTick,
        windupTicks: windupTicks,
        activeTicks: activeTicks,
        recoveryTicks: recoveryTicks,
        cooldownTicks: cooldownTicks,
        staminaCost100: cost.staminaCost100,
        cooldownGroupId: cooldownGroupId,
        tick: plannedHitTick ?? commitTick + windupTicks,
      ),
    );

    spendAiAbilityCost(world, actor, cost);
    world.cooldown.startCooldown(actor, cooldownGroupId, cooldownTicks);

    world.activeAbility.set(
      actor,
      id: abilityId,
      slot: AbilitySlot.primary,
      commitTick: commitTick,
      windupTicks: windupTicks,
      activeTicks: activeTicks,
      recoveryTicks: recoveryTicks,
      facingDir: facing,
    );

    return abilityTiming.totalTicks;
  }

  _MeleeTiming? _resolveMeleeTiming(AbilityDef ability, int actionSpeedBp) {
    if (ability.hitDelivery is! MeleeHitDelivery) return null;
    final windupTicks = _scaleTicksForActionSpeed(
      _scaleAbilityTicks(ability.windupTicks),
      actionSpeedBp,
    );
    final activeTicks = _scaleAbilityTicks(ability.activeTicks);
    final totalBaseTicks =
        ability.windupTicks + ability.activeTicks + ability.recoveryTicks;
    final totalTicks = _scaleTicksForActionSpeed(
      _scaleAbilityTicks(totalBaseTicks),
      actionSpeedBp,
    );
    final clampedTotalTicks = max(totalTicks, windupTicks + activeTicks);
    return _MeleeTiming(
      windupTicks: windupTicks,
      activeTicks: activeTicks,
      totalTicks: clampedTotalTicks,
    );
  }

  int _actionSpeedBpForEntity(EcsWorld world, EntityId entity) {
    final modifierIndex = world.statModifier.tryIndexOf(entity);
    if (modifierIndex == null) return bpScale;
    return world.statModifier.actionSpeedBp[modifierIndex];
  }

  int _scaleTicksForActionSpeed(int ticks, int actionSpeedBp) {
    if (ticks <= 0) return 0;
    final clampedSpeedBp = clampInt(actionSpeedBp, 1000, 20000);
    if (clampedSpeedBp == bpScale) return ticks;
    return (ticks * bpScale + clampedSpeedBp - 1) ~/ clampedSpeedBp;
  }

  int _scaleAbilityTicks(int ticks) {
    if (ticks <= 0) return 0;
    if (tickHz == abilityAuthoringTickHz) return ticks;
    final seconds = ticks / abilityAuthoringTickHz;
    return (seconds * tickHz).ceil();
  }
}

class _MeleeTiming {
  const _MeleeTiming({
    required this.windupTicks,
    required this.activeTicks,
    required this.totalTicks,
  });

  final int windupTicks;
  final int activeTicks;
  final int totalTicks;
}
