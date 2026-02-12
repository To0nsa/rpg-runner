import '../../projectiles/projectile_id.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class ProjectileItemOriginDef {
  const ProjectileItemOriginDef({required this.projectileId});

  final ProjectileId projectileId;
}

/// Metadata for projectile entities (spawned from projectile slot items).
class ProjectileItemOriginStore extends SparseSet {
  final List<ProjectileId> projectileId = <ProjectileId>[];

  void add(EntityId entity, ProjectileItemOriginDef def) {
    final i = addEntity(entity);
    projectileId[i] = def.projectileId;
  }

  @override
  void onDenseAdded(int denseIndex) {
    projectileId.add(ProjectileId.iceBolt);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    projectileId[removeIndex] = projectileId[lastIndex];
    projectileId.removeLast();
  }
}
