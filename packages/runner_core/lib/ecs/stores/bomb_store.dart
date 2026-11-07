import '../entity_id.dart';
import '../sparse_set.dart';

/// Fuse state attached to a ballistic projectile. The projectile retains the
/// committed payload and attribution through landing and its visible explosion.
class BombStore extends SparseSet {
  final List<int> explodeTick = [];
  final List<double> radius = [];
  final List<bool> exploded = [];
  void add(
    EntityId entity, {
    required int explodeTick,
    required double radius,
  }) {
    final i = addEntity(entity);
    this.explodeTick[i] = explodeTick;
    this.radius[i] = radius;
    exploded[i] = false;
  }

  @override
  void onDenseAdded(int index) {
    explodeTick.add(0);
    radius.add(0);
    exploded.add(false);
  }

  @override
  void onSwapRemove(int index, int last) {
    explodeTick[index] = explodeTick[last];
    radius[index] = radius[last];
    exploded[index] = exploded[last];
    explodeTick.removeLast();
    radius.removeLast();
    exploded.removeLast();
  }
}
