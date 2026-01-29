import '../../abilities/ability_def.dart';
import '../../snapshots/enums.dart';
import '../../players/player_tuning.dart';
import '../stores/mobility_intent_store.dart';
import '../world.dart';

/// Executes mobility intents (dash/roll) and applies movement state.
///
/// Responsibilities:
/// - Validate cooldown/stamina/locks at commit.
/// - Start cooldown + ActiveAbility state on commit.
/// - Apply dash movement and gravity suppression on execute tick.
class MobilitySystem {
  void step(
    EcsWorld world,
    MovementTuningDerived tuning, {
    required int currentTick,
  }) {
    final intents = world.mobilityIntent;
    if (intents.denseEntities.isEmpty) return;

    final movements = world.movement;
    final transforms = world.transform;
    final bodies = world.body;
    final staminas = world.stamina;
    final inputs = world.playerInput;

    final count = intents.denseEntities.length;
    for (var ii = 0; ii < count; ii += 1) {
      final entity = intents.denseEntities[ii];
      if (intents.slot[ii] == AbilitySlot.jump) {
        continue;
      }
      final commitTick = intents.commitTick[ii];
      final executeTick = intents.tick[ii];

      if (commitTick == currentTick) {
        if (world.controlLock.isStunned(entity, currentTick)) {
          _invalidateIntent(intents, ii);
          continue;
        }

        final mi = movements.tryIndexOf(entity);
        final bi = bodies.tryIndexOf(entity);
        if (mi == null || bi == null) {
          _invalidateIntent(intents, ii);
          continue;
        }
        if (!bodies.enabled[bi] || bodies.isKinematic[bi]) {
          _invalidateIntent(intents, ii);
          continue;
        }
        if (movements.dashTicksLeft[mi] > 0) {
          _invalidateIntent(intents, ii);
          continue;
        }
        // Check mobility cooldown from CooldownStore using intent group.
        final cooldownGroup = intents.cooldownGroupId[ii];
        if (world.cooldown.isOnCooldown(entity, cooldownGroup)) {
          _invalidateIntent(intents, ii);
          continue;
        }

        final iiInput = inputs.tryIndexOf(entity);
        if (iiInput != null) {
          // Mobility cannot start while aiming (must release aim first).
          final aimHeld =
              (inputs.projectileAimDirX[iiInput].abs() > 1e-6) ||
              (inputs.projectileAimDirY[iiInput].abs() > 1e-6) ||
              (inputs.meleeAimDirX[iiInput].abs() > 1e-6) ||
              (inputs.meleeAimDirY[iiInput].abs() > 1e-6);
          if (aimHeld) {
            _invalidateIntent(intents, ii);
            continue;
          }
        }

        final staminaCost = intents.staminaCost100[ii];
        if (staminaCost > 0) {
          final si = staminas.tryIndexOf(entity);
          if (si == null) {
            _invalidateIntent(intents, ii);
            continue;
          }
          if (staminas.stamina[si] < staminaCost) {
            _invalidateIntent(intents, ii);
            continue;
          }
          staminas.stamina[si] -= staminaCost;
        }

        // Start mobility cooldown in CooldownStore.
        world.cooldown.startCooldown(
          entity,
          cooldownGroup,
          intents.cooldownTicks[ii],
        );

        final dirX = intents.dirX[ii];
        final facing = dirX >= 0 ? Facing.right : Facing.left;
        movements.facing[mi] = facing;

        world.activeAbility.set(
          entity,
          id: intents.abilityId[ii],
          slot: intents.slot[ii],
          commitTick: currentTick,
          windupTicks: intents.windupTicks[ii],
          activeTicks: intents.activeTicks[ii],
          recoveryTicks: intents.recoveryTicks[ii],
          facingDir: facing,
        );

        _cancelCombatIntents(world, entity);
      }

      if (executeTick != currentTick) continue;

      _invalidateIntent(intents, ii);

      final mi = movements.tryIndexOf(entity);
      final ti = transforms.tryIndexOf(entity);
      final bi = bodies.tryIndexOf(entity);
      if (mi == null || ti == null || bi == null) continue;
      if (!bodies.enabled[bi] || bodies.isKinematic[bi]) continue;

      final activeTicks = intents.activeTicks[ii];
      if (activeTicks <= 0) continue;

      final modifierIndex = world.statModifier.tryIndexOf(entity);
      final moveSpeedMul = modifierIndex == null
          ? 1.0
          : world.statModifier.moveSpeedMul[modifierIndex];

      final dirX = intents.dirX[ii];
      movements.dashDirX[mi] = dirX;
      movements.dashTicksLeft[mi] = activeTicks;
      movements.facing[mi] = dirX >= 0 ? Facing.right : Facing.left;

      // Cancel vertical motion and suppress gravity to keep dash horizontal.
      transforms.velY[ti] = 0;
      transforms.velX[ti] = dirX * tuning.base.dashSpeedX * moveSpeedMul;
      world.gravityControl.setSuppressForTicks(entity, activeTicks);
    }
  }

  void _invalidateIntent(MobilityIntentStore intents, int index) {
    intents.tick[index] = -1;
    intents.commitTick[index] = -1;
  }

  void _cancelCombatIntents(EcsWorld world, int entity) {
    if (world.meleeIntent.has(entity)) {
      final i = world.meleeIntent.indexOf(entity);
      world.meleeIntent.tick[i] = -1;
      world.meleeIntent.commitTick[i] = -1;
    }
    if (world.projectileIntent.has(entity)) {
      final i = world.projectileIntent.indexOf(entity);
      world.projectileIntent.tick[i] = -1;
      world.projectileIntent.commitTick[i] = -1;
    }
    if (world.selfIntent.has(entity)) {
      final i = world.selfIntent.indexOf(entity);
      world.selfIntent.tick[i] = -1;
      world.selfIntent.commitTick[i] = -1;
    }
  }
}
