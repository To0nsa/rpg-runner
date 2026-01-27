import 'dart:math';

import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../combat/hit_payload_builder.dart';
import '../../enemies/enemy_catalog.dart';
import '../../projectiles/projectile_catalog.dart';
import '../../projectiles/projectile_item_catalog.dart';
import '../../projectiles/projectile_item_def.dart';
import '../../projectiles/projectile_item_id.dart';
import '../../snapshots/enums.dart';
import '../../tuning/flying_enemy_tuning.dart';
import '../../util/double_math.dart';
import '../entity_id.dart';
import '../stores/projectile_intent_store.dart';
import '../world.dart';

/// Handles enemy projectile strike decisions and writes projectile intents.
class EnemyCastSystem {
  EnemyCastSystem({
    required this.unocoDemonTuning,
    required this.enemyCatalog,
    required this.projectileItems,
    required this.projectiles,
  });

  final UnocoDemonTuningDerived unocoDemonTuning;
  final EnemyCatalog enemyCatalog;
  final ProjectileItemCatalog projectileItems;
  final ProjectileCatalogDerived projectiles;

  /// Evaluates casts for all enemies and writes projectile intents.
  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    if (!world.transform.has(player)) return;

    final ability = AbilityCatalog.tryGet(_enemyAbilityId);
    if (ability == null) return;

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
      final projectileItemId = enemyCatalog.get(enemyId).primaryProjectileItemId;
      if (projectileItemId == null) continue;

      final projectileItem = projectileItems.get(projectileItemId);
      final projectileId = projectileItem.projectileId;
      final projectileSpeed =
          projectiles.base.get(projectileId).speedUnitsPerSecond;

      var enemyCenterX = world.transform.posX[ti];
      var enemyCenterY = world.transform.posY[ti];
      if (world.colliderAabb.has(enemy)) {
        final ai = world.colliderAabb.indexOf(enemy);
        enemyCenterX += world.colliderAabb.offsetX[ai];
        enemyCenterY += world.colliderAabb.offsetY[ai];
      }

      _writeProjectileIntent(
        world,
        ability: ability,
        projectileItemId: projectileItemId,
        projectileItem: projectileItem,
        enemyIndex: ei,
        enemyCenterX: enemyCenterX,
        enemyCenterY: enemyCenterY,
        playerCenterX: playerCenterX,
        playerCenterY: playerCenterY,
        playerVelX: playerVelX,
        playerVelY: playerVelY,
        projectileSpeed: projectileSpeed,
        currentTick: currentTick,
      );
    }
  }

  void _writeProjectileIntent(
    EcsWorld world, {
    required AbilityDef ability,
    required int enemyIndex,
    required double enemyCenterX,
    required double enemyCenterY,
    required double playerCenterX,
    required double playerCenterY,
    required double playerVelX,
    required double playerVelY,
    required double projectileSpeed,
    required int currentTick,
    required ProjectileItemId projectileItemId,
    required ProjectileItemDef projectileItem,
  }) {
    final tuning = unocoDemonTuning;

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
      world.enemy.facing[enemyIndex] =
          castDirX >= 0 ? Facing.right : Facing.left;
    }

    final enemy = world.enemy.denseEntities[enemyIndex];
    final payload = HitPayloadBuilder.build(
      ability: ability,
      source: enemy,
      weaponStats: projectileItem.stats,
      weaponDamageType: projectileItem.damageType,
      weaponProcs: projectileItem.procs,
    );

    final windupTicks = _scaleAbilityTicks(ability.windupTicks);
    final activeTicks = _scaleAbilityTicks(ability.activeTicks);
    final recoveryTicks = _scaleAbilityTicks(ability.recoveryTicks);
    final commitTick = currentTick;
    final executeTick = commitTick + windupTicks;

    world.projectileIntent.set(
      enemy,
      ProjectileIntentDef(
        projectileItemId: projectileItemId,
        abilityId: ability.id,
        slot: AbilitySlot.projectile,
        damage100: payload.damage100,
        staminaCost100: ability.staminaCost,
        manaCost100: ability.manaCost,
        cooldownTicks: tuning.unocoDemonCastCooldownTicks,
        projectileId: projectileItem.projectileId,
        damageType: payload.damageType,
        procs: payload.procs,
        ballistic: projectileItem.ballistic,
        gravityScale: projectileItem.gravityScale,
        dirX: targetX - enemyCenterX,
        dirY: targetY - enemyCenterY,
        fallbackDirX: 1.0,
        fallbackDirY: 0.0,
        originOffset: tuning.base.unocoDemonCastOriginOffset,
        commitTick: commitTick,
        windupTicks: windupTicks,
        activeTicks: activeTicks,
        recoveryTicks: recoveryTicks,
        tick: executeTick,
      ),
    );
  }

  int _scaleAbilityTicks(int ticks) {
    if (ticks <= 0) return 0;
    if (unocoDemonTuning.tickHz <= 0) return ticks;
    final seconds = ticks / _abilityTickHz;
    return (seconds * unocoDemonTuning.tickHz).ceil();
  }

  static const int _abilityTickHz = 60;
  static const AbilityKey _enemyAbilityId = 'common.enemy_cast';
}
