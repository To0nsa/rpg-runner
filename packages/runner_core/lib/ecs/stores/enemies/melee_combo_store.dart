import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Combo state for melee enemies that can chain follow-up attacks.
///
/// `armed == true` means the next committed melee strike should use the
/// configured follow-up attack variant.
class MeleeComboStore extends SparseSet {
  final List<bool> armed = <bool>[];

  void add(EntityId entity) {
    final i = addEntity(entity);
    armed[i] = false;
  }

  @override
  void onDenseAdded(int denseIndex) {
    armed.add(false);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    armed[removeIndex] = armed[lastIndex];
    armed.removeLast();
  }
}
