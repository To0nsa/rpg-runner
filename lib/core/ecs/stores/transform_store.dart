import '../entity_id.dart';
import '../sparse_set.dart';

/// SoA store for `Transform` (position + velocity).
class TransformStore extends SparseSet {
  final List<double> posX = <double>[];
  final List<double> posY = <double>[];
  final List<double> velX = <double>[];
  final List<double> velY = <double>[];

  void add(
    EntityId entity, {
    required double posX,
    required double posY,
    required double velX,
    required double velY,
  }) {
    final i = addEntity(entity);
    this.posX[i] = posX;
    this.posY[i] = posY;
    this.velX[i] = velX;
    this.velY[i] = velY;
  }

  void setPosXY(EntityId entity, double x, double y) {
    final i = indexOf(entity);
    posX[i] = x;
    posY[i] = y;
  }

  void setVelXY(EntityId entity, double x, double y) {
    final i = indexOf(entity);
    velX[i] = x;
    velY[i] = y;
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
