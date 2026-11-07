import '../entity_id.dart';
import '../world.dart';

/// Despawns physics-driven projectiles that collided with the static world.
///
/// This is intended for ballistic projectiles (arrows, thrown axes) that use
/// [BodyStore] + terrain motion for ground/wall collision. When a collision
/// occurs, the projectile is removed immediately (same tick).
class ProjectileWorldCollisionSystem {
  final List<EntityId> _toDespawn = <EntityId>[];

  void step(EcsWorld world) {
    final projectiles = world.projectile;
    if (projectiles.denseEntities.isEmpty) return;

    final collisions = world.collision;
    if (collisions.denseEntities.isEmpty) return;

    _toDespawn.clear();
    for (var pi = 0; pi < projectiles.denseEntities.length; pi += 1) {
      if (!projectiles.usePhysics[pi]) continue;

      final p = projectiles.denseEntities[pi];
      final ci = collisions.tryIndexOf(p);
      if (ci == null) continue;

      if (world.bomb.has(p)) {
        if (collisions.grounded[ci]) {
          // Land without bouncing or detonation; the fuse continues independently.
          final ti = world.transform.indexOf(p);
          world.transform.velX[ti] = 0;
          world.transform.velY[ti] = 0;
          world.body.enabled[world.body.indexOf(p)] = false;
        }
        continue;
      }

      if (collisions.grounded[ci] ||
          collisions.hitCeiling[ci] ||
          collisions.hitLeft[ci] ||
          collisions.hitRight[ci]) {
        _toDespawn.add(p);
      }
    }

    for (final p in _toDespawn) {
      world.destroyEntity(p);
    }
  }
}
