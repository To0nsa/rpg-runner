import '../../../combat/status/status.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Remaining effect strength and duration, in basis points (10000 = unchanged).
/// Multipliers range from 0 to 10000. Strength scales DoT DPS and debuff
/// magnitude; duration-only Stun/Silence ignore strength and use duration.
class StatusEffectResistance {
  const StatusEffectResistance({
    this.magnitudeScaleBp = 10000,
    this.durationScaleBp = 10000,
  }) : assert(magnitudeScaleBp >= 0 && magnitudeScaleBp <= 10000),
       assert(durationScaleBp >= 0 && durationScaleBp <= 10000);

  final int magnitudeScaleBp;
  final int durationScaleBp;
}

/// Target-owned resistance to incoming harmful statuses, separate from immunity.
/// Each optional effect overrides the complete default pair. Beneficial effects
/// always retain their source tuning. Changes affect new applications only.
class StatusResistanceDef {
  const StatusResistanceDef({
    this.defaultDebuff = const StatusEffectResistance(),
    this.dot,
    this.slow,
    this.stun,
    this.vulnerable,
    this.weaken,
    this.drench,
    this.silence,
  });

  final StatusEffectResistance defaultDebuff;
  final StatusEffectResistance? dot;
  final StatusEffectResistance? slow;
  final StatusEffectResistance? stun;
  final StatusEffectResistance? vulnerable;
  final StatusEffectResistance? weaken;
  final StatusEffectResistance? drench;
  final StatusEffectResistance? silence;

  StatusEffectResistance forType(StatusEffectType type) => switch (type) {
    StatusEffectType.dot => dot ?? defaultDebuff,
    StatusEffectType.slow => slow ?? defaultDebuff,
    StatusEffectType.stun => stun ?? defaultDebuff,
    StatusEffectType.vulnerable => vulnerable ?? defaultDebuff,
    StatusEffectType.weaken => weaken ?? defaultDebuff,
    StatusEffectType.drench => drench ?? defaultDebuff,
    StatusEffectType.silence => silence ?? defaultDebuff,
    StatusEffectType.haste ||
    StatusEffectType.damageReduction ||
    StatusEffectType.resourceOverTime ||
    StatusEffectType.offenseBuff => const StatusEffectResistance(),
  };
}

/// Immutable profiles shared by actors; absent components mean no resistance.
/// Kept in the world lifecycle so recycled IDs cannot retain old defenses.
class StatusResistanceStore extends SparseSet {
  final List<StatusResistanceDef> profiles = [];

  void add(EntityId entity, StatusResistanceDef def) {
    profiles[addEntity(entity)] = def;
  }

  StatusResistanceDef forEntity(EntityId entity) {
    final index = tryIndexOf(entity);
    return index == null ? const StatusResistanceDef() : profiles[index];
  }

  @override
  void onDenseAdded(int denseIndex) {
    profiles.add(const StatusResistanceDef());
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    profiles[removeIndex] = profiles[lastIndex];
    profiles.removeLast();
  }
}
