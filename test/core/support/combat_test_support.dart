import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';
import 'package:runner_core/ecs/world.dart';

/// Completes synthetic damageable actors with the runtime capsule derived from
/// their authored AABB. Production actors receive the equivalent catalog
/// capsule from terrain-authority initialization before broad-phase rebuild.
void attachMissingCombatCapsules(EcsWorld world) {
  for (final entity in world.health.denseEntities) {
    if (world.worldContactCapsule.has(entity)) continue;
    final colliderIndex = world.colliderAabb.tryIndexOf(entity);
    if (colliderIndex == null) continue;
    world.worldContactCapsule.add(
      entity,
      WorldContactCapsuleDef.fromAabb(
        ColliderAabbDef(
          halfX: world.colliderAabb.halfX[colliderIndex],
          halfY: world.colliderAabb.halfY[colliderIndex],
          offsetX: world.colliderAabb.offsetX[colliderIndex],
          offsetY: world.colliderAabb.offsetY[colliderIndex],
        ),
      ),
    );
  }
}
