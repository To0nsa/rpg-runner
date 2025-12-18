import '../../snapshots/enums.dart';
import '../../tuning/v0_movement_tuning.dart';
import '../entity_id.dart';
import '../world.dart';

/// Applies platformer-style movement for entities with:
/// - Transform
/// - PlayerInput
/// - Movement
/// - Body
///
/// MovementSystem writes velocities only (input/jump/dash/gravity/clamps).
/// Position integration and collision resolution are handled by CollisionSystem.
class MovementSystem {
  void step(EcsWorld world, V0MovementTuningDerived tuning) {
    final dt = tuning.dtSeconds;
    final t = tuning.base;

    // Iterate movement entities; this stays allocation-free and cache-friendly.
    for (var mi = 0; mi < world.movement.denseEntities.length; mi += 1) {
      final EntityId e = world.movement.denseEntities[mi];
      if (!world.transform.has(e) ||
          !world.playerInput.has(e) ||
          !world.body.has(e) ||
          !world.collision.has(e)) {
        continue;
      }

      final ti = world.transform.indexOf(e);
      final ii = world.playerInput.indexOf(e);
      final bi = world.body.indexOf(e);
      final ci = world.collision.indexOf(e);

      if (!world.body.enabled[bi]) continue;
      if (world.body.isKinematic[bi]) {
        continue;
      }

      // Timers.
      if (world.movement.dashCooldownTicksLeft[mi] > 0) {
        world.movement.dashCooldownTicksLeft[mi] -= 1;
      }
      if (world.movement.dashTicksLeft[mi] > 0) {
        world.movement.dashTicksLeft[mi] -= 1;
      }
      if (world.movement.jumpBufferTicksLeft[mi] > 0) {
        world.movement.jumpBufferTicksLeft[mi] -= 1;
      }

      final wasGrounded = world.collision.grounded[ci];
      if (wasGrounded) {
        world.movement.coyoteTicksLeft[mi] = tuning.coyoteTicks;
      } else if (world.movement.coyoteTicksLeft[mi] > 0) {
        world.movement.coyoteTicksLeft[mi] -= 1;
      }

      // Buffer jump on edge-triggered press.
      if (world.playerInput.jumpPressed[ii]) {
        world.movement.jumpBufferTicksLeft[mi] = tuning.jumpBufferTicks;
      }

      // Dash request.
      if (world.playerInput.dashPressed[ii]) {
        _tryStartDash(world, mi: mi, ti: ti, ii: ii, tuning: tuning);
      }

      final dashing = world.movement.dashTicksLeft[mi] > 0;

      if (dashing) {
        world.transform.velX[ti] = world.movement.dashDirX[mi] * t.dashSpeedX;
        world.transform.velY[ti] = 0;
      } else {
        world.transform.velX[ti] = _applyHorizontalMove(
          world.transform.velX[ti],
          world.playerInput.moveAxis[ii],
          dt,
          tuning,
        );

        // Jump attempt before gravity (to match the previous behavior).
        if (world.movement.jumpBufferTicksLeft[mi] > 0 &&
            (wasGrounded || world.movement.coyoteTicksLeft[mi] > 0)) {
          world.transform.velY[ti] = -t.jumpSpeed;
          world.movement.jumpBufferTicksLeft[mi] = 0;
          world.movement.coyoteTicksLeft[mi] = 0;
        }

        // Gravity.
        if (world.body.useGravity[bi]) {
          final scaledGravity = t.gravityY * world.body.gravityScale[bi];
          world.transform.velY[ti] += scaledGravity * dt;
        }
      }

      // Clamp speeds.
      world.transform.velX[ti] = world.transform.velX[ti]
          .clamp(-world.body.maxVelX[bi], world.body.maxVelX[bi])
          .toDouble();
      world.transform.velY[ti] = world.transform.velY[ti]
          .clamp(-world.body.maxVelY[bi], world.body.maxVelY[bi])
          .toDouble();
    }
  }

  double _applyHorizontalMove(
    double velocityX,
    double axis,
    double dt,
    V0MovementTuningDerived tuning,
  ) {
    final t = tuning.base;
    if (axis != 0) {
      final desiredX = axis * t.maxSpeedX;
      final deltaX = desiredX - velocityX;
      final maxDelta = t.accelerationX * dt;
      if (deltaX.abs() > maxDelta) {
        return velocityX + (deltaX > 0 ? maxDelta : -maxDelta);
      }
      return desiredX;
    }

    final speedX = velocityX.abs();
    if (speedX <= 0) return 0;
    final drop = t.decelerationX * dt;
    if (speedX <= drop || speedX <= t.minMoveSpeed) {
      return 0;
    }
    return velocityX + (velocityX > 0 ? -drop : drop);
  }

  void _tryStartDash(
    EcsWorld world, {
    required int mi,
    required int ti,
    required int ii,
    required V0MovementTuningDerived tuning,
  }) {
    if (world.movement.dashTicksLeft[mi] > 0) return;
    if (world.movement.dashCooldownTicksLeft[mi] > 0) return;

    final axis = world.playerInput.moveAxis[ii];
    final dirX = axis != 0
        ? (axis > 0 ? 1.0 : -1.0)
        : (world.movement.facing[mi] == Facing.right ? 1.0 : -1.0);

    world.movement.dashDirX[mi] = dirX;
    world.movement.facing[mi] = dirX > 0 ? Facing.right : Facing.left;

    world.movement.dashTicksLeft[mi] = tuning.dashDurationTicks;
    world.movement.dashCooldownTicksLeft[mi] = tuning.dashCooldownTicks;

    // Cancel vertical motion so dash doesn't inherit jump/fall.
    world.transform.velY[ti] = 0;
  }
}
