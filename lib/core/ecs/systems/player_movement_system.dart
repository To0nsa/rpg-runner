import '../../snapshots/enums.dart';
import '../../tuning/player/player_movement_tuning.dart';
import '../../tuning/player/player_resource_tuning.dart';
import '../../util/velocity_math.dart';
import '../entity_id.dart';
import '../queries.dart';
import '../world.dart';

/// Applies platformer-style movement for entities with:
/// - Transform
/// - PlayerInput
/// - Movement
/// - Body
///
/// PlayerMovementSystem writes velocities only (input/jump/dash/gravity/clamps).
/// Position integration and collision resolution are handled by CollisionSystem.
///
/// **Responsibilities**:
/// *   Update movement state timers (Dash cooldown, Coyote time, Jump buffer).
/// *   Process Input (Dash request, Jump request, Horizontal move).
/// *   Apply velocities based on state.
class PlayerMovementSystem {
  void step(
    EcsWorld world,
    MovementTuningDerived tuning, {
    required ResourceTuning resources,
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

      // -- Timers --
      // Decrement state timers. These track cooldowns and temporary states (dash, buffers).
      if (world.movement.dashCooldownTicksLeft[mi] > 0) {
        world.movement.dashCooldownTicksLeft[mi] -= 1;
      }
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
      // Buffer a jump request if pressed this frame.
      // This allows a jump input slightly BEFORE landing to still register as a jump upon landing.
      if (world.playerInput.jumpPressed[ii]) {
        world.movement.jumpBufferTicksLeft[mi] = tuning.jumpBufferTicks;
      }

      // -- Dash Logic --
      // Attempt to start a dash if requested.
      // Dash is an atomic action that overrides normal movement.
      if (world.playerInput.dashPressed[ii]) {
        _tryStartDash(
          world,
          entity: e,
          mi: mi,
          ti: ti,
          ii: ii,
          si: si,
          tuning: tuning,
          staminaCost: resources.dashStaminaCost,
        );
      }

      final dashing = world.movement.dashTicksLeft[mi] > 0;
      final modifierIndex = world.statModifier.tryIndexOf(e);
      final moveSpeedMul =
          modifierIndex == null ? 1.0 : world.statModifier.moveSpeedMul[modifierIndex];

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
        if (axis != 0) {
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
          if (world.stamina.stamina[si] >= resources.jumpStaminaCost) {
            world.stamina.stamina[si] -= resources.jumpStaminaCost;

            // Apply instantaneous upward velocity.
            world.transform.velY[ti] = -t.jumpSpeed;
            
            // Consume the buffer and coyote time immediately to prevent double-jumping
            // in the same window.
            world.movement.jumpBufferTicksLeft[mi] = 0;
            world.movement.coyoteTicksLeft[mi] = 0;
          }
        }
      }

      // -- Limits --
      // Soft cap on horizontal velocity to prevent runaway speeds from external forces.
      world.transform.velX[ti] = world.transform.velX[ti]
          .clamp(-world.body.maxVelX[bi], world.body.maxVelX[bi]);
    });
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

  /// Attempts to initiate a dash action.
  ///
  /// **Logic**:
  /// 1.  **Checks**: Must not be Dashing, Cooldown active, or Insufficient Stamina.
  /// 2.  **Direction**: Prioritizes raw input [axis]. If neutral, uses current [facing].
  /// 3.  **Physics**: Cancels vertical velocity and suppresses gravity for duration.
  /// 4.  **State**: Sets cooldowns and consumes stamina.
  void _tryStartDash(
    EcsWorld world, {
    required EntityId entity,
    required int mi,
    required int ti,
    required int ii,
    required int si,
    required MovementTuningDerived tuning,
    required double staminaCost,
  }) {
    if (world.movement.dashTicksLeft[mi] > 0) return;
    if (world.movement.dashCooldownTicksLeft[mi] > 0) return;
    if (world.stamina.stamina[si] < staminaCost) return;

    // Determine Dash Direction:
    // - If holding direction: Dash that way.
    // - If neutral: Dash forward (current facing).
    final axis = world.playerInput.moveAxis[ii];
    final dirX = axis != 0
        ? (axis > 0 ? 1.0 : -1.0)
        : (world.movement.facing[mi] == Facing.right ? 1.0 : -1.0);

    world.movement.dashDirX[mi] = dirX;
    world.movement.facing[mi] = dirX > 0 ? Facing.right : Facing.left;

    world.movement.dashTicksLeft[mi] = tuning.dashDurationTicks;
    world.movement.dashCooldownTicksLeft[mi] = tuning.dashCooldownTicks;

    // Cancel vertical motion so dash doesn't inherit jump/fall.
    // Suppress gravity to ensure linear horizontal movement.
    world.transform.velY[ti] = 0;
    world.gravityControl.setSuppressForTicks(entity, tuning.dashDurationTicks);

    world.stamina.stamina[si] -= staminaCost;
  }
}
