import '../../combat/combat_geometry.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

/// Anchor-relative vulnerable body pose. Terrain/navigation dimensions stay in
/// WorldContactCapsuleStore; this shape changes only combat and its projection.
final class CombatHurtboxStore extends SparseSet {
  final List<CombatCapsule?> capsule = [];
  final List<double> poseAngle = [];

  void set(EntityId entity, CombatCapsule value, {double angle = 0}) {
    final i = (has(entity) ? indexOf(entity) : addEntity(entity));
    capsule[i] = value;
    poseAngle[i] = angle;
  }

  @override
  void onDenseAdded(int denseIndex) {
    capsule.add(null);
    poseAngle.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    capsule[removeIndex] = capsule[lastIndex];
    poseAngle[removeIndex] = poseAngle[lastIndex];
    capsule.removeLast();
    poseAngle.removeLast();
  }
}
