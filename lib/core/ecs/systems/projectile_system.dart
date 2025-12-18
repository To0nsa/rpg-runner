import '../../tuning/v0_movement_tuning.dart';
import '../entity_id.dart';
import '../world.dart';

class ProjectileSystem {
  final List<EntityId> _toDespawn = <EntityId>[];

  void step(EcsWorld world, V0MovementTuningDerived movement) {
    final dt = movement.dtSeconds;
    final projectiles = world.projectile;

    _toDespawn.clear();

    for (var pi = 0; pi < projectiles.denseEntities.length; pi += 1) {
      final e = projectiles.denseEntities[pi];
      if (!world.transform.has(e) || !world.lifetime.has(e)) {
        continue;
      }

      final ti = world.transform.indexOf(e);
      final li = world.lifetime.indexOf(e);

      final vx = projectiles.dirX[pi] * projectiles.speedUnitsPerSecond[pi];
      final vy = projectiles.dirY[pi] * projectiles.speedUnitsPerSecond[pi];

      world.transform.velX[ti] = vx;
      world.transform.velY[ti] = vy;

      world.transform.posX[ti] += vx * dt;
      world.transform.posY[ti] += vy * dt;

      final ticksLeft = world.lifetime.ticksLeft[li] - 1;
      world.lifetime.ticksLeft[li] = ticksLeft;
      if (ticksLeft <= 0) {
        _toDespawn.add(e);
      }
    }

    for (final e in _toDespawn) {
      world.destroyEntity(e);
    }
  }
}
