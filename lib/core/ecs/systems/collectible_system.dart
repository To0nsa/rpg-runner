import '../hit/aabb_hit_utils.dart';
import '../entity_id.dart';
import '../world.dart';
import '../../tuning/collectible_tuning.dart';

class CollectibleSystem {
  final List<EntityId> _toDespawn = <EntityId>[];

  void step(
    EcsWorld world, {
    required EntityId player,
    required double cameraLeft,
    required CollectibleTuning tuning,
    required void Function(int value) onCollected,
  }) {
    final collectibles = world.collectible;
    if (collectibles.denseEntities.isEmpty) return;

    final playerTi = world.transform.tryIndexOf(player);
    final playerAi = world.colliderAabb.tryIndexOf(player);

    _toDespawn.clear();

    final despawnLimit = cameraLeft - tuning.despawnBehindCameraMargin;
    for (var ci = 0; ci < collectibles.denseEntities.length; ci += 1) {
      final e = collectibles.denseEntities[ci];
      final ti = world.transform.tryIndexOf(e);
      final ai = world.colliderAabb.tryIndexOf(e);
      if (ti == null || ai == null) continue;

      final centerX = world.transform.posX[ti] + world.colliderAabb.offsetX[ai];
      if (centerX < despawnLimit) {
        _toDespawn.add(e);
        continue;
      }

      if (playerTi != null && playerAi != null) {
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

    for (final e in _toDespawn) {
      world.destroyEntity(e);
    }
  }
}
