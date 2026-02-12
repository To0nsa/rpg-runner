import '../../projectiles/projectile_id.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class ProjectileOriginDef {
  const ProjectileOriginDef({required this.projectileId});

  final ProjectileId projectileId;
}

/// Metadata for projectile entities (spawned from projectile slot items).
class ProjectileOriginStore extends SparseSet {
  final List<ProjectileId> projectileId = <ProjectileId>[];

  void add(EntityId entity, ProjectileOriginDef def) {
    final i = addEntity(entity);
    projectileId[i] = def.projectileId;
  }

  @override
  void onDenseAdded(int denseIndex) {
    projectileId.add(ProjectileId.unknown);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    projectileId[removeIndex] = projectileId[lastIndex];
    projectileId.removeLast();
  }
}
