import '../../collision/terrain/terrain_motion_request.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

/// Temporary encounter confinement, enforced by the terrain motion controller.
class ActorMotionBoundsStore extends SparseSet {
  final List<TerrainHorizontalBounds?> bounds = [];
  final List<bool> frozen = [];

  void add(
    EntityId entity,
    TerrainHorizontalBounds value, {
    bool freeze = false,
  }) {
    final i = addEntity(entity);
    bounds[i] = value;
    frozen[i] = freeze;
  }

  @override
  void onDenseAdded(int denseIndex) {
    bounds.add(null);
    frozen.add(false);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    bounds[removeIndex] = bounds[lastIndex];
    bounds.removeLast();
    frozen[removeIndex] = frozen[lastIndex];
    frozen.removeLast();
  }
}
