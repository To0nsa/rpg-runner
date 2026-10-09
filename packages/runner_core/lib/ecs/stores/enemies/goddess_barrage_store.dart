import '../../sparse_set.dart';

/// Per-cast hand sequence; the exit is owned by Goddess tactical state.
class GoddessBarrageStore extends SparseSet {
  final List<int> commitTick = [];
  final List<int> firstHandTick = [];
  final List<int> nextHand = [];
  final List<int> endTick = [];
  final List<bool> fromLeft = [];
  final List<bool> positioned = [];
  final List<bool> hovering = [];

  @override
  void onDenseAdded(int denseIndex) {
    commitTick.add(-1);
    firstHandTick.add(-1);
    nextHand.add(0);
    endTick.add(-1);
    fromLeft.add(true);
    positioned.add(false);
    hovering.add(false);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    commitTick[removeIndex] = commitTick[lastIndex];
    firstHandTick[removeIndex] = firstHandTick[lastIndex];
    nextHand[removeIndex] = nextHand[lastIndex];
    endTick[removeIndex] = endTick[lastIndex];
    fromLeft[removeIndex] = fromLeft[lastIndex];
    positioned[removeIndex] = positioned[lastIndex];
    hovering[removeIndex] = hovering[lastIndex];
    commitTick.removeLast();
    firstHandTick.removeLast();
    nextHand.removeLast();
    endTick.removeLast();
    fromLeft.removeLast();
    positioned.removeLast();
    hovering.removeLast();
  }
}
