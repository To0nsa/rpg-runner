import '../ecs/entity_id.dart';
import '../ecs/stores/body_store.dart';
import '../ecs/stores/collider_aabb_store.dart';
import '../ecs/stores/lifetime_store.dart';
import '../ecs/stores/projectile_store.dart';
import '../ecs/world.dart';

/// Registers a projectile for shared motion, swept hits and bounded cleanup.
///
/// Positions and collider dimensions are world pixels; lifetime is in ticks.
/// [projectile] must contain a normalized launch direction. Physics projectiles
/// receive initial velocity, gravity and terrain collision state; straight
/// projectiles remain driven by ProjectileSystem. Gravity scale multiplies the
/// level's acceleration and does not change the projectile's launch speed.
EntityId spawnProjectile(
  EcsWorld world, {
  required ProjectileEntityDef projectile,
  required double x,
  required double y,
  required ColliderAabbDef collider,
  required int lifetimeTicks,
  double gravityScale = 1,
}) {
  final entity = world.createEntity();
  world.transform.add(
    entity,
    posX: x,
    posY: y,
    velX: projectile.usePhysics
        ? projectile.dirX * projectile.speedUnitsPerSecond
        : 0,
    velY: projectile.usePhysics
        ? projectile.dirY * projectile.speedUnitsPerSecond
        : 0,
  );
  world.projectile.add(entity, projectile);
  world.hitOnce.add(entity);
  world.colliderAabb.add(entity, collider);
  world.lifetime.add(entity, LifetimeDef(ticksLeft: lifetimeTicks));
  if (projectile.usePhysics) {
    world.body.add(
      entity,
      BodyDef(
        gravityScale: gravityScale,
        sideMask: BodyDef.sideLeft | BodyDef.sideRight,
      ),
    );
    world.collision.add(entity);
  }
  return entity;
}
