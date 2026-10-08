import '../../../snapshots/enums.dart';
import '../../sparse_set.dart';

/// Per-cast hand sequence and collision-resolved return, owned only by Goddess AI.
class GoddessBarrageStore extends SparseSet {
  final List<int> commitTick = [];
  final List<int> firstHandTick = [];
  final List<int> nextHand = [];
  final List<int> returnTick = [];
  final List<int> returnDeadlineTick = [];
  final List<double> originX = [];
  final List<double> originY = [];
  final List<Facing> originFacing = [];
  final List<bool> fromLeft = [];
  final List<bool> positioned = [];
  final List<bool> hovering = [];
  final List<bool> returning = [];

  @override
  void onDenseAdded(int denseIndex) {
    commitTick.add(-1);
    firstHandTick.add(-1);
    nextHand.add(0);
    returnTick.add(-1);
    returnDeadlineTick.add(-1);
    originX.add(0);
    originY.add(0);
    originFacing.add(Facing.left);
    fromLeft.add(true);
    positioned.add(false);
    hovering.add(false);
    returning.add(false);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    commitTick[removeIndex] = commitTick[lastIndex];
    firstHandTick[removeIndex] = firstHandTick[lastIndex];
    nextHand[removeIndex] = nextHand[lastIndex];
    returnTick[removeIndex] = returnTick[lastIndex];
    returnDeadlineTick[removeIndex] = returnDeadlineTick[lastIndex];
    originX[removeIndex] = originX[lastIndex];
    originY[removeIndex] = originY[lastIndex];
    originFacing[removeIndex] = originFacing[lastIndex];
    fromLeft[removeIndex] = fromLeft[lastIndex];
    positioned[removeIndex] = positioned[lastIndex];
    hovering[removeIndex] = hovering[lastIndex];
    returning[removeIndex] = returning[lastIndex];
    commitTick.removeLast();
    firstHandTick.removeLast();
    nextHand.removeLast();
    returnTick.removeLast();
    returnDeadlineTick.removeLast();
    originX.removeLast();
    originY.removeLast();
    originFacing.removeLast();
    fromLeft.removeLast();
    positioned.removeLast();
    hovering.removeLast();
    returning.removeLast();
  }
}
