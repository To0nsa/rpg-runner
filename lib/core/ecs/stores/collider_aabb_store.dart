import '../entity_id.dart';
import '../sparse_set.dart';

/// AABB collider configuration for an entity.
///
/// Representation is center-based for stability:
/// - `Transform.pos` is treated as the entity center
/// - collider center is `pos + offset`
/// - extents are half-sizes in world units (virtual pixels)
class ColliderAabbDef {
  const ColliderAabbDef({
    required this.halfX,
    required this.halfY,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  final double halfX;
  final double halfY;
  final double offsetX;
  final double offsetY;
}

/// SoA store for AABB collider config (half extents + offset).
class ColliderAabbStore extends SparseSet {
  final List<double> halfX = <double>[];
  final List<double> halfY = <double>[];
  final List<double> offsetX = <double>[];
  final List<double> offsetY = <double>[];

  void add(EntityId entity, ColliderAabbDef def) {
    final i = addEntity(entity);
    halfX[i] = def.halfX;
    halfY[i] = def.halfY;
    offsetX[i] = def.offsetX;
    offsetY[i] = def.offsetY;
  }

  @override
  void onDenseAdded(int denseIndex) {
    halfX.add(0);
    halfY.add(0);
    offsetX.add(0);
    offsetY.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    halfX[removeIndex] = halfX[lastIndex];
    halfY[removeIndex] = halfY[lastIndex];
    offsetX[removeIndex] = offsetX[lastIndex];
    offsetY[removeIndex] = offsetY[lastIndex];

    halfX.removeLast();
    halfY.removeLast();
    offsetX.removeLast();
    offsetY.removeLast();
  }
}
