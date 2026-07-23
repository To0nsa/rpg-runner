import '../collision/terrain/terrain_numeric.dart';
import '../collision/terrain/terrain_traversal_profile.dart';
import '../ecs/stores/world_contact_capsule_store.dart';

/// How an enemy participates in polygon-terrain authority.
enum EnemyTerrainMotionKind {
  /// Gravity-driven actor that retains eligible terrain support.
  groundedDynamic,

  /// Freely steered actor blocked by solids without becoming grounded.
  flyingDynamic,

  /// Stationary actor validated only when explicitly placed or moved.
  kinematicPlacement,
}

/// How authored locomotion speed is interpreted on eligible supports.
enum EnemyTerrainLocomotionKind {
  /// The actor has no ordinary support-following locomotion.
  none,

  /// Authored speed is distance along the support, independent of its angle.
  constantSurfaceDistance,
}

/// Immutable world-contact shape and terrain rules for one enemy archetype.
///
/// The capsule is quantized once when the catalog-owned profile is initialized.
/// [traversal] contains collision masks and support limits; [motionKind] remains
/// the authority for whether a classified floor contact may create grounding.
class EnemyTerrainContactProfile {
  /// Creates a profile and rejects role/physics combinations that could leave
  /// terrain ownership ambiguous.
  factory EnemyTerrainContactProfile({
    required EnemyTerrainMotionKind motionKind,
    required EnemyTerrainLocomotionKind locomotionKind,
    required WorldContactCapsuleDef capsule,
    required TerrainTraversalProfile traversal,
  }) {
    switch (motionKind) {
      case EnemyTerrainMotionKind.groundedDynamic:
        if (traversal.isKinematic ||
            !traversal.useGravity ||
            !traversal.groundedMobilityHelpersEnabled ||
            locomotionKind !=
                EnemyTerrainLocomotionKind.constantSurfaceDistance) {
          throw ArgumentError(
            'Grounded enemy terrain profiles require gravity, dynamic motion, '
            'ground helpers, and constant surface-distance locomotion.',
          );
        }
      case EnemyTerrainMotionKind.flyingDynamic:
        if (traversal.isKinematic ||
            traversal.useGravity ||
            traversal.oneWaySupportEnabled ||
            traversal.groundedMobilityHelpersEnabled ||
            traversal.stepHeightTicks != 0 ||
            traversal.snapDistanceTicks != 0 ||
            locomotionKind != EnemyTerrainLocomotionKind.none) {
          throw ArgumentError(
            'Flying enemy terrain profiles must be dynamic, gravity-free, '
            'support-free, and ignore one-way terrain.',
          );
        }
      case EnemyTerrainMotionKind.kinematicPlacement:
        if (!traversal.isKinematic ||
            traversal.useGravity ||
            traversal.groundedMobilityHelpersEnabled ||
            traversal.stepHeightTicks != 0 ||
            traversal.snapDistanceTicks != 0 ||
            locomotionKind != EnemyTerrainLocomotionKind.none) {
          throw ArgumentError(
            'Kinematic enemy terrain profiles may only participate in '
            'explicit placement queries.',
          );
        }
    }
    return EnemyTerrainContactProfile._(
      motionKind: motionKind,
      locomotionKind: locomotionKind,
      capsule: capsule,
      traversal: traversal,
    );
  }

  const EnemyTerrainContactProfile._({
    required this.motionKind,
    required this.locomotionKind,
    required this.capsule,
    required this.traversal,
  });

  /// Dynamic, flying, or explicit-placement participation rule.
  final EnemyTerrainMotionKind motionKind;

  /// Interpretation of authored movement speed on terrain.
  final EnemyTerrainLocomotionKind locomotionKind;

  /// Catalog AABB-derived contact capsule, quantized once in physics ticks.
  final WorldContactCapsuleDef capsule;

  /// Collision masks, support limit, gravity, step, and snap policy.
  final TerrainTraversalProfile traversal;

  /// Whether final eligible floor contact may become authoritative support.
  bool get canGround => motionKind == EnemyTerrainMotionKind.groundedDynamic;
}

