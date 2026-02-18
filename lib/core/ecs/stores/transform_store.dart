import '../entity_id.dart';
import '../sparse_set.dart';
import '../../util/fixed_math.dart';

/// SoA store for `Transform` (position + velocity).
///
/// This is the "hot" store accessed by almost every system.
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

  /// Quantizes velocity to a subpixel grid for fixed-point pilot paths.
  void quantizeVelAtIndex(int denseIndex, {required int subpixelScale}) {
    velX[denseIndex] = quantizeToScale(velX[denseIndex], subpixelScale);
    velY[denseIndex] = quantizeToScale(velY[denseIndex], subpixelScale);
  }

  /// Quantizes position + velocity to a subpixel grid for fixed-point pilot paths.
  void quantizePosVelAtIndex(int denseIndex, {required int subpixelScale}) {
    posX[denseIndex] = quantizeToScale(posX[denseIndex], subpixelScale);
    posY[denseIndex] = quantizeToScale(posY[denseIndex], subpixelScale);
    quantizeVelAtIndex(denseIndex, subpixelScale: subpixelScale);
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
