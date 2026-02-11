import '../ecs/entity_id.dart';
import '../ecs/world.dart';

/// Reason why an ability commit was rejected by [AbilityGate].
enum AbilityGateFail {
  /// Entity is currently stun-locked.
  stunned,

  /// Cooldown group still has remaining ticks.
  onCooldown,

  /// Required mana resource store is missing.
  missingMana,

  /// Available mana is below requested cost.
  insufficientMana,

  /// Required stamina resource store is missing.
  missingStamina,

  /// Available stamina is below requested cost.
  insufficientStamina,

  // Mobility-only
  /// Mobility requires [MovementStore], but entity has none.
  missingMovement,

  /// Mobility requires [BodyStore], but entity has none.
  missingBody,

  /// Mobility cannot commit with disabled or kinematic bodies.
  bodyDisabledOrKinematic,

  /// Dash already active; disallow overlapping mobility commits.
  dashAlreadyActive,

  /// Mobility is blocked while player is actively holding an aim vector.
  aimingHeld,
}

/// Static guard helpers used before creating ability intents.
///
/// These checks are deterministic and side-effect free. Callers can use the
/// returned failure reason for telemetry or UI messaging.
abstract class AbilityGate {
  /// Returns `null` when combat ability commit is allowed, otherwise a reason.
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
    // Cooldown is checked before resource costs so failures report "on cooldown"
    // consistently when both constraints are true.
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

  /// Returns `null` when mobility ability commit is allowed, otherwise a reason.
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

    // Mobility cannot start while aim is held. This preserves
    // existing input semantics where dash/roll commits require a neutral aim.
    final ii = world.playerInput.tryIndexOf(entity);
    if (ii != null) {
      final aimHeld =
          (world.playerInput.aimDirX[ii].abs() > 1e-6) ||
          (world.playerInput.aimDirY[ii].abs() > 1e-6);
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
