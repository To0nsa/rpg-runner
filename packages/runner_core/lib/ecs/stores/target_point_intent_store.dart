import '../../abilities/ability_def.dart';
import '../../combat/damage_type.dart';
import '../../events/game_event.dart';
import '../../spell_impacts/spell_impact_id.dart';
import '../../weapons/weapon_proc.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

/// Per-entity "apply a world-space impact at target point this tick" intent.
class TargetPointIntentDef {
  const TargetPointIntentDef({
    required this.abilityId,
    required this.slot,
    required this.damage100,
    this.critChanceBp = 0,
    required this.staminaCost100,
    required this.manaCost100,
    required this.cooldownTicks,
    required this.cooldownGroupId,
    required this.damageType,
    this.procs = const <WeaponProc>[],
    required this.halfX,
    required this.halfY,
    this.hitPolicy = HitPolicy.oncePerTarget,
    this.sourceKind = DeathSourceKind.spellImpact,
    this.impactEffectId = SpellImpactId.unknown,
    required this.targetX,
    required this.targetY,
    required this.commitTick,
    required this.windupTicks,
    required this.activeTicks,
    required this.recoveryTicks,
    required this.tick,
  });

  final AbilityKey abilityId;
  final AbilitySlot slot;
  final int damage100;
  final int critChanceBp;
  final int staminaCost100;
  final int manaCost100;
  final int cooldownTicks;
  final int cooldownGroupId;
  final DamageType damageType;
  final List<WeaponProc> procs;
  final double halfX;
  final double halfY;
  final HitPolicy hitPolicy;
  final DeathSourceKind sourceKind;
  final SpellImpactId impactEffectId;
  final double targetX;
  final double targetY;
  final int commitTick;
  final int windupTicks;
  final int activeTicks;
  final int recoveryTicks;
  final int tick;
}

class TargetPointIntentStore extends SparseSet {
  final List<AbilityKey> abilityId = <AbilityKey>[];
  final List<AbilitySlot> slot = <AbilitySlot>[];
  final List<int> damage100 = <int>[];
  final List<int> critChanceBp = <int>[];
  final List<int> staminaCost100 = <int>[];
  final List<int> manaCost100 = <int>[];
  final List<int> cooldownTicks = <int>[];
  final List<int> cooldownGroupId = <int>[];
  final List<DamageType> damageType = <DamageType>[];
  final List<List<WeaponProc>> procs = <List<WeaponProc>>[];
  final List<double> halfX = <double>[];
  final List<double> halfY = <double>[];
  final List<HitPolicy> hitPolicy = <HitPolicy>[];
  final List<DeathSourceKind> sourceKind = <DeathSourceKind>[];
  final List<SpellImpactId> impactEffectId = <SpellImpactId>[];
  final List<double> targetX = <double>[];
  final List<double> targetY = <double>[];
  final List<int> commitTick = <int>[];
  final List<int> windupTicks = <int>[];
  final List<int> activeTicks = <int>[];
  final List<int> recoveryTicks = <int>[];
  final List<int> tick = <int>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  void set(EntityId entity, TargetPointIntentDef def) {
    assert(
      has(entity),
      'TargetPointIntentStore.set called for entity without TargetPointIntentStore; add the component at spawn time.',
    );
    final i = indexOf(entity);
    abilityId[i] = def.abilityId;
    slot[i] = def.slot;
    damage100[i] = def.damage100;
    critChanceBp[i] = def.critChanceBp;
    staminaCost100[i] = def.staminaCost100;
    manaCost100[i] = def.manaCost100;
    cooldownTicks[i] = def.cooldownTicks;
    cooldownGroupId[i] = def.cooldownGroupId;
    damageType[i] = def.damageType;
    procs[i] = def.procs;
    halfX[i] = def.halfX;
    halfY[i] = def.halfY;
    hitPolicy[i] = def.hitPolicy;
    sourceKind[i] = def.sourceKind;
    impactEffectId[i] = def.impactEffectId;
    targetX[i] = def.targetX;
    targetY[i] = def.targetY;
    commitTick[i] = def.commitTick;
    windupTicks[i] = def.windupTicks;
    activeTicks[i] = def.activeTicks;
    recoveryTicks[i] = def.recoveryTicks;
    tick[i] = def.tick;
  }

  @override
  void onDenseAdded(int denseIndex) {
    abilityId.add('derf.fire_explosion');
    slot.add(AbilitySlot.projectile);
    damage100.add(0);
    critChanceBp.add(0);
    staminaCost100.add(0);
    manaCost100.add(0);
    cooldownTicks.add(0);
    cooldownGroupId.add(0);
    damageType.add(DamageType.fire);
    procs.add(const <WeaponProc>[]);
    halfX.add(0.0);
    halfY.add(0.0);
    hitPolicy.add(HitPolicy.oncePerTarget);
    sourceKind.add(DeathSourceKind.spellImpact);
    impactEffectId.add(SpellImpactId.unknown);
    targetX.add(0.0);
    targetY.add(0.0);
    commitTick.add(-1);
    windupTicks.add(0);
    activeTicks.add(0);
    recoveryTicks.add(0);
    tick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    abilityId[removeIndex] = abilityId[lastIndex];
    slot[removeIndex] = slot[lastIndex];
    damage100[removeIndex] = damage100[lastIndex];
    critChanceBp[removeIndex] = critChanceBp[lastIndex];
    staminaCost100[removeIndex] = staminaCost100[lastIndex];
    manaCost100[removeIndex] = manaCost100[lastIndex];
    cooldownTicks[removeIndex] = cooldownTicks[lastIndex];
    cooldownGroupId[removeIndex] = cooldownGroupId[lastIndex];
    damageType[removeIndex] = damageType[lastIndex];
    procs[removeIndex] = procs[lastIndex];
    halfX[removeIndex] = halfX[lastIndex];
    halfY[removeIndex] = halfY[lastIndex];
    hitPolicy[removeIndex] = hitPolicy[lastIndex];
    sourceKind[removeIndex] = sourceKind[lastIndex];
    impactEffectId[removeIndex] = impactEffectId[lastIndex];
    targetX[removeIndex] = targetX[lastIndex];
    targetY[removeIndex] = targetY[lastIndex];
    commitTick[removeIndex] = commitTick[lastIndex];
    windupTicks[removeIndex] = windupTicks[lastIndex];
    activeTicks[removeIndex] = activeTicks[lastIndex];
    recoveryTicks[removeIndex] = recoveryTicks[lastIndex];
    tick[removeIndex] = tick[lastIndex];

    abilityId.removeLast();
    slot.removeLast();
    damage100.removeLast();
    critChanceBp.removeLast();
    staminaCost100.removeLast();
    manaCost100.removeLast();
    cooldownTicks.removeLast();
    cooldownGroupId.removeLast();
    damageType.removeLast();
    procs.removeLast();
    halfX.removeLast();
    halfY.removeLast();
    hitPolicy.removeLast();
    sourceKind.removeLast();
    impactEffectId.removeLast();
    targetX.removeLast();
    targetY.removeLast();
    commitTick.removeLast();
    windupTicks.removeLast();
    activeTicks.removeLast();
    recoveryTicks.removeLast();
    tick.removeLast();
  }
}
