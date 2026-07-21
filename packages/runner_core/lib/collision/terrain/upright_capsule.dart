import 'dart:math' as math;

import 'terrain_numeric.dart';

/// Horizontal facing used only to resolve an authored collider X offset.
enum TerrainFacing { left, right }

/// Immutable upright capsule on the deterministic physics grid.
///
/// [radiusTicks] and [verticalHalfSegmentTicks] use 1/1024 world-unit ticks.
/// A zero half-segment is a circle. The derived AABB half extents are
/// `(radius, radius + halfSegment)`.
class UprightCapsule {
  /// Creates a non-negative capsule on the physics grid.
  factory UprightCapsule({
    required TerrainPoint center,
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
  }) {
    if (radiusTicks < 0 || verticalHalfSegmentTicks < 0) {
      throw ArgumentError('Capsule dimensions must be non-negative.');
    }
    return UprightCapsule._(
      center: center,
      radiusTicks: radiusTicks,
      verticalHalfSegmentTicks: verticalHalfSegmentTicks,
    );
  }

  const UprightCapsule._({
    required this.center,
    required this.radiusTicks,
    required this.verticalHalfSegmentTicks,
  });

  /// Resolves a body-centered capsule, mirroring only the authored X offset.
  factory UprightCapsule.fromBody({
    required TerrainPoint bodyCenter,
    required TerrainFacing facing,
    required int offsetXTicks,
    required int offsetYTicks,
    required int radiusTicks,
    required int verticalHalfSegmentTicks,
  }) {
    if (radiusTicks < 0 || verticalHalfSegmentTicks < 0) {
      throw ArgumentError('Capsule dimensions must be non-negative.');
    }
    final facingSign = facing == TerrainFacing.right ? 1 : -1;
    return UprightCapsule(
      center: bodyCenter.translated(offsetXTicks * facingSign, offsetYTicks),
      radiusTicks: radiusTicks,
      verticalHalfSegmentTicks: verticalHalfSegmentTicks,
    );
  }

  /// Center of the vertical spine in physics ticks.
  final TerrainPoint center;

  /// Cap/side radius in 1/1024-world-unit physics ticks.
  final int radiusTicks;

  /// Half-length of the vertical spine in physics ticks.
  final int verticalHalfSegmentTicks;

  /// Horizontal AABB half extent in physics ticks.
  int get halfWidthTicks => radiusTicks;

  /// Vertical AABB half extent in physics ticks.
  int get halfHeightTicks => radiusTicks + verticalHalfSegmentTicks;

  /// Upper endpoint of the vertical spine in Y-down coordinates.
  TerrainPoint get spineStart =>
      center.translated(0, -verticalHalfSegmentTicks);

  /// Lower endpoint of the vertical spine in Y-down coordinates.
  TerrainPoint get spineEnd => center.translated(0, verticalHalfSegmentTicks);

  /// Tight inclusive bounds in physics ticks.
  TerrainAabb get bounds => TerrainAabb(
    minX: center.xTicks - radiusTicks,
    minY: center.yTicks - halfHeightTicks,
    maxX: center.xTicks + radiusTicks,
    maxY: center.yTicks + halfHeightTicks,
  );

  /// Closed AABB covering this capsule before and after a tick displacement.
  TerrainAabb sweptBounds(int dxTicks, int dyTicks) => TerrainAabb(
    minX: math.min(bounds.minX, bounds.minX + dxTicks),
    minY: math.min(bounds.minY, bounds.minY + dyTicks),
    maxX: math.max(bounds.maxX, bounds.maxX + dxTicks),
    maxY: math.max(bounds.maxY, bounds.maxY + dyTicks),
  );
}
