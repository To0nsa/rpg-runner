import '../entity_id.dart';
import '../world.dart';

/// Despawns physics-driven projectiles that collided with the static world.
///
/// This is intended for ballistic projectiles (arrows, thrown axes) that use
/// [BodyStore] + [CollisionSystem] for ground/wall collision. When a collision
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

