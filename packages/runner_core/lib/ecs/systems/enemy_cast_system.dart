import 'dart:math';

import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../combat/control_lock.dart';
import '../../combat/hit_payload_builder.dart';
import '../../enemies/enemy_catalog.dart';
import '../../projectiles/projectile_catalog.dart';
import '../../projectiles/projectile_item_def.dart';
import '../../projectiles/projectile_id.dart';
import '../../snapshots/enums.dart';
import '../../tuning/flying_enemy_tuning.dart';
import '../../util/double_math.dart';
import '../../util/fixed_math.dart';
import '../entity_id.dart';
import '../stores/enemies/flying_enemy_combat_mode_store.dart';
import '../stores/projectile_intent_store.dart';
import '../world.dart';

/// Handles enemy projectile strike decisions and writes projectile intents.
class EnemyCastSystem {
  EnemyCastSystem({
    required this.unocoDemonTuning,
    required this.enemyCatalog,
    required this.projectiles,
    this.abilities = AbilityCatalog.shared,
  });

  final UnocoDemonTuningDerived unocoDemonTuning;
  final EnemyCatalog enemyCatalog;
  final ProjectileCatalog projectiles;
  final AbilityResolver abilities;

  /// Evaluates casts for all enemies and writes projectile intents.
  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    if (!world.transform.has(player)) return;

    final castAbility = abilities.resolve(_enemyAbilityId);
    if (castAbility == null) return;
    final castCooldownGroupId = castAbility.effectiveCooldownGroup(
      AbilitySlot.projectile,
    );

    final playerTi = world.transform.indexOf(player);
    final playerX = world.transform.posX[playerTi];
    final playerY = world.transform.posY[playerTi];
    final playerVelX = world.transform.velX[playerTi];
    final playerVelY = world.transform.velY[playerTi];
    var playerCenterX = playerX;
    var playerCenterY = playerY;
    if (world.colliderAabb.has(player)) {
      final ai = world.colliderAabb.indexOf(player);
      playerCenterX += world.colliderAabb.offsetX[ai];
      playerCenterY += world.colliderAabb.offsetY[ai];
    }

    final enemies = world.enemy;
    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      final enemy = enemies.denseEntities[ei];
      if (world.deathState.has(enemy)) continue;
      final ti = world.transform.tryIndexOf(enemy);
      if (ti == null) continue;

      final modeIndex = world.flyingEnemyCombatMode.tryIndexOf(enemy);
      if (modeIndex != null &&
          world.flyingEnemyCombatMode.mode[modeIndex] ==
              FlyingEnemyCombatMode.meleeFallback) {
        continue;
      }

      if (!world.cooldown.has(enemy)) continue;
      if (world.controlLock.isStunned(enemy, currentTick)) continue;
      if (world.activeAbility.hasActiveAbility(enemy)) continue;

      if (!world.projectileIntent.has(enemy)) {
        assert(
          false,
          'EnemyCastSystem requires ProjectileIntentStore on enemies; add it at spawn time.',
        );
        continue;
      }

      final enemyId = enemies.enemyId[ei];
      final archetype = enemyCatalog.get(enemyId);
      final projectileId = archetype.primaryProjectileId;
      if (projectileId == null) continue;

      final projectile = projectiles.get(projectileId);
      final projectileSpeed = projectile.speedUnitsPerSecond;
      final castCost = castAbility.resolveCostForWeaponType(
        projectile.weaponType,
      );

      if (!_canAffordCost(world, enemy: enemy, cost: castCost)) {
        continue;
      }
      if (world.cooldown.isOnCooldown(enemy, castCooldownGroupId)) continue;
      if (world.controlLock.isLocked(enemy, LockFlag.cast, currentTick)) {
        continue;
      }

      var enemyCenterX = world.transform.posX[ti];
      var enemyCenterY = world.transform.posY[ti];
      if (world.colliderAabb.has(enemy)) {
        final ai = world.colliderAabb.indexOf(enemy);
        enemyCenterX += world.colliderAabb.offsetX[ai];
        enemyCenterY += world.colliderAabb.offsetY[ai];
      }

