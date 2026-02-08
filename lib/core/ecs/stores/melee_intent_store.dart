import '../../abilities/ability_def.dart';
import '../../combat/damage_type.dart';
import '../../weapons/weapon_proc.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class MeleeIntentDef {
  const MeleeIntentDef({
    required this.abilityId,
    required this.slot,
    required this.damage100,
    this.critChanceBp = 0,
    required this.damageType,
    this.procs = const <WeaponProc>[],
    required this.halfX,
    required this.halfY,
    required this.offsetX,
    required this.offsetY,
    required this.dirX,
    required this.dirY,
    required this.commitTick,
    required this.windupTicks,
    required this.activeTicks,
    required this.recoveryTicks,
    required this.cooldownTicks,
    required this.staminaCost100,
    required this.cooldownGroupId,
    required this.tick,
  });

  final AbilityKey abilityId;
  final AbilitySlot slot;

  /// Fixed-point: 100 = 1.0
  final int damage100;

  /// Critical strike chance in basis points (100 = 1%).
  final int critChanceBp;
  final DamageType damageType;
  final List<WeaponProc> procs;
  final double halfX;
  final double halfY;
  final double offsetX;
  final double offsetY;
  final double dirX;
  final double dirY;

  /// Tick the ability was committed (costs/cooldown start).
  final int commitTick;

  /// Windup duration (ticks) before hitbox spawns.
  final int windupTicks;
  final int activeTicks;

  /// Recovery duration (ticks) after active window.
  final int recoveryTicks;
  final int cooldownTicks;

  /// Fixed-point: 100 = 1.0
  final int staminaCost100;
  final int cooldownGroupId;

  /// Tick stamp for effect execution.
  ///
  /// Use `-1` for "no intent". The effect spawns only when `tick == currentTick`.
  final int tick;
}

/// Per-entity "perform a melee strike this tick" intent.
///
/// This is written by player/enemy intent writers and consumed by `MeleeStrikeSystem`.
///
/// **Usage**: Persistent component. Intents are set via `set()` with a `tick` stamp.
/// Old intents are ignored if `tick` matches current game tick.
class MeleeIntentStore extends SparseSet {
  final List<AbilityKey?> abilityId = <AbilityKey?>[];
  final List<AbilitySlot> slot = <AbilitySlot>[];

  /// Fixed-point: 100 = 1.0
  final List<int> damage100 = <int>[];
  final List<int> critChanceBp = <int>[];
  final List<DamageType> damageType = <DamageType>[];
  final List<List<WeaponProc>> procs = <List<WeaponProc>>[];
  final List<double> halfX = <double>[];
  final List<double> halfY = <double>[];
  final List<double> offsetX = <double>[];
  final List<double> offsetY = <double>[];
  final List<double> dirX = <double>[];
  final List<double> dirY = <double>[];
  final List<int> commitTick = <int>[];
  final List<int> windupTicks = <int>[];
  final List<int> activeTicks = <int>[];
  final List<int> recoveryTicks = <int>[];
  final List<int> cooldownTicks = <int>[];

  /// Fixed-point: 100 = 1.0
  final List<int> staminaCost100 = <int>[];
  final List<int> cooldownGroupId = <int>[];
  final List<int> tick = <int>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  void set(EntityId entity, MeleeIntentDef def) {
    assert(
      has(entity),
      'MeleeIntentStore.set called for entity without MeleeIntentStore; add the component at spawn time.',
    );
    final i = indexOf(entity);
    abilityId[i] = def.abilityId;
    slot[i] = def.slot;
    damage100[i] = def.damage100;
    critChanceBp[i] = def.critChanceBp;
    damageType[i] = def.damageType;
    procs[i] = def.procs;
    halfX[i] = def.halfX;
    halfY[i] = def.halfY;
    offsetX[i] = def.offsetX;
    offsetY[i] = def.offsetY;
    dirX[i] = def.dirX;
    dirY[i] = def.dirY;
    commitTick[i] = def.commitTick;
    windupTicks[i] = def.windupTicks;
    activeTicks[i] = def.activeTicks;
    recoveryTicks[i] = def.recoveryTicks;
    cooldownTicks[i] = def.cooldownTicks;
    staminaCost100[i] = def.staminaCost100;
    cooldownGroupId[i] = def.cooldownGroupId;
    tick[i] = def.tick;
  }

  @override
  void onDenseAdded(int denseIndex) {
    abilityId.add(null);
    slot.add(AbilitySlot.primary);
    damage100.add(0);
    critChanceBp.add(0);
    damageType.add(DamageType.physical);
    procs.add(const <WeaponProc>[]);
    halfX.add(0.0);
    halfY.add(0.0);
    offsetX.add(0.0);
    offsetY.add(0.0);
    dirX.add(1.0);
    dirY.add(0.0);
    commitTick.add(-1);
    windupTicks.add(0);
    activeTicks.add(0);
    recoveryTicks.add(0);
    cooldownTicks.add(0);
    staminaCost100.add(0);
    cooldownGroupId.add(0);
    tick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    abilityId[removeIndex] = abilityId[lastIndex];
    slot[removeIndex] = slot[lastIndex];
    damage100[removeIndex] = damage100[lastIndex];
    critChanceBp[removeIndex] = critChanceBp[lastIndex];
    damageType[removeIndex] = damageType[lastIndex];
    procs[removeIndex] = procs[lastIndex];
    halfX[removeIndex] = halfX[lastIndex];
    halfY[removeIndex] = halfY[lastIndex];
    offsetX[removeIndex] = offsetX[lastIndex];
    offsetY[removeIndex] = offsetY[lastIndex];
    dirX[removeIndex] = dirX[lastIndex];
    dirY[removeIndex] = dirY[lastIndex];
    commitTick[removeIndex] = commitTick[lastIndex];
    windupTicks[removeIndex] = windupTicks[lastIndex];
    activeTicks[removeIndex] = activeTicks[lastIndex];
    recoveryTicks[removeIndex] = recoveryTicks[lastIndex];
    cooldownTicks[removeIndex] = cooldownTicks[lastIndex];
    staminaCost100[removeIndex] = staminaCost100[lastIndex];
    cooldownGroupId[removeIndex] = cooldownGroupId[lastIndex];
    tick[removeIndex] = tick[lastIndex];

    abilityId.removeLast();
    slot.removeLast();
    damage100.removeLast();
    critChanceBp.removeLast();
    damageType.removeLast();
    procs.removeLast();
    halfX.removeLast();
    halfY.removeLast();
    offsetX.removeLast();
    offsetY.removeLast();
    dirX.removeLast();
    dirY.removeLast();
    commitTick.removeLast();
    windupTicks.removeLast();
    activeTicks.removeLast();
    recoveryTicks.removeLast();
    cooldownTicks.removeLast();
    staminaCost100.removeLast();
    cooldownGroupId.removeLast();
    tick.removeLast();
  }
}
