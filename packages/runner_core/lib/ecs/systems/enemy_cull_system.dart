import '../../tuning/track_tuning.dart';
import '../collider_aabb_utils.dart';
import '../entity_id.dart';
import '../world.dart';

/// Despawns autonomous actors behind the camera or below the world.
///
/// Rules:
/// - Behind: enemy maxX < cameraLeft - tuning.cullBehindMargin
/// - Below:  enemy bottomY > groundTopY + tuning.enemyCullBelowGroundOffsetY
class EnemyCullSystem {
  final List<EntityId> _toDespawn = <EntityId>[];
  final Set<EntityId> _fatalLosses = {};

  void step(
    EcsWorld world, {
    required double cameraLeft,
    required double groundTopY,
    required TrackTuning tuning,
    bool Function(EntityId entity)? retainForEncounter,
  }) {
    if (world.enemy.denseEntities.isEmpty && world.npc.denseEntities.isEmpty) {
      return;
    }

    _toDespawn.clear();
    _fatalLosses.clear();

    final despawnX = cameraLeft - tuning.cullBehindMargin;
    final despawnY = groundTopY + tuning.enemyCullBelowGroundOffsetY;

    // 1. identify enemies to despawn
    for (final actors in [world.enemy.denseEntities, world.npc.denseEntities]) {
      for (final e in actors) {
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
          cx = colliderCenterX(
            world,
            entity: e,
            transformIndex: ti,
            colliderIndex: ci,
          );
          cy += world.colliderAabb.offsetY[ci];
          maxX = cx + world.colliderAabb.halfX[ci];
          bottomY = cy + world.colliderAabb.halfY[ci];
        }

        final fatalLoss = bottomY > despawnY;
        if (fatalLoss ||
            (maxX < despawnX && !(retainForEncounter?.call(e) ?? false))) {
          _toDespawn.add(e);
          if (fatalLoss) _fatalLosses.add(e);
        }
      }
    }

    if (_toDespawn.isEmpty) return;

    // 2. destroy
    for (final e in _toDespawn) {
      world.destroyEntity(e, fatalWorldLoss: _fatalLosses.contains(e));
    }
  }
}
