import 'dart:collection';

import 'terrain_edge.dart';
import 'terrain_numeric.dart';

/// One signed slope-speed control point in fixed angle and basis-point units.
class TerrainSlopeSpeedPoint {
  const TerrainSlopeSpeedPoint({
    required this.angleUnits,
    required this.uphillMultiplierBp,
    required this.downhillMultiplierBp,
  });

  /// Absolute surface angle in 1/1024-degree units.
  final int angleUnits;

  /// Target world-X multiplier where `10000 == 100%`.
  final int uphillMultiplierBp;

  /// Target world-X multiplier where `10000 == 100%`.
  final int downhillMultiplierBp;
}

/// Immutable actor policy consumed by terrain contact and motion.
///
/// Thresholds and tuning use integers so the controller does not depend on
/// platform trigonometry or controller-local tolerances.
class TerrainTraversalProfile {
  factory TerrainTraversalProfile({
    required bool enabled,
    required bool isKinematic,
    required bool useGravity,
    required int gravityScaleBp,
    required bool collideCeilings,
    required bool collideLeftWalls,
    required bool collideRightWalls,
    required int maxWalkableSlopeAngleUnits,
    required int minimumSupportUpComponent,
    required int stepHeightTicks,
    required int snapDistanceTicks,
    required bool oneWaySupportEnabled,
    required bool dropThroughEnabled,
    required bool groundedMobilityHelpersEnabled,
    required Iterable<TerrainSlopeSpeedPoint> slopeSpeedPoints,
  }) {
    if (gravityScaleBp < 0) {
      throw ArgumentError.value(
        gravityScaleBp,
        'gravityScaleBp',
        'Must be non-negative.',
      );
    }
    if (maxWalkableSlopeAngleUnits <= 0 ||
        maxWalkableSlopeAngleUnits > 90 * terrainSlopeAngleUnitsPerDegree) {
      throw ArgumentError.value(
        maxWalkableSlopeAngleUnits,
        'maxWalkableSlopeAngleUnits',
        'Must be in the interval (0, 90 degrees].',
      );
    }
    if (minimumSupportUpComponent <= 0 ||
        minimumSupportUpComponent > terrainDirectionScale) {
      throw ArgumentError.value(
        minimumSupportUpComponent,
        'minimumSupportUpComponent',
        'Must be a positive quantized up-normal component.',
      );
    }
    if (stepHeightTicks < 0 || snapDistanceTicks < 0) {
      throw ArgumentError('Step and snap distances must be non-negative.');
    }

    final points = List<TerrainSlopeSpeedPoint>.of(slopeSpeedPoints);
    if (points.length < 2 ||
        points.first.angleUnits != 0 ||
        points.last.angleUnits != maxWalkableSlopeAngleUnits) {
      throw ArgumentError(
        'Slope-speed points must span zero through maximum walkable slope.',
      );
    }
    for (var index = 0; index < points.length; index += 1) {
      final point = points[index];
      if (point.uphillMultiplierBp <= 0 || point.downhillMultiplierBp <= 0) {
        throw ArgumentError('Slope-speed multipliers must be positive.');
      }
      if (index > 0 && points[index - 1].angleUnits >= point.angleUnits) {
        throw ArgumentError(
          'Slope-speed control angles must be strictly increasing.',
        );
      }
    }

    return TerrainTraversalProfile._(
      enabled: enabled,
      isKinematic: isKinematic,
      useGravity: useGravity,
      gravityScaleBp: gravityScaleBp,
      collideCeilings: collideCeilings,
      collideLeftWalls: collideLeftWalls,
      collideRightWalls: collideRightWalls,
      maxWalkableSlopeAngleUnits: maxWalkableSlopeAngleUnits,
      minimumSupportUpComponent: minimumSupportUpComponent,
      stepHeightTicks: stepHeightTicks,
      snapDistanceTicks: snapDistanceTicks,
      oneWaySupportEnabled: oneWaySupportEnabled,
      dropThroughEnabled: dropThroughEnabled,
      groundedMobilityHelpersEnabled: groundedMobilityHelpersEnabled,
      slopeSpeedPoints: UnmodifiableListView<TerrainSlopeSpeedPoint>(points),
    );
  }

  const TerrainTraversalProfile._({
    required this.enabled,
    required this.isKinematic,
    required this.useGravity,
    required this.gravityScaleBp,
    required this.collideCeilings,
    required this.collideLeftWalls,
    required this.collideRightWalls,
    required this.maxWalkableSlopeAngleUnits,
    required this.minimumSupportUpComponent,
    required this.stepHeightTicks,
    required this.snapDistanceTicks,
    required this.oneWaySupportEnabled,
    required this.dropThroughEnabled,
    required this.groundedMobilityHelpersEnabled,
    required this.slopeSpeedPoints,
  });

  final bool enabled;
  final bool isKinematic;
  final bool useGravity;

  /// Gravity scale in basis points (`10000 == 1.0x`).
  final int gravityScaleBp;

