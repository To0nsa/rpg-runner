import 'dart:math';

import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../combat/control_lock.dart';
import '../../enemies/enemy_catalog.dart';
import '../../snapshots/enums.dart';
import '../../tuning/flying_enemy_tuning.dart';
import '../../util/ability_timing.dart';
import '../../util/fixed_math.dart';
import '../collider_aabb_utils.dart';
import '../entity_id.dart';
import '../stores/enemies/flying_enemy_combat_mode_store.dart';
import '../stores/melee_intent_store.dart';
import '../world.dart';

/// Commits melee fallback attacks for flying enemies when planner selects them.
class FlyingEnemyMeleeSystem {
  FlyingEnemyMeleeSystem({
    required this.unocoDemonTuning,
    this.enemyCatalog = const EnemyCatalog(),
    this.abilities = AbilityCatalog.shared,
  });

  final UnocoDemonTuningDerived unocoDemonTuning;
  final EnemyCatalog enemyCatalog;
  final AbilityResolver abilities;

  /// Evaluates fallback melee commits for flying enemies.
  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    if (!world.transform.has(player)) return;

    var playerCenterX = 0.0;
    final playerTi = world.transform.tryIndexOf(player);
    if (playerTi != null) {
      playerCenterX = world.transform.posX[playerTi];
      if (world.colliderAabb.has(player)) {
        final ai = world.colliderAabb.indexOf(player);
        playerCenterX = colliderCenterX(
          world,
          entity: player,
          transformIndex: playerTi,
          colliderIndex: ai,
        );
      }
    }

