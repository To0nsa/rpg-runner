import '../world.dart';

/// Keeps hitbox entities attached to their owner by applying `HitboxStore` offsets.
///
/// IMPORTANT:
/// - The hitbox position is derived from `owner Transform + Hitbox.offset` every tick.
/// - Spawners should avoid manually computing hitbox world positions to prevent drift.
class HitboxFollowOwnerSystem {
  void step(EcsWorld world) {
    final hitboxes = world.hitbox;
    if (hitboxes.denseEntities.isEmpty) return;

    for (var hi = 0; hi < hitboxes.denseEntities.length; hi += 1) {
      final hitbox = hitboxes.denseEntities[hi];
      if (!world.transform.has(hitbox)) continue;

      final owner = hitboxes.owner[hi];
      if (!world.transform.has(owner)) continue;

      final ownerTi = world.transform.indexOf(owner);
      final x = world.transform.posX[ownerTi] + hitboxes.offsetX[hi];
      final y = world.transform.posY[ownerTi] + hitboxes.offsetY[hi];

      world.transform.setPosXY(hitbox, x, y);
    }
  }
}

