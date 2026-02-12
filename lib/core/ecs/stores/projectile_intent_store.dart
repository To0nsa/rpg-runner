import '../../abilities/ability_def.dart';
import '../../combat/damage_type.dart';
import '../../projectiles/projectile_id.dart';
import '../../weapons/weapon_proc.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class ProjectileIntentDef {
  const ProjectileIntentDef({
    required this.projectileId,
    required this.abilityId,
    required this.slot,
    required this.damage100,
    this.critChanceBp = 0,
    required this.staminaCost100,
    required this.manaCost100,
    required this.cooldownTicks,
    required this.cooldownGroupId,
    required this.pierce,
    required this.maxPierceHits,
    required this.damageType,
    this.procs = const <WeaponProc>[],
    required this.ballistic,
    required this.gravityScale,
    this.speedScaleBp = 10000,
    required this.dirX,
    required this.dirY,
    required this.fallbackDirX,
    required this.fallbackDirY,
    required this.originOffset,
    required this.commitTick,
    required this.windupTicks,
    required this.activeTicks,
    required this.recoveryTicks,
    required this.tick,
  });

  final ProjectileId projectileId;
  final AbilityKey abilityId;
  final AbilitySlot slot;
  final int damage100;
  final int critChanceBp;
  final int staminaCost100;
  final int manaCost100;
  final int cooldownTicks;
  final int cooldownGroupId;
  final bool pierce;
  final int maxPierceHits;
  final DamageType damageType;
  final List<WeaponProc> procs;
  final bool ballistic;
  final double gravityScale;
  final int speedScaleBp;

  final double dirX;
  final double dirY;
  final double fallbackDirX;
  final double fallbackDirY;
  final double originOffset;
  final int commitTick;
  final int windupTicks;
  final int activeTicks;
  final int recoveryTicks;
  final int tick;
}

/// Per-entity "fire a projectile item this tick" intent.
class ProjectileIntentStore extends SparseSet {
  final List<ProjectileId> projectileId = <ProjectileId>[];
  final List<AbilityKey> abilityId = <AbilityKey>[];
  final List<AbilitySlot> slot = <AbilitySlot>[];
  final List<int> damage100 = <int>[];
  final List<int> critChanceBp = <int>[];
  final List<int> staminaCost100 = <int>[];
  final List<int> manaCost100 = <int>[];
  final List<int> cooldownTicks = <int>[];
  final List<int> cooldownGroupId = <int>[];
  final List<bool> pierce = <bool>[];
  final List<int> maxPierceHits = <int>[];
  final List<DamageType> damageType = <DamageType>[];
  final List<List<WeaponProc>> procs = <List<WeaponProc>>[];
  final List<bool> ballistic = <bool>[];
  final List<double> gravityScale = <double>[];
  final List<int> speedScaleBp = <int>[];

  final List<double> dirX = <double>[];
  final List<double> dirY = <double>[];
  final List<double> fallbackDirX = <double>[];
  final List<double> fallbackDirY = <double>[];
  final List<double> originOffset = <double>[];
  final List<int> commitTick = <int>[];
  final List<int> windupTicks = <int>[];
  final List<int> activeTicks = <int>[];
  final List<int> recoveryTicks = <int>[];
  final List<int> tick = <int>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  void set(EntityId entity, ProjectileIntentDef def) {
    assert(
      has(entity),
      'ProjectileIntentStore.set called for entity without ProjectileIntentStore; add the component at spawn time.',
    );
    final i = indexOf(entity);
    projectileId[i] = def.projectileId;
    abilityId[i] = def.abilityId;
    slot[i] = def.slot;
    damage100[i] = def.damage100;
    critChanceBp[i] = def.critChanceBp;
    staminaCost100[i] = def.staminaCost100;
    manaCost100[i] = def.manaCost100;
    cooldownTicks[i] = def.cooldownTicks;
    cooldownGroupId[i] = def.cooldownGroupId;
    pierce[i] = def.pierce;
    maxPierceHits[i] = def.maxPierceHits;
    damageType[i] = def.damageType;
    procs[i] = def.procs;
    ballistic[i] = def.ballistic;
    gravityScale[i] = def.gravityScale;
    speedScaleBp[i] = def.speedScaleBp;
    dirX[i] = def.dirX;
    dirY[i] = def.dirY;
    fallbackDirX[i] = def.fallbackDirX;
    fallbackDirY[i] = def.fallbackDirY;
    originOffset[i] = def.originOffset;
    commitTick[i] = def.commitTick;
    windupTicks[i] = def.windupTicks;
    activeTicks[i] = def.activeTicks;
    recoveryTicks[i] = def.recoveryTicks;
    tick[i] = def.tick;
  }

