import '../../tuning/track_tuning.dart';
import '../entity_id.dart';
import '../world.dart';

/// Despawns enemies that are behind the camera or below the ground.
///
/// Rules:
/// - Behind: enemy maxX < cameraLeft - tuning.cullBehindMargin
/// - Below:  enemy bottomY > groundTopY + tuning.enemyCullBelowGroundOffsetY
class EnemyCullSystem {
  final List<EntityId> _toDespawn = <EntityId>[];

  void step(
    EcsWorld world, {
    required double cameraLeft,
    required double groundTopY,
    required TrackTuning tuning,
  }) {
    final enemies = world.enemy;
    if (enemies.denseEntities.isEmpty) return;

    _toDespawn.clear();

    final despawnX = cameraLeft - tuning.cullBehindMargin;
    final despawnY = groundTopY + tuning.enemyCullBelowGroundOffsetY;

    // 1. identify enemies to despawn
    for (var i = 0; i < enemies.denseEntities.length; i += 1) {
      final e = enemies.denseEntities[i];

      final ti = world.transform.tryIndexOf(e);
      if (ti == null) {
        // Orphan enemy, kill it.
        _toDespawn.add(e);
        continue;
      }

      // Compute bounds using ColliderAabb when present.
      var cx = world.transform.posX[ti];
      var cy = world.transform.posY[ti];
      var maxX = cx;
      var bottomY = cy;

      final ci = world.colliderAabb.tryIndexOf(e);
      if (ci != null) {
        cx += world.colliderAabb.offsetX[ci];
        cy += world.colliderAabb.offsetY[ci];
        maxX = cx + world.colliderAabb.halfX[ci];
        bottomY = cy + world.colliderAabb.halfY[ci];
      }

      if (maxX < despawnX || bottomY > despawnY) {
        _toDespawn.add(e);
      }
    }

    if (_toDespawn.isEmpty) return;

    // 2. destroy
    for (final e in _toDespawn) {
      world.destroyEntity(e);
    }
  }
}
