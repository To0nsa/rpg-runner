import 'dart:math';

import 'package:rpg_runner/core/ecs/entity_id.dart';

import '../../combat/damage_type.dart';
import '../../combat/status/status.dart';
import '../../enemies/enemy_catalog.dart';
import '../../enemies/enemy_id.dart';
import '../../projectiles/projectile_catalog.dart';
import '../../snapshots/enums.dart';
import '../../spells/spell_catalog.dart';
import '../../tuning/flying_enemy_tuning.dart';
import '../../tuning/ground_enemy_tuning.dart';
import '../../util/double_math.dart';
import '../stores/cast_intent_store.dart';
import '../stores/melee_intent_store.dart';
import '../stores/enemies/melee_engagement_store.dart';
import '../world.dart';

/// Handles enemy attack decisions and writes intent components.
class EnemyCombatSystem {
  EnemyCombatSystem({
    required this.unocoDemonTuning,
    required this.groundEnemyTuning,
    required this.enemyCatalog,
    required this.spells,
    required this.projectiles,
  });

  final UnocoDemonTuningDerived unocoDemonTuning;
  final GroundEnemyTuningDerived groundEnemyTuning;
  final EnemyCatalog enemyCatalog;
  final SpellCatalog spells;
  final ProjectileCatalogDerived projectiles;

  /// Evaluates attacks for all enemies and writes cast/melee intents.
  void stepAttacks(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    if (!world.transform.has(player)) return;

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
      final ti = world.transform.tryIndexOf(enemy);
      if (ti == null) continue;

      if (!world.cooldown.has(enemy)) continue;

      final ex = world.transform.posX[ti];
      final ey = world.transform.posY[ti];

      switch (enemies.enemyId[ei]) {
        case EnemyId.unocoDemon:
          var enemyCenterX = ex;
          var enemyCenterY = ey;
          if (world.colliderAabb.has(enemy)) {
            final ai = world.colliderAabb.indexOf(enemy);
            enemyCenterX += world.colliderAabb.offsetX[ai];
            enemyCenterY += world.colliderAabb.offsetY[ai];
          }
          _writeUnocoDemonCastIntent(
            world,
            enemy: enemy,
            enemyIndex: ei,
            enemyCenterX: enemyCenterX,
            enemyCenterY: enemyCenterY,
            playerCenterX: playerCenterX,
            playerCenterY: playerCenterY,
            playerVelX: playerVelX,
            playerVelY: playerVelY,
            currentTick: currentTick,
          );
        case EnemyId.groundEnemy:
          _writeGroundEnemyMeleeIntent(
            world,
            enemy: enemy,
            enemyIndex: ei,
            ex: ex,
            ey: ey,
            playerX: playerX,
            currentTick: currentTick,
          );
      }
    }
  }

  void _writeUnocoDemonCastIntent(
    EcsWorld world, {
    required EntityId enemy,
    required int enemyIndex,
    required double enemyCenterX,
    required double enemyCenterY,
    required double playerCenterX,
    required double playerCenterY,
    required double playerVelX,
    required double playerVelY,
    required int currentTick,
  }) {
    final tuning = unocoDemonTuning;
    if (!world.castIntent.has(enemy)) {
      assert(
        false,
        'EnemyCombatSystem requires CastIntentStore on enemies; add it at spawn time.',
      );
      return;
    }

    final enemyId = world.enemy.enemyId[enemyIndex];
    final spellId = enemyCatalog.get(enemyId).primarySpellId;
    if (spellId == null) return;
    final projectileId = spells.get(spellId).projectileId;
    final projectileSpeed = projectileId == null
        ? null
        : projectiles.base.get(projectileId).speedUnitsPerSecond;

    var targetX = playerCenterX;
    var targetY = playerCenterY;
    if (projectileSpeed != null && projectileSpeed > 0.0) {
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

    world.castIntent.set(
      enemy,
      CastIntentDef(
        spellId: spellId,
        dirX: targetX - enemyCenterX,
        dirY: targetY - enemyCenterY,
        fallbackDirX: 1.0,
        fallbackDirY: 0.0,
        originOffset: tuning.base.unocoDemonCastOriginOffset,
        cooldownTicks: tuning.unocoDemonCastCooldownTicks,
        tick: currentTick,
      ),
    );
  }

  void _writeGroundEnemyMeleeIntent(
    EcsWorld world, {
    required EntityId enemy,
    required int enemyIndex,
    required double ex,
    required double ey,
    required double playerX,
    required int currentTick,
  }) {
    final tuning = groundEnemyTuning;
    if (!world.meleeIntent.has(enemy)) {
      assert(
        false,
        'EnemyCombatSystem requires MeleeIntentStore on enemies; add it at spawn time.',
      );
      return;
    }
    if (!world.colliderAabb.has(enemy)) {
      assert(
        false,
        'GroundEnemy melee requires ColliderAabbStore on the enemy to compute hitbox offset.',
      );
      return;
    }

    final dx = (playerX - ex).abs();
    if (dx > tuning.combat.meleeRangeX) return;

    final facing = world.enemy.facing[enemyIndex];
    final dirX = facing == Facing.right ? 1.0 : -1.0;

    final halfX = tuning.combat.meleeHitboxSizeX * 0.5;
    final halfY = tuning.combat.meleeHitboxSizeY * 0.5;

    final ownerHalfX =
        world.colliderAabb.halfX[world.colliderAabb.indexOf(enemy)];
    final offsetX = dirX * (ownerHalfX * 0.5 + halfX);
    const offsetY = 0.0;

    world.meleeIntent.set(
      enemy,
      MeleeIntentDef(
        damage: tuning.combat.meleeDamage,
        damageType: DamageType.physical,
        statusProfileId: StatusProfileId.none,
        halfX: halfX,
        halfY: halfY,
        offsetX: offsetX,
        offsetY: offsetY,
        dirX: dirX,
        dirY: 0.0,
        activeTicks: tuning.combat.meleeActiveTicks,
        cooldownTicks: tuning.combat.meleeCooldownTicks,
        staminaCost: 0.0,
        tick: currentTick,
      ),
    );

    if (world.meleeEngagement.has(enemy)) {
      final mi = world.meleeEngagement.indexOf(enemy);
      world.meleeEngagement.state[mi] = MeleeEngagementState.attack;
      world.meleeEngagement.ticksLeft[mi] = tuning.combat.meleeAnimTicks;
      world.meleeEngagement.preferredSide[mi] = ex >= playerX ? 1 : -1;
    } else {
      assert(
        false,
        'EnemyCombatSystem requires MeleeEngagementStore on melee enemies; add it at spawn time.',
      );
    }

    world.enemy.lastMeleeTick[enemyIndex] = currentTick;
    world.enemy.lastMeleeFacing[enemyIndex] = facing;
    world.enemy.lastMeleeAnimTicks[enemyIndex] =
        tuning.combat.meleeAnimTicks;
  }
}
