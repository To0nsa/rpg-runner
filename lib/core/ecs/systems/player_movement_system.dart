import '../../abilities/ability_def.dart';
import '../../stats/character_stats_resolver.dart';
import '../../snapshots/enums.dart';
import '../../players/player_tuning.dart';
import '../../util/velocity_math.dart';
import '../queries.dart';
import '../world.dart';

/// Applies platformer-style movement for entities with:
/// - Transform
/// - PlayerInput
/// - Movement
/// - Body
///
/// PlayerMovementSystem writes velocities only (input/jump/dash state/gravity/clamps).
/// Dash initiation is handled by [MobilitySystem].
/// Position integration and collision resolution are handled by CollisionSystem.
///
/// **Responsibilities**:
/// *   Update movement state timers (Dash cooldown, Coyote time, Jump buffer).
/// *   Process Input (Jump request, Horizontal move).
/// *   Apply velocities based on state.
class PlayerMovementSystem {
  PlayerMovementSystem({
    CharacterStatsResolver statsResolver = const CharacterStatsResolver(),
  }) : _statsResolver = statsResolver;

  final CharacterStatsResolver _statsResolver;

  void step(
    EcsWorld world,
    MovementTuningDerived tuning, {
    required ResourceTuningDerived resources,
    required int currentTick,
  }) {
    final dt = tuning.dtSeconds;
    final t = tuning.base;

    // Iterate over all controllable entities (Join: Movement + Input + Body +...).
    // Uses EcsQueries to efficiently fetch entities with all required components.
    EcsQueries.forMovementBodies(world, (e, mi, ti, ii, bi, ci, si) {
      if (!world.body.enabled[bi]) return;

      // Kinematic bodies are moved by scripts/physics directly, not by player input.
      if (world.body.isKinematic[bi]) {
        return;
      }

      // -- Stun Check --
      // If stunned, Zero horizontal velocity and skip input input processing.
      // Vertical velocity (gravity) continues to apply normally (falling).
      if (world.controlLock.isStunned(e, currentTick)) {
        // Cancel dash if active (so we don't float)
        if (world.movement.dashTicksLeft[mi] > 0) {
          world.movement.dashTicksLeft[mi] = 0;
          // Restore gravity if it was suppressed by dash
          if (world.gravityControl.suppressGravityTicksLeft[world.gravityControl
                  .indexOf(e)] >
              0) {
            world.gravityControl.suppressGravityTicksLeft[world.gravityControl
                    .indexOf(e)] =
                0;
          }
        }
        world.transform.velX[ti] = 0;
        return;
      }

      // -- Timers --
      // Decrement state timers. These track cooldowns and temporary states (dash, buffers).

      if (world.movement.dashTicksLeft[mi] > 0) {
        world.movement.dashTicksLeft[mi] -= 1;
      }
      if (world.movement.jumpBufferTicksLeft[mi] > 0) {
        world.movement.jumpBufferTicksLeft[mi] -= 1;
      }

      // -- Coyote Time --
      // "Coyote Time" allows the player to jump for a few frames after walking off a ledge.
      // - If currently grounded (from CollisionSystem last frame), reset the timer to full.
      // - If in air, decrement the timer.
      final wasGrounded = world.collision.grounded[ci];
      if (wasGrounded) {
        world.movement.coyoteTicksLeft[mi] = tuning.coyoteTicks;
      } else if (world.movement.coyoteTicksLeft[mi] > 0) {
        world.movement.coyoteTicksLeft[mi] -= 1;
      }

      // -- Input Buffering --
      // Buffer a jump request coming from the ability pipeline.
      final jumpIntentIndex = world.mobilityIntent.tryIndexOf(e);
      final hasJumpIntent =
          jumpIntentIndex != null &&
          world.mobilityIntent.slot[jumpIntentIndex] == AbilitySlot.jump;
      if (hasJumpIntent &&
          world.mobilityIntent.commitTick[jumpIntentIndex] == currentTick) {
        // Jump pressed this tick: prime the buffer.
        world.movement.jumpBufferTicksLeft[mi] = tuning.jumpBufferTicks;
      }

      final dashing = world.movement.dashTicksLeft[mi] > 0;
      final gearMoveSpeedMul = _gearMoveSpeedMultiplier(world, e);
      final modifierIndex = world.statModifier.tryIndexOf(e);
      final statusMoveSpeedMul = modifierIndex == null
          ? 1.0
          : world.statModifier.moveSpeedMul[modifierIndex];
      final moveSpeedMul = gearMoveSpeedMul * statusMoveSpeedMul;

      if (world.movement.facingLockTicksLeft[mi] > 0) {
        world.movement.facingLockTicksLeft[mi] -= 1;
      }

      // -- Horizontal Movement --
      if (dashing) {
        // [State: Dashing]
        // Lock velocity to the dash direction and speed.
        // Zero out Y velocity to prevent gravity from affecting the dash arc (linear dash).
        world.transform.velX[ti] =
            world.movement.dashDirX[mi] * t.dashSpeedX * moveSpeedMul;
        world.transform.velY[ti] = 0;
      } else {
        // [State: Normal Control]
        final axis = world.playerInput.moveAxis[ii];

        // Visuals: Update facing direction based on input.
        // This is decoupled from velocity to allow "turning" animations before velocity flips.
        if (world.movement.facingLockTicksLeft[mi] == 0 && axis != 0) {
          world.movement.facing[mi] = axis > 0 ? Facing.right : Facing.left;
        }

        // Apply horizontal acceleration/deceleration.
        world.transform.velX[ti] = _applyHorizontalMove(
          world.transform.velX[ti],
          axis,
          dt,
          tuning,
          moveSpeedMul,
        );

        // -- Jumping --
        // Execute Jump if:
        // 1. Jump is buffered (Pressed recently).
        // 2. Player can jump (Grounded OR Coyote Time active).
        // 3. Sufficient Stamina.
        if (world.movement.jumpBufferTicksLeft[mi] > 0 &&
            (wasGrounded || world.movement.coyoteTicksLeft[mi] > 0)) {
          final jumpCost = hasJumpIntent
              ? world.mobilityIntent.staminaCost100[jumpIntentIndex]
              : resources.jumpStaminaCost100;
          if (world.stamina.stamina[si] >= jumpCost) {
            // Stamina cost is handled by AbilityActivationSystem at commit time.
            // world.stamina.stamina[si] -= jumpCost;

            // Apply instantaneous upward velocity.
            world.transform.velY[ti] = -t.jumpSpeed;

            // Consume the buffer and coyote time immediately to prevent double-jumping
            // in the same window.
            world.movement.jumpBufferTicksLeft[mi] = 0;
            world.movement.coyoteTicksLeft[mi] = 0;

            if (hasJumpIntent) {
              // Mark the jump intent as consumed and stamp the active ability.
              final intent = world.mobilityIntent;
              intent.tick[jumpIntentIndex] = -1;
              intent.commitTick[jumpIntentIndex] = -1;

              if (world.activeAbility.has(e)) {
                world.activeAbility.set(
                  e,
                  id: intent.abilityId[jumpIntentIndex],
                  slot: intent.slot[jumpIntentIndex],
                  commitTick: currentTick,
                  windupTicks: intent.windupTicks[jumpIntentIndex],
                  activeTicks: intent.activeTicks[jumpIntentIndex],
                  recoveryTicks: intent.recoveryTicks[jumpIntentIndex],
                  facingDir: world.movement.facing[mi],
                );
              }
            }
          }
        }
      }

      // If a jump intent is buffered but expired, clear it.
      if (hasJumpIntent && world.movement.jumpBufferTicksLeft[mi] <= 0) {
        world.mobilityIntent.tick[jumpIntentIndex] = -1;
        world.mobilityIntent.commitTick[jumpIntentIndex] = -1;
      }

      // -- Limits --
      // Soft cap on horizontal velocity to prevent runaway speeds from external forces.
      world.transform.velX[ti] = world.transform.velX[ti].clamp(
        -world.body.maxVelX[bi],
        world.body.maxVelX[bi],
      );
    });
  }

