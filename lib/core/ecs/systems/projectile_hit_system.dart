import '../../combat/damage.dart';
import '../../events/game_event.dart';
import '../entity_id.dart';
import '../hit/hit_resolver.dart';
import '../spatial/broadphase_grid.dart';
import '../world.dart';

class ProjectileHitSystem {
  final List<EntityId> _toDespawn = <EntityId>[];
  final HitResolver _resolver = HitResolver();

  void step(
    EcsWorld world,
    void Function(DamageRequest request) queueDamage,
    BroadphaseGrid broadphase,
  ) {
    final projectiles = world.projectile;
    if (projectiles.denseEntities.isEmpty) return;

    if (broadphase.targets.isEmpty) return;

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
      final dirX = projectiles.dirX[pi];
      final dirY = projectiles.dirY[pi];

      final ax = pcx - dirX * phx;
      final ay = pcy - dirY * phx;
      final bx = pcx + dirX * phx;
      final by = pcy + dirY * phx;

      final owner = projectiles.owner[pi];
      final sourceFaction = projectiles.faction[pi];
      final projectileId = projectiles.projectileId[pi];
      final enemyId = world.enemy.has(owner)
          ? world.enemy.enemyId[world.enemy.indexOf(owner)]
          : null;
      final spellId = world.spellOrigin.has(p)
          ? world.spellOrigin.spellId[world.spellOrigin.indexOf(p)]
          : null;

      final targetIndex = _resolver.firstOrderedOverlapCapsule(
        broadphase: broadphase,
        ax: ax,
        ay: ay,
        bx: bx,
        by: by,
        radius: phy,
        owner: owner,
        sourceFaction: sourceFaction,
      );
      if (targetIndex == null) continue;

      final target = broadphase.targets.entities[targetIndex];
      queueDamage(
        DamageRequest(
          target: target,
          amount: projectiles.damage[pi],
          source: owner,
          sourceKind: DeathSourceKind.projectile,
          sourceEnemyId: enemyId,
          sourceProjectileId: projectileId,
          sourceSpellId: spellId,
        ),
      );
      _toDespawn.add(p);
    }

    for (final e in _toDespawn) {
      world.destroyEntity(e);
    }
  }
}
