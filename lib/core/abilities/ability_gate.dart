import '../ecs/entity_id.dart';
import '../ecs/world.dart';

enum AbilityGateFail {
  stunned,
  onCooldown,
  missingMana,
  insufficientMana,
  missingStamina,
  insufficientStamina,

  // Mobility-only
  missingMovement,
  missingBody,
  bodyDisabledOrKinematic,
  dashAlreadyActive,
  aimingHeld,
}

abstract class AbilityGate {
  static AbilityGateFail? canCommitCombat(
    EcsWorld world, {
    required EntityId entity,
    required int currentTick,
    required int cooldownGroupId,
    required int manaCost100,
    required int staminaCost100,
  }) {
    if (world.controlLock.isStunned(entity, currentTick)) {
      return AbilityGateFail.stunned;
    }
    if (world.cooldown.isOnCooldown(entity, cooldownGroupId)) {
      return AbilityGateFail.onCooldown;
    }

    if (manaCost100 > 0) {
      final mi = world.mana.tryIndexOf(entity);
      if (mi == null) return AbilityGateFail.missingMana;
      if (world.mana.mana[mi] < manaCost100) {
        return AbilityGateFail.insufficientMana;
      }
    }

    if (staminaCost100 > 0) {
      final si = world.stamina.tryIndexOf(entity);
      if (si == null) return AbilityGateFail.missingStamina;
      if (world.stamina.stamina[si] < staminaCost100) {
        return AbilityGateFail.insufficientStamina;
      }
    }

    return null;
  }

  static AbilityGateFail? canCommitMobility(
    EcsWorld world, {
    required EntityId entity,
    required int currentTick,
    required int cooldownGroupId,
    required int staminaCost100,
  }) {
    if (world.controlLock.isStunned(entity, currentTick)) {
      return AbilityGateFail.stunned;
    }

    final mi = world.movement.tryIndexOf(entity);
    if (mi == null) return AbilityGateFail.missingMovement;

    final bi = world.body.tryIndexOf(entity);
    if (bi == null) return AbilityGateFail.missingBody;

    if (!world.body.enabled[bi] || world.body.isKinematic[bi]) {
      return AbilityGateFail.bodyDisabledOrKinematic;
    }

    if (world.movement.dashTicksLeft[mi] > 0) {
      return AbilityGateFail.dashAlreadyActive;
    }

    if (world.cooldown.isOnCooldown(entity, cooldownGroupId)) {
      return AbilityGateFail.onCooldown;
    }

    // Mobility cannot start while aiming (existing behavior from MobilitySystem commit block).
    final ii = world.playerInput.tryIndexOf(entity);
    if (ii != null) {
      final aimHeld =
          (world.playerInput.projectileAimDirX[ii].abs() > 1e-6) ||
          (world.playerInput.projectileAimDirY[ii].abs() > 1e-6) ||
          (world.playerInput.meleeAimDirX[ii].abs() > 1e-6) ||
          (world.playerInput.meleeAimDirY[ii].abs() > 1e-6);
      if (aimHeld) return AbilityGateFail.aimingHeld;
    }

    if (staminaCost100 > 0) {
      final si = world.stamina.tryIndexOf(entity);
      if (si == null) return AbilityGateFail.missingStamina;
      if (world.stamina.stamina[si] < staminaCost100) {
        return AbilityGateFail.insufficientStamina;
      }
    }

    return null;
  }
}
