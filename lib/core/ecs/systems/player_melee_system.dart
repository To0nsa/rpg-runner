import 'dart:math';

import '../../snapshots/enums.dart';
import '../../tuning/v0_ability_tuning.dart';
import '../../tuning/v0_movement_tuning.dart';
import '../entity_id.dart';
import '../stores/melee_intent_store.dart';
import '../world.dart';

class PlayerMeleeSystem {
  const PlayerMeleeSystem({required this.abilities, required this.movement});

  final V0AbilityTuningDerived abilities;
  final V0MovementTuningDerived movement;

  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    _trySpawnPlayerMelee(world, player: player, currentTick: currentTick);
  }

  void _trySpawnPlayerMelee(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    if (!world.playerInput.has(player)) return;
    if (!world.transform.has(player)) return;
    if (!world.movement.has(player)) return;
    if (!world.meleeIntent.has(player)) {
      assert(
        false,
        'PlayerMeleeSystem requires MeleeIntentStore on the player; add it at spawn time.',
      );
      return;
    }

    final ii = world.playerInput.indexOf(player);
    if (!world.playerInput.attackPressed[ii]) return;

    final mi = world.movement.indexOf(player);
    final facing = world.movement.facing[mi];
    final aimX = world.playerInput.meleeAimDirX[ii];
    final aimY = world.playerInput.meleeAimDirY[ii];
    final len2 = aimX * aimX + aimY * aimY;

    final double dirX;
    final double dirY;
    if (len2 > 1e-12) {
      final invLen = 1.0 / sqrt(len2);
      dirX = aimX * invLen;
      dirY = aimY * invLen;
    } else {
      dirX = (facing == Facing.right) ? 1.0 : -1.0;
      dirY = 0.0;
    }

    final halfX = abilities.base.meleeHitboxSizeX * 0.5;
    final halfY = abilities.base.meleeHitboxSizeY * 0.5;

    // origin = playerPos + aimDir * (playerRadius * 0.5) for casts
    // melee uses facing-only:
    // center = playerPos + dirX * (playerRadius * 0.5 + halfX)
    final forward = movement.base.playerRadius * 0.5 + max(halfX, halfY);
    final offsetX = dirX * forward;
    final offsetY = dirY * forward;

    // IMPORTANT: PlayerMeleeSystem writes intent only; execution happens in
    // `MeleeAttackSystem` which owns stamina/cooldown rules and hitbox spawning.
    world.meleeIntent.set(
      player,
      MeleeIntentDef(
        damage: abilities.base.meleeDamage,
        halfX: halfX,
        halfY: halfY,
        offsetX: offsetX,
        offsetY: offsetY,
        activeTicks: abilities.meleeActiveTicks,
        cooldownTicks: abilities.meleeCooldownTicks,
        staminaCost: abilities.base.meleeStaminaCost,
        tick: currentTick,
      ),
    );
  }
}
