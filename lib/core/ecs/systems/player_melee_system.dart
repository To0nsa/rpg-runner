import 'dart:math';

import '../../snapshots/enums.dart';
import '../../tuning/player/player_ability_tuning.dart';
import '../../weapons/weapon_catalog.dart';
import '../entity_id.dart';
import '../stores/melee_intent_store.dart';
import '../world.dart';

/// Translates player input into a [MeleeIntentDef] for the [MeleeAttackSystem].
///
/// **Responsibilities**:
/// *   Checks input state (Attack button).
/// *   Calculates attack direction (Analog aim or Facing fallback).
/// *   Calculates hitbox offsets based on attack reach.
/// *   Registers intent (Costs/Cooldowns checked downstream).
class PlayerMeleeSystem {
  const PlayerMeleeSystem({
    required this.abilities,
    required this.weapons,
  });

  final AbilityTuningDerived abilities;
  final WeaponCatalog weapons;

  void step(
    EcsWorld world, {
    required EntityId player,
    required int currentTick,
  }) {
    // -- 1. Component Checks --
    
    // Check if the store exists (should be added at spawn).
    if (!world.meleeIntent.has(player)) {
      assert(
        false,
        'PlayerMeleeSystem requires MeleeIntentStore on the player; add it at spawn time.',
      );
      return;
    }

    // Input is required to know if attacking.
    final inputIndex = world.playerInput.tryIndexOf(player);
    if (inputIndex == null) return;
    
    // Movement is required for facing direction fallback.
    final movementIndex = world.movement.tryIndexOf(player);
    if (movementIndex == null) return;

    // Equipped weapon determines status profile, etc.
    final weaponIndex = world.equippedWeapon.tryIndexOf(player);
    if (weaponIndex == null) {
      assert(
        false,
        'PlayerMeleeSystem requires EquippedWeaponStore on the player; add it at spawn time.',
      );
      return;
    }

    // -- 2. Input Logic --

    // If button not pressed, early exit.
    if (!world.playerInput.attackPressed[inputIndex]) return;

    final actionAnimIndex = world.actionAnim.tryIndexOf(player);
    if (actionAnimIndex == null) {
      assert(
        false,
        'PlayerMeleeSystem requires ActionAnimStore on the player; add it at spawn time.',
      );
      return;
    }

    final facing = world.movement.facing[movementIndex];
    final aimX = world.playerInput.meleeAimDirX[inputIndex];
    final aimY = world.playerInput.meleeAimDirY[inputIndex];
    final len2 = aimX * aimX + aimY * aimY;

    // Normalize aim direction if valid, otherwise fallback to facing direction.
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

    // -- 3. Intent Calculation --

    final halfX = abilities.base.meleeHitboxSizeX * 0.5;
    final halfY = abilities.base.meleeHitboxSizeY * 0.5;

    // Calculate how far in front of the player the hitbox should appear.
    // origin = playerPos + aimDir * (playerColliderMaxHalfExtent * 0.5 + maxDimension)
    var maxHalfExtent = 0.0;
    if (world.colliderAabb.has(player)) {
      final aabbi = world.colliderAabb.indexOf(player);
      final colliderHalfX = world.colliderAabb.halfX[aabbi];
      final colliderHalfY = world.colliderAabb.halfY[aabbi];
      maxHalfExtent = colliderHalfX > colliderHalfY ? colliderHalfX : colliderHalfY;
    }
    final forward = maxHalfExtent * 0.5 + max(halfX, halfY);
    final offsetX = dirX * forward;
    final offsetY = dirY * forward;

    // IMPORTANT: PlayerMeleeSystem writes intent only; execution happens in
    // `MeleeAttackSystem` which owns stamina/cooldown rules and hitbox spawning.
    final weaponId = world.equippedWeapon.weaponId[weaponIndex];
    final weapon = weapons.get(weaponId);
    world.meleeIntent.set(
      player,
      MeleeIntentDef(
        damage: abilities.base.meleeDamage,
        damageType: weapon.damageType,
        statusProfileId: weapon.statusProfileId,
        halfX: halfX,
        halfY: halfY,
        offsetX: offsetX,
        offsetY: offsetY,
        dirX: dirX,
        dirY: dirY,
        activeTicks: abilities.meleeActiveTicks,
        cooldownTicks: abilities.meleeCooldownTicks,
        staminaCost: abilities.base.meleeStaminaCost,
        tick: currentTick,
      ),
    );
    world.actionAnim.lastMeleeTick[actionAnimIndex] = currentTick;
  }
}
