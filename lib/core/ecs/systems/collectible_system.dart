import '../hit/aabb_hit_utils.dart';
import '../entity_id.dart';
import '../world.dart';
import '../../tuning/collectible_tuning.dart';

/// System responsible for updating collectible entities (e.g. coins).
///
/// It handles:
/// 1. Despawning collectibles that have fallen behind the camera.
/// 2. Detecting collisions between the player and collectibles.
/// 3. Triggering collection callbacks and destroying collected entities.
class CollectibleSystem {
  // Recycled list to avoid per-frame allocations for destruction.
  final List<EntityId> _toDespawn = <EntityId>[];

  /// Updates all collectibles.
  ///
  /// [cameraLeft] is the world-space X coordinate of the left edge of the camera,
  /// used for culling entities that are no longer visible.
  void step(
    EcsWorld world, {
    required EntityId player,
    required double cameraLeft,
    required CollectibleTuning tuning,
    required void Function(int value) onCollected,
  }) {
    final collectibles = world.collectible;
    if (collectibles.denseEntities.isEmpty) return;

    // Pre-resolve player components to avoid looking them up for every collectible.
    final playerTi = world.transform.tryIndexOf(player);
    final playerAi = world.colliderAabb.tryIndexOf(player);
    final canCollect = playerTi != null && playerAi != null;

    _toDespawn.clear();

    final despawnLimit = cameraLeft - tuning.despawnBehindCameraMargin;
    for (var ci = 0; ci < collectibles.denseEntities.length; ci += 1) {
      final e = collectibles.denseEntities[ci];
      final ti = world.transform.tryIndexOf(e);
      final ai = world.colliderAabb.tryIndexOf(e);
      // Skip if entity is missing required components (malformed entity).
      if (ti == null || ai == null) continue;

      final centerX = world.transform.posX[ti] + world.colliderAabb.offsetX[ai];
      
      // 1. Culling: Despawn if far behind the camera.
      if (centerX < despawnLimit) {
        _toDespawn.add(e);
        continue;
      }

      // 2. Collection: Check AABB overlap with player.
      if (canCollect) {
        final overlaps = aabbOverlapsWorldColliders(
          world,
          aTransformIndex: ti,
          aAabbIndex: ai,
          bTransformIndex: playerTi,
          bAabbIndex: playerAi,
        );
        if (overlaps) {
          onCollected(collectibles.value[ci]);
          _toDespawn.add(e);
        }
      }
    }

    // Apply deferred destruction.
    for (final e in _toDespawn) {
      world.destroyEntity(e);
    }
  }
}
