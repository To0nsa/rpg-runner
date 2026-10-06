import '../../combat/combat_geometry.dart';
import '../../snapshots/enums.dart';
import '../../combat/damage_type.dart';
import '../../combat/knockback.dart';
import '../../combat/damage_credit.dart';
import '../../combat/faction.dart';
import '../../combat/hit_target_policy.dart';
import '../../projectiles/projectile_id.dart';
import '../../weapons/weapon_proc.dart';
import '../../traps/trap_placement.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class ProjectileEntityDef {
  const ProjectileEntityDef({
    required this.projectileId,
    required this.faction,
    required this.owner,
    required this.dirX,
    required this.dirY,
    required this.speedUnitsPerSecond,
    required this.damage100,
    this.critChanceBp = 0,
    required this.damageType,
    this.procs = const <WeaponProc>[],
    this.knockback,
    this.pierce = false,
    this.maxPierceHits = 1,
    this.usePhysics = false,
    this.firstHitTick = 0,
    this.spawnTick,
    this.targetPolicy = HitTargetPolicy.hostile,
    this.credit = DamageCredit.none,
    this.sourceTrap,
  }) : assert(maxPierceHits > 0, 'maxPierceHits must be > 0');

  final ProjectileId projectileId;
  final Faction faction;
  final EntityId owner;
  final double dirX;
  final double dirY;
  final double speedUnitsPerSecond;

  /// Fixed-point: 100 = 1.0
  final int damage100;

  /// Critical strike chance in basis points (100 = 1%).
  final int critChanceBp;
  final DamageType damageType;
  final List<WeaponProc> procs;
  final KnockbackSource? knockback;
  final bool pierce;
  final int maxPierceHits;

  /// If true, this projectile is moved by core physics (GravitySystem +
  /// terrain motion authority) rather than [ProjectileSystem].
  final bool usePhysics;

  /// Environmental launches defer collision until their first moved tick.
  final int firstHitTick;
  final int? spawnTick;
  final HitTargetPolicy targetPolicy;
  final DamageCredit credit;
  final TrapSourceRef? sourceTrap;
}

/// Immutable metadata for active projectiles.
///
/// Combines with `Transform` for position and `ColliderAabb` values for the
/// projectile's direction-oriented attack-capsule dimensions.
class ProjectileStore extends SparseSet {
  final List<ProjectileId> projectileId = <ProjectileId>[];
  final List<Faction> faction = <Faction>[];
  final List<EntityId> owner = <EntityId>[];
  final List<double> dirX = <double>[];
  final List<double> dirY = <double>[];
  final List<double> speedUnitsPerSecond = <double>[];

  /// Fixed-point: 100 = 1.0
  final List<int> damage100 = <int>[];
  final List<int> critChanceBp = <int>[];
  final List<DamageType> damageType = <DamageType>[];
  final List<List<WeaponProc>> procs = <List<WeaponProc>>[];
  final List<KnockbackSource?> knockback = [];
  final List<bool> pierce = <bool>[];
  final List<int> maxPierceHits = <int>[];
  final List<bool> usePhysics = <bool>[];
  final List<int> firstHitTick = <int>[];
  final List<int?> spawnTick = [];
  final List<CombatCapsule?> combatCapsule = [];
  final List<AnimKey> anim = [];
  final List<int> animFrame = [];
  final List<HitTargetPolicy> targetPolicy = <HitTargetPolicy>[];
  final List<DamageCredit> credit = [];
  final List<TrapSourceRef?> sourceTrap = <TrapSourceRef?>[];

  /// Start-of-step transform position, null until the first motion capture.
  /// New ordinary launches use their current position for launch-tick overlap.
  final List<double?> previousX = <double?>[];
  final List<double?> previousY = <double?>[];

