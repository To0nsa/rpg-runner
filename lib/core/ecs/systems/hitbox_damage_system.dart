import '../../combat/damage.dart';
import '../hit/aabb_hit_utils.dart';
import '../world.dart';

class HitboxDamageSystem {
  final DamageableTargetCache _targets = DamageableTargetCache();

  void step(EcsWorld world, void Function(DamageRequest request) queueDamage) {
    final hitboxes = world.hitbox;
    if (hitboxes.denseEntities.isEmpty) return;

    _targets.rebuild(world);
    if (_targets.isEmpty) return;

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

      for (var ti = 0; ti < _targets.length; ti += 1) {
        final target = _targets.entities[ti];
        if (target == owner) continue;

        if (isFriendlyFire(sourceFaction, _targets.factions[ti])) continue;

        if (!aabbOverlapsCenters(
          aCenterX: hbCx,
          aCenterY: hbCy,
          aHalfX: hbHalfX,
          aHalfY: hbHalfY,
          bCenterX: _targets.centerX[ti],
          bCenterY: _targets.centerY[ti],
          bHalfX: _targets.halfX[ti],
          bHalfY: _targets.halfY[ti],
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
