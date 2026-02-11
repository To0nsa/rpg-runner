import '../../abilities/ability_def.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class MobilityIntentDef {
  const MobilityIntentDef({
    required this.abilityId,
    required this.slot,
    required this.dirX,
    required this.dirY,
    required this.speedScaleBp,
    required this.commitTick,
    required this.windupTicks,
    required this.activeTicks,
    required this.recoveryTicks,
    required this.cooldownTicks,
    required this.cooldownGroupId,
    required this.staminaCost100,
    required this.tick,
  });

  final AbilityKey abilityId;
  final AbilitySlot slot;

  /// Direction of the mobility action (normalized X).
  final double dirX;

  /// Direction of the mobility action (normalized Y).
  final double dirY;

  /// Mobility speed scale in basis points (`10000 == 1.0x`).
  final int speedScaleBp;

  /// Tick the ability was committed (costs/cooldown start).
  final int commitTick;

  /// Windup duration (ticks) before movement starts.
  final int windupTicks;
  final int activeTicks;

  /// Recovery duration (ticks) after active window.
  final int recoveryTicks;
  final int cooldownTicks;
  final int cooldownGroupId;

  /// Fixed-point: 100 = 1.0
  final int staminaCost100;

  /// Tick stamp for movement execution.
  ///
  /// Use `-1` for "no intent". The effect triggers only when
  /// `tick == currentTick`.
  final int tick;
}

/// Per-entity "perform a mobility action this tick" intent.
///
/// Written by [AbilityActivationSystem], consumed by [MobilitySystem].
class MobilityIntentStore extends SparseSet {
  final List<AbilityKey> abilityId = <AbilityKey>[];
  final List<AbilitySlot> slot = <AbilitySlot>[];
  final List<double> dirX = <double>[];
  final List<double> dirY = <double>[];
  final List<int> speedScaleBp = <int>[];
  final List<int> commitTick = <int>[];
  final List<int> windupTicks = <int>[];
  final List<int> activeTicks = <int>[];
  final List<int> recoveryTicks = <int>[];
  final List<int> cooldownTicks = <int>[];
  final List<int> cooldownGroupId = <int>[];

  /// Fixed-point: 100 = 1.0
  final List<int> staminaCost100 = <int>[];
  final List<int> tick = <int>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  void set(EntityId entity, MobilityIntentDef def) {
    assert(
      has(entity),
      'MobilityIntentStore.set called for entity without MobilityIntentStore; add the component at spawn time.',
    );
    final i = indexOf(entity);
    abilityId[i] = def.abilityId;
    slot[i] = def.slot;
    dirX[i] = def.dirX;
    dirY[i] = def.dirY;
    speedScaleBp[i] = def.speedScaleBp;
    commitTick[i] = def.commitTick;
    windupTicks[i] = def.windupTicks;
    activeTicks[i] = def.activeTicks;
    recoveryTicks[i] = def.recoveryTicks;
    cooldownTicks[i] = def.cooldownTicks;
    cooldownGroupId[i] = def.cooldownGroupId;
    staminaCost100[i] = def.staminaCost100;
    tick[i] = def.tick;
  }

  @override
  void onDenseAdded(int denseIndex) {
    abilityId.add('eloise.dash');
    slot.add(AbilitySlot.mobility);
    dirX.add(1.0);
    dirY.add(0.0);
    speedScaleBp.add(10000);
    commitTick.add(-1);
    windupTicks.add(0);
    activeTicks.add(0);
    recoveryTicks.add(0);
    cooldownTicks.add(0);
    cooldownGroupId.add(0);
    staminaCost100.add(0);
    tick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    abilityId[removeIndex] = abilityId[lastIndex];
    slot[removeIndex] = slot[lastIndex];
    dirX[removeIndex] = dirX[lastIndex];
    dirY[removeIndex] = dirY[lastIndex];
    speedScaleBp[removeIndex] = speedScaleBp[lastIndex];
    commitTick[removeIndex] = commitTick[lastIndex];
    windupTicks[removeIndex] = windupTicks[lastIndex];
    activeTicks[removeIndex] = activeTicks[lastIndex];
    recoveryTicks[removeIndex] = recoveryTicks[lastIndex];
    cooldownTicks[removeIndex] = cooldownTicks[lastIndex];
    cooldownGroupId[removeIndex] = cooldownGroupId[lastIndex];
    staminaCost100[removeIndex] = staminaCost100[lastIndex];
    tick[removeIndex] = tick[lastIndex];

    abilityId.removeLast();
    slot.removeLast();
    dirX.removeLast();
    dirY.removeLast();
    speedScaleBp.removeLast();
    commitTick.removeLast();
    windupTicks.removeLast();
    activeTicks.removeLast();
    recoveryTicks.removeLast();
    cooldownTicks.removeLast();
    cooldownGroupId.removeLast();
    staminaCost100.removeLast();
    tick.removeLast();
  }
}
