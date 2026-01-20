import 'dart:math';

import 'package:rpg_runner/core/ecs/entity_id.dart';

import '../../enemies/enemy_catalog.dart';
import '../../projectiles/projectile_catalog.dart';
import '../../snapshots/enums.dart';
import '../../spells/spell_catalog.dart';
import '../../spells/spell_id.dart';
import '../../tuning/flying_enemy_tuning.dart';
import '../../util/double_math.dart';
import '../stores/cast_intent_store.dart';
import '../world.dart';

/// Handles enemy ranged attack decisions and writes cast intents.
class EnemyCastSystem {
  EnemyCastSystem({
    required this.unocoDemonTuning,
    required this.enemyCatalog,
    required this.spells,
    required this.projectiles,
  });

  final UnocoDemonTuningDerived unocoDemonTuning;
  final EnemyCatalog enemyCatalog;
  final SpellCatalog spells;
  final ProjectileCatalogDerived projectiles;

  /// Evaluates casts for all enemies and writes cast intents.
  void step(
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
      if (world.deathState.has(enemy)) continue;
      final ti = world.transform.tryIndexOf(enemy);
      if (ti == null) continue;

      if (!world.cooldown.has(enemy)) continue;

      if (!world.castIntent.has(enemy)) {
        assert(
          false,
          'EnemyCastSystem requires CastIntentStore on enemies; add it at spawn time.',
        );
        continue;
      }

      final enemyId = enemies.enemyId[ei];
      final spellId = enemyCatalog.get(enemyId).primarySpellId;
      if (spellId == null) continue;

      var enemyCenterX = world.transform.posX[ti];
      var enemyCenterY = world.transform.posY[ti];
      if (world.colliderAabb.has(enemy)) {
        final ai = world.colliderAabb.indexOf(enemy);
        enemyCenterX += world.colliderAabb.offsetX[ai];
        enemyCenterY += world.colliderAabb.offsetY[ai];
      }

      _writeCastIntent(
        world,
        enemyIndex: ei,
        enemyCenterX: enemyCenterX,
        enemyCenterY: enemyCenterY,
        playerCenterX: playerCenterX,
        playerCenterY: playerCenterY,
        playerVelX: playerVelX,
        playerVelY: playerVelY,
        spellId: spellId,
        currentTick: currentTick,
      );
    }
  }

  void _writeCastIntent(
    EcsWorld world, {
    required int enemyIndex,
    required double enemyCenterX,
    required double enemyCenterY,
    required double playerCenterX,
    required double playerCenterY,
    required double playerVelX,
    required double playerVelY,
    required SpellId spellId,
    required int currentTick,
  }) {
    final tuning = unocoDemonTuning;

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

    final enemy = world.enemy.denseEntities[enemyIndex];
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
}
