import '../../enemies/death_behavior.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class DeathStateDef {
  const DeathStateDef({
    required this.phase,
    this.deathStartTick = -1,
    this.despawnTick = -1,
    this.maxFallDespawnTick = -1,
  });

  final DeathPhase phase;
  final int deathStartTick;
  final int despawnTick;
  final int maxFallDespawnTick;
}

/// Per-entity death lifecycle state (enemy-only for now).
class DeathStateStore extends SparseSet {
  final List<DeathPhase> phase = <DeathPhase>[];
  final List<int> deathStartTick = <int>[];
  final List<int> despawnTick = <int>[];
  final List<int> maxFallDespawnTick = <int>[];

  void add(EntityId entity, DeathStateDef def) {
    final i = addEntity(entity);
    phase[i] = def.phase;
    deathStartTick[i] = def.deathStartTick;
    despawnTick[i] = def.despawnTick;
    maxFallDespawnTick[i] = def.maxFallDespawnTick;
  }

  @override
  void onDenseAdded(int denseIndex) {
    phase.add(DeathPhase.none);
    deathStartTick.add(-1);
    despawnTick.add(-1);
    maxFallDespawnTick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    phase[removeIndex] = phase[lastIndex];
    deathStartTick[removeIndex] = deathStartTick[lastIndex];
    despawnTick[removeIndex] = despawnTick[lastIndex];
    maxFallDespawnTick[removeIndex] = maxFallDespawnTick[lastIndex];

    phase.removeLast();
    deathStartTick.removeLast();
    despawnTick.removeLast();
    maxFallDespawnTick.removeLast();
  }
}

