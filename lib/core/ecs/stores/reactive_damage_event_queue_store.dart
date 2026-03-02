import '../../combat/damage_type.dart';
import '../entity_id.dart';

/// World-level queue for post-damage outcomes consumed by reactive proc logic.
///
/// Entries are appended by [DamageSystem] when non-zero damage is applied.
class ReactiveDamageEventQueueStore {
  final List<EntityId> target = <EntityId>[];
  final List<EntityId?> sourceEntity = <EntityId?>[];
  final List<int> appliedAmount100 = <int>[];
  final List<int> prevHp100 = <int>[];
  final List<int> nextHp100 = <int>[];
  final List<int> maxHp100 = <int>[];
  final List<DamageType> damageType = <DamageType>[];

  int get length => target.length;

  int add({
    required EntityId targetEntity,
    required EntityId? source,
    required int appliedDamage100,
    required int previousHp100,
    required int nextHpAfterDamage100,
    required int maxHpAtApply100,
    required DamageType type,
  }) {
    if (appliedDamage100 <= 0) return -1;
    final index = target.length;
    target.add(targetEntity);
    sourceEntity.add(source);
    appliedAmount100.add(appliedDamage100);
    prevHp100.add(previousHp100);
    nextHp100.add(nextHpAfterDamage100);
    maxHp100.add(maxHpAtApply100);
    damageType.add(type);
    return index;
  }

  void clear() {
    target.clear();
    sourceEntity.clear();
    appliedAmount100.clear();
    prevHp100.clear();
    nextHp100.clear();
    maxHp100.clear();
    damageType.clear();
  }
}
