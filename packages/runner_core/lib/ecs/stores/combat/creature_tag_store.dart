import '../../../combat/creature_tag.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

class CreatureTagDef {
  const CreatureTagDef({this.mask = 0});

  final int mask;
}

/// Broad tag classifications for creatures (enemies + player variants).
class CreatureTagStore extends SparseSet {
  final List<int> tagsMask = <int>[];

  void add(EntityId entity, [CreatureTagDef def = const CreatureTagDef()]) {
    final i = addEntity(entity);
    tagsMask[i] = def.mask;
  }

  bool hasTag(EntityId entity, CreatureTag tag) {
    final i = tryIndexOf(entity);
    if (i == null) return false;
    return (tagsMask[i] & CreatureTagMask.forTag(tag)) != 0;
  }

  void addTag(EntityId entity, CreatureTag tag) {
    final i = tryIndexOf(entity);
    if (i == null) return;
    tagsMask[i] |= CreatureTagMask.forTag(tag);
  }

  @override
  void onDenseAdded(int denseIndex) {
    tagsMask.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    tagsMask[removeIndex] = tagsMask[lastIndex];
    tagsMask.removeLast();
  }
}