  double _gearMoveSpeedMultiplier(EcsWorld world, int entity) {
    final li = world.equippedLoadout.tryIndexOf(entity);
    if (li == null) return 1.0;
    final loadout = world.equippedLoadout;
    final resolved = _statsResolver.resolveEquipped(
      mask: loadout.mask[li],
      mainWeaponId: loadout.mainWeaponId[li],
      offhandWeaponId: loadout.offhandWeaponId[li],
      projectileItemId: loadout.projectileItemId[li],
      spellBookId: loadout.spellBookId[li],
      accessoryId: loadout.accessoryId[li],
    );
    return resolved.moveSpeedMultiplier;
  }

  /// Calculates the new horizontal velocity using linear acceleration/deceleration.
  ///
  /// Note:
  /// - Uses [t.decelerationX] when `axis == 0` (Stopping).
  /// - Uses [t.accelerationX] for both Speeding Up and Turning (changing direction).
  /// - Snaps to 0 if speed is below [t.minMoveSpeed] and input is 0.
  double _applyHorizontalMove(
    double velocityX,
    double axis,
    double dt,
    MovementTuningDerived tuning,
    double moveSpeedMul,
  ) {
    final t = tuning.base;
    final desiredX = axis == 0.0 ? 0.0 : axis * t.maxSpeedX * moveSpeedMul;
    return applyAccelDecel(
      current: velocityX,
      desired: desiredX,
      dtSeconds: dt,
      accelPerSecond: t.accelerationX * moveSpeedMul,
      decelPerSecond: t.decelerationX * moveSpeedMul,
      minStopSpeed: t.minMoveSpeed,
    );
  }

  // Dash initiation moved to MobilitySystem (ability-driven).
}
