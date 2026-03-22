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

  /// Evaluates melee strikes for all enemies and writes melee intents.
  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    if (!world.transform.has(player)) return;

    final playerTi = world.transform.indexOf(player);
    final playerX = world.transform.posX[playerTi];

    final meleeEngagement = world.meleeEngagement;
    for (var i = 0; i < meleeEngagement.denseEntities.length; i += 1) {
      final enemy = meleeEngagement.denseEntities[i];
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
      final ability = abilities.resolve(abilityId);
      if (ability == null) continue;
      final hitDelivery = ability.hitDelivery;
      if (hitDelivery is! MeleeHitDelivery) continue;

      final actionSpeedBp = _actionSpeedBpForEntity(world, enemy);
      final abilityTiming = _resolveMeleeTiming(ability, actionSpeedBp);
      if (abilityTiming == null) continue;

      final commitTick = meleeEngagement.strikeStartTick[i];
      final windupTicks = plannedHitTick > commitTick
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
      final cooldownGroupId = ability.effectiveCooldownGroup(
        AbilitySlot.primary,
      );

      final ex = world.transform.posX[ti];
      final facing = playerX >= ex ? Facing.right : Facing.left;
      world.enemy.facing[enemyIndex] = facing;
      final dirX = facing == Facing.right ? 1.0 : -1.0;

      final halfX = hitDelivery.sizeX * 0.5;
      final halfY = hitDelivery.sizeY * 0.5;
      final colliderIndex = world.colliderAabb.indexOf(enemy);
      final ownerHalfX = world.colliderAabb.halfX[colliderIndex];
      final ownerHalfY = world.colliderAabb.halfY[colliderIndex];
      final maxHalfExtent = max(ownerHalfX, ownerHalfY);
      final forward =
          maxHalfExtent * 0.5 + max(halfX, halfY) + hitDelivery.offsetX;
      final offsetX = dirX * forward;
      final offsetY = hitDelivery.offsetY;

      world.meleeIntent.set(
        enemy,
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
          staminaCost100: 0,
          cooldownGroupId: cooldownGroupId,
          tick: plannedHitTick,
        ),
      );

      // Commit side effects (Cooldown + ActiveAbility) must be applied manually
      // since enemies don't use AbilityActivationSystem.
      world.cooldown.startCooldown(enemy, cooldownGroupId, cooldownTicks);

      world.activeAbility.set(
        enemy,
        id: abilityId,
        slot: AbilitySlot.primary,
        commitTick: commitTick,
        windupTicks: windupTicks,
        activeTicks: activeTicks,
        recoveryTicks: recoveryTicks,
        facingDir: facing,
      );

      if (abilityId == archetype.comboMeleeAbilityId) {
        final comboIndex = world.meleeCombo.tryIndexOf(enemy);
        if (comboIndex != null) {
          world.meleeCombo.armed[comboIndex] = false;
        }
      }

      world.enemy.lastMeleeTick[enemyIndex] = currentTick;
      world.enemy.lastMeleeFacing[enemyIndex] = facing;
      world.enemy.lastMeleeAnimTicks[enemyIndex] = abilityTiming.totalTicks;
    }
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
    if (groundEnemyTuning.tickHz == abilityAuthoringTickHz) return ticks;
    final seconds = ticks / abilityAuthoringTickHz;
    return (seconds * groundEnemyTuning.tickHz).ceil();
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
