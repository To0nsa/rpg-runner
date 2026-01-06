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

      final gci = world.gravityControl.tryIndexOf(e);
      if (gci != null) {
        final left = world.gravityControl.suppressGravityTicksLeft[gci];
        if (left > 0) {
          final nextLeft = left - 1;
          if (nextLeft <= 0) {
            world.gravityControl.removeEntity(e);
          } else {
            world.gravityControl.suppressGravityTicksLeft[gci] = nextLeft;
          }
          continue;
        } else {
          world.gravityControl.removeEntity(e);
        }
      }

      final scaledGravityY = gravityY * bodies.gravityScale[bi];
      world.transform.velY[ti] += scaledGravityY * dt;

      final maxVelY = bodies.maxVelY[bi];
      world.transform.velY[ti] = world.transform.velY[ti]
          .clamp(-maxVelY, maxVelY)
          .toDouble();
    }
  }
}
