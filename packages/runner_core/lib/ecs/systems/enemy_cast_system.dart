import 'dart:math' as math;

import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../combat/control_lock.dart';
import '../../combat/ai_cast_aim_policy.dart';
import '../../combat/cast_origin_offset.dart';
import '../../combat/damage_type.dart';
import '../../combat/hit_payload.dart';
import '../../combat/hit_payload_builder.dart';
import '../../enemies/enemy_catalog.dart';
import '../../enemies/enemy_id.dart';
import '../../events/game_event.dart';
import '../../projectiles/projectile_catalog.dart';
import '../../projectiles/projectile_item_def.dart';
import '../../projectiles/projectile_id.dart';
import '../../projectiles/ballistic_aim.dart';
import '../../snapshots/enums.dart';
import '../../tuning/flying_enemy_tuning.dart';
import '../../tuning/physics_tuning.dart';
import '../../util/ability_timing.dart';
import '../../util/fixed_math.dart';
import '../../util/target_prediction.dart';
import '../../weapons/weapon_proc.dart';
import '../collider_aabb_utils.dart';
import '../entity_id.dart';
import '../actor_facing.dart';
import '../combat_target.dart';
import '../stores/enemies/derf_phase_store.dart';
import '../stores/enemies/flying_enemy_combat_mode_store.dart';
import '../stores/projectile_intent_store.dart';
import '../stores/target_point_intent_store.dart';
import '../world.dart';
import 'ai_ability_commit.dart';

typedef _CastAim = ({
  double x,
  double y,
  double dirX,
  double dirY,
  DamageType? weaponDamageType,
  List<WeaponProc> weaponProcs,
});

/// Handles enemy cast decisions and writes execution intents.
class EnemyCastSystem {
  EnemyCastSystem({
    required this.unocoDemonTuning,
    required this.enemyCatalog,
    required this.projectiles,
    this.abilities = AbilityCatalog.shared,
    PhysicsTuning physics = const PhysicsTuning(),
  }) : committer = AiCastCommitter(
         tickHz: unocoDemonTuning.tickHz,
         projectiles: projectiles,
         physics: physics,
         minTravelLeadSeconds:
             unocoDemonTuning.base.unocoDemonAimLeadMinSeconds,
         maxTravelLeadSeconds:
             unocoDemonTuning.base.unocoDemonAimLeadMaxSeconds,
       );

  final AiCastCommitter committer;
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
    final enemies = world.enemy;
    for (var ei = 0; ei < enemies.denseEntities.length; ei += 1) {
      final enemy = enemies.denseEntities[ei];
      if (enemies.enemyId[ei] == EnemyId.bringerOfDeath) continue;
      final target = combatTarget(world, enemy, player);
      if (target == null) continue;
      final targetTi = world.transform.indexOf(target);
      final targetVelX = world.transform.velX[targetTi];
      final targetVelY = world.transform.velY[targetTi];
      final targetCenter = aiActorCenter(
        world,
        target,
        fallbackX: world.transform.posX[targetTi],
        fallbackY: world.transform.posY[targetTi],
      );
      if (world.deathState.has(enemy)) continue;
      final derf = world.derfPhase.tryIndexOf(enemy);
      if (derf != null && world.derfPhase.phase[derf] != DerfPhase.caster) {
        continue;
      }
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

      final enemyCenter = aiActorCenter(
        world,
        enemy,
        fallbackX: world.transform.posX[enemyTi],
        fallbackY: world.transform.posY[enemyTi],
      );
      if (archetype.facingPolicy == EnemyFacingPolicy.facePlayerAlways) {
        _faceActorTowardX(
          world,
          actor: enemy,
          targetX: targetCenter.$1,
          sourceX: enemyCenter.$1,
        );
      }
      committer.commit(
        world,
        actor: enemy,
        castAbility: castAbility,
        sourceX: enemyCenter.$1,
        sourceY: enemyCenter.$2,
        targetX: targetCenter.$1,
        targetY: targetCenter.$2,
        targetVelX: targetVelX,
        targetVelY: targetVelY,
        aimPolicy: archetype.castTargetPolicy,
        casterOriginOffset: archetype.castOriginOffset,
        currentTick: currentTick,
      );
    }
  }
}

