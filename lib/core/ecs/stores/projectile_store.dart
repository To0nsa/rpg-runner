import '../../combat/faction.dart';
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
  });

  final ProjectileId projectileId;
  final Faction faction;
  final EntityId owner;
  final double dirX;
  final double dirY;
  final double speedUnitsPerSecond;
  final double damage;
}

class ProjectileStore extends SparseSet {
  final List<ProjectileId> projectileId = <ProjectileId>[];
  final List<Faction> faction = <Faction>[];
  final List<EntityId> owner = <EntityId>[];
  final List<double> dirX = <double>[];
  final List<double> dirY = <double>[];
  final List<double> speedUnitsPerSecond = <double>[];
  final List<double> damage = <double>[];

  void add(EntityId entity, ProjectileDef def) {
    final i = addEntity(entity);
    projectileId[i] = def.projectileId;
    faction[i] = def.faction;
    owner[i] = def.owner;
    dirX[i] = def.dirX;
    dirY[i] = def.dirY;
    speedUnitsPerSecond[i] = def.speedUnitsPerSecond;
    damage[i] = def.damage;
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

    projectileId.removeLast();
    faction.removeLast();
    owner.removeLast();
    dirX.removeLast();
    dirY.removeLast();
    speedUnitsPerSecond.removeLast();
    damage.removeLast();
  }
}
