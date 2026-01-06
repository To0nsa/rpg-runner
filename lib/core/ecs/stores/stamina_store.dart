import '../entity_id.dart';
import '../sparse_set.dart';

class StaminaDef {
  const StaminaDef({
    required this.stamina,
    required this.staminaMax,
    required this.regenPerSecond,
  });

  final double stamina;
  final double staminaMax;
  final double regenPerSecond;
}

/// Tracks stamina for dashing and melee attacks.
class StaminaStore extends SparseSet {
  final List<double> stamina = <double>[];
  final List<double> staminaMax = <double>[];
  final List<double> regenPerSecond = <double>[];

  void add(EntityId entity, StaminaDef def) {
    final i = addEntity(entity);
    stamina[i] = def.stamina;
    staminaMax[i] = def.staminaMax;
    regenPerSecond[i] = def.regenPerSecond;
  }

  @override
  void onDenseAdded(int denseIndex) {
    stamina.add(0);
    staminaMax.add(0);
    regenPerSecond.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    stamina[removeIndex] = stamina[lastIndex];
    staminaMax[removeIndex] = staminaMax[lastIndex];
    regenPerSecond[removeIndex] = regenPerSecond[lastIndex];

    stamina.removeLast();
    staminaMax.removeLast();
    regenPerSecond.removeLast();
  }
}

