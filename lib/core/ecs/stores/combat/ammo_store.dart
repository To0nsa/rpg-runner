import '../../../weapons/ammo_type.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

class AmmoDef {
  const AmmoDef({this.arrows = 0, this.throwingAxes = 0, this.throwingKnives = 0});

  final int arrows;
  final int throwingAxes;
  final int throwingKnives;

  int countFor(AmmoType type) {
    switch (type) {
      case AmmoType.arrow:
        return arrows;
      case AmmoType.throwingAxe:
        return throwingAxes;
      case AmmoType.throwingKnife:
        return throwingKnives;
    }
  }
}

/// Per-entity ammo pools for ranged weapons.
class AmmoStore extends SparseSet {
  final List<int> arrows = <int>[];
  final List<int> throwingAxes = <int>[];
  final List<int> throwingKnives = <int>[];
  void add(EntityId entity, [AmmoDef def = const AmmoDef()]) {
    final i = addEntity(entity);
    arrows[i] = def.arrows;
    throwingAxes[i] = def.throwingAxes;
    throwingKnives[i] = def.throwingKnives;
  }

  int countForIndex(int index, AmmoType type) {
    switch (type) {
      case AmmoType.arrow:
        return arrows[index];
      case AmmoType.throwingAxe:
        return throwingAxes[index];
      case AmmoType.throwingKnife:
        return throwingKnives[index];
    }
  }

  void setCountForIndex(int index, AmmoType type, int value) {
    final clamped = value < 0 ? 0 : value;
    switch (type) {
      case AmmoType.arrow:
        arrows[index] = clamped;
      case AmmoType.throwingAxe:
        throwingAxes[index] = clamped;
      case AmmoType.throwingKnife:
        throwingKnives[index] = clamped;
    }
  }

  @override
  void onDenseAdded(int denseIndex) {
    arrows.add(0);
    throwingAxes.add(0);
    throwingKnives.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    arrows[removeIndex] = arrows[lastIndex];
    throwingAxes[removeIndex] = throwingAxes[lastIndex];

    arrows.removeLast();
    throwingAxes.removeLast();
    throwingKnives.removeLast();
  }
}

