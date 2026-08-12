import '../../collision/terrain/terrain_numeric.dart';
import '../entity_id.dart';
import '../sparse_set.dart';
import 'collider_aabb_store.dart';

/// Authored upright capsule definition compiled once into physics-grid ticks.
///
/// The authored values remain available so enclosing AABBs can be derived
/// without changing existing catalog dimensions. Terrain and actor combat use
/// the checked tick values stored in [WorldContactCapsuleStore].
class WorldContactCapsuleDef {
  factory WorldContactCapsuleDef({
    required double radius,
    required double verticalHalfSegment,
    double offsetX = 0,
    double offsetY = 0,
  }) {
    _requireFinite(radius, 'radius');
    _requireFinite(verticalHalfSegment, 'verticalHalfSegment');
    _requireFinite(offsetX, 'offsetX');
    _requireFinite(offsetY, 'offsetY');
    if (radius <= 0) {
      throw ArgumentError.value(radius, 'radius', 'Must be positive.');
    }
    if (verticalHalfSegment < 0) {
      throw ArgumentError.value(
        verticalHalfSegment,
        'verticalHalfSegment',
        'Must be non-negative.',
      );
    }

    return WorldContactCapsuleDef._(
      radius: radius,
      verticalHalfSegment: verticalHalfSegment,
      offsetX: offsetX,
      offsetY: offsetY,
      radiusTicks: physicsCoordinateToTicks(radius, name: 'radius'),
      verticalHalfSegmentTicks: physicsCoordinateToTicks(
        verticalHalfSegment,
        name: 'verticalHalfSegment',
      ),
      offsetXTicks: physicsCoordinateToTicks(offsetX, name: 'offsetX'),
      offsetYTicks: physicsCoordinateToTicks(offsetY, name: 'offsetY'),
    );
  }

  const WorldContactCapsuleDef._({
    required this.radius,
    required this.verticalHalfSegment,
    required this.offsetX,
    required this.offsetY,
    required this.radiusTicks,
    required this.verticalHalfSegmentTicks,
    required this.offsetXTicks,
    required this.offsetYTicks,
  });

  /// Derives the capsule from an existing center-based AABB.
  ///
  /// This frozen migration uses the horizontal half extent as radius and keeps
  /// the remaining vertical half extent as the capsule spine.
  factory WorldContactCapsuleDef.fromAabb(ColliderAabbDef collider) {
    return WorldContactCapsuleDef(
      radius: collider.halfX,
      verticalHalfSegment: (collider.halfY - collider.halfX).clamp(
        0,
        double.infinity,
      ),
      offsetX: collider.offsetX,
      offsetY: collider.offsetY,
    );
  }

  /// Authored radius in world units.
  final double radius;

  /// Authored half-length of the vertical spine in world units.
  final double verticalHalfSegment;

  /// Authored horizontal center offset, mirrored with logical facing.
  final double offsetX;

  /// Authored vertical center offset in world units.
  final double offsetY;

  /// Radius in authoritative 1/1024-world-unit physics ticks.
  final int radiusTicks;

  /// Vertical spine half-length in authoritative physics ticks.
  final int verticalHalfSegmentTicks;

  /// Authored horizontal offset quantized to authoritative physics ticks.
  final int offsetXTicks;

  /// Authored vertical offset quantized to authoritative physics ticks.
  final int offsetYTicks;

  /// Exact authored enclosing AABB derived from this capsule.
  ColliderAabbDef get derivedAabb => ColliderAabbDef(
    halfX: radius,
    halfY: radius + verticalHalfSegment,
    offsetX: offsetX,
    offsetY: offsetY,
  );
}

/// SoA storage for authoritative upright world-contact capsule dimensions.
///
/// Values are immutable after component attachment. Facing changes affect only
/// how [offsetXTicks] is resolved by the motion authority.
class WorldContactCapsuleStore extends SparseSet {
  final List<int> radiusTicks = <int>[];
  final List<int> verticalHalfSegmentTicks = <int>[];
  final List<int> offsetXTicks = <int>[];
  final List<int> offsetYTicks = <int>[];

  void add(EntityId entity, WorldContactCapsuleDef def) {
    final index = addEntity(entity);
    radiusTicks[index] = def.radiusTicks;
    verticalHalfSegmentTicks[index] = def.verticalHalfSegmentTicks;
    offsetXTicks[index] = def.offsetXTicks;
    offsetYTicks[index] = def.offsetYTicks;
  }

  @override
  void onDenseAdded(int denseIndex) {
    radiusTicks.add(0);
    verticalHalfSegmentTicks.add(0);
    offsetXTicks.add(0);
    offsetYTicks.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    radiusTicks[removeIndex] = radiusTicks[lastIndex];
    verticalHalfSegmentTicks[removeIndex] = verticalHalfSegmentTicks[lastIndex];
    offsetXTicks[removeIndex] = offsetXTicks[lastIndex];
    offsetYTicks[removeIndex] = offsetYTicks[lastIndex];

    radiusTicks.removeLast();
    verticalHalfSegmentTicks.removeLast();
    offsetXTicks.removeLast();
    offsetYTicks.removeLast();
  }
}

void _requireFinite(double value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, name, 'Must be finite.');
  }
}
