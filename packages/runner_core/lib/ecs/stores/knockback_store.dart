import '../entity_id.dart';
import '../sparse_set.dart';

/// Collision-resolved shove state; the last accepted hit replaces an old shove.
class KnockbackStore extends SparseSet {
  final List<double> signedDistance = [];
  final List<int> startTick = [];
  final List<int> durationTicks = [];

  void set(
    EntityId entity, {
    required double distance,
    required int start,
    required int duration,
  }) {
    final i = addEntity(entity);
    signedDistance[i] = distance;
    startTick[i] = start;
    durationTicks[i] = duration;
  }

  @override
  void onDenseAdded(int denseIndex) {
    signedDistance.add(0);
    startTick.add(0);
    durationTicks.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    signedDistance[removeIndex] = signedDistance[lastIndex];
    startTick[removeIndex] = startTick[lastIndex];
    durationTicks[removeIndex] = durationTicks[lastIndex];
    signedDistance.removeLast();
    startTick.removeLast();
    durationTicks.removeLast();
  }
}
