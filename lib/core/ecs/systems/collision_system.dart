import '../../contracts/v0_render_contract.dart';
import '../../collision/static_world_geometry.dart';
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
  void step(
    EcsWorld world,
    V0MovementTuningDerived tuning, {
    required StaticWorldGeometry staticWorldGeometry,
  }) {
    final dt = tuning.dtSeconds;
    const eps = 1e-3;

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

      //final prevPosX = world.transform.posX[ti];
      final prevPosY = world.transform.posY[ti];

      // Integrate position from the current velocity.
      world.transform.posX[ti] += world.transform.velX[ti] * dt;
      world.transform.posY[ti] += world.transform.velY[ti] * dt;

      final halfX = world.colliderAabb.halfX[aabbi];
      final halfY = world.colliderAabb.halfY[aabbi];
      final offsetX = world.colliderAabb.offsetX[aabbi];
      final offsetY = world.colliderAabb.offsetY[aabbi];

      //final prevCenterX = prevPosX + offsetX;
      final prevCenterY = prevPosY + offsetY;
      final prevBottom = prevCenterY + halfY;

      final centerX = world.transform.posX[ti] + offsetX;
      final centerY = world.transform.posY[ti] + offsetY;
      final minX = centerX - halfX;
      final maxX = centerX + halfX;
      final bottom = centerY + halfY;

      // Vertical top resolution (one-way platforms): only while moving downward.
      double? bestTopY;
      if (world.transform.velY[ti] > 0) {
        for (final solid in staticWorldGeometry.solids) {
          final overlapX = maxX > solid.minX + eps && minX < solid.maxX - eps;
          if (!overlapX) continue;

          final topY = solid.minY;
          final crossesTop =
              prevBottom <= topY + eps && bottom >= topY - eps;
          if (!crossesTop) continue;

          if (bestTopY == null || topY < bestTopY) {
            bestTopY = topY;
          }
        }
      }

      // Ground is treated as an infinite solid with a top at `v0GroundTopY`.
      // It competes with platforms: if a platform is higher (smaller Y), it
      // should win.
      final groundTopY = v0GroundTopY.toDouble();
      if (world.transform.velY[ti] > 0 &&
          prevBottom <= groundTopY + eps &&
          bottom >= groundTopY - eps) {
        if (bestTopY == null || groundTopY < bestTopY) {
          bestTopY = groundTopY;
        }
      }

      if (bestTopY != null) {
        world.transform.posY[ti] = bestTopY - offsetY - halfY;
        if (world.transform.velY[ti] > 0) {
          world.transform.velY[ti] = 0;
        }
        world.collision.grounded[coli] = true;
        if (mi != null) world.movement.grounded[mi] = true;
      }
    }
  }
}