/// Shares cast gates, timing, payloads and gravity-aware aiming across actors.
/// [physics] must match the motion authority's level tuning. Unreachable
/// ballistic shots are rejected before spending resources or starting cooldowns.
class AiCastCommitter {
  const AiCastCommitter({
    required this.tickHz,
    required this.projectiles,
    this.physics = const PhysicsTuning(),
    this.minTravelLeadSeconds = .08,
    this.maxTravelLeadSeconds = .4,
  });
  final int tickHz;
  final ProjectileCatalog projectiles;
  final PhysicsTuning physics;
  final double minTravelLeadSeconds;
  final double maxTravelLeadSeconds;

  bool commit(
    EcsWorld world, {
    required EntityId actor,
    required AbilityDef castAbility,
    required double sourceX,
    required double sourceY,
    required double targetX,
    required double targetY,
    required double targetVelX,
    required double targetVelY,
    required AiCastAimPolicy aimPolicy,
    double? casterOriginOffset,
    double casterOriginOffsetY = 0,
    required int currentTick,
  }) {
    if (!world.transform.has(actor) || !world.cooldown.has(actor)) return false;
    if (world.activeAbility.hasActiveAbility(actor)) return false;

    final castCost = _resolveCastCost(castAbility);
    if (!canAffordAiAbility(world, actor, castCost)) return false;

    final cooldownGroupId = castAbility.effectiveCooldownGroup(
      AbilitySlot.projectile,
    );
    if (world.cooldown.isOnCooldown(actor, cooldownGroupId)) return false;
    if (!canCommitAiAbility(
      world,
      actor,
      currentTick: currentTick,
      lock: LockFlag.cast,
      cooldownGroupId: cooldownGroupId,
      cost: castCost,
    )) {
      return false;
    }

    final actionSpeedBp = _actionSpeedBpForEntity(world, actor);
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
      castTargetPolicy: aimPolicy,
      sourceX: sourceX,
      sourceY: sourceY + casterOriginOffsetY,
      targetX: targetX,
      targetY: targetY,
      targetVelX: targetVelX,
      targetVelY: targetVelY,
      windupTicks: windupTicks,
      originOffset: castAbility.hitDelivery is ProjectileHitDelivery
          ? resolveCasterProjectileOriginOffset(
              world,
              actor,
              authoredCasterOffset: casterOriginOffset,
            )
          : 0,
    );
    if (resolvedAim == null) return false;
    final aimX = resolvedAim.x;
    final aimY = resolvedAim.y;
    _faceActorTowardX(world, actor: actor, targetX: aimX, sourceX: sourceX);

    final payload = _buildPayload(
      world,
      source: actor,
      ability: castAbility,
      weaponDamageType: resolvedAim.weaponDamageType,
      weaponProcs: resolvedAim.weaponProcs,
    );

