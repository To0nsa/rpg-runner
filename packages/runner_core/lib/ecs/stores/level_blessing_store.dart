import '../../interactions/level_blessing.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

/// Player-owned modifiers independent of streamed interaction lifetimes.
/// Removal follows ordinary entity teardown; base resource rates are untouched.
final class LevelBlessingStore extends SparseSet {
  final List<Map<LevelBlessingId, int>> _grants = [];
  final List<int> healthRegen100 = [];
  final List<int> manaRegen100 = [];
  final List<int> staminaRegen100 = [];

  /// Returns true only for a new grant. Repeated grants preserve the first tick.
  bool grant(EntityId entity, LevelBlessingId id, {required int tick}) {
    final i = addEntity(entity);
    if (_grants[i].containsKey(id)) return false;
    final def = LevelBlessingDefinition.get(id);
    _grants[i][id] = tick;
    healthRegen100[i] += def.healthRegen100;
    manaRegen100[i] += def.manaRegen100;
    staminaRegen100[i] += def.staminaRegen100;
    return true;
  }

  List<LevelBlessingSnapshot> snapshots(EntityId entity) {
    final i = tryIndexOf(entity);
    if (i == null) return const [];
    return List.unmodifiable([
      for (final id in LevelBlessingId.values)
        if (_grants[i][id] case final tick?)
          LevelBlessingSnapshot(id: id, grantedAtTick: tick),
    ]);
  }

  @override
  void onDenseAdded(int denseIndex) {
    _grants.add({});
    healthRegen100.add(0);
    manaRegen100.add(0);
    staminaRegen100.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    _grants[removeIndex] = _grants[lastIndex];
    healthRegen100[removeIndex] = healthRegen100[lastIndex];
    manaRegen100[removeIndex] = manaRegen100[lastIndex];
    staminaRegen100[removeIndex] = staminaRegen100[lastIndex];
    _grants.removeLast();
    healthRegen100.removeLast();
    manaRegen100.removeLast();
    staminaRegen100.removeLast();
  }
}
