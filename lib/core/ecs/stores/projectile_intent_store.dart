import '../../abilities/ability_def.dart';
import '../../combat/damage_type.dart';
import '../../projectiles/projectile_id.dart';
import '../../projectiles/projectile_item_id.dart';
import '../../weapons/weapon_proc.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class ProjectileIntentDef {
  const ProjectileIntentDef({
    required this.projectileItemId,
    required this.abilityId,
    required this.slot,
    required this.damage100,
    required this.staminaCost100,
    required this.manaCost100,
    required this.cooldownTicks,
    required this.projectileId,
    required this.damageType,
    this.procs = const <WeaponProc>[],
    required this.ballistic,
    required this.gravityScale,
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

  final ProjectileItemId projectileItemId;
  final AbilityKey abilityId;
  final AbilitySlot slot;
  final int damage100;
  final int staminaCost100;
  final int manaCost100;
  final int cooldownTicks;
  final ProjectileId projectileId;
  final DamageType damageType;
  final List<WeaponProc> procs;
  final bool ballistic;
  final double gravityScale;

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
  final List<ProjectileItemId> projectileItemId = <ProjectileItemId>[];
  final List<AbilityKey> abilityId = <AbilityKey>[];
  final List<AbilitySlot> slot = <AbilitySlot>[];
  final List<int> damage100 = <int>[];
  final List<int> staminaCost100 = <int>[];
  final List<int> manaCost100 = <int>[];
  final List<int> cooldownTicks = <int>[];
  final List<ProjectileId> projectileId = <ProjectileId>[];
  final List<DamageType> damageType = <DamageType>[];
  final List<List<WeaponProc>> procs = <List<WeaponProc>>[];
  final List<bool> ballistic = <bool>[];
  final List<double> gravityScale = <double>[];

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
    projectileItemId[i] = def.projectileItemId;
    abilityId[i] = def.abilityId;
    slot[i] = def.slot;
    damage100[i] = def.damage100;
    staminaCost100[i] = def.staminaCost100;
    manaCost100[i] = def.manaCost100;
    cooldownTicks[i] = def.cooldownTicks;
    projectileId[i] = def.projectileId;
    damageType[i] = def.damageType;
    procs[i] = def.procs;
    ballistic[i] = def.ballistic;
    gravityScale[i] = def.gravityScale;
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
    projectileItemId.add(ProjectileItemId.iceBolt);
    abilityId.add('eloise.ice_bolt');
    slot.add(AbilitySlot.projectile);
    damage100.add(0);
    staminaCost100.add(0);
    manaCost100.add(0);
    cooldownTicks.add(0);
    projectileId.add(ProjectileId.iceBolt);
    damageType.add(DamageType.ice);
    procs.add(const <WeaponProc>[]);
    ballistic.add(false);
    gravityScale.add(1.0);
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
    projectileItemId[removeIndex] = projectileItemId[lastIndex];
    abilityId[removeIndex] = abilityId[lastIndex];
    slot[removeIndex] = slot[lastIndex];
    damage100[removeIndex] = damage100[lastIndex];
    staminaCost100[removeIndex] = staminaCost100[lastIndex];
    manaCost100[removeIndex] = manaCost100[lastIndex];
    cooldownTicks[removeIndex] = cooldownTicks[lastIndex];
    projectileId[removeIndex] = projectileId[lastIndex];
    damageType[removeIndex] = damageType[lastIndex];
    procs[removeIndex] = procs[lastIndex];
    ballistic[removeIndex] = ballistic[lastIndex];
    gravityScale[removeIndex] = gravityScale[lastIndex];
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

    projectileItemId.removeLast();
    abilityId.removeLast();
    slot.removeLast();
    damage100.removeLast();
    staminaCost100.removeLast();
    manaCost100.removeLast();
    cooldownTicks.removeLast();
    projectileId.removeLast();
    damageType.removeLast();
    procs.removeLast();
    ballistic.removeLast();
    gravityScale.removeLast();
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
