import '../../combat/damage_type.dart';
import '../../combat/faction.dart';
import '../../projectiles/projectile_id.dart';
import '../../weapons/weapon_proc.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class ProjectileDef {
  const ProjectileDef({
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
    this.pierce = false,
    this.maxPierceHits = 1,
    this.usePhysics = false,
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
  final bool pierce;
  final int maxPierceHits;

  /// If true, this projectile is moved by core physics (GravitySystem +
  /// CollisionSystem) rather than [ProjectileSystem].
  final bool usePhysics;
}

/// Immutable metadata for active projectiles.
///
/// Combines with `Transform` (for position) and `ColliderAabb` (for hit detection).
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
  final List<bool> pierce = <bool>[];
  final List<int> maxPierceHits = <int>[];
  final List<bool> usePhysics = <bool>[];

  void add(EntityId entity, ProjectileDef def) {
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
    pierce[i] = def.pierce;
    maxPierceHits[i] = def.maxPierceHits;
    usePhysics[i] = def.usePhysics;
  }

  @override
  void onDenseAdded(int denseIndex) {
    projectileId.add(ProjectileId.iceBolt);
    faction.add(Faction.player);
    owner.add(0);
    dirX.add(1.0);
    dirY.add(0.0);
    speedUnitsPerSecond.add(0.0);
    damage100.add(0);
    critChanceBp.add(0);
    damageType.add(DamageType.physical);
    procs.add(const <WeaponProc>[]);
    pierce.add(false);
    maxPierceHits.add(1);
    usePhysics.add(false);
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
    pierce[removeIndex] = pierce[lastIndex];
    maxPierceHits[removeIndex] = maxPierceHits[lastIndex];
    usePhysics[removeIndex] = usePhysics[lastIndex];

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
    pierce.removeLast();
    maxPierceHits.removeLast();
    usePhysics.removeLast();
  }
}