  final bool collideCeilings;
  final bool collideLeftWalls;
  final bool collideRightWalls;

  /// Inclusive maximum support angle in 1/1024-degree units.
  final int maxWalkableSlopeAngleUnits;

  /// Inclusive `dot(normal, worldUp)` threshold on the 1024 direction scale.
  final int minimumSupportUpComponent;

  /// Maximum automatic upward step in 1/1024-world-unit ticks.
  final int stepHeightTicks;

  /// Maximum support-preserving downward snap in physics ticks.
  final int snapDistanceTicks;

  final bool oneWaySupportEnabled;
  final bool dropThroughEnabled;
  final bool groundedMobilityHelpersEnabled;
  final List<TerrainSlopeSpeedPoint> slopeSpeedPoints;

  /// Whether [edge] has an upward normal inside the inclusive slope limit.
  bool isWalkableSupport(TerrainEdge edge) =>
      -edge.outwardNormal.yTicks >= minimumSupportUpComponent;

  /// Interpolates the signed target-X multiplier in deterministic basis points.
  int slopeMultiplierBp({
    required int absoluteAngleUnits,
    required bool uphill,
  }) {
    final angle = absoluteAngleUnits.clamp(0, maxWalkableSlopeAngleUnits);
    for (var index = 1; index < slopeSpeedPoints.length; index += 1) {
      final right = slopeSpeedPoints[index];
      if (angle > right.angleUnits) continue;
      final left = slopeSpeedPoints[index - 1];
      final leftMultiplier = uphill
          ? left.uphillMultiplierBp
          : left.downhillMultiplierBp;
      final rightMultiplier = uphill
          ? right.uphillMultiplierBp
          : right.downhillMultiplierBp;
      return _interpolateRounded(
        leftMultiplier,
        rightMultiplier,
        angle - left.angleUnits,
        right.angleUnits - left.angleUnits,
      );
    }
    final last = slopeSpeedPoints.last;
    return uphill ? last.uphillMultiplierBp : last.downhillMultiplierBp;
  }

  /// Classifies signed horizontal travel independently from edge authoring.
  bool isUphill(TerrainEdge edge, int requestedHorizontalTicks) {
    if (requestedHorizontalTicks == 0 || edge.dyTicks == 0) return false;
    return requestedHorizontalTicks * edge.dxTicks * edge.dyTicks < 0;
  }
}

/// Frozen Phase 2 Éloïse traversal policy.
TerrainTraversalProfile createEloiseTerrainTraversalProfile({
  required bool enabled,
  required bool isKinematic,
  required bool useGravity,
  required double gravityScale,
  required bool collideCeilings,
  required bool collideLeftWalls,
  required bool collideRightWalls,
}) {
  if (!gravityScale.isFinite) {
    throw ArgumentError.value(gravityScale, 'gravityScale', 'Must be finite.');
  }
  return TerrainTraversalProfile(
    enabled: enabled,
    isKinematic: isKinematic,
    useGravity: useGravity,
    gravityScaleBp: (gravityScale * 10000).round(),
    collideCeilings: collideCeilings,
    collideLeftWalls: collideLeftWalls,
    collideRightWalls: collideRightWalls,
    maxWalkableSlopeAngleUnits: 60 * terrainSlopeAngleUnitsPerDegree,
    minimumSupportUpComponent: terrainDirectionScale ~/ 2,
    stepHeightTicks: 4 * terrainPhysicsTicksPerWorldUnit,
    snapDistanceTicks: 4 * terrainPhysicsTicksPerWorldUnit,
    oneWaySupportEnabled: true,
    dropThroughEnabled: false,
    groundedMobilityHelpersEnabled: true,
    slopeSpeedPoints: const <TerrainSlopeSpeedPoint>[
      TerrainSlopeSpeedPoint(
        angleUnits: 0,
        uphillMultiplierBp: 10000,
        downhillMultiplierBp: 10000,
      ),
      TerrainSlopeSpeedPoint(
        angleUnits: 30 * terrainSlopeAngleUnitsPerDegree,
        uphillMultiplierBp: 9500,
        downhillMultiplierBp: 10500,
      ),
      TerrainSlopeSpeedPoint(
        angleUnits: 45 * terrainSlopeAngleUnitsPerDegree,
        uphillMultiplierBp: 8500,
        downhillMultiplierBp: 11000,
      ),
      TerrainSlopeSpeedPoint(
        angleUnits: 60 * terrainSlopeAngleUnitsPerDegree,
        uphillMultiplierBp: 7500,
        downhillMultiplierBp: 11500,
      ),
    ],
  );
}

int _interpolateRounded(int start, int end, int offset, int span) {
  final numerator = (end - start) * offset;
  final roundedDelta = numerator >= 0
      ? (numerator + span ~/ 2) ~/ span
      : -((-numerator + span ~/ 2) ~/ span);
  return start + roundedDelta;
}