    final hitDelivery = castAbility.hitDelivery;
    if (hitDelivery is ProjectileHitDelivery) {
      if (!world.projectileIntent.has(actor)) {
        assert(
          false,
          'AiCastCommitter requires ProjectileIntentStore on its actor.',
        );
        return false;
      }
      final projectile = projectiles.get(hitDelivery.projectileId);
      _writeProjectileIntent(
        world,
        actor: actor,
        ability: castAbility,
        casterOriginOffset: casterOriginOffset,
        casterOriginOffsetY: casterOriginOffsetY,
        payload: payload,
        commitCost: castCost,
        dirX: resolvedAim.dirX,
        dirY: resolvedAim.dirY,
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
      if (!world.targetPointIntent.has(actor)) {
        assert(
          false,
          'AiCastCommitter requires TargetPointIntentStore on its actor.',
        );
        return false;
      }
      _writeTargetPointIntent(
        world,
        actor: actor,
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
      return false;
    }

    spendAiAbilityCost(world, actor, castCost);
    world.cooldown.startCooldown(actor, cooldownGroupId, cooldownTicks);
    world.activeAbility.set(
      actor,
      id: castAbility.id,
      slot: AbilitySlot.projectile,
      commitTick: commitTick,
      windupTicks: windupTicks,
      activeTicks: activeTicks,
      recoveryTicks: recoveryTicks,
      facingDir: actorFacing(world, actor),
    );
    return true;
  }

  _CastAim? _resolveAimPoint({
    required AbilityDef castAbility,
    required AiCastAimPolicy castTargetPolicy,
    required double sourceX,
    required double sourceY,
    required double targetX,
    required double targetY,
    required double targetVelX,
    required double targetVelY,
    required int windupTicks,
    required double originOffset,
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
      if (projectile.ballistic) {
        final predict =
            castTargetPolicy == AiCastAimPolicy.predictedTargetCenter;
        final aim = solveBallisticAim(
          sourceX: sourceX,
          sourceY: sourceY,
          targetX: targetX,
          targetY: targetY,
          targetVelX: predict ? targetVelX : 0,
          targetVelY: predict ? targetVelY : 0,
          windupSeconds: predict ? _ticksToSeconds(windupTicks) : 0,
          speed: projectile.speedUnitsPerSecond,
          gravityY: physics.gravityY * projectile.gravityScale,
          tickHz: tickHz,
          maxFlightSeconds:
              ((projectile.lifetimeSeconds * tickHz).ceil() - 1) / tickHz,
          originOffset: originOffset,
        );
        if (aim == null) return null;
        return (
          x:
              targetX +
              (predict
                  ? targetVelX *
                        (_ticksToSeconds(windupTicks) + aim.flightSeconds)
                  : 0),
          y:
              targetY +
              (predict
                  ? targetVelY *
                        (_ticksToSeconds(windupTicks) + aim.flightSeconds)
                  : 0),
          dirX: aim.dirX,
          dirY: aim.dirY,
          weaponDamageType: weaponDamageType,
          weaponProcs: weaponProcs,
        );
      }
    }

    var leadSeconds = 0.0;
    if (castTargetPolicy == AiCastAimPolicy.predictedTargetCenter) {
      leadSeconds = computeCastLeadSeconds(
        windupSeconds: _ticksToSeconds(windupTicks),
        includeTravelLead: includeTravelLead,
        sourceX: sourceX,
        sourceY: sourceY,
        targetX: targetX,
        targetY: targetY,
        travelSpeedUnitsPerSecond: travelSpeedUnitsPerSecond,
        minTravelLeadSeconds: minTravelLeadSeconds,
        maxTravelLeadSeconds: maxTravelLeadSeconds,
      );
    }

    final predicted = predictLinearTargetPosition(
      targetX: targetX,
      targetY: targetY,
      targetVelX: targetVelX,
      targetVelY: targetVelY,
      leadSeconds: leadSeconds,
    );
    return (
      x: predicted.$1,
      y: predicted.$2,
      dirX: predicted.$1 - sourceX,
      dirY: predicted.$2 - sourceY,
      weaponDamageType: weaponDamageType,
      weaponProcs: weaponProcs,
    );
  }

  void _writeProjectileIntent(
    EcsWorld world, {
    required EntityId actor,
    required AbilityDef ability,
    required double? casterOriginOffset,
    required double casterOriginOffsetY,
    required HitPayload payload,
    required AbilityResourceCost commitCost,
    required double dirX,
    required double dirY,
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
      actor,
      authoredCasterOffset: casterOriginOffset,
    );
    world.projectileIntent.set(
      actor,
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
        knockback: payload.knockback,
        ballistic: projectile.ballistic,
        gravityScale: projectile.gravityScale,
        dirX: dirX,
        dirY: dirY,
        fallbackDirX: 1.0,
        fallbackDirY: 0.0,
        originOffset: originOffset,
        sourceOffsetY: casterOriginOffsetY,
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
    required EntityId actor,
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
      actor,
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
        knockback: payload.knockback,
        profile: hitDelivery.profile,
        frameStepTicks: math.max(
          1,
          (hitDelivery.stepTimeSeconds * tickHz).round(),
        ),
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

  int _scaleAbilityTicks(int ticks) {
    if (ticks <= 0) return 0;
    if (tickHz <= 0) return ticks;
    final seconds = ticks / abilityAuthoringTickHz;
    return (seconds * tickHz).ceil();
  }

  double _ticksToSeconds(int ticks) {
    if (ticks <= 0 || tickHz <= 0) return 0.0;
    return ticks / tickHz;
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
}

/// Collider center shared by autonomous aim decisions.
(double, double) aiActorCenter(
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

void _faceActorTowardX(
  EcsWorld world, {
  required EntityId actor,
  required double targetX,
  required double sourceX,
}) {
  final dirX = targetX - sourceX;
  if (dirX.abs() <= 1e-6) return;
  setActorFacing(world, actor, dirX >= 0 ? Facing.right : Facing.left);
}