      _writeProjectileIntent(
        world,
        ability: castAbility,
        commitCost: castCost,
        projectileId: projectileId,
        projectile: projectile,
        enemyIndex: ei,
        enemyCenterX: enemyCenterX,
        enemyCenterY: enemyCenterY,
        playerCenterX: playerCenterX,
        playerCenterY: playerCenterY,
        playerVelX: playerVelX,
        playerVelY: playerVelY,
        projectileSpeed: projectileSpeed,
        currentTick: currentTick,
        cooldownGroupId: castCooldownGroupId,
      );
    }
  }

  void _writeProjectileIntent(
    EcsWorld world, {
    required AbilityDef ability,
    required AbilityResourceCost commitCost,
    required int enemyIndex,
    required double enemyCenterX,
    required double enemyCenterY,
    required double playerCenterX,
    required double playerCenterY,
    required double playerVelX,
    required double playerVelY,
    required double projectileSpeed,
    required int currentTick,
    required int cooldownGroupId,
    required ProjectileId projectileId,
    required ProjectileItemDef projectile,
  }) {
    final tuning = unocoDemonTuning;
    final hitDelivery = ability.hitDelivery;
    if (hitDelivery is! ProjectileHitDelivery) return;

    var targetX = playerCenterX;
    var targetY = playerCenterY;
    if (projectileSpeed > 0.0) {
      final dx = playerCenterX - enemyCenterX;
      final dy = playerCenterY - enemyCenterY;
      final distance = sqrt(dx * dx + dy * dy);
      final leadSeconds = clampDouble(
        distance / projectileSpeed,
        tuning.base.unocoDemonAimLeadMinSeconds,
        tuning.base.unocoDemonAimLeadMaxSeconds,
      );
      targetX = playerCenterX + playerVelX * leadSeconds;
      targetY = playerCenterY + playerVelY * leadSeconds;
    }

    final castDirX = targetX - enemyCenterX;
    if (castDirX.abs() > 1e-6) {
      world.enemy.facing[enemyIndex] = castDirX >= 0
          ? Facing.right
          : Facing.left;
    }

    final enemy = world.enemy.denseEntities[enemyIndex];
    final offenseIndex = world.offenseBuff.tryIndexOf(enemy);
    final offensePowerBp =
        offenseIndex != null && world.offenseBuff.ticksLeft[offenseIndex] > 0
        ? world.offenseBuff.powerBonusBp[offenseIndex]
        : 0;
    final offenseCritBp =
        offenseIndex != null && world.offenseBuff.ticksLeft[offenseIndex] > 0
        ? world.offenseBuff.critBonusBp[offenseIndex]
        : 0;
    final payload = HitPayloadBuilder.build(
      ability: ability,
      source: enemy,
      globalPowerBonusBp: offensePowerBp,
      globalCritChanceBonusBp: offenseCritBp,
      weaponDamageType: projectile.damageType,
      weaponProcs: projectile.procs,
    );

    final actionSpeedBp = _actionSpeedBpForEntity(world, enemy);
    final windupTicks = _scaleTicksForActionSpeed(
      _scaleAbilityTicks(ability.windupTicks),
      actionSpeedBp,
    );
    final activeTicks = _scaleAbilityTicks(ability.activeTicks);
    final recoveryTicks = _scaleTicksForActionSpeed(
      _scaleAbilityTicks(ability.recoveryTicks),
      actionSpeedBp,
    );
    final commitTick = currentTick;
    final executeTick = commitTick + windupTicks;
    final baseCooldownTicks = _scaleAbilityTicks(ability.cooldownTicks);
    final cooldownTicks = _scaleTicksForActionSpeed(
      baseCooldownTicks,
      actionSpeedBp,
    );

    world.projectileIntent.set(
      enemy,
      ProjectileIntentDef(
        projectileId: projectileId,
        abilityId: ability.id,
        slot: AbilitySlot.projectile,
        damage100: payload.damage100,
        critChanceBp: payload.critChanceBp,
        staminaCost100: commitCost.staminaCost100,
        manaCost100: commitCost.manaCost100,
        cooldownTicks: cooldownTicks,
        pierce: false,
        maxPierceHits: 1,
        damageType: payload.damageType,
        procs: payload.procs,
        ballistic: projectile.ballistic,
        gravityScale: projectile.gravityScale,
        dirX: targetX - enemyCenterX,
        dirY: targetY - enemyCenterY,
        fallbackDirX: 1.0,
        fallbackDirY: 0.0,
        originOffset: hitDelivery.originOffset,
        commitTick: commitTick,
        windupTicks: windupTicks,
        activeTicks: activeTicks,
        recoveryTicks: recoveryTicks,
        cooldownGroupId: cooldownGroupId,
        tick: executeTick,
      ),
    );

    // Commit side effects (Cooldown + ActiveAbility) must be applied manually
    // since enemies don't use AbilityActivationSystem.
    _applyCommitResourceCosts(world, enemy: enemy, cost: commitCost);
    world.cooldown.startCooldown(enemy, cooldownGroupId, cooldownTicks);
    world.activeAbility.set(
      enemy,
      id: ability.id,
      slot: AbilitySlot.projectile,
      commitTick: commitTick,
      windupTicks: windupTicks,
      activeTicks: activeTicks,
      recoveryTicks: recoveryTicks,
      facingDir: world.enemy.facing[enemyIndex],
    );
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

  int _scaleAbilityTicks(int ticks) {
    if (ticks <= 0) return 0;
    if (unocoDemonTuning.tickHz <= 0) return ticks;
    final seconds = ticks / _abilityTickHz;
    return (seconds * unocoDemonTuning.tickHz).ceil();
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

  static const int _abilityTickHz = 60;
  static const int _minCommitHp100 = 1;
  static const AbilityKey _enemyAbilityId = 'unoco.enemy_cast';
}
