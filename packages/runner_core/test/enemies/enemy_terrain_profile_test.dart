import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/upright_capsule.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/enemies/enemy_terrain_profile.dart';
import 'package:test/test.dart';

void main() {
  const catalog = EnemyCatalog();

  test('catalog defines one stable terrain policy for every current enemy', () {
    final profiles = <EnemyTerrainContactProfile>[
      for (final id in EnemyId.values) catalog.terrainContactProfile(id),
    ];

    expect(EnemyId.values, hasLength(4));
    expect(profiles, hasLength(EnemyId.values.length));
    for (var index = 0; index < EnemyId.values.length; index += 1) {
      expect(
        identical(
          profiles[index],
          catalog.terrainContactProfile(EnemyId.values[index]),
        ),
        isTrue,
      );
    }
  });

  test('enemy capsules preserve authored AABBs and facing offsets exactly', () {
    final expected =
        <
          EnemyId,
          ({double radius, double spine, double offsetX, double offsetY})
        >{
          EnemyId.unocoDemon: (
            radius: 8.125,
            spine: 0.5,
            offsetX: 0.0,
            offsetY: 2.0,
          ),
          EnemyId.grojib: (
            radius: 19.5,
            spine: 5.5,
            offsetX: -4.0,
            offsetY: 18.0,
          ),
          EnemyId.hashash: (
            radius: 14.0,
            spine: 7.5,
            offsetX: -1.0,
            offsetY: 7.0,
          ),
          EnemyId.derf: (
            radius: 11.5,
            spine: 12.75,
            offsetX: 0.0,
            offsetY: 7.0,
          ),
        };
    final bodyCenter = TerrainPoint.fromWorld(100, 200);

    for (final id in EnemyId.values) {
      final archetype = catalog.get(id);
      final capsule = catalog.terrainContactProfile(id).capsule;
      final values = expected[id]!;
      final derived = capsule.derivedAabb;

      expect(capsule.radius, values.radius, reason: '$id radius');
      expect(capsule.verticalHalfSegment, values.spine, reason: '$id spine');
      expect(capsule.offsetX, values.offsetX, reason: '$id offsetX');
      expect(capsule.offsetY, values.offsetY, reason: '$id offsetY');
      expect(
        capsule.radiusTicks,
        (values.radius * terrainPhysicsTicksPerWorldUnit).round(),
      );
      expect(
        capsule.verticalHalfSegmentTicks,
        (values.spine * terrainPhysicsTicksPerWorldUnit).round(),
      );
      expect(
        capsule.offsetXTicks,
        (values.offsetX * terrainPhysicsTicksPerWorldUnit).round(),
      );
      expect(
        capsule.offsetYTicks,
        (values.offsetY * terrainPhysicsTicksPerWorldUnit).round(),
      );
      expect(derived.halfX, archetype.collider.halfX, reason: '$id halfX');
      expect(derived.halfY, archetype.collider.halfY, reason: '$id halfY');
      expect(derived.offsetX, archetype.collider.offsetX);
      expect(derived.offsetY, archetype.collider.offsetY);

      final right = UprightCapsule.fromBody(
        bodyCenter: bodyCenter,
        facing: TerrainFacing.right,
        offsetXTicks: capsule.offsetXTicks,
        offsetYTicks: capsule.offsetYTicks,
        radiusTicks: capsule.radiusTicks,
        verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
      );
      final left = UprightCapsule.fromBody(
        bodyCenter: bodyCenter,
        facing: TerrainFacing.left,
        offsetXTicks: capsule.offsetXTicks,
        offsetYTicks: capsule.offsetYTicks,
        radiusTicks: capsule.radiusTicks,
        verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
      );
      expect(
        right.center.xTicks - bodyCenter.xTicks,
        -(left.center.xTicks - bodyCenter.xTicks),
      );
      expect(right.center.yTicks, left.center.yTicks);
      expect(right.halfWidthTicks, left.halfWidthTicks);
      expect(right.halfHeightTicks, left.halfHeightTicks);
    }
  });

  test('grounded profiles freeze slope, helper, and collision policy', () {
    final grojib = catalog.terrainContactProfile(EnemyId.grojib);
    final hashash = catalog.terrainContactProfile(EnemyId.hashash);

    for (final profile in <EnemyTerrainContactProfile>[grojib, hashash]) {
      expect(profile.motionKind, EnemyTerrainMotionKind.groundedDynamic);
      expect(profile.canGround, isTrue);
      expect(
        profile.locomotionKind,
        EnemyTerrainLocomotionKind.constantSurfaceDistance,
      );
      expect(profile.traversal.isKinematic, isFalse);
      expect(profile.traversal.useGravity, isTrue);
      expect(profile.traversal.gravityScaleBp, 10000);
      expect(profile.traversal.collideCeilings, isFalse);
      expect(profile.traversal.collideLeftWalls, isTrue);
      expect(profile.traversal.collideRightWalls, isTrue);
      expect(
        profile.traversal.stepHeightTicks,
        4 * terrainPhysicsTicksPerWorldUnit,
      );
      expect(
        profile.traversal.snapDistanceTicks,
        4 * terrainPhysicsTicksPerWorldUnit,
      );
      expect(profile.traversal.oneWaySupportEnabled, isTrue);
      expect(profile.traversal.dropThroughEnabled, isFalse);
      expect(profile.traversal.groundedMobilityHelpersEnabled, isTrue);
    }

    expect(
      grojib.traversal.maxWalkableSlopeAngleUnits,
      45 * terrainSlopeAngleUnitsPerDegree,
    );
    expect(grojib.traversal.minimumSupportUpComponent, 724);
    expect(
      hashash.traversal.maxWalkableSlopeAngleUnits,
      60 * terrainSlopeAngleUnitsPerDegree,
    );
    expect(hashash.traversal.minimumSupportUpComponent, 512);
  });

  test('flying and kinematic profiles cannot acquire dynamic support', () {
    final unoco = catalog.terrainContactProfile(EnemyId.unocoDemon);
    final derf = catalog.terrainContactProfile(EnemyId.derf);

    expect(unoco.motionKind, EnemyTerrainMotionKind.flyingDynamic);
    expect(unoco.canGround, isFalse);
    expect(unoco.traversal.isKinematic, isFalse);
    expect(unoco.traversal.useGravity, isFalse);
    expect(unoco.traversal.collideCeilings, isTrue);
    expect(unoco.traversal.oneWaySupportEnabled, isFalse);
    expect(unoco.traversal.stepHeightTicks, 0);
    expect(unoco.traversal.snapDistanceTicks, 0);

    expect(derf.motionKind, EnemyTerrainMotionKind.kinematicPlacement);
    expect(derf.canGround, isFalse);
    expect(derf.traversal.isKinematic, isTrue);
    expect(derf.traversal.useGravity, isFalse);
    expect(derf.traversal.collideCeilings, isTrue);
    expect(derf.traversal.oneWaySupportEnabled, isFalse);
    expect(
      derf.traversal.maxWalkableSlopeAngleUnits,
      15 * terrainSlopeAngleUnitsPerDegree,
    );
    expect(derf.traversal.minimumSupportUpComponent, 989);
  });

  test('profile construction rejects invalid authoring and role mixtures', () {
    expect(
      () => createGroundedEnemyTerrainProfile(
        capsule: catalog.terrainContactProfile(EnemyId.grojib).capsule,
        maxWalkableSlopeDegrees: 0,
        minimumSupportUpComponent: 724,
      ),
      throwsArgumentError,
    );
    final unoco = catalog.terrainContactProfile(EnemyId.unocoDemon);
    expect(
      () => EnemyTerrainContactProfile(
        motionKind: EnemyTerrainMotionKind.groundedDynamic,
        locomotionKind: EnemyTerrainLocomotionKind.constantSurfaceDistance,
        capsule: unoco.capsule,
        traversal: unoco.traversal,
      ),
      throwsArgumentError,
    );
  });
}
