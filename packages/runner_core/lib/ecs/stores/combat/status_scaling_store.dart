import '../../../combat/status/status.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Incoming effect multipliers in basis points (10000 = unchanged).
/// Nonnegative values below 10000 resist effects; values above 10000 amplify
/// them. Strength scales DoT DPS and debuff magnitude before existing caps;
/// duration-only Stun/Silence ignore strength and use duration.
class StatusEffectScaling {
  const StatusEffectScaling({
    this.magnitudeScaleBp = 10000,
    this.durationScaleBp = 10000,
  }) : assert(magnitudeScaleBp >= 0),
       assert(durationScaleBp >= 0);

  final int magnitudeScaleBp;
  final int durationScaleBp;
}

/// Target-owned scaling of incoming harmful statuses, separate from immunity.
/// Each optional effect overrides the complete default pair. Beneficial effects
/// always retain their source tuning. Changes affect new applications only.
class StatusScalingDef {
  const StatusScalingDef({
    this.defaultDebuff = const StatusEffectScaling(),
    this.dot,
    this.slow,
    this.stun,
    this.vulnerable,
    this.weaken,
    this.drench,
    this.silence,
  });

  final StatusEffectScaling defaultDebuff;
  final StatusEffectScaling? dot;
  final StatusEffectScaling? slow;
  final StatusEffectScaling? stun;
  final StatusEffectScaling? vulnerable;
  final StatusEffectScaling? weaken;
  final StatusEffectScaling? drench;
  final StatusEffectScaling? silence;

  StatusEffectScaling forType(StatusEffectType type) => switch (type) {
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
    StatusEffectType.offenseBuff => const StatusEffectScaling(),
  };
}

/// Immutable profiles shared by actors; absent components mean neutral scaling.
/// Kept in the world lifecycle so recycled IDs cannot retain old scaling.
class StatusScalingStore extends SparseSet {
  final List<StatusScalingDef> profiles = [];

  void add(EntityId entity, StatusScalingDef def) {
    profiles[addEntity(entity)] = def;
  }

  StatusScalingDef forEntity(EntityId entity) {
    final index = tryIndexOf(entity);
    return index == null ? const StatusScalingDef() : profiles[index];
  }

  @override
  void onDenseAdded(int denseIndex) {
    profiles.add(const StatusScalingDef());
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    profiles[removeIndex] = profiles[lastIndex];
    profiles.removeLast();
  }
}
