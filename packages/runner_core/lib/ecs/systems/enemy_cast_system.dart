import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../combat/control_lock.dart';
import '../../combat/cast_origin_offset.dart';
import '../../combat/damage_type.dart';
import '../../combat/hit_payload.dart';
import '../../combat/hit_payload_builder.dart';
import '../../enemies/enemy_catalog.dart';
import '../../events/game_event.dart';
import '../../projectiles/projectile_catalog.dart';
import '../../projectiles/projectile_item_def.dart';
import '../../projectiles/projectile_id.dart';
import '../../snapshots/enums.dart';
import '../../tuning/flying_enemy_tuning.dart';
import '../../util/ability_timing.dart';
import '../../util/fixed_math.dart';
import '../../util/target_prediction.dart';
import '../../weapons/weapon_proc.dart';
import '../collider_aabb_utils.dart';
import '../entity_id.dart';
import '../stores/enemies/flying_enemy_combat_mode_store.dart';
import '../stores/projectile_intent_store.dart';
import '../stores/target_point_intent_store.dart';
import '../world.dart';

/// Handles enemy cast decisions and writes execution intents.
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

  /// Evaluates casts for all enemies and writes execute intents.
  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    final playerTi = world.transform.tryIndexOf(player);
    if (playerTi == null) return;

    final playerX = world.transform.posX[playerTi];
    final playerY = world.transform.posY[playerTi];
    final playerVelX = world.transform.velX[playerTi];
    final playerVelY = world.transform.velY[playerTi];
    final playerCenter = _entityCenter(
      world,
      player,
      fallbackX: playerX,
      fallbackY: playerY,
    );

    final enemies = world.enemy;
    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      final enemy = enemies.denseEntities[ei];
      if (world.deathState.has(enemy)) continue;
      final enemyTi = world.transform.tryIndexOf(enemy);
      if (enemyTi == null) continue;

      final modeIndex = world.flyingEnemyCombatMode.tryIndexOf(enemy);
      if (modeIndex != null &&
          world.flyingEnemyCombatMode.mode[modeIndex] ==
              FlyingEnemyCombatMode.meleeFallback) {
        continue;
      }

      if (!world.cooldown.has(enemy)) continue;
      if (world.controlLock.isStunned(enemy, currentTick)) continue;

      final enemyId = enemies.enemyId[ei];
      final archetype = enemyCatalog.get(enemyId);
      final castAbilityId = archetype.primaryCastAbilityId;
      if (castAbilityId == null) continue;
      final castAbility = abilities.resolve(castAbilityId);
      if (castAbility == null) continue;

      final enemyCenter = _entityCenter(
        world,
        enemy,
        fallbackX: world.transform.posX[enemyTi],
        fallbackY: world.transform.posY[enemyTi],
      );
      if (archetype.facingPolicy == EnemyFacingPolicy.facePlayerAlways) {
        _faceEnemyTowardX(
          world,
          enemyIndex: ei,
          targetX: playerCenter.$1,
          sourceX: enemyCenter.$1,
        );
      }
      if (world.activeAbility.hasActiveAbility(enemy)) continue;

      final castCost = _resolveCastCost(castAbility);
      if (!_canAffordCost(world, enemy: enemy, cost: castCost)) continue;

      final cooldownGroupId = castAbility.effectiveCooldownGroup(
        AbilitySlot.projectile,
      );
      if (world.cooldown.isOnCooldown(enemy, cooldownGroupId)) continue;
      if (world.controlLock.isLocked(enemy, LockFlag.cast, currentTick)) {
        continue;
      }

      final actionSpeedBp = _actionSpeedBpForEntity(world, enemy);
      final windupTicks = _scaleTicksForActionSpeed(
        _scaleAbilityTicks(castAbility.windupTicks),
        actionSpeedBp,
      );
      final activeTicks = _scaleAbilityTicks(castAbility.activeTicks);
      final recoveryTicks = _scaleTicksForActionSpeed(
        _scaleAbilityTicks(castAbility.recoveryTicks),
        actionSpeedBp,
      );
      final commitTick = currentTick;
      final executeTick = commitTick + windupTicks;
      final baseCooldownTicks = _scaleAbilityTicks(castAbility.cooldownTicks);
      final cooldownTicks = _scaleTicksForActionSpeed(
        baseCooldownTicks,
        actionSpeedBp,
      );

      final resolvedAim = _resolveAimPoint(
        castAbility: castAbility,
        castTargetPolicy: archetype.castTargetPolicy,
        sourceX: enemyCenter.$1,
        sourceY: enemyCenter.$2,
        targetX: playerCenter.$1,
        targetY: playerCenter.$2,
        targetVelX: playerVelX,
        targetVelY: playerVelY,
        windupTicks: windupTicks,
      );
      final aimX = resolvedAim.$1;
      final aimY = resolvedAim.$2;
      _faceEnemyTowardX(
        world,
        enemyIndex: ei,
        targetX: aimX,
        sourceX: enemyCenter.$1,
      );

      final payload = _buildPayload(
        world,
        source: enemy,
        ability: castAbility,
        weaponDamageType: resolvedAim.$3,
        weaponProcs: resolvedAim.$4,
      );

      final hitDelivery = castAbility.hitDelivery;
      if (hitDelivery is ProjectileHitDelivery) {
        if (!world.projectileIntent.has(enemy)) {
          assert(
            false,
            'EnemyCastSystem requires ProjectileIntentStore on enemies; add it at spawn time.',
          );
          continue;
        }
        final projectile = projectiles.get(hitDelivery.projectileId);
        _writeProjectileIntent(
          world,
          enemy: enemy,
          ability: castAbility,
          casterOriginOffset: archetype.castOriginOffset,
          payload: payload,
          commitCost: castCost,
          targetX: aimX,
          targetY: aimY,
          sourceX: enemyCenter.$1,
          sourceY: enemyCenter.$2,
          commitTick: commitTick,
          executeTick: executeTick,
          windupTicks: windupTicks,
          activeTicks: activeTicks,
          recoveryTicks: recoveryTicks,
          cooldownTicks: cooldownTicks,
          cooldownGroupId: cooldownGroupId,
          projectileId: hitDelivery.projectileId,
          projectile: projectile,
        );
      } else if (hitDelivery is TargetPointHitDelivery) {
        if (!world.targetPointIntent.has(enemy)) {
          assert(
            false,
            'EnemyCastSystem requires TargetPointIntentStore on enemies; add the component at spawn time.',
          );
          continue;
        }
        _writeTargetPointIntent(
          world,
          enemy: enemy,
          ability: castAbility,
          hitDelivery: hitDelivery,
          payload: payload,
          commitCost: castCost,
          targetX: aimX,
          targetY: aimY,
          commitTick: commitTick,
          executeTick: executeTick,
          windupTicks: windupTicks,
          activeTicks: activeTicks,
          recoveryTicks: recoveryTicks,
          cooldownTicks: cooldownTicks,
          cooldownGroupId: cooldownGroupId,
        );
      } else {
        continue;
      }

      _applyCommitResourceCosts(world, enemy: enemy, cost: castCost);
      world.cooldown.startCooldown(enemy, cooldownGroupId, cooldownTicks);
      world.activeAbility.set(
        enemy,
        id: castAbility.id,
        slot: AbilitySlot.projectile,
        commitTick: commitTick,
        windupTicks: windupTicks,
        activeTicks: activeTicks,
        recoveryTicks: recoveryTicks,
        facingDir: world.enemy.facing[ei],
      );
    }
  }

  (double, double, DamageType?, List<WeaponProc>) _resolveAimPoint({
    required AbilityDef castAbility,
    required EnemyCastTargetPolicy castTargetPolicy,
    required double sourceX,
    required double sourceY,
    required double targetX,
    required double targetY,
    required double targetVelX,
    required double targetVelY,
    required int windupTicks,
  }) {
    final hitDelivery = castAbility.hitDelivery;
    DamageType? weaponDamageType;
    List<WeaponProc> weaponProcs = const <WeaponProc>[];
    var includeTravelLead = false;
    var travelSpeedUnitsPerSecond = 0.0;

    if (hitDelivery is ProjectileHitDelivery) {
      final projectile = projectiles.get(hitDelivery.projectileId);
      includeTravelLead = true;
      travelSpeedUnitsPerSecond = projectile.speedUnitsPerSecond;
      weaponDamageType = projectile.damageType;
      weaponProcs = projectile.procs;
    }

    var leadSeconds = 0.0;
    if (castTargetPolicy == EnemyCastTargetPolicy.predictedPlayerCenter) {
      leadSeconds = computeCastLeadSeconds(
        windupSeconds: _ticksToSeconds(windupTicks),
        includeTravelLead: includeTravelLead,
        sourceX: sourceX,
        sourceY: sourceY,
        targetX: targetX,
        targetY: targetY,
        travelSpeedUnitsPerSecond: travelSpeedUnitsPerSecond,
        minTravelLeadSeconds: unocoDemonTuning.base.unocoDemonAimLeadMinSeconds,
        maxTravelLeadSeconds: unocoDemonTuning.base.unocoDemonAimLeadMaxSeconds,
      );
    }

    final predicted = predictLinearTargetPosition(
      targetX: targetX,
      targetY: targetY,
      targetVelX: targetVelX,
      targetVelY: targetVelY,
      leadSeconds: leadSeconds,
    );
    return (predicted.$1, predicted.$2, weaponDamageType, weaponProcs);
  }

  void _writeProjectileIntent(
    EcsWorld world, {
    required EntityId enemy,
    required AbilityDef ability,
    required double? casterOriginOffset,
    required HitPayload payload,
    required AbilityResourceCost commitCost,
    required double targetX,
    required double targetY,
    required double sourceX,
    required double sourceY,
    required int commitTick,
    required int executeTick,
    required int windupTicks,
    required int activeTicks,
    required int recoveryTicks,
    required int cooldownTicks,
    required int cooldownGroupId,
    required ProjectileId projectileId,
    required ProjectileItemDef projectile,
  }) {
    final originOffset = resolveCasterProjectileOriginOffset(
      world,
      enemy,
      authoredCasterOffset: casterOriginOffset,
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
        dirX: targetX - sourceX,
        dirY: targetY - sourceY,
        fallbackDirX: 1.0,
        fallbackDirY: 0.0,
        originOffset: originOffset,
        commitTick: commitTick,
        windupTicks: windupTicks,
        activeTicks: activeTicks,
        recoveryTicks: recoveryTicks,
        cooldownGroupId: cooldownGroupId,
        tick: executeTick,
      ),
    );
  }

  void _writeTargetPointIntent(
    EcsWorld world, {
    required EntityId enemy,
    required AbilityDef ability,
    required TargetPointHitDelivery hitDelivery,
    required HitPayload payload,
    required AbilityResourceCost commitCost,
    required double targetX,
    required double targetY,
    required int commitTick,
    required int executeTick,
    required int windupTicks,
    required int activeTicks,
    required int recoveryTicks,
    required int cooldownTicks,
    required int cooldownGroupId,
  }) {
    world.targetPointIntent.set(
      enemy,
      TargetPointIntentDef(
        abilityId: ability.id,
        slot: AbilitySlot.projectile,
        damage100: payload.damage100,
        critChanceBp: payload.critChanceBp,
        staminaCost100: commitCost.staminaCost100,
        manaCost100: commitCost.manaCost100,
        cooldownTicks: cooldownTicks,
        cooldownGroupId: cooldownGroupId,
        damageType: payload.damageType,
        procs: payload.procs,
        halfX: hitDelivery.halfX,
        halfY: hitDelivery.halfY,
        hitPolicy: hitDelivery.hitPolicy,
        sourceKind: DeathSourceKind.spellImpact,
        impactEffectId: hitDelivery.impactEffectId,
        targetX: targetX,
        targetY: targetY,
        commitTick: commitTick,
        windupTicks: windupTicks,
        activeTicks: activeTicks,
        recoveryTicks: recoveryTicks,
        tick: executeTick,
      ),
    );
  }

  (double, double) _entityCenter(
    EcsWorld world,
    EntityId entity, {
    required double fallbackX,
    required double fallbackY,
  }) {
    var x = fallbackX;
    var y = fallbackY;
    if (world.colliderAabb.has(entity)) {
      final ai = world.colliderAabb.indexOf(entity);
      final ti = world.transform.tryIndexOf(entity);
      if (ti != null) {
        x = colliderCenterX(
          world,
          entity: entity,
          transformIndex: ti,
          colliderIndex: ai,
        );
      } else {
        x += colliderEffectiveOffsetX(world, entity: entity, colliderIndex: ai);
      }
      y += world.colliderAabb.offsetY[ai];
    }
    return (x, y);
  }

  void _faceEnemyTowardX(
    EcsWorld world, {
    required int enemyIndex,
    required double targetX,
    required double sourceX,
  }) {
    final dirX = targetX - sourceX;
    if (dirX.abs() <= 1e-6) return;
    world.enemy.facing[enemyIndex] = dirX >= 0 ? Facing.right : Facing.left;
  }

  HitPayload _buildPayload(
    EcsWorld world, {
    required EntityId source,
    required AbilityDef ability,
    required DamageType? weaponDamageType,
    required List<WeaponProc> weaponProcs,
  }) {
    final offenseIndex = world.offenseBuff.tryIndexOf(source);
    final offensePowerBp =
        offenseIndex != null && world.offenseBuff.ticksLeft[offenseIndex] > 0
        ? world.offenseBuff.powerBonusBp[offenseIndex]
        : 0;
    final offenseCritBp =
        offenseIndex != null && world.offenseBuff.ticksLeft[offenseIndex] > 0
        ? world.offenseBuff.critBonusBp[offenseIndex]
        : 0;
    return HitPayloadBuilder.build(
      ability: ability,
      source: source,
      globalPowerBonusBp: offensePowerBp,
      globalCritChanceBonusBp: offenseCritBp,
      weaponDamageType: weaponDamageType,
      weaponProcs: weaponProcs,
    );
  }

  AbilityResourceCost _resolveCastCost(AbilityDef castAbility) {
    final hitDelivery = castAbility.hitDelivery;
    if (hitDelivery is ProjectileHitDelivery) {
      final projectile = projectiles.tryGet(hitDelivery.projectileId);
      if (projectile != null) {
        return castAbility.resolveCostForWeaponType(projectile.weaponType);
      }
    }
    return castAbility.resolveCostForWeaponType(null);
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
    final seconds = ticks / abilityAuthoringTickHz;
    return (seconds * unocoDemonTuning.tickHz).ceil();
  }

  double _ticksToSeconds(int ticks) {
    if (ticks <= 0 || unocoDemonTuning.tickHz <= 0) return 0.0;
    return ticks / unocoDemonTuning.tickHz;
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

  static const int _minCommitHp100 = 1;
}
