import '../../math/vec2.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

/// SoA store for `Transform` (position + velocity).
class TransformStore extends SparseSet {
  final List<double> posX = <double>[];
  final List<double> posY = <double>[];
  final List<double> velX = <double>[];
  final List<double> velY = <double>[];

  void add(EntityId entity, {required Vec2 pos, required Vec2 vel}) {
    final i = addEntity(entity);
    posX[i] = pos.x;
    posY[i] = pos.y;
    velX[i] = vel.x;
    velY[i] = vel.y;
  }

  Vec2 getPos(EntityId entity) {
    final i = indexOf(entity);
    return Vec2(posX[i], posY[i]);
  }

  Vec2 getVel(EntityId entity) {
    final i = indexOf(entity);
    return Vec2(velX[i], velY[i]);
  }

  void setPos(EntityId entity, Vec2 value) {
    final i = indexOf(entity);
    posX[i] = value.x;
    posY[i] = value.y;
  }

  void setVel(EntityId entity, Vec2 value) {
    final i = indexOf(entity);
    velX[i] = value.x;
    velY[i] = value.y;
  }

  @override
  void onDenseAdded(int denseIndex) {
    posX.add(0);
    posY.add(0);
    velX.add(0);
    velY.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    posX[removeIndex] = posX[lastIndex];
    posY[removeIndex] = posY[lastIndex];
    velX[removeIndex] = velX[lastIndex];
    velY[removeIndex] = velY[lastIndex];

    posX.removeLast();
    posY.removeLast();
    velX.removeLast();
    velY.removeLast();
  }
}
