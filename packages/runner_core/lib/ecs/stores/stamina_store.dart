import '../entity_id.dart';
import '../sparse_set.dart';

class StaminaDef {
  const StaminaDef({
    required this.stamina,
    required this.staminaMax,
    required this.regenPerSecond100,
  });

  /// Fixed-point: 100 = 1.0
  final int stamina;
  final int staminaMax;
  final int regenPerSecond100;
}

/// Tracks stamina for dashing and melee strikes.
class StaminaStore extends SparseSet {
  /// Fixed-point: 100 = 1.0
  final List<int> stamina = <int>[];
  final List<int> staminaMax = <int>[];
  final List<int> regenPerSecond100 = <int>[];
  final List<int> regenAccumulator = <int>[];

  void add(EntityId entity, StaminaDef def) {
    final i = addEntity(entity);
    stamina[i] = def.stamina;
    staminaMax[i] = def.staminaMax;
    regenPerSecond100[i] = def.regenPerSecond100;
    regenAccumulator[i] = 0;
  }

  @override
  void onDenseAdded(int denseIndex) {
    stamina.add(0);
    staminaMax.add(0);
    regenPerSecond100.add(0);
    regenAccumulator.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    stamina[removeIndex] = stamina[lastIndex];
    staminaMax[removeIndex] = staminaMax[lastIndex];
    regenPerSecond100[removeIndex] = regenPerSecond100[lastIndex];
    regenAccumulator[removeIndex] = regenAccumulator[lastIndex];

    stamina.removeLast();
    staminaMax.removeLast();
    regenPerSecond100.removeLast();
    regenAccumulator.removeLast();
  }
}
