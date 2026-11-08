import '../../combat/damage.dart';
import '../../events/game_event.dart';
import '../../snapshots/enums.dart';
import '../hit/hit_resolver.dart';
import '../spatial/broadphase_grid.dart';
import '../world.dart';

/// Resolves swept contact or fuse expiry after terrain/broadphase, before damage.
/// The one-time blast ignores allies and requires a clear solid-terrain ray.
class BombSystem {
  BombSystem({required this.tickHz, required this.pathClear});
  final int tickHz;
  final bool Function(double, double, double, double) pathClear;
  final HitResolver _resolver = HitResolver();
  final List<int> _overlaps = [];

  void step(
    EcsWorld world,
    BroadphaseGrid broadphase, {
    required int currentTick,
  }) {
    final bombs = world.bomb;
    for (var i = 0; i < bombs.denseEntities.length; i++) {
      final entity = bombs.denseEntities[i];
      final pi = world.projectile.indexOf(entity);
      final ti = world.transform.indexOf(entity);
      final projectile = world.projectile;
      if (!bombs.exploded[i]) {
        final x = world.transform.posX[ti], y = world.transform.posY[ti];
        final startX = projectile.previousX[pi] ?? x;
        final startY = projectile.previousY[pi] ?? y;
        final ci = world.colliderAabb.indexOf(entity);
        // Terrain already clipped this segment; swept hostile contact can
        // detonate earlier along it without tunnelling through a thin target.
        final contact = _resolver.firstSweptCapsuleContact(
          broadphase: broadphase,
          ax: startX,
          ay: startY,
          bx: startX,
          by: startY,
          radius: world.colliderAabb.halfY[ci],
          deltaX: x - startX,
          deltaY: y - startY,
          owner: projectile.owner[pi],
          sourceFaction: projectile.faction[pi],
        );
        final collision = world.collision.indexOf(entity);
        final terrainContact =
            world.collision.grounded[collision] ||
            world.collision.hitCeiling[collision] ||
            world.collision.hitLeft[collision] ||
            world.collision.hitRight[collision];
        if (contact != null) {
          world.transform.posX[ti] = startX + (x - startX) * contact.fraction;
          world.transform.posY[ti] = startY + (y - startY) * contact.fraction;
        }
        if (contact != null || terrainContact) {
          bombs.explodeTick[i] = currentTick;
        }
      }
      final fuse = bombs.explodeTick[i];
      if (currentTick < fuse) {
        final start = projectile.spawnTick[pi] ?? currentTick;
        final countdown = start + (fuse - start) ~/ 2;
        projectile.anim[pi] = currentTick < countdown
            ? AnimKey.idle
            : AnimKey.bombFuse;
        projectile.animFrame[pi] =
            currentTick - (currentTick < countdown ? start : countdown);
        continue;
      }
      projectile.anim[pi] = AnimKey.bombExplosion;
      projectile.animFrame[pi] = currentTick - fuse;
      if (bombs.exploded[i]) continue;
      bombs.exploded[i] = true;
      world.body.enabled[world.body.indexOf(entity)] = false;
      world.transform.velX[ti] = 0;
      world.transform.velY[ti] = 0;
      projectile.dirX[pi] = 1;
      projectile.dirY[pi] = 0;
      // Nine frames at 0.06s; keep the effect alive without another damage pulse.
      final frameTicks = (tickHz * .06).round().clamp(1, tickHz);
      world.lifetime.ticksLeft[world.lifetime.indexOf(entity)] =
          9 * frameTicks + 1;
      final x = world.transform.posX[ti], y = world.transform.posY[ti];
      _overlaps.clear();
      _resolver.collectOrderedOverlapsCapsule(
        broadphase: broadphase,
        ax: x,
        ay: y,
        bx: x,
        by: y,
        radius: bombs.radius[i],
        owner: projectile.owner[pi],
        sourceFaction: projectile.faction[pi],
        outTargetIndices: _overlaps,
      );
      for (final index in _overlaps) {
        final target = broadphase.targets.entities[index];
        final targetTransform = world.transform.indexOf(target);
        if (!pathClear(
          x,
          y,
          world.transform.posX[targetTransform],
          world.transform.posY[targetTransform],
        )) {
          continue;
        }
        world.damageQueue.add(
          DamageRequest(
            target: target,
            amount100: projectile.damage100[pi],
            critChanceBp: projectile.critChanceBp[pi],
            damageType: projectile.damageType[pi],
            procs: projectile.procs[pi],
            source: projectile.owner[pi] == 0 ? null : projectile.owner[pi],
            sourceKind: DeathSourceKind.projectile,
            sourceProjectileId: projectile.projectileId[pi],
            credit: projectile.credit[pi],
          ),
        );
      }
    }
  }
}