/// Builds the frozen grounded-enemy collision and traversal policy.
///
/// [minimumSupportUpComponent] is the inclusive quantized cosine threshold for
/// [maxWalkableSlopeDegrees]. Enemy locomotion converts authored speed to the
/// support tangent before invoking the controller; the neutral speed curve is
/// therefore intentionally not the player slope-speed curve.
EnemyTerrainContactProfile createGroundedEnemyTerrainProfile({
  required WorldContactCapsuleDef capsule,
  required int maxWalkableSlopeDegrees,
  required int minimumSupportUpComponent,
}) {
  final maxAngleUnits =
      maxWalkableSlopeDegrees * terrainSlopeAngleUnitsPerDegree;
  return EnemyTerrainContactProfile(
    motionKind: EnemyTerrainMotionKind.groundedDynamic,
    locomotionKind: EnemyTerrainLocomotionKind.constantSurfaceDistance,
    capsule: capsule,
    traversal: TerrainTraversalProfile(
      enabled: true,
      isKinematic: false,
      useGravity: true,
      gravityScaleBp: 10000,
      collideCeilings: false,
      collideLeftWalls: true,
      collideRightWalls: true,
      maxWalkableSlopeAngleUnits: maxAngleUnits,
      minimumSupportUpComponent: minimumSupportUpComponent,
      stepHeightTicks: 4 * terrainPhysicsTicksPerWorldUnit,
      snapDistanceTicks: 4 * terrainPhysicsTicksPerWorldUnit,
      oneWaySupportEnabled: true,
      dropThroughEnabled: false,
      groundedMobilityHelpersEnabled: true,
      slopeSpeedPoints: <TerrainSlopeSpeedPoint>[
        const TerrainSlopeSpeedPoint(
          angleUnits: 0,
          uphillMultiplierBp: 10000,
          downhillMultiplierBp: 10000,
        ),
        TerrainSlopeSpeedPoint(
          angleUnits: maxAngleUnits,
          uphillMultiplierBp: 10000,
          downhillMultiplierBp: 10000,
        ),
      ],
    ),
  );
}

/// Builds the frozen Unoco solid-contact policy.
EnemyTerrainContactProfile createFlyingEnemyTerrainProfile({
  required WorldContactCapsuleDef capsule,
}) => EnemyTerrainContactProfile(
  motionKind: EnemyTerrainMotionKind.flyingDynamic,
  locomotionKind: EnemyTerrainLocomotionKind.none,
  capsule: capsule,
  traversal: TerrainTraversalProfile(
    enabled: true,
    isKinematic: false,
    useGravity: false,
    gravityScaleBp: 0,
    collideCeilings: true,
    collideLeftWalls: true,
    collideRightWalls: true,
    maxWalkableSlopeAngleUnits: 90 * terrainSlopeAngleUnitsPerDegree,
    minimumSupportUpComponent: 1,
    stepHeightTicks: 0,
    snapDistanceTicks: 0,
    oneWaySupportEnabled: false,
    dropThroughEnabled: false,
    groundedMobilityHelpersEnabled: false,
    slopeSpeedPoints: const <TerrainSlopeSpeedPoint>[
      TerrainSlopeSpeedPoint(
        angleUnits: 0,
        uphillMultiplierBp: 10000,
        downhillMultiplierBp: 10000,
      ),
      TerrainSlopeSpeedPoint(
        angleUnits: 90 * terrainSlopeAngleUnitsPerDegree,
        uphillMultiplierBp: 10000,
        downhillMultiplierBp: 10000,
      ),
    ],
  ),
);

/// Builds the frozen Derf clearance-only placement policy.
EnemyTerrainContactProfile createKinematicEnemyTerrainProfile({
  required WorldContactCapsuleDef capsule,
}) => EnemyTerrainContactProfile(
  motionKind: EnemyTerrainMotionKind.kinematicPlacement,
  locomotionKind: EnemyTerrainLocomotionKind.none,
  capsule: capsule,
  traversal: TerrainTraversalProfile(
    enabled: true,
    isKinematic: true,
    useGravity: false,
    gravityScaleBp: 0,
    collideCeilings: true,
    collideLeftWalls: true,
    collideRightWalls: true,
    maxWalkableSlopeAngleUnits: 15 * terrainSlopeAngleUnitsPerDegree,
    minimumSupportUpComponent: 989,
    stepHeightTicks: 0,
    snapDistanceTicks: 0,
    oneWaySupportEnabled: false,
    dropThroughEnabled: false,
    groundedMobilityHelpersEnabled: false,
    slopeSpeedPoints: const <TerrainSlopeSpeedPoint>[
      TerrainSlopeSpeedPoint(
        angleUnits: 0,
        uphillMultiplierBp: 10000,
        downhillMultiplierBp: 10000,
      ),
      TerrainSlopeSpeedPoint(
        angleUnits: 15 * terrainSlopeAngleUnitsPerDegree,
        uphillMultiplierBp: 10000,
        downhillMultiplierBp: 10000,
      ),
    ],
  ),
);
