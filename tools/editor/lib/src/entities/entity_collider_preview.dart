import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';

import 'entity_domain_models.dart';

/// Axis of the finite spine used by an entity's runtime combat capsule.
enum EntityColliderCapsuleAxis { horizontal, vertical }

/// Runtime-faithful collider geometry projected from one editor entry.
///
/// Actor values use Core's exact AABB-to-quantized-capsule derivation.
/// Projectile values preserve their existing horizontal attack-capsule
/// interpretation. This projection is display-only and does not own writes.
class EntityColliderPreview {
  const EntityColliderPreview._({
    required this.axis,
    required this.radius,
    required this.halfSegment,
    required this.offsetX,
    required this.offsetY,
  });

  /// Returns null when the entry cannot produce a valid runtime capsule.
  static EntityColliderPreview? tryFrom(EntityEntry entry) {
    if (!entry.halfX.isFinite ||
        !entry.halfY.isFinite ||
        !entry.offsetX.isFinite ||
        !entry.offsetY.isFinite ||
        entry.halfX <= 0 ||
        entry.halfY <= 0) {
      return null;
    }

    if (entry.entityType == EntityType.projectile) {
      return EntityColliderPreview._(
        axis: EntityColliderCapsuleAxis.horizontal,
        radius: entry.halfY,
        halfSegment: entry.halfX,
        offsetX: entry.offsetX,
        offsetY: entry.offsetY,
      );
    }
    if (entry.halfY < entry.halfX) return null;

    final capsule = WorldContactCapsuleDef.fromAabb(
      ColliderAabbDef(
        halfX: entry.halfX,
        halfY: entry.halfY,
        offsetX: entry.offsetX,
        offsetY: entry.offsetY,
      ),
    );
    const scale = terrainPhysicsTicksPerWorldUnit;
    return EntityColliderPreview._(
      axis: EntityColliderCapsuleAxis.vertical,
      radius: capsule.radiusTicks / scale,
      halfSegment: capsule.verticalHalfSegmentTicks / scale,
      offsetX: capsule.offsetXTicks / scale,
      offsetY: capsule.offsetYTicks / scale,
    );
  }

  final EntityColliderCapsuleAxis axis;
  final double radius;
  final double halfSegment;
  final double offsetX;
  final double offsetY;

  double get boundsHalfX => switch (axis) {
    EntityColliderCapsuleAxis.horizontal => radius + halfSegment,
    EntityColliderCapsuleAxis.vertical => radius,
  };

  double get boundsHalfY => switch (axis) {
    EntityColliderCapsuleAxis.horizontal => radius,
    EntityColliderCapsuleAxis.vertical => radius + halfSegment,
  };
}