    final combatMode = world.flyingEnemyCombatMode;
    for (var i = 0; i < combatMode.denseEntities.length; i += 1) {
      final enemy = combatMode.denseEntities[i];
      if (combatMode.mode[i] != FlyingEnemyCombatMode.meleeFallback) continue;
      if (world.deathState.has(enemy)) continue;

      final enemyIndex = world.enemy.tryIndexOf(enemy);
      if (enemyIndex == null) {
        assert(
          false,
          'FlyingEnemyMeleeSystem requires EnemyStore on flying enemies; add it at spawn time.',
        );
        continue;
      }

      final enemyTi = world.transform.tryIndexOf(enemy);
      if (enemyTi == null) continue;
      if (!world.cooldown.has(enemy)) continue;
      if (world.controlLock.isStunned(enemy, currentTick) ||
          world.controlLock.isLocked(enemy, LockFlag.strike, currentTick)) {
        continue;
      }
      if (world.activeAbility.hasActiveAbility(enemy)) continue;
      if (!_isInContactWithPlayer(world, enemy: enemy, player: player)) {
        continue;
      }

      final archetype = enemyCatalog.get(world.enemy.enemyId[enemyIndex]);
      final meleeAbilityId = archetype.primaryMeleeAbilityId;
      if (meleeAbilityId == null) continue;
      final meleeAbility = abilities.resolve(meleeAbilityId);
      if (meleeAbility == null) continue;
      final hitDelivery = meleeAbility.hitDelivery;
      if (hitDelivery is! MeleeHitDelivery) continue;

      final cooldownGroupId = meleeAbility.effectiveCooldownGroup(
        AbilitySlot.primary,
      );
      if (world.cooldown.isOnCooldown(enemy, cooldownGroupId)) continue;

      if (!world.meleeIntent.has(enemy)) {
        assert(
          false,
          'FlyingEnemyMeleeSystem requires MeleeIntentStore on flying enemies; add it at spawn time.',
        );
        continue;
      }
      if (!world.colliderAabb.has(enemy)) {
        assert(
          false,
          'FlyingEnemyMeleeSystem requires ColliderAabbStore on flying enemies.',
        );
        continue;
      }

      final commitCost = meleeAbility.resolveCostForWeaponType(null);
      if (!_canAffordCost(world, enemy: enemy, cost: commitCost)) continue;

      var enemyCenterX = world.transform.posX[enemyTi];
      if (world.colliderAabb.has(enemy)) {
        final ai = world.colliderAabb.indexOf(enemy);
        enemyCenterX = colliderCenterX(
          world,
          entity: enemy,
          transformIndex: enemyTi,
          colliderIndex: ai,
        );
      }

      final actionSpeedBp = _actionSpeedBpForEntity(world, enemy);
      final windupTicks = _scaleTicksForActionSpeed(
        _scaleAbilityTicks(meleeAbility.windupTicks),
        actionSpeedBp,
      );
      final activeTicks = _scaleAbilityTicks(meleeAbility.activeTicks);
      final recoveryTicks = _scaleTicksForActionSpeed(
        _scaleAbilityTicks(meleeAbility.recoveryTicks),
        actionSpeedBp,
      );
      final cooldownTicks = _scaleTicksForActionSpeed(
        _scaleAbilityTicks(meleeAbility.cooldownTicks),
        actionSpeedBp,
      );

      final facing = playerCenterX >= enemyCenterX ? Facing.right : Facing.left;
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
          abilityId: meleeAbility.id,
          slot: AbilitySlot.primary,
          damage100: meleeAbility.baseDamage,
          damageType: meleeAbility.baseDamageType,
          procs: meleeAbility.procs,
          halfX: halfX,
          halfY: halfY,
          offsetX: offsetX,
          offsetY: offsetY,
          dirX: dirX,
          dirY: 0.0,
          commitTick: currentTick,
          windupTicks: windupTicks,
          activeTicks: activeTicks,
          recoveryTicks: recoveryTicks,
          cooldownTicks: cooldownTicks,
          staminaCost100: commitCost.staminaCost100,
          cooldownGroupId: cooldownGroupId,
          tick: currentTick + windupTicks,
        ),
      );

      _applyCommitResourceCosts(world, enemy: enemy, cost: commitCost);
      world.cooldown.startCooldown(enemy, cooldownGroupId, cooldownTicks);
      world.activeAbility.set(
        enemy,
        id: meleeAbility.id,
        slot: AbilitySlot.primary,
        commitTick: currentTick,
        windupTicks: windupTicks,
        activeTicks: activeTicks,
        recoveryTicks: recoveryTicks,
        facingDir: facing,
      );
      combatMode.requiresFallbackStrike[i] = false;
      world.enemy.lastMeleeTick[enemyIndex] = currentTick;
      world.enemy.lastMeleeFacing[enemyIndex] = facing;
      world.enemy.lastMeleeAnimTicks[enemyIndex] =
          windupTicks + activeTicks + recoveryTicks;
    }
  }

  bool _canAffordCost(
    EcsWorld world, {
    required EntityId enemy,
    required AbilityResourceCost cost,
  }) {
    if (cost.manaCost100 > 0) {
      final manaIndex = world.mana.tryIndexOf(enemy);
      if (manaIndex == null) return false;
      if (world.mana.mana[manaIndex] < cost.manaCost100) return false;
    }
    if (cost.staminaCost100 > 0) {
      final staminaIndex = world.stamina.tryIndexOf(enemy);
      if (staminaIndex == null) return false;
      if (world.stamina.stamina[staminaIndex] < cost.staminaCost100) {
        return false;
      }
    }
    if (cost.healthCost100 > 0) {
      final healthIndex = world.health.tryIndexOf(enemy);
      if (healthIndex == null) return false;
      if (world.health.hp[healthIndex] - cost.healthCost100 < _minCommitHp100) {
        return false;
      }
    }
    return true;
  }

  bool _isInContactWithPlayer(
    EcsWorld world, {
    required EntityId enemy,
    required EntityId player,
  }) {
    final enemyTransformIndex = world.transform.tryIndexOf(enemy);
    final playerTransformIndex = world.transform.tryIndexOf(player);
    if (enemyTransformIndex == null || playerTransformIndex == null) {
      return false;
    }

    var enemyCenterX = world.transform.posX[enemyTransformIndex];
    var enemyCenterY = world.transform.posY[enemyTransformIndex];
    var enemyHalfX = 0.0;
    var enemyHalfY = 0.0;
    if (world.colliderAabb.has(enemy)) {
      final colliderIndex = world.colliderAabb.indexOf(enemy);
      enemyCenterX = colliderCenterX(
        world,
        entity: enemy,
        transformIndex: enemyTransformIndex,
        colliderIndex: colliderIndex,
      );
      enemyCenterY += world.colliderAabb.offsetY[colliderIndex];
      enemyHalfX = world.colliderAabb.halfX[colliderIndex];
      enemyHalfY = world.colliderAabb.halfY[colliderIndex];
    }

    var playerCenterX = world.transform.posX[playerTransformIndex];
    var playerCenterY = world.transform.posY[playerTransformIndex];
    var playerHalfX = 0.0;
    var playerHalfY = 0.0;
    if (world.colliderAabb.has(player)) {
      final colliderIndex = world.colliderAabb.indexOf(player);
      playerCenterX = colliderCenterX(
        world,
        entity: player,
        transformIndex: playerTransformIndex,
        colliderIndex: colliderIndex,
      );
      playerCenterY += world.colliderAabb.offsetY[colliderIndex];
      playerHalfX = world.colliderAabb.halfX[colliderIndex];
      playerHalfY = world.colliderAabb.halfY[colliderIndex];
    }

    final overlapX =
        (enemyCenterX - playerCenterX).abs() <= (enemyHalfX + playerHalfX);
    final overlapY =
        (enemyCenterY - playerCenterY).abs() <= (enemyHalfY + playerHalfY);
    return overlapX && overlapY;
  }

  void _applyCommitResourceCosts(
    EcsWorld world, {
    required EntityId enemy,
    required AbilityResourceCost cost,
  }) {
    if (cost.manaCost100 > 0) {
      final manaIndex = world.mana.tryIndexOf(enemy);
      assert(
        manaIndex != null,
        'Missing ManaStore on $enemy for manaCost=${cost.manaCost100}',
      );
      if (manaIndex != null) {
        final current = world.mana.mana[manaIndex];
        final max = world.mana.manaMax[manaIndex];
        world.mana.mana[manaIndex] = clampInt(
          current - cost.manaCost100,
          0,
          max,
        );
      }
    }
    if (cost.staminaCost100 > 0) {
      final staminaIndex = world.stamina.tryIndexOf(enemy);
      assert(
        staminaIndex != null,
        'Missing StaminaStore on $enemy for staminaCost=${cost.staminaCost100}',
      );
      if (staminaIndex != null) {
        final current = world.stamina.stamina[staminaIndex];
        final max = world.stamina.staminaMax[staminaIndex];
        world.stamina.stamina[staminaIndex] = clampInt(
          current - cost.staminaCost100,
          0,
          max,
        );
      }
    }
    if (cost.healthCost100 > 0) {
      final healthIndex = world.health.tryIndexOf(enemy);
      assert(
        healthIndex != null,
        'Missing HealthStore on $enemy for healthCost=${cost.healthCost100}',
      );
      if (healthIndex != null) {
        final current = world.health.hp[healthIndex];
        final max = world.health.hpMax[healthIndex];
        world.health.hp[healthIndex] = clampInt(
          current - cost.healthCost100,
          _minCommitHp100,
          max,
        );
      }
    }
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
    if (unocoDemonTuning.tickHz <= 0) return ticks;
    final seconds = ticks / abilityAuthoringTickHz;
    return (seconds * unocoDemonTuning.tickHz).ceil();
  }

  static const int _minCommitHp100 = 1;
}
