import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Runtime phase for Hashash teleport evade/ambush behavior.
abstract class HashashTeleportPhase {
  static const int idle = 0;
  static const int evadeOut = 1;
  static const int ambush = 2;
}

/// Per-entity state used by Hashash teleport evade + ambush logic.
class HashashTeleportStateDef {
  const HashashTeleportStateDef({
    this.phase = HashashTeleportPhase.idle,
    this.phaseEndTick = -1,
    this.cooldownUntilTick = 0,
    this.rngState = 1,
  });

  final int phase;
  final int phaseEndTick;
  final int cooldownUntilTick;
  final int rngState;
}

/// Hashash-only teleport state with deterministic RNG.
class HashashTeleportStateStore extends SparseSet {
  final List<int> phase = <int>[];
  final List<int> phaseEndTick = <int>[];
  final List<int> cooldownUntilTick = <int>[];
  final List<int> rngState = <int>[];

  void add(
    EntityId entity, [
    HashashTeleportStateDef def = const HashashTeleportStateDef(),
  ]) {
    final i = addEntity(entity);
    phase[i] = def.phase;
    phaseEndTick[i] = def.phaseEndTick;
    cooldownUntilTick[i] = def.cooldownUntilTick;
    rngState[i] = def.rngState;
  }

  @override
  void onDenseAdded(int denseIndex) {
    phase.add(HashashTeleportPhase.idle);
    phaseEndTick.add(-1);
    cooldownUntilTick.add(0);
    rngState.add(1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    phase[removeIndex] = phase[lastIndex];
    phaseEndTick[removeIndex] = phaseEndTick[lastIndex];
    cooldownUntilTick[removeIndex] = cooldownUntilTick[lastIndex];
    rngState[removeIndex] = rngState[lastIndex];

    phase.removeLast();
    phaseEndTick.removeLast();
    cooldownUntilTick.removeLast();
    rngState.removeLast();
  }
}
