import '../../combat/damage.dart';
import '../entity_id.dart';
import '../hit/aabb_hit_utils.dart';
import '../world.dart';

class ProjectileHitSystem {
  final List<EntityId> _toDespawn = <EntityId>[];
  final DamageableTargetCache _targets = DamageableTargetCache();

  void step(EcsWorld world, void Function(DamageRequest request) queueDamage) {
    final projectiles = world.projectile;
    if (projectiles.denseEntities.isEmpty) return;

    _targets.rebuild(world);
    if (_targets.isEmpty) return;

    _toDespawn.clear();

    for (var pi = 0; pi < projectiles.denseEntities.length; pi += 1) {
      final p = projectiles.denseEntities[pi];
      if (!world.transform.has(p)) continue;
      if (!world.colliderAabb.has(p)) continue;

      final pti = world.transform.indexOf(p);
      final pa = world.colliderAabb.indexOf(p);
      final pcx = world.transform.posX[pti] + world.colliderAabb.offsetX[pa];
      final pcy = world.transform.posY[pti] + world.colliderAabb.offsetY[pa];
      final phx = world.colliderAabb.halfX[pa];
      final phy = world.colliderAabb.halfY[pa];

      final owner = projectiles.owner[pi];
      final sourceFaction = projectiles.faction[pi];

      var hit = false;
      for (var ti = 0; ti < _targets.length; ti += 1) {
        final target = _targets.entities[ti];
        if (target == owner) continue;

        if (isFriendlyFire(sourceFaction, _targets.factions[ti])) continue;

        if (!aabbOverlapsCenters(
          aCenterX: pcx,
          aCenterY: pcy,
          aHalfX: phx,
          aHalfY: phy,
          bCenterX: _targets.centerX[ti],
          bCenterY: _targets.centerY[ti],
          bHalfX: _targets.halfX[ti],
          bHalfY: _targets.halfY[ti],
        )) {
          continue;
        }

        queueDamage(
          DamageRequest(target: target, amount: projectiles.damage[pi]),
        );
        _toDespawn.add(p);
        hit = true;
        break;
      }

      if (hit) continue;
    }

    for (final e in _toDespawn) {
      world.destroyEntity(e);
    }
  }
}
