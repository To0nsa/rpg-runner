import '../../abilities/ability_def.dart';
import '../../combat/status/status.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class SelfIntentDef {
  const SelfIntentDef({
    required this.abilityId,
    required this.slot,
    this.selfStatusProfileId = StatusProfileId.none,
    this.selfRestoreHealthBp = 0,
    this.selfRestoreManaBp = 0,
    this.selfRestoreStaminaBp = 0,
    required this.commitTick,
    required this.windupTicks,
    required this.activeTicks,
    required this.recoveryTicks,
    required this.cooldownTicks,
    required this.cooldownGroupId,
    required this.staminaCost100,
    required this.manaCost100,
    required this.tick,
  });

  final AbilityKey abilityId;
  final AbilitySlot slot;
  final StatusProfileId selfStatusProfileId;
  final int selfRestoreHealthBp;
  final int selfRestoreManaBp;
  final int selfRestoreStaminaBp;

  /// Tick the ability was committed (costs/cooldown start).
  final int commitTick;

  /// Windup duration (ticks) before effect window.
  final int windupTicks;
  final int activeTicks;

  /// Recovery duration (ticks) after active window.
  final int recoveryTicks;
  final int cooldownTicks;
  final int cooldownGroupId;

  /// Fixed-point: 100 = 1.0
  final int staminaCost100;

  /// Fixed-point: 100 = 1.0
  final int manaCost100;

  /// Tick stamp for execution.
  ///
  /// Use `-1` for "no intent". The effect triggers only when
  /// `tick == currentTick`.
  final int tick;
}

/// Per-entity "perform a self ability this tick" intent.
///
/// Written by [AbilityActivationSystem], consumed by [SelfAbilitySystem].
class SelfIntentStore extends SparseSet {
  final List<AbilityKey> abilityId = <AbilityKey>[];
  final List<AbilitySlot> slot = <AbilitySlot>[];
  final List<StatusProfileId> selfStatusProfileId = <StatusProfileId>[];
  final List<int> selfRestoreHealthBp = <int>[];
  final List<int> selfRestoreManaBp = <int>[];
  final List<int> selfRestoreStaminaBp = <int>[];
  final List<int> commitTick = <int>[];
  final List<int> windupTicks = <int>[];
  final List<int> activeTicks = <int>[];
  final List<int> recoveryTicks = <int>[];
  final List<int> cooldownTicks = <int>[];
  final List<int> cooldownGroupId = <int>[];

  /// Fixed-point: 100 = 1.0
  final List<int> staminaCost100 = <int>[];

  /// Fixed-point: 100 = 1.0
  final List<int> manaCost100 = <int>[];
  final List<int> tick = <int>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  void set(EntityId entity, SelfIntentDef def) {
    assert(
      has(entity),
      'SelfIntentStore.set called for entity without SelfIntentStore; add the component at spawn time.',
    );
    final i = indexOf(entity);
    abilityId[i] = def.abilityId;
    slot[i] = def.slot;
    selfStatusProfileId[i] = def.selfStatusProfileId;
    selfRestoreHealthBp[i] = def.selfRestoreHealthBp;
    selfRestoreManaBp[i] = def.selfRestoreManaBp;
    selfRestoreStaminaBp[i] = def.selfRestoreStaminaBp;
    commitTick[i] = def.commitTick;
    windupTicks[i] = def.windupTicks;
    activeTicks[i] = def.activeTicks;
    recoveryTicks[i] = def.recoveryTicks;
    cooldownTicks[i] = def.cooldownTicks;
    cooldownGroupId[i] = def.cooldownGroupId;
    staminaCost100[i] = def.staminaCost100;
    manaCost100[i] = def.manaCost100;
    tick[i] = def.tick;
  }

  @override
  void onDenseAdded(int denseIndex) {
    abilityId.add('eloise.sword_parry');
    slot.add(AbilitySlot.primary);
    selfStatusProfileId.add(StatusProfileId.none);
    selfRestoreHealthBp.add(0);
    selfRestoreManaBp.add(0);
    selfRestoreStaminaBp.add(0);
    commitTick.add(-1);
    windupTicks.add(0);
    activeTicks.add(0);
    recoveryTicks.add(0);
    cooldownTicks.add(0);
    cooldownGroupId.add(0);
    staminaCost100.add(0);
    manaCost100.add(0);
    tick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    abilityId[removeIndex] = abilityId[lastIndex];
    slot[removeIndex] = slot[lastIndex];
    selfStatusProfileId[removeIndex] = selfStatusProfileId[lastIndex];
    selfRestoreHealthBp[removeIndex] = selfRestoreHealthBp[lastIndex];
    selfRestoreManaBp[removeIndex] = selfRestoreManaBp[lastIndex];
    selfRestoreStaminaBp[removeIndex] = selfRestoreStaminaBp[lastIndex];
    commitTick[removeIndex] = commitTick[lastIndex];
    windupTicks[removeIndex] = windupTicks[lastIndex];
    activeTicks[removeIndex] = activeTicks[lastIndex];
    recoveryTicks[removeIndex] = recoveryTicks[lastIndex];
    cooldownTicks[removeIndex] = cooldownTicks[lastIndex];
    cooldownGroupId[removeIndex] = cooldownGroupId[lastIndex];
    staminaCost100[removeIndex] = staminaCost100[lastIndex];
    manaCost100[removeIndex] = manaCost100[lastIndex];
    tick[removeIndex] = tick[lastIndex];

    abilityId.removeLast();
    slot.removeLast();
    selfStatusProfileId.removeLast();
    selfRestoreHealthBp.removeLast();
    selfRestoreManaBp.removeLast();
    selfRestoreStaminaBp.removeLast();
    commitTick.removeLast();
    windupTicks.removeLast();
    activeTicks.removeLast();
    recoveryTicks.removeLast();
    cooldownTicks.removeLast();
    cooldownGroupId.removeLast();
    staminaCost100.removeLast();
    manaCost100.removeLast();
    tick.removeLast();
  }
}
