import '../entity_id.dart';
import '../sparse_set.dart';

class HitOnceStore extends SparseSet {
  final List<int> count = <int>[];
  final List<EntityId> hit0 = <EntityId>[];
  final List<EntityId> hit1 = <EntityId>[];
  final List<EntityId> hit2 = <EntityId>[];
  final List<EntityId> hit3 = <EntityId>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  bool hasHit(EntityId entity, EntityId target) {
    final i = indexOf(entity);
    final c = count[i];
    if (c <= 0) return false;
    if (hit0[i] == target) return true;
    if (c <= 1) return false;
    if (hit1[i] == target) return true;
    if (c <= 2) return false;
    if (hit2[i] == target) return true;
    if (c <= 3) return false;
    return hit3[i] == target;
  }

  void markHit(EntityId entity, EntityId target) {
    final i = indexOf(entity);
    var c = count[i];
    if (c <= 0) {
      hit0[i] = target;
      count[i] = 1;
      return;
    }
    if (c == 1) {
      hit1[i] = target;
      count[i] = 2;
      return;
    }
    if (c == 2) {
      hit2[i] = target;
      count[i] = 3;
      return;
    }
    if (c == 3) {
      hit3[i] = target;
      count[i] = 4;
      return;
    }
    // Saturate: in V0 we don't expect more than a few hits per swing.
  }

  @override
  void onDenseAdded(int denseIndex) {
    count.add(0);
    hit0.add(0);
    hit1.add(0);
    hit2.add(0);
    hit3.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    count[removeIndex] = count[lastIndex];
    hit0[removeIndex] = hit0[lastIndex];
    hit1[removeIndex] = hit1[lastIndex];
    hit2[removeIndex] = hit2[lastIndex];
    hit3[removeIndex] = hit3[lastIndex];

    count.removeLast();
    hit0.removeLast();
    hit1.removeLast();
    hit2.removeLast();
    hit3.removeLast();
  }
}

