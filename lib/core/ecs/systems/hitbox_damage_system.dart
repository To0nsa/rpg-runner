import '../../combat/damage.dart';
import '../hit/hit_resolver.dart';
import '../spatial/broadphase_grid.dart';
import '../world.dart';

class HitboxDamageSystem {
  final HitResolver _resolver = HitResolver();
  final List<int> _overlaps = <int>[];

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

      _resolver.collectOrderedOverlapsCenters(
        broadphase: broadphase,
        centerX: hbCx,
        centerY: hbCy,
        halfX: hbHalfX,
        halfY: hbHalfY,
        owner: owner,
        sourceFaction: sourceFaction,
        outTargetIndices: _overlaps,
      );
      if (_overlaps.isEmpty) continue;

      for (var i = 0; i < _overlaps.length; i += 1) {
        final ti = _overlaps[i];
        final target = broadphase.targets.entities[ti];
        if (world.hitOnce.hasHit(hb, target)) continue;
        world.hitOnce.markHit(hb, target);

        queueDamage(DamageRequest(target: target, amount: hitboxes.damage[hi]));
      }
    }
  }
}
