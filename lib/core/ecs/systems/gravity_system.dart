import '../../tuning/movement_tuning.dart';
import '../../tuning/physics_tuning.dart';
import '../world.dart';

/// Applies gravity to all enabled, non-kinematic bodies that opt into gravity.
///
/// Gravity is applied before collision integration/resolution each tick.
class GravitySystem {
  void step(
    EcsWorld world,
    MovementTuningDerived movement, {
    required PhysicsTuning physics,
  }) {
    final dt = movement.dtSeconds;
    if (dt <= 0.0) return;

    final gravityY = physics.gravityY;
    final bodies = world.body;

    for (var bi = 0; bi < bodies.denseEntities.length; bi += 1) {
      final e = bodies.denseEntities[bi];

      final ti = world.transform.tryIndexOf(e);
      if (ti == null) continue;

      if (!bodies.enabled[bi]) continue;
      if (bodies.isKinematic[bi]) continue;
      if (!bodies.useGravity[bi]) continue;

      // -- Gravity Suppression Logic --
      // Check if gravity is temporarily suppressed for this entity (e.g. during a dash).
      final gci = world.gravityControl.tryIndexOf(e);
      if (gci != null) {
        final ticksLeft = world.gravityControl.suppressGravityTicksLeft[gci];
        
        if (ticksLeft > 0) {
          // Decrement timer.
          final nextTicks = ticksLeft - 1;
          world.gravityControl.suppressGravityTicksLeft[gci] = nextTicks;
          
          // If timer just expired, remove the component so gravity resumes NEXT tick.
          if (nextTicks <= 0) {
            world.gravityControl.removeEntity(e);
          }
          // Skip gravity application for this frame.
          continue;
        } else {
          // Component exists but is stale (0 or negative ticks), remove it and apply gravity immediately.
          world.gravityControl.removeEntity(e);
        }
      }

      // -- Apply Gravity --
      final scaledGravityY = gravityY * bodies.gravityScale[bi];
      world.transform.velY[ti] += scaledGravityY * dt;

      // -- Terminal Velocity --
      final maxVelY = bodies.maxVelY[bi];
      world.transform.velY[ti] = world.transform.velY[ti]
          .clamp(-maxVelY, maxVelY);
    }
  }
}
