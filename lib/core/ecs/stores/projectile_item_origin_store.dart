import '../../projectiles/projectile_item_id.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class ProjectileItemOriginDef {
  const ProjectileItemOriginDef({required this.projectileItemId});

  final ProjectileItemId projectileItemId;
}

/// Metadata for projectile entities (spawned from projectile slot items).
class ProjectileItemOriginStore extends SparseSet {
  final List<ProjectileItemId> projectileItemId = <ProjectileItemId>[];

  void add(EntityId entity, ProjectileItemOriginDef def) {
    final i = addEntity(entity);
    projectileItemId[i] = def.projectileItemId;
  }

  @override
  void onDenseAdded(int denseIndex) {
    projectileItemId.add(ProjectileItemId.iceBolt);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    projectileItemId[removeIndex] = projectileItemId[lastIndex];
    projectileItemId.removeLast();
  }
}
