import '../../combat/damage.dart';
import '../../combat/faction.dart';
import '../world.dart';

class HitboxDamageSystem {
  void step(EcsWorld world, void Function(DamageRequest request) queueDamage) {
    final hitboxes = world.hitbox;
    if (hitboxes.denseEntities.isEmpty) return;

    final targets = world.health;
    if (targets.denseEntities.isEmpty) return;

    for (var hi = 0; hi < hitboxes.denseEntities.length; hi += 1) {
      final hb = hitboxes.denseEntities[hi];
      if (!world.transform.has(hb)) continue;
      if (!world.hitOnce.has(hb)) continue;

      final hbTi = world.transform.indexOf(hb);
      final hbCx = world.transform.posX[hbTi];
      final hbCy = world.transform.posY[hbTi];
      final hbHalfX = hitboxes.halfX[hi];
      final hbHalfY = hitboxes.halfY[hi];

      final hbMinX = hbCx - hbHalfX;
      final hbMaxX = hbCx + hbHalfX;
      final hbMinY = hbCy - hbHalfY;
      final hbMaxY = hbCy + hbHalfY;

      final owner = hitboxes.owner[hi];
      final sourceFaction = hitboxes.faction[hi];

      for (var ti = 0; ti < targets.denseEntities.length; ti += 1) {
        final target = targets.denseEntities[ti];
        if (target == owner) continue;

        final fi = world.faction.tryIndexOf(target);
        if (fi == null) continue;
        final targetFaction = world.faction.faction[fi];
        if (_isFriendlyFire(sourceFaction, targetFaction)) continue;

        final targetTi = world.transform.tryIndexOf(target);
        if (targetTi == null) continue;
        final aabbi = world.colliderAabb.tryIndexOf(target);
        if (aabbi == null) continue;

        final tcx = world.transform.posX[targetTi] + world.colliderAabb.offsetX[aabbi];
        final tcy = world.transform.posY[targetTi] + world.colliderAabb.offsetY[aabbi];
        final thx = world.colliderAabb.halfX[aabbi];
        final thy = world.colliderAabb.halfY[aabbi];

        final tMinX = tcx - thx;
        final tMaxX = tcx + thx;
        final tMinY = tcy - thy;
        final tMaxY = tcy + thy;

        final overlaps =
            hbMinX < tMaxX && hbMaxX > tMinX && hbMinY < tMaxY && hbMaxY > tMinY;
        if (!overlaps) continue;

        if (world.hitOnce.hasHit(hb, target)) continue;
        world.hitOnce.markHit(hb, target);

        queueDamage(DamageRequest(target: target, amount: hitboxes.damage[hi]));
      }
    }
  }

  bool _isFriendlyFire(Faction a, Faction b) => a == b;
}
