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
  const UprightCapsule({
    required this.center,
    required this.radiusTicks,
    required this.verticalHalfSegmentTicks,
  }) : assert(radiusTicks >= 0),
       assert(verticalHalfSegmentTicks >= 0);

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

  final TerrainPoint center;
  final int radiusTicks;
  final int verticalHalfSegmentTicks;

  int get halfWidthTicks => radiusTicks;
  int get halfHeightTicks => radiusTicks + verticalHalfSegmentTicks;

  TerrainPoint get spineStart =>
      center.translated(0, -verticalHalfSegmentTicks);
  TerrainPoint get spineEnd => center.translated(0, verticalHalfSegmentTicks);

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
