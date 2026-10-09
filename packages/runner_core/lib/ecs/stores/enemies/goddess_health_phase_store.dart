import '../../sparse_set.dart';

/// One barrage per 75/50/25% health crossing, retained beyond each cast/return.
/// Earned phases survive healing and interruptions; destruction resets them.
class GoddessHealthPhaseStore extends SparseSet {
  final List<int> reached = [];
  final List<int> committed = [];

  @override
  void onDenseAdded(int denseIndex) {
    reached.add(0);
    committed.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    reached[removeIndex] = reached[lastIndex];
    committed[removeIndex] = committed[lastIndex];
    reached.removeLast();
    committed.removeLast();
  }
}
