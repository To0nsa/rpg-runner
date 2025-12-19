import '../../combat/damage.dart';
import '../hit/aabb_hit_utils.dart';
import '../spatial/broadphase_grid.dart';
import '../world.dart';

class HitboxDamageSystem {
  final List<int> _candidateTargets = <int>[];

  void step(
    EcsWorld world,
    void Function(DamageRequest request) queueDamage,
    BroadphaseGrid broadphase,
  ) {
    final hitboxes = world.hitbox;
    if (hitboxes.denseEntities.isEmpty) return;

    if (broadphase.targets.isEmpty) return;

    for (var hi = 0; hi < hitboxes.denseEntities.length; hi += 1) {
      final hb = hitboxes.denseEntities[hi];
      if (!world.transform.has(hb)) continue;
      if (!world.hitOnce.has(hb)) continue;

      final hbTi = world.transform.indexOf(hb);
      final hbCx = world.transform.posX[hbTi];
      final hbCy = world.transform.posY[hbTi];
      final hbHalfX = hitboxes.halfX[hi];
      final hbHalfY = hitboxes.halfY[hi];

      final owner = hitboxes.owner[hi];
      final sourceFaction = hitboxes.faction[hi];

      broadphase.queryAabbMinMax(
        minX: hbCx - hbHalfX,
        minY: hbCy - hbHalfY,
        maxX: hbCx + hbHalfX,
        maxY: hbCy + hbHalfY,
        outTargetIndices: _candidateTargets,
      );
      if (_candidateTargets.isEmpty) continue;

      // Deterministic multi-hit order: sort candidates by EntityId.
      _candidateTargets.sort(
        (a, b) => broadphase.targets.entities[a].compareTo(
          broadphase.targets.entities[b],
        ),
      );

      for (var ci = 0; ci < _candidateTargets.length; ci += 1) {
        final ti = _candidateTargets[ci];
        final target = broadphase.targets.entities[ti];
        if (target == owner) continue;

        if (isFriendlyFire(sourceFaction, broadphase.targets.factions[ti])) continue;

        if (!aabbOverlapsCenters(
          aCenterX: hbCx,
          aCenterY: hbCy,
          aHalfX: hbHalfX,
          aHalfY: hbHalfY,
          bCenterX: broadphase.targets.centerX[ti],
          bCenterY: broadphase.targets.centerY[ti],
          bHalfX: broadphase.targets.halfX[ti],
          bHalfY: broadphase.targets.halfY[ti],
        )) {
          continue;
        }

        if (world.hitOnce.hasHit(hb, target)) continue;
        world.hitOnce.markHit(hb, target);

        queueDamage(DamageRequest(target: target, amount: hitboxes.damage[hi]));
      }
    }
  }
}
