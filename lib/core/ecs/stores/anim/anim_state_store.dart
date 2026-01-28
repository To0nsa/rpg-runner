import '../../../snapshots/enums.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Per-entity animation state computed by [AnimSystem].
class AnimStateStore extends SparseSet {
  /// Current animation key (idle, run, hit, death, etc.).
  final List<AnimKey> anim = <AnimKey>[];

  /// Frame offset for the current animation (ticks since anim start).
  final List<int> animFrame = <int>[];

  void add(EntityId entity) {
    final i = addEntity(entity);
    anim[i] = AnimKey.idle;
    animFrame[i] = 0;
  }

  @override
  void onDenseAdded(int denseIndex) {
    anim.add(AnimKey.idle);
    animFrame.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    anim[removeIndex] = anim[lastIndex];
    animFrame[removeIndex] = animFrame[lastIndex];

    anim.removeLast();
    animFrame.removeLast();
  }
}
