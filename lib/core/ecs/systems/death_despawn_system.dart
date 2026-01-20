import '../../enemies/death_behavior.dart';
import '../entity_id.dart';
import '../world.dart';

/// Despawns entities when their death animation has completed.
class DeathDespawnSystem {
  final List<EntityId> _toDespawn = <EntityId>[];

  void step(EcsWorld world, {required int currentTick}) {
    final deathState = world.deathState;
    if (deathState.denseEntities.isEmpty) return;

    _toDespawn.clear();
    for (var i = 0; i < deathState.denseEntities.length; i += 1) {
      final e = deathState.denseEntities[i];
      if (deathState.phase[i] != DeathPhase.deathAnim) continue;

      final despawnTick = deathState.despawnTick[i];
      if (despawnTick >= 0 && currentTick >= despawnTick) {
        _toDespawn.add(e);
      }
    }

    for (final e in _toDespawn) {
      world.destroyEntity(e);
    }
  }
}

