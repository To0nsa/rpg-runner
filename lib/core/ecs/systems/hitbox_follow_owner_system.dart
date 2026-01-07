import '../world.dart';

/// Synchronizes the position of hitbox entities with their owners.
///
/// **Responsibilities**:
/// *   Iterate over all active hitboxes (entities with `HitboxStore`).
/// *   Retrieve the owner's current position.
/// *   Apply the hitbox's local offset (defined at spawn).
/// *   Update the hitbox's `Transform` component to match the calculated world position.
///
/// **Usage Note**:
/// This system ensures that a sword swing or projectile hitbox moves *with* the
/// character/projectile effectively. It runs every tick to prevent "hitbox drift".
class HitboxFollowOwnerSystem {
  /// Executes the synchronization logic.
  void step(EcsWorld world) {
    final hitboxes = world.hitbox;
    // Early exit if no hitboxes exist.
    if (hitboxes.denseEntities.isEmpty) return;

    for (var hi = 0; hi < hitboxes.denseEntities.length; hi += 1) {
      final hitbox = hitboxes.denseEntities[hi];
      
      // Safety: The hitbox entity itself must have a Transform component to be positioned.
      if (!world.transform.has(hitbox)) continue;

      final owner = hitboxes.owner[hi];
      
      // If the owner has been destroyed or lacks a transform,
      // we cannot position the hitbox relative to it.
      final ownerTi = world.transform.tryIndexOf(owner);
      if (ownerTi == null) continue;

      // Calculate world position: Owner Position + Local Offset.
      final x = world.transform.posX[ownerTi] + hitboxes.offsetX[hi];
      final y = world.transform.posY[ownerTi] + hitboxes.offsetY[hi];

      // specific Snap behavior: We overwrite the position completely.
      // Physics forces are not applied here; it's a hard attachment.
      world.transform.setPosXY(hitbox, x, y);
    }
  }
}

