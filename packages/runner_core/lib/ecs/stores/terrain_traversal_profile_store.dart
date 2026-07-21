import '../../collision/terrain/terrain_traversal_profile.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

/// Immutable per-actor terrain policy attached only under terrain authority.
class TerrainTraversalProfileStore extends SparseSet {
  final List<TerrainTraversalProfile> profile = <TerrainTraversalProfile>[];

  void add(EntityId entity, TerrainTraversalProfile value) {
    final index = addEntity(entity);
    profile[index] = value;
  }

  @override
  void onDenseAdded(int denseIndex) {
    profile.add(
      createEloiseTerrainTraversalProfile(
        enabled: false,
        isKinematic: false,
        useGravity: false,
        gravityScale: 0,
        collideCeilings: false,
        collideLeftWalls: false,
        collideRightWalls: false,
      ),
    );
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    profile[removeIndex] = profile[lastIndex];
    profile.removeLast();
  }
}
