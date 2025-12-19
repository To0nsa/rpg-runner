import '../../combat/damage.dart';
import '../entity_id.dart';
import '../hit/aabb_hit_utils.dart';
import '../spatial/broadphase_grid.dart';
import '../world.dart';

class ProjectileHitSystem {
  final List<EntityId> _toDespawn = <EntityId>[];
  final List<int> _candidateTargets = <int>[];

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

      final owner = projectiles.owner[pi];
      final sourceFaction = projectiles.faction[pi];

      broadphase.queryAabbMinMax(
        minX: pcx - phx,
        minY: pcy - phy,
        maxX: pcx + phx,
        maxY: pcy + phy,
        outTargetIndices: _candidateTargets,
      );
      if (_candidateTargets.isEmpty) continue;

      // Deterministic "first hit wins": sort candidates by EntityId.
      _candidateTargets.sort(
        (a, b) => broadphase.targets.entities[a].compareTo(
          broadphase.targets.entities[b],
        ),
      );

      var hit = false;
      for (var ci = 0; ci < _candidateTargets.length; ci += 1) {
        final ti = _candidateTargets[ci];
        final target = broadphase.targets.entities[ti];
        if (target == owner) continue;

        if (isFriendlyFire(sourceFaction, broadphase.targets.factions[ti])) continue;

        if (!aabbOverlapsCenters(
          aCenterX: pcx,
          aCenterY: pcy,
          aHalfX: phx,
          aHalfY: phy,
          bCenterX: broadphase.targets.centerX[ti],
          bCenterY: broadphase.targets.centerY[ti],
          bHalfX: broadphase.targets.halfX[ti],
          bHalfY: broadphase.targets.halfY[ti],
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
