import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Fourth-attack cadence and pending reactive teleport, cleared with the actor.
class GoddessDodgeStore extends SparseSet {
  final List<int> attacks = [];
  final List<int> startTick = [];
  final List<int> executeTick = [];
  final List<EntityId> player = [];

  /// A combo counts once; evading it also rejects that activation's follow-ups.
  /// World-assigned combo activation IDs never recycle during a run.
  final List<Map<(EntityId, int), bool>> comboDodged = [];

  @override
  void onDenseAdded(int denseIndex) {
    attacks.add(0);
    startTick.add(-1);
    executeTick.add(-1);
    player.add(-1);
    comboDodged.add({});
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    attacks[removeIndex] = attacks[lastIndex];
    startTick[removeIndex] = startTick[lastIndex];
    executeTick[removeIndex] = executeTick[lastIndex];
    player[removeIndex] = player[lastIndex];
    comboDodged[removeIndex] = comboDodged[lastIndex];
    attacks.removeLast();
    startTick.removeLast();
    executeTick.removeLast();
    player.removeLast();
    comboDodged.removeLast();
  }
}
