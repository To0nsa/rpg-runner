import '../../contracts/v0_render_contract.dart';
import '../../tuning/v0_movement_tuning.dart';
import '../entity_id.dart';
import '../world.dart';

/// Integrates positions and resolves collisions (V0: ground band only).
///
/// Order within a tick:
/// - MovementSystem computes velocities (including gravity, jump/dash).
/// - CollisionSystem integrates `pos += vel * dt`, resolves collisions, and
///   finalizes grounded/contact state for the tick.
class CollisionSystem {
  void step(EcsWorld world, V0MovementTuningDerived tuning) {
    final dt = tuning.dtSeconds;

    // Iterate colliders as the collision "query" for V0.
    for (var ci = 0; ci < world.colliderAabb.denseEntities.length; ci += 1) {
      final EntityId e = world.colliderAabb.denseEntities[ci];
      if (!world.transform.has(e) || !world.body.has(e) || !world.collision.has(e)) {
        continue;
      }

      final ti = world.transform.indexOf(e);
      final bi = world.body.indexOf(e);
      final coli = world.collision.indexOf(e);
      final aabbi = world.colliderAabb.indexOf(e);

      if (!world.body.enabled[bi]) continue;

      // Kinematic bodies are excluded from physics integration/resolution.
      if (world.body.isKinematic[bi]) {
        world.collision.grounded[coli] = false;
        final mi = world.movement.tryIndexOf(e);
        if (mi != null) world.movement.grounded[mi] = false;
        continue;
      }

      // Reset per-tick collision results.
      world.collision.grounded[coli] = false;
      world.collision.hitCeiling[coli] = false;
      world.collision.hitLeft[coli] = false;
      world.collision.hitRight[coli] = false;

      final mi = world.movement.tryIndexOf(e);
      if (mi != null) world.movement.grounded[mi] = false;

      // Integrate position from the current velocity.
      world.transform.posX[ti] += world.transform.velX[ti] * dt;
      world.transform.posY[ti] += world.transform.velY[ti] * dt;

      // V0 ground collision:
      // Treat the ground band as an infinite solid with a top at `v0GroundTopY`.
      final bottom =
          world.transform.posY[ti] + world.colliderAabb.offsetY[aabbi] + world.colliderAabb.halfY[aabbi];
      if (bottom > v0GroundTopY) {
        world.transform.posY[ti] =
            v0GroundTopY - world.colliderAabb.offsetY[aabbi] - world.colliderAabb.halfY[aabbi];
        if (world.transform.velY[ti] > 0) {
          world.transform.velY[ti] = 0;
        }
        world.collision.grounded[coli] = true;
        if (mi != null) world.movement.grounded[mi] = true;
      }
    }
  }
}

