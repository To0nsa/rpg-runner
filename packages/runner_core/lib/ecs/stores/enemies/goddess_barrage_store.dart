import '../../../snapshots/enums.dart';
import '../../sparse_set.dart';

/// Per-cast hand sequence and safe return position, owned only by Goddess AI.
class GoddessBarrageStore extends SparseSet {
  final List<int> commitTick = [];
  final List<int> firstHandTick = [];
  final List<int> nextHand = [];
  final List<int> returnTick = [];
  final List<double> originX = [];
  final List<double> originY = [];
  final List<Facing> originFacing = [];
  final List<bool> fromLeft = [];
  final List<bool> positioned = [];
  final List<bool> hovering = [];

  @override
  void onDenseAdded(int denseIndex) {
    commitTick.add(-1);
    firstHandTick.add(-1);
    nextHand.add(0);
    returnTick.add(-1);
    originX.add(0);
    originY.add(0);
    originFacing.add(Facing.left);
    fromLeft.add(true);
    positioned.add(false);
    hovering.add(false);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    commitTick[removeIndex] = commitTick[lastIndex];
    firstHandTick[removeIndex] = firstHandTick[lastIndex];
    nextHand[removeIndex] = nextHand[lastIndex];
    returnTick[removeIndex] = returnTick[lastIndex];
    originX[removeIndex] = originX[lastIndex];
    originY[removeIndex] = originY[lastIndex];
    originFacing[removeIndex] = originFacing[lastIndex];
    fromLeft[removeIndex] = fromLeft[lastIndex];
    positioned[removeIndex] = positioned[lastIndex];
    hovering[removeIndex] = hovering[lastIndex];
    commitTick.removeLast();
    firstHandTick.removeLast();
    nextHand.removeLast();
    returnTick.removeLast();
    originX.removeLast();
    originY.removeLast();
    originFacing.removeLast();
    fromLeft.removeLast();
    positioned.removeLast();
    hovering.removeLast();
  }
}
