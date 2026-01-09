import '../../combat/damage_type.dart';
import '../../combat/faction.dart';
import '../../combat/status/status.dart';
import '../../projectiles/projectile_id.dart';
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
    required this.damage,
    required this.damageType,
    required this.statusProfileId,
    this.usePhysics = false,
  });

  final ProjectileId projectileId;
  final Faction faction;
  final EntityId owner;
  final double dirX;
  final double dirY;
  final double speedUnitsPerSecond;
  final double damage;
  final DamageType damageType;
  final StatusProfileId statusProfileId;

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
  final List<double> damage = <double>[];
  final List<DamageType> damageType = <DamageType>[];
  final List<StatusProfileId> statusProfileId = <StatusProfileId>[];
  final List<bool> usePhysics = <bool>[];

  void add(EntityId entity, ProjectileDef def) {
    final i = addEntity(entity);
    projectileId[i] = def.projectileId;
    faction[i] = def.faction;
    owner[i] = def.owner;
    dirX[i] = def.dirX;
    dirY[i] = def.dirY;
    speedUnitsPerSecond[i] = def.speedUnitsPerSecond;
    damage[i] = def.damage;
    damageType[i] = def.damageType;
    statusProfileId[i] = def.statusProfileId;
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
    damage.add(0.0);
    damageType.add(DamageType.physical);
    statusProfileId.add(StatusProfileId.none);
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
    damage[removeIndex] = damage[lastIndex];
    damageType[removeIndex] = damageType[lastIndex];
    statusProfileId[removeIndex] = statusProfileId[lastIndex];
    usePhysics[removeIndex] = usePhysics[lastIndex];

    projectileId.removeLast();
    faction.removeLast();
    owner.removeLast();
    dirX.removeLast();
    dirY.removeLast();
    speedUnitsPerSecond.removeLast();
    damage.removeLast();
    damageType.removeLast();
    statusProfileId.removeLast();
    usePhysics.removeLast();
  }
}
