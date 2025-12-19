import '../../combat/damage.dart';
import '../entity_id.dart';
import '../hit/aabb_hit_utils.dart';
import '../world.dart';

class ProjectileHitSystem {
  final List<EntityId> _toDespawn = <EntityId>[];

  void step(EcsWorld world, void Function(DamageRequest request) queueDamage) {
    final projectiles = world.projectile;
    if (projectiles.denseEntities.isEmpty) return;

    final health = world.health;
    if (health.denseEntities.isEmpty) return;

    _toDespawn.clear();

    for (var pi = 0; pi < projectiles.denseEntities.length; pi += 1) {
      final p = projectiles.denseEntities[pi];
      if (!world.transform.has(p)) continue;
      if (!world.colliderAabb.has(p)) continue;

      final pti = world.transform.indexOf(p);
      final pa = world.colliderAabb.indexOf(p);

      final owner = projectiles.owner[pi];
      final sourceFaction = projectiles.faction[pi];

      var hit = false;
      for (var hi = 0; hi < health.denseEntities.length; hi += 1) {
        final target = health.denseEntities[hi];
        if (target == owner) continue;

        final fi = world.faction.tryIndexOf(target);
        if (fi == null) continue;
        final targetFaction = world.faction.faction[fi];
        if (isFriendlyFire(sourceFaction, targetFaction)) continue;

        final ti = world.transform.tryIndexOf(target);
        if (ti == null) continue;
        final aabbi = world.colliderAabb.tryIndexOf(target);
        if (aabbi == null) continue;

        if (!aabbOverlapsWorldColliders(
          world,
          aTransformIndex: pti,
          aAabbIndex: pa,
          bTransformIndex: ti,
          bAabbIndex: aabbi,
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
