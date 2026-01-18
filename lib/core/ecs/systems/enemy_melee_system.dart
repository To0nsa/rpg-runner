import 'package:rpg_runner/core/ecs/entity_id.dart';

import '../../combat/damage_type.dart';
import '../../combat/status/status.dart';
import '../../snapshots/enums.dart';
import '../../tuning/ground_enemy_tuning.dart';
import '../stores/enemies/melee_engagement_store.dart';
import '../stores/melee_intent_store.dart';
import '../world.dart';

/// Handles enemy melee attack decisions and writes melee intents.
class EnemyMeleeSystem {
  EnemyMeleeSystem({required this.groundEnemyTuning});

  final GroundEnemyTuningDerived groundEnemyTuning;

  /// Evaluates melee attacks for all enemies and writes melee intents.
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
      final enemyIndex = world.enemy.tryIndexOf(enemy);
      if (enemyIndex == null) {
        assert(
          false,
          'EnemyMeleeSystem requires EnemyStore on melee enemies; add it at spawn time.',
        );
        continue;
      }

      if (!world.cooldown.has(enemy)) continue;

      final ti = world.transform.tryIndexOf(enemy);
      if (ti == null) continue;

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

      final ex = world.transform.posX[ti];
      _writeMeleeIntent(
        world,
        enemy: enemy,
        enemyIndex: enemyIndex,
        ex: ex,
        playerX: playerX,
        currentTick: currentTick,
      );
    }
  }

  void _writeMeleeIntent(
    EcsWorld world, {
    required EntityId enemy,
    required int enemyIndex,
    required double ex,
    required double playerX,
    required int currentTick,
  }) {
    final tuning = groundEnemyTuning;
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
        'EnemyMeleeSystem requires MeleeEngagementStore on melee enemies; add it at spawn time.',
      );
    }

    world.enemy.lastMeleeTick[enemyIndex] = currentTick;
    world.enemy.lastMeleeFacing[enemyIndex] = facing;
    world.enemy.lastMeleeAnimTicks[enemyIndex] = tuning.combat.meleeAnimTicks;
  }
}
