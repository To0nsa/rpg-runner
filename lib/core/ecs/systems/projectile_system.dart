import 'dart:math';

import '../../tuning/player/player_movement_tuning.dart';
import '../world.dart';

/// Moves active projectiles based on their linear velocity.
///
/// **Responsibilities**:
/// - Updates `velX` and `velY` (for use by renderers/interpolation).
/// - Explicitly integrates position: `pos += vel * dt`.
///
/// Note: Projectiles are typically simple kinematic objects that do not participate
/// in the full physics/collision resolution loop (no `Body` component), hence the
/// manual position integration here.
class ProjectileSystem {
  void step(EcsWorld world, MovementTuningDerived movement) {
    final dt = movement.dtSeconds;
    final projectiles = world.projectile;
    final transforms = world.transform;

    // Iterate efficiently over dense projectile arrays.
    final count = projectiles.denseEntities.length;
    for (var pi = 0; pi < count; pi += 1) {
      final e = projectiles.denseEntities[pi];
      
      final ti = transforms.tryIndexOf(e);
      if (ti == null) continue;

      // Physics-driven projectiles (ballistic) are moved by the main physics
      // pipeline (GravitySystem + CollisionSystem). We only keep direction
      // in sync with velocity for hitbox orientation / rendering.
      if (projectiles.usePhysics[pi]) {
        final vx = transforms.velX[ti];
        final vy = transforms.velY[ti];
        final len2 = vx * vx + vy * vy;
        if (len2 > 1e-12) {
          final invLen = 1.0 / sqrt(len2);
          projectiles.dirX[pi] = vx * invLen;
          projectiles.dirY[pi] = vy * invLen;
        }
        continue;
      }

      // Calculate velocity from direction and speed.
      final vx = projectiles.dirX[pi] * projectiles.speedUnitsPerSecond[pi];
      final vy = projectiles.dirY[pi] * projectiles.speedUnitsPerSecond[pi];

      // Update Transform velocity (useful for other systems/debug).
      transforms.velX[ti] = vx;
      transforms.velY[ti] = vy;

      // Explicit Euler integration: pos += vel * dt
      // We do this here because projectiles lack a 'Body' component for simplicity
      // and thus aren't moved by the main physics solver.
      transforms.posX[ti] += vx * dt;
      transforms.posY[ti] += vy * dt;
    }
  }
}