  @override
  void onDenseAdded(int denseIndex) {
    projectileId.add(ProjectileId.unknown);
    abilityId.add('eloise.charged_shot');
    slot.add(AbilitySlot.projectile);
    damage100.add(0);
    critChanceBp.add(0);
    staminaCost100.add(0);
    manaCost100.add(0);
    cooldownTicks.add(0);
    cooldownGroupId.add(0);
    pierce.add(false);
    maxPierceHits.add(1);
    damageType.add(DamageType.ice);
    procs.add(const <WeaponProc>[]);
    ballistic.add(false);
    gravityScale.add(1.0);
    speedScaleBp.add(10000);
    dirX.add(0.0);
    dirY.add(0.0);
    fallbackDirX.add(1.0);
    fallbackDirY.add(0.0);
    originOffset.add(0.0);
    commitTick.add(-1);
    windupTicks.add(0);
    activeTicks.add(0);
    recoveryTicks.add(0);
    tick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    projectileId[removeIndex] = projectileId[lastIndex];
    abilityId[removeIndex] = abilityId[lastIndex];
    slot[removeIndex] = slot[lastIndex];
    damage100[removeIndex] = damage100[lastIndex];
    critChanceBp[removeIndex] = critChanceBp[lastIndex];
    staminaCost100[removeIndex] = staminaCost100[lastIndex];
    manaCost100[removeIndex] = manaCost100[lastIndex];
    cooldownTicks[removeIndex] = cooldownTicks[lastIndex];
    cooldownGroupId[removeIndex] = cooldownGroupId[lastIndex];
    pierce[removeIndex] = pierce[lastIndex];
    maxPierceHits[removeIndex] = maxPierceHits[lastIndex];
    damageType[removeIndex] = damageType[lastIndex];
    procs[removeIndex] = procs[lastIndex];
    ballistic[removeIndex] = ballistic[lastIndex];
    gravityScale[removeIndex] = gravityScale[lastIndex];
    speedScaleBp[removeIndex] = speedScaleBp[lastIndex];
    dirX[removeIndex] = dirX[lastIndex];
    dirY[removeIndex] = dirY[lastIndex];
    fallbackDirX[removeIndex] = fallbackDirX[lastIndex];
    fallbackDirY[removeIndex] = fallbackDirY[lastIndex];
    originOffset[removeIndex] = originOffset[lastIndex];
    commitTick[removeIndex] = commitTick[lastIndex];
    windupTicks[removeIndex] = windupTicks[lastIndex];
    activeTicks[removeIndex] = activeTicks[lastIndex];
    recoveryTicks[removeIndex] = recoveryTicks[lastIndex];
    tick[removeIndex] = tick[lastIndex];

    projectileId.removeLast();
    abilityId.removeLast();
    slot.removeLast();
    damage100.removeLast();
    critChanceBp.removeLast();
    staminaCost100.removeLast();
    manaCost100.removeLast();
    cooldownTicks.removeLast();
    cooldownGroupId.removeLast();
    pierce.removeLast();
    maxPierceHits.removeLast();
    damageType.removeLast();
    procs.removeLast();
    ballistic.removeLast();
    gravityScale.removeLast();
    speedScaleBp.removeLast();
    dirX.removeLast();
    dirY.removeLast();
    fallbackDirX.removeLast();
    fallbackDirY.removeLast();
    originOffset.removeLast();
    commitTick.removeLast();
    windupTicks.removeLast();
    activeTicks.removeLast();
    recoveryTicks.removeLast();
    tick.removeLast();
  }
}