  void add(EntityId entity, ProjectileEntityDef def) {
    final i = addEntity(entity);
    projectileId[i] = def.projectileId;
    faction[i] = def.faction;
    owner[i] = def.owner;
    dirX[i] = def.dirX;
    dirY[i] = def.dirY;
    speedUnitsPerSecond[i] = def.speedUnitsPerSecond;
    damage100[i] = def.damage100;
    critChanceBp[i] = def.critChanceBp;
    damageType[i] = def.damageType;
    procs[i] = def.procs;
    knockback[i] = def.knockback;
    pierce[i] = def.pierce;
    maxPierceHits[i] = def.maxPierceHits;
    usePhysics[i] = def.usePhysics;
    firstHitTick[i] = def.firstHitTick;
    spawnTick[i] = def.spawnTick;
    targetPolicy[i] = def.targetPolicy;
    credit[i] = def.credit;
    sourceTrap[i] = def.sourceTrap;
    previousX[i] = null;
    previousY[i] = null;
  }

  @override
  void onDenseAdded(int denseIndex) {
    projectileId.add(ProjectileId.unknown);
    faction.add(Faction.player);
    owner.add(0);
    dirX.add(1.0);
    dirY.add(0.0);
    speedUnitsPerSecond.add(0.0);
    damage100.add(0);
    critChanceBp.add(0);
    damageType.add(DamageType.physical);
    procs.add(const <WeaponProc>[]);
    knockback.add(null);
    pierce.add(false);
    maxPierceHits.add(1);
    usePhysics.add(false);
    firstHitTick.add(0);
    spawnTick.add(null);
    combatCapsule.add(null);
    anim.add(AnimKey.idle);
    animFrame.add(0);
    targetPolicy.add(HitTargetPolicy.hostile);
    credit.add(DamageCredit.none);
    sourceTrap.add(null);
    previousX.add(null);
    previousY.add(null);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    projectileId[removeIndex] = projectileId[lastIndex];
    faction[removeIndex] = faction[lastIndex];
    owner[removeIndex] = owner[lastIndex];
    dirX[removeIndex] = dirX[lastIndex];
    dirY[removeIndex] = dirY[lastIndex];
    speedUnitsPerSecond[removeIndex] = speedUnitsPerSecond[lastIndex];
    damage100[removeIndex] = damage100[lastIndex];
    critChanceBp[removeIndex] = critChanceBp[lastIndex];
    damageType[removeIndex] = damageType[lastIndex];
    procs[removeIndex] = procs[lastIndex];
    knockback[removeIndex] = knockback[lastIndex];
    pierce[removeIndex] = pierce[lastIndex];
    maxPierceHits[removeIndex] = maxPierceHits[lastIndex];
    usePhysics[removeIndex] = usePhysics[lastIndex];
    firstHitTick[removeIndex] = firstHitTick[lastIndex];
    spawnTick[removeIndex] = spawnTick[lastIndex];
    combatCapsule[removeIndex] = combatCapsule[lastIndex];
    anim[removeIndex] = anim[lastIndex];
    animFrame[removeIndex] = animFrame[lastIndex];
    targetPolicy[removeIndex] = targetPolicy[lastIndex];
    credit[removeIndex] = credit[lastIndex];
    sourceTrap[removeIndex] = sourceTrap[lastIndex];
    previousX[removeIndex] = previousX[lastIndex];
    previousY[removeIndex] = previousY[lastIndex];

    projectileId.removeLast();
    faction.removeLast();
    owner.removeLast();
    dirX.removeLast();
    dirY.removeLast();
    speedUnitsPerSecond.removeLast();
    damage100.removeLast();
    critChanceBp.removeLast();
    damageType.removeLast();
    procs.removeLast();
    knockback.removeLast();
    pierce.removeLast();
    maxPierceHits.removeLast();
    usePhysics.removeLast();
    firstHitTick.removeLast();
    spawnTick.removeLast();
    combatCapsule.removeLast();
    anim.removeLast();
    animFrame.removeLast();
    targetPolicy.removeLast();
    credit.removeLast();
    sourceTrap.removeLast();
    previousX.removeLast();
    previousY.removeLast();
  }
}
