import 'package:rpg_runner/core/ecs/entity_id.dart';

import '../../abilities/ability_def.dart';
import '../../combat/damage_type.dart';
import '../../snapshots/enums.dart';
import '../../tuning/ground_enemy_tuning.dart';
import '../../util/fixed_math.dart';
import '../stores/enemies/melee_engagement_store.dart';
import '../stores/melee_intent_store.dart';
import '../world.dart';

/// Handles enemy melee strike decisions and writes melee intents.
class EnemyMeleeSystem {
  EnemyMeleeSystem({required this.groundEnemyTuning});

  final GroundEnemyTuningDerived groundEnemyTuning;

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

      if (!world.cooldown.has(enemy)) continue;

      final ti = world.transform.tryIndexOf(enemy);
      if (ti == null) continue;

      if (world.controlLock.isStunned(enemy, currentTick)) continue;
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

      final ex = world.transform.posX[ti];
      final tuning = groundEnemyTuning;

      final facing = playerX >= ex ? Facing.right : Facing.left;
      world.enemy.facing[enemyIndex] = facing;
      final dirX = facing == Facing.right ? 1.0 : -1.0;

      final halfX = tuning.combat.meleeHitboxSizeX * 0.5;
      final halfY = tuning.combat.meleeHitboxSizeY * 0.5;

      final ownerHalfX =
          world.colliderAabb.halfX[world.colliderAabb.indexOf(enemy)];
      final offsetX = dirX * (ownerHalfX * 0.5 + halfX);
      const offsetY = 0.0;

      final commitTick = meleeEngagement.strikeStartTick[i];
      final windupTicks = plannedHitTick > commitTick
          ? plannedHitTick - commitTick
          : tuning.combat.meleeWindupTicks;
      final recoveryTicks =
          tuning.combat.meleeAnimTicks -
          windupTicks -
          tuning.combat.meleeActiveTicks;
      final clampedRecovery = recoveryTicks < 0 ? 0 : recoveryTicks;

      world.meleeIntent.set(
        enemy,
        MeleeIntentDef(
          abilityId: 'common.enemy_strike',
          slot: AbilitySlot.primary,
          damage100: toFixed100(tuning.combat.meleeDamage),
          damageType: DamageType.physical,
          halfX: halfX,
          halfY: halfY,
          offsetX: offsetX,
          offsetY: offsetY,
          dirX: dirX,
          dirY: 0.0,
          commitTick: commitTick,
          windupTicks: windupTicks,
          activeTicks: tuning.combat.meleeActiveTicks,
          recoveryTicks: clampedRecovery,
          cooldownTicks: tuning.combat.meleeCooldownTicks,
          staminaCost100: 0,
          cooldownGroupId: CooldownGroup.primary,
          tick: plannedHitTick,
        ),
      );

      // Commit side effects (Cooldown + ActiveAbility) must be applied manually
      // since enemies don't use AbilityActivationSystem.
      world.cooldown.startCooldown(
        enemy,
        CooldownGroup.primary,
        tuning.combat.meleeCooldownTicks,
      );

      world.activeAbility.set(
        enemy,
        id: 'common.enemy_strike',
        slot: AbilitySlot.primary,
        commitTick: commitTick,
        windupTicks: windupTicks,
        activeTicks: tuning.combat.meleeActiveTicks,
        recoveryTicks: clampedRecovery,
        facingDir: facing,
      );

      world.enemy.lastMeleeTick[enemyIndex] = currentTick;
      world.enemy.lastMeleeFacing[enemyIndex] = facing;
      world.enemy.lastMeleeAnimTicks[enemyIndex] = tuning.combat.meleeAnimTicks;
    }
  }
}
