import 'package:runner_core/collision/terrain/terrain_capsule_controller.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_contact_policy.dart';
import 'package:runner_core/collision/terrain/terrain_controller_diagnostic.dart';
import 'package:runner_core/collision/terrain/terrain_edge.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_traversal_profile.dart';
import 'package:runner_core/collision/terrain/upright_capsule.dart';
import 'package:test/test.dart';

void main() {
  group('terrain capsule controller', () {
    test('stationary support and horizontal travel retain stable ground', () {
      final harness = _Harness([
        _polygon('ground', const [(0, 100), (200, 100), (200, 200), (0, 200)]),
      ]);
      final support = harness.upwardEdges.single;
      final capsule = _circle(50, 100 - 10 - terrainCollisionSkinTicks / 1024);
      final result = TerrainCapsuleMotionResult();

      harness.controller.move(
        capsule: capsule,
        request: TerrainMotionRequest(
          displacementXTicks: 10 * 1024,
          displacementYTicks: 0,
          gravityYTicks: 200,
          mode: TerrainMotionMode.groundedHorizontal,
        ),
        beganGrounded: true,
        priorSupportEdgeId: support.id,
        priorSupportGeometryVersion: harness.geometry.version,
        out: result,
      );

      expect(result.grounded, isTrue);
      expect(result.supportEdgeId, support.id);
      expect(result.resolvedXTicks, 10 * 1024);
      expect(result.resolvedYTicks, 0);
      expect(result.usedSnap, isFalse);
      expect(result.diagnostic, TerrainControllerDiagnostic.none);
    });

    test('continuous fall lands at skin without tunneling', () {
      final harness = _Harness([
        _polygon('ground', const [(0, 100), (200, 100), (200, 200), (0, 200)]),
      ]);
      final result = TerrainCapsuleMotionResult();

      harness.controller.move(
        capsule: _circle(50, 30),
        request: TerrainMotionRequest(
          displacementXTicks: 0,
          displacementYTicks: 100 * 1024,
          mode: TerrainMotionMode.worldSpace,
        ),
        beganGrounded: false,
        out: result,
      );

      expect(result.grounded, isTrue);
      expect(result.supportNormalYTicks, -1024);
      expect(
        result.finalCenterYTicks,
        closeTo(90 * 1024 - terrainCollisionSkinTicks, 2),
      );
      expect(result.contactIterations, 1);
      expect(result.diagnostic, TerrainControllerDiagnostic.none);
    });

    test('solid wall and ceiling block on their physical sides', () {
      final harness = _Harness([
        _polygon('wall', const [(100, 0), (120, 0), (120, 100), (100, 100)]),
        _polygon('ceiling', const [(0, 10), (80, 10), (80, 20), (0, 20)]),
      ]);

      final wallResult = TerrainCapsuleMotionResult();
      harness.controller.move(
        capsule: _circle(50, 60),
        request: TerrainMotionRequest(
          displacementXTicks: 100 * 1024,
          displacementYTicks: 0,
          mode: TerrainMotionMode.worldSpace,
        ),
        beganGrounded: false,
        out: wallResult,
      );
      expect(wallResult.hitRight, isTrue);
      expect(
        wallResult.finalCenterXTicks,
        closeTo(90 * 1024 - terrainCollisionSkinTicks, 2),
      );

      final ceilingResult = TerrainCapsuleMotionResult();
      harness.controller.move(
        capsule: _circle(40, 50),
        request: TerrainMotionRequest(
          displacementXTicks: 0,
          displacementYTicks: -50 * 1024,
          mode: TerrainMotionMode.worldSpace,
        ),
        beganGrounded: false,
        out: ceilingResult,
      );
      expect(ceilingResult.hitCeiling, isTrue);
      expect(
        ceilingResult.finalCenterYTicks,
        closeTo(30 * 1024 + terrainCollisionSkinTicks, 2),
      );
    });

    test(
      'equal-time floor and wall contacts form a stable corner constraint',
      () {
        final harness = _Harness([
          _polygon('ground', const [
            (0, 100),
            (180, 100),
            (180, 180),
            (0, 180),
          ]),
          _polygon('wall', const [(100, 0), (180, 0), (180, 100), (100, 100)]),
        ]);
        final result = TerrainCapsuleMotionResult();

        harness.controller.move(
          capsule: _circle(70, 70),
          request: TerrainMotionRequest(
            displacementXTicks: 50 * 1024,
            displacementYTicks: 50 * 1024,
            mode: TerrainMotionMode.worldSpace,
          ),
          beganGrounded: false,
          out: result,
        );

        expect(result.grounded, isTrue);
        expect(result.hitRight, isTrue);
        expect(result.contactCount, greaterThanOrEqualTo(2));
        expect(
          result.finalCenterXTicks,
          closeTo(90 * 1024 - terrainCollisionSkinTicks, 2),
        );
        expect(
          result.finalCenterYTicks,
          closeTo(90 * 1024 - terrainCollisionSkinTicks, 2),
        );
      },
    );

    test(
      'equal-time ceiling and wall contacts form a stable corner constraint',
      () {
        final harness = _Harness([
          _polygon('ceiling', const [(0, 80), (180, 80), (180, 100), (0, 100)]),
          _polygon('wall', const [
            (100, 100),
            (180, 100),
            (180, 180),
            (100, 180),
          ]),
        ]);
        final result = TerrainCapsuleMotionResult();

        harness.controller.move(
          capsule: _circle(70, 130),
          request: TerrainMotionRequest(
            displacementXTicks: 50 * 1024,
            displacementYTicks: -50 * 1024,
            mode: TerrainMotionMode.worldSpace,
          ),
          beganGrounded: false,
          out: result,
        );

        expect(result.hitCeiling, isTrue);
        expect(result.hitRight, isTrue);
        expect(result.contactCount, greaterThanOrEqualTo(2));
        expect(
          result.finalCenterXTicks,
          closeTo(90 * 1024 - terrainCollisionSkinTicks, 2),
        );
        expect(
          result.finalCenterYTicks,
          closeTo(110 * 1024 + terrainCollisionSkinTicks, 2),
        );
      },
    );

    test('equal-time opposing walls form a stable two-wall constraint', () {
      final harness = _Harness([
        _polygon('left-funnel', const [(0, 0), (145, 0), (100, 200), (0, 200)]),
        _polygon('right-funnel', const [
          (155, 0),
          (300, 0),
          (300, 200),
          (200, 200),
        ]),
      ]);
      final result = TerrainCapsuleMotionResult();

      harness.controller.move(
        capsule: _circle(150, 250),
        request: TerrainMotionRequest(
          displacementXTicks: 0,
          displacementYTicks: -300 * 1024,
          mode: TerrainMotionMode.worldSpace,
        ),
        beganGrounded: false,
        out: result,
      );

      expect(result.hitLeft, isTrue);
      expect(result.hitRight, isTrue);
      expect(result.hitCeiling, isFalse);
      expect(result.contactCount, greaterThanOrEqualTo(2));
      expect(
        result.contactKinds.take(result.contactCount),
        everyElement(TerrainContactKind.wall),
      );
      expect(result.diagnostic, TerrainControllerDiagnostic.blockedWall);
    });

    test('contact iteration exhaustion keeps its bounded safe state', () {
      final harness = _Harness([
        _polygon('faceted-descent', const [
          (0, 100),
          (100, 200),
          (200, 280),
          (300, 340),
          (400, 380),
          (500, 400),
          (600, 400),
          (600, 700),
          (0, 700),
        ]),
      ]);
      final result = TerrainCapsuleMotionResult();

      harness.controller.move(
        capsule: _circle(20, 20),
        request: TerrainMotionRequest(
          displacementXTicks: 560 * 1024,
          displacementYTicks: 1680 * 1024,
          mode: TerrainMotionMode.worldSpace,
        ),
        beganGrounded: false,
        out: result,
      );

      expect(
        result.contactIterations,
        terrainMaxBlockingContacts,
        reason:
            'diagnostic=${result.diagnostic} '
            'contacts=${result.contactCount} '
            'final=(${result.finalCenterXTicks},${result.finalCenterYTicks})',
      );
      expect(
        result.diagnostic,
        TerrainControllerDiagnostic.contactIterationLimit,
      );
      expect(result.finalCenterXTicks, lessThan(600 * 1024));
      expect(result.finalCenterYTicks, lessThan(700 * 1024));
    });

    test('one-way passes from below and lands from above', () {
      final harness = _Harness([
        _polygon('one-way', const [
          (0, 100),
          (200, 100),
          (200, 110),
          (0, 110),
        ], collisionMode: TerrainCollisionMode.oneWay),
      ]);

      final passResult = TerrainCapsuleMotionResult();
      harness.controller.move(
        capsule: _circle(50, 130),
        request: TerrainMotionRequest(
          displacementXTicks: 0,
          displacementYTicks: -80 * 1024,
          mode: TerrainMotionMode.worldSpace,
        ),
        beganGrounded: false,
        out: passResult,
      );
      expect(passResult.finalCenterYTicks, 50 * 1024);
      expect(passResult.grounded, isFalse);
      expect(passResult.hitCeiling, isFalse);

      final landResult = TerrainCapsuleMotionResult();
      harness.controller.move(
        capsule: _circle(50, 40),
        request: TerrainMotionRequest(
          displacementXTicks: 0,
          displacementYTicks: 80 * 1024,
          mode: TerrainMotionMode.worldSpace,
        ),
        beganGrounded: false,
        out: landResult,
      );
      expect(landResult.grounded, isTrue);
      expect(landResult.supportEdgeId, harness.upwardEdges.single.id);
    });

    test(
      'inclusive 60-degree edge supports while over-limit edge is a wall',
      () {
        final inclusive = _Harness([
          _polygon('inclusive', const [
            (0, 197),
            (56, 100),
            (100, 240),
            (0, 240),
          ]),
        ]);
        final overLimit = _Harness([
          _polygon('over', const [(0, 197), (55, 100), (100, 240), (0, 240)]),
        ]);

        expect(
          inclusive.profile.isWalkableSupport(
            inclusive.geometry.edges.singleWhere(
              (edge) => edge.dxTicks.abs() == 56 * 1024,
            ),
          ),
          isTrue,
        );
        expect(
          overLimit.profile.isWalkableSupport(
            overLimit.geometry.edges.singleWhere(
              (edge) => edge.dxTicks.abs() == 55 * 1024,
            ),
          ),
          isFalse,
        );
      },
    );

    test(
      'grounded horizontal motion preserves world X on a 45-degree slope',
      () {
        final harness = _Harness([
          _polygon('slope', const [(0, 100), (100, 0), (180, 180), (0, 180)]),
        ]);
        final support = harness.geometry.edges.singleWhere(
          (edge) =>
              edge.dxTicks.abs() == 100 * 1024 &&
              edge.dyTicks.abs() == 100 * 1024 &&
              edge.outwardNormal.yTicks < 0,
        );
        final capsule = _supportedCircle(support, contactXWorld: 40);
        final result = TerrainCapsuleMotionResult();

        harness.controller.move(
          capsule: capsule,
          request: TerrainMotionRequest(
            displacementXTicks: 8 * 1024,
            displacementYTicks: 0,
            gravityYTicks: 200,
            mode: TerrainMotionMode.groundedHorizontal,
          ),
          beganGrounded: true,
          priorSupportEdgeId: support.id,
          priorSupportGeometryVersion: harness.geometry.version,
          out: result,
        );

        expect(result.grounded, isTrue);
        expect(result.resolvedXTicks, 8 * 1024);
        expect(
          result.resolvedYTicks,
          closeTo(-8 * 1024, terrainCollisionSkinTicks),
        );
        expect(result.progressionXTicks, 8 * 1024);
      },
    );

    test(
      'support snap follows a three-pixel descent without acquiring from air',
      () {
        final harness = _Harness([
          _polygon('high', const [(0, 100), (100, 100), (100, 200), (0, 200)]),
          _polygon('low', const [
            (100, 103),
            (220, 103),
            (220, 200),
            (100, 200),
          ]),
        ]);
        final highSupport = harness.upwardEdges.singleWhere(
          (edge) => edge.start.yTicks == 100 * 1024,
        );
        final start = _circle(88, 100 - 10 - terrainCollisionSkinTicks / 1024);

        final grounded = TerrainCapsuleMotionResult();
        harness.controller.move(
          capsule: start,
          request: TerrainMotionRequest(
            displacementXTicks: 24 * 1024,
            displacementYTicks: 0,
            mode: TerrainMotionMode.groundedHorizontal,
          ),
          beganGrounded: true,
          priorSupportEdgeId: highSupport.id,
          priorSupportGeometryVersion: harness.geometry.version,
          out: grounded,
        );
        expect(grounded.grounded, isTrue);
        expect(grounded.usedSnap, isTrue);
        expect(grounded.snapCorrectionYTicks, closeTo(3 * 1024, 2));

        final airborne = TerrainCapsuleMotionResult();
        harness.controller.move(
          capsule: start,
          request: TerrainMotionRequest(
            displacementXTicks: 24 * 1024,
            displacementYTicks: 0,
            mode: TerrainMotionMode.worldSpace,
          ),
          beganGrounded: false,
          out: airborne,
        );
        expect(airborne.usedSnap, isFalse);
      },
    );

    test('connected convex peak and concave valley retain support', () {
      for (final fixture in <(String, List<(double, double)>, int)>[
        (
          'peak',
          const [(0, 100), (100, 50), (200, 100), (200, 200), (0, 200)],
          -50,
        ),
        (
          'valley',
          const [(0, 50), (100, 100), (200, 50), (200, 200), (0, 200)],
          50,
        ),
      ]) {
        final harness = _Harness([_polygon(fixture.$1, fixture.$2)]);
        final firstSupport = harness.geometry.edges.singleWhere(
          (edge) =>
              edge.dxTicks == 100 * 1024 &&
              edge.dyTicks == fixture.$3 * 1024 &&
              edge.outwardNormal.yTicks < 0,
        );
        final result = TerrainCapsuleMotionResult();

        harness.controller.move(
          capsule: _supportedCircle(firstSupport, contactXWorld: 90),
          request: TerrainMotionRequest(
            displacementXTicks: 24 * 1024,
            displacementYTicks: 0,
            mode: TerrainMotionMode.groundedHorizontal,
          ),
          beganGrounded: true,
          priorSupportEdgeId: firstSupport.id,
          priorSupportGeometryVersion: harness.geometry.version,
          out: result,
        );

        expect(
          result.grounded,
          isTrue,
          reason:
              '${fixture.$1}: pos=(${result.finalCenterXTicks},'
              '${result.finalCenterYTicks}) contacts=${result.contactCount} '
              'support=${result.supportEdgeId} snap=${result.usedSnap} '
              'diag=${result.diagnostic}',
        );
        expect(
          result.resolvedXTicks,
          closeTo(24 * 1024, terrainCollisionSkinTicks),
          reason: fixture.$1,
        );
        expect(
          result.diagnostic,
          TerrainControllerDiagnostic.none,
          reason: fixture.$1,
        );
      }
    });

    test(
      'grounded surface motion preserves scalar distance across support joins',
      () {
        for (final fixture in <(String, List<(double, double)>, int)>[
          (
            'surface-peak',
            const [(0, 100), (100, 50), (200, 100), (200, 200), (0, 200)],
            -50,
          ),
          (
            'surface-valley',
            const [(0, 50), (100, 100), (200, 50), (200, 200), (0, 200)],
            50,
          ),
        ]) {
          final harness = _Harness([_polygon(fixture.$1, fixture.$2)]);
          final support = harness.geometry.edges.singleWhere(
            (edge) =>
                edge.dxTicks == 100 * 1024 &&
                edge.dyTicks == fixture.$3 * 1024 &&
                edge.outwardNormal.yTicks < 0,
          );
          final result = TerrainCapsuleMotionResult();

          harness.controller.move(
            capsule: _supportedCircle(support, contactXWorld: 90),
            request: TerrainMotionRequest(
              displacementXTicks: 30 * 1024,
              displacementYTicks: 0,
              mode: TerrainMotionMode.groundedSurface,
              surfaceDirectionSign: 1,
            ),
            beganGrounded: true,
            priorSupportEdgeId: support.id,
            priorSupportGeometryVersion: harness.geometry.version,
            out: result,
          );

          expect(result.grounded, isTrue, reason: fixture.$1);
          expect(
            result.supportedTravelTicks.abs(),
            closeTo(30 * 1024, 8),
            reason: fixture.$1,
          );
        }
      },
    );

    test('stationary supported gravity does not slide on ordinary slopes', () {
      for (final fixture in <(String, List<(double, double)>)>[
        ('slope-30', const [(0, 197), (97, 141), (160, 240), (0, 240)]),
        ('slope-45', const [(0, 197), (97, 100), (160, 240), (0, 240)]),
        ('slope-60', const [(0, 197), (56, 100), (100, 240), (0, 240)]),
      ]) {
        final harness = _Harness([_polygon(fixture.$1, fixture.$2)]);
        final support = harness.geometry.edges
            .where(
              (edge) =>
                  edge.outwardNormal.yTicks < 0 &&
                  harness.profile.isWalkableSupport(edge),
            )
            .first;
        var capsule = _supportedCircleAtCenterX(support, centerXWorld: 30);
        final start = capsule.center;
        var supportId = support.id;

        for (var tick = 0; tick < 180; tick += 1) {
          final result = TerrainCapsuleMotionResult();
          harness.controller.move(
            capsule: capsule,
            request: TerrainMotionRequest(
              displacementXTicks: 0,
              displacementYTicks: 0,
              gravityYTicks: 400,
              mode: TerrainMotionMode.groundedHorizontal,
            ),
            beganGrounded: true,
            priorSupportEdgeId: supportId,
            priorSupportGeometryVersion: harness.geometry.version,
            out: result,
          );
          expect(result.grounded, isTrue, reason: '${fixture.$1} tick $tick');
          capsule = UprightCapsule(
            center: TerrainPoint(
              result.finalCenterXTicks,
              result.finalCenterYTicks,
            ),
            radiusTicks: capsule.radiusTicks,
            verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
          );
          supportId = result.supportEdgeId!;
        }

        expect(capsule.center, start, reason: fixture.$1);
      }
    });

    test(
      'diagnostics distinguish blockers, support loss, and stale geometry',
      () {
        final wallHarness = _Harness([
          _polygon('wall', const [(100, 0), (120, 0), (120, 100), (100, 100)]),
        ]);
        final wall = TerrainCapsuleMotionResult();
        wallHarness.controller.move(
          capsule: _circle(50, 60),
          request: TerrainMotionRequest(
            displacementXTicks: 100 * 1024,
            displacementYTicks: 0,
            mode: TerrainMotionMode.worldSpace,
          ),
          beganGrounded: false,
          out: wall,
        );
        expect(wall.diagnostic, TerrainControllerDiagnostic.blockedWall);

        final floorHarness = _Harness([
          _polygon('floor', const [(0, 100), (100, 100), (100, 180), (0, 180)]),
        ]);
        final support = floorHarness.upwardEdges.single;
        final stale = TerrainCapsuleMotionResult();
        floorHarness.controller.move(
          capsule: _circle(50, 90 - terrainCollisionSkinTicks / 1024),
          request: TerrainMotionRequest(
            displacementXTicks: 0,
            displacementYTicks: 0,
            mode: TerrainMotionMode.groundedHorizontal,
          ),
          beganGrounded: true,
          priorSupportEdgeId: support.id,
          priorSupportGeometryVersion: 0,
          out: stale,
        );
        expect(
          stale.diagnostic,
          TerrainControllerDiagnostic.invalidGeometryVersion,
        );

        final departed = TerrainCapsuleMotionResult();
        floorHarness.controller.move(
          capsule: _circle(88, 90 - terrainCollisionSkinTicks / 1024),
          request: TerrainMotionRequest(
            displacementXTicks: 30 * 1024,
            displacementYTicks: 0,
            mode: TerrainMotionMode.groundedHorizontal,
          ),
          beganGrounded: true,
          priorSupportEdgeId: support.id,
          priorSupportGeometryVersion: floorHarness.geometry.version,
          out: departed,
        );
        expect(departed.grounded, isFalse);
        expect(departed.diagnostic, TerrainControllerDiagnostic.unsupported);
      },
    );

    test(
      'published geometry replacement invalidates retained support version',
      () {
        final polygons = [
          _polygon('floor', const [(0, 100), (100, 100), (100, 180), (0, 180)]),
        ];
        final original = _Harness(polygons, geometryVersion: 1);
        final replacement = _Harness(polygons, geometryVersion: 2);
        final originalSupport = original.upwardEdges.single;
        final replacementSupport = replacement.upwardEdges.single;
        final result = TerrainCapsuleMotionResult();

        replacement.controller.move(
          capsule: _supportedCircleAtCenterX(
            replacementSupport,
            centerXWorld: 50,
          ),
          request: TerrainMotionRequest(
            displacementXTicks: 0,
            displacementYTicks: 0,
            mode: TerrainMotionMode.groundedHorizontal,
          ),
          beganGrounded: true,
          priorSupportEdgeId: originalSupport.id,
          priorSupportGeometryVersion: original.geometry.version,
          out: result,
        );

        expect(
          result.diagnostic,
          TerrainControllerDiagnostic.invalidGeometryVersion,
        );
        expect(result.grounded, isFalse);
        expect(result.supportEdgeId, isNull);
      },
    );

    test('automatic step climbs three pixels and rejects five pixels', () {
      final threePixel = _stepHarness(stepHeight: 3);
      final threeSupport = threePixel.upwardEdges.singleWhere(
        (edge) => edge.start.yTicks == 103 * 1024,
      );
      final accepted = TerrainCapsuleMotionResult();
      threePixel.controller.move(
        capsule: _circle(88, 103 - 10 - terrainCollisionSkinTicks / 1024),
        request: TerrainMotionRequest(
          displacementXTicks: 24 * 1024,
          displacementYTicks: 0,
          mode: TerrainMotionMode.groundedHorizontal,
        ),
        beganGrounded: true,
        priorSupportEdgeId: threeSupport.id,
        priorSupportGeometryVersion: threePixel.geometry.version,
        out: accepted,
      );
      expect(accepted.usedStep, isTrue);
      expect(accepted.grounded, isTrue);
      expect(accepted.stepVerticalCorrectionYTicks, closeTo(-3 * 1024, 2));

      final fivePixel = _stepHarness(stepHeight: 5);
      final fiveSupport = fivePixel.upwardEdges.singleWhere(
        (edge) => edge.start.yTicks == 105 * 1024,
      );
      final rejected = TerrainCapsuleMotionResult();
      fivePixel.controller.move(
        capsule: _circle(88, 105 - 10 - terrainCollisionSkinTicks / 1024),
        request: TerrainMotionRequest(
          displacementXTicks: 24 * 1024,
          displacementYTicks: 0,
          mode: TerrainMotionMode.groundedHorizontal,
        ),
        beganGrounded: true,
        priorSupportEdgeId: fiveSupport.id,
        priorSupportGeometryVersion: fivePixel.geometry.version,
        out: rejected,
      );
      expect(rejected.usedStep, isFalse);
      expect(rejected.hitRight, isTrue);
      expect(rejected.finalCenterXTicks, lessThan(100 * 1024));
    });

    test('automatic step uses an inclusive four-pixel limit', () {
      for (final value in <(double, bool)>[
        (0, false),
        (3.5, true),
        (4, true),
        (4.5, false),
      ]) {
        final harness = _stepHarness(stepHeight: value.$1);
        final support = harness.upwardEdges.singleWhere(
          (edge) =>
              edge.id.shapeId == 'lower' &&
              edge.start.yTicks == (100 + value.$1) * 1024,
        );
        final result = TerrainCapsuleMotionResult();
        harness.controller.move(
          capsule: _circle(
            88,
            100 +
                value.$1 -
                10 -
                terrainCollisionSkinTicks / terrainPhysicsTicksPerWorldUnit,
          ),
          request: TerrainMotionRequest(
            displacementXTicks: 24 * 1024,
            displacementYTicks: 0,
            mode: TerrainMotionMode.groundedHorizontal,
          ),
          beganGrounded: true,
          priorSupportEdgeId: support.id,
          priorSupportGeometryVersion: harness.geometry.version,
          out: result,
        );
        expect(result.usedStep, value.$2, reason: '${value.$1} pixels');
      }
    });

    test('automatic step rejects blocked overhead clearance', () {
      final harness = _Harness([
        _polygon('lower', const [(0, 103), (100, 103), (100, 200), (0, 200)]),
        _polygon('upper', const [
          (100, 100),
          (220, 100),
          (220, 200),
          (100, 200),
        ]),
        _polygon('ceiling', const [
          (60, 60),
          (130, 60),
          (130, 79.5),
          (60, 79.5),
        ]),
      ]);
      final support = harness.upwardEdges.singleWhere(
        (edge) => edge.start.yTicks == 103 * 1024,
      );
      final result = TerrainCapsuleMotionResult();

      harness.controller.move(
        capsule: _circle(88, 103 - 10 - terrainCollisionSkinTicks / 1024),
        request: TerrainMotionRequest(
          displacementXTicks: 24 * 1024,
          displacementYTicks: 0,
          mode: TerrainMotionMode.groundedHorizontal,
        ),
        beganGrounded: true,
        priorSupportEdgeId: support.id,
        priorSupportGeometryVersion: harness.geometry.version,
        out: result,
      );

      expect(
        result.usedStep,
        isFalse,
        reason:
            'pos=(${result.finalCenterXTicks},${result.finalCenterYTicks}) '
            'recovery=(${result.recoveryCorrectionXTicks},'
            '${result.recoveryCorrectionYTicks}) '
            'contacts=${result.contactCount} ceiling=${result.hitCeiling}',
      );
      expect(result.hitRight, isTrue);
    });

    test('automatic step works from both sides of a four-pixel platform', () {
      final harness = _Harness([
        _polygon('left-lower', const [
          (0, 104),
          (100, 104),
          (100, 200),
          (0, 200),
        ]),
        _polygon('platform', const [
          (100, 100),
          (200, 100),
          (200, 200),
          (100, 200),
        ]),
        _polygon('right-lower', const [
          (200, 104),
          (300, 104),
          (300, 200),
          (200, 200),
        ]),
      ]);

      for (final direction in <int>[1, -1]) {
        final support = harness.upwardEdges.singleWhere(
          (edge) =>
              edge.start.yTicks == 104 * 1024 &&
              (direction > 0
                  ? edge.start.xTicks == 0
                  : edge.start.xTicks == 200 * 1024),
        );
        final result = TerrainCapsuleMotionResult();
        harness.controller.move(
          capsule: _supportedCircleAtCenterX(
            support,
            centerXWorld: direction > 0 ? 88 : 212,
          ),
          request: TerrainMotionRequest(
            displacementXTicks: direction * 24 * 1024,
            displacementYTicks: 0,
            mode: TerrainMotionMode.groundedHorizontal,
          ),
          beganGrounded: true,
          priorSupportEdgeId: support.id,
          priorSupportGeometryVersion: harness.geometry.version,
          out: result,
        );

        expect(result.usedStep, isTrue, reason: 'direction $direction');
        expect(result.grounded, isTrue, reason: 'direction $direction');
        expect(
          result.stepVerticalCorrectionYTicks,
          closeTo(-4 * 1024, 2),
          reason: 'direction $direction',
        );
      }
    });

    test(
      'step helper cannot be acquired from air or bypass a taller ledge',
      () {
        final fourPixel = _stepHarness(stepHeight: 4);
        final airborne = TerrainCapsuleMotionResult();
        fourPixel.controller.move(
          capsule: _circle(88, 94 - terrainCollisionSkinTicks / 1024),
          request: TerrainMotionRequest(
            displacementXTicks: 24 * 1024,
            displacementYTicks: 0,
            mode: TerrainMotionMode.worldSpace,
          ),
          beganGrounded: false,
          out: airborne,
        );
        expect(airborne.usedStep, isFalse);
        expect(airborne.finalCenterXTicks, lessThan(100 * 1024));

        final sixPixel = _stepHarness(stepHeight: 6);
        final support = sixPixel.upwardEdges.singleWhere(
          (edge) => edge.start.yTicks == 106 * 1024,
        );
        final highSpeed = TerrainCapsuleMotionResult();
        sixPixel.controller.move(
          capsule: _supportedCircleAtCenterX(support, centerXWorld: 50),
          request: TerrainMotionRequest(
            displacementXTicks: 100 * 1024,
            displacementYTicks: 0,
            mode: TerrainMotionMode.groundedHorizontal,
          ),
          beganGrounded: true,
          priorSupportEdgeId: support.id,
          priorSupportGeometryVersion: sixPixel.geometry.version,
          out: highSpeed,
        );
        expect(highSpeed.usedStep, isFalse);
        expect(highSpeed.finalCenterXTicks, lessThan(100 * 1024));
        expect(highSpeed.hitRight, isTrue);
      },
    );

    test('one-way endpoint is never promoted into a step wall', () {
      final harness = _Harness([
        _polygon('lower', const [(0, 104), (100, 104), (100, 200), (0, 200)]),
        _polygon('one-way', const [
          (100, 100),
          (220, 100),
          (220, 110),
          (100, 110),
        ], collisionMode: TerrainCollisionMode.oneWay),
      ]);
      final support = harness.upwardEdges.singleWhere(
        (edge) =>
            edge.collisionMode == TerrainCollisionMode.solid &&
            edge.start.yTicks == 104 * 1024,
      );
      final result = TerrainCapsuleMotionResult();

      harness.controller.move(
        capsule: _supportedCircleAtCenterX(support, centerXWorld: 88),
        request: TerrainMotionRequest(
          displacementXTicks: 24 * 1024,
          displacementYTicks: 0,
          mode: TerrainMotionMode.groundedHorizontal,
        ),
        beganGrounded: true,
        priorSupportEdgeId: support.id,
        priorSupportGeometryVersion: harness.geometry.version,
        out: result,
      );

      expect(result.usedStep, isFalse);
      expect(result.hitRight, isFalse);
    });

    test('automatic step rejects blocked, narrow, and steep landings', () {
      final fixtures = <(String, _Harness)>[
        (
          'blocked-forward',
          _Harness([
            _polygon('lower', const [
              (0, 104),
              (100, 104),
              (100, 200),
              (0, 200),
            ]),
            _polygon('upper', const [
              (100, 100),
              (108, 100),
              (108, 200),
              (100, 200),
            ]),
            _polygon('blocker', const [
              (108, 50),
              (140, 50),
              (140, 200),
              (108, 200),
            ]),
          ]),
        ),
        (
          'narrow-landing',
          _Harness([
            _polygon('lower', const [
              (0, 104),
              (100, 104),
              (100, 200),
              (0, 200),
            ]),
            _polygon('upper', const [
              (100, 100),
              (104, 100),
              (104, 200),
              (100, 200),
            ]),
          ]),
        ),
        (
          'steep-landing',
          _Harness([
            _polygon('lower', const [
              (0, 104),
              (100, 104),
              (100, 200),
              (0, 200),
            ]),
            _polygon('upper', const [
              (100, 100),
              (130, 40),
              (180, 200),
              (100, 200),
            ]),
          ]),
        ),
      ];

      for (final fixture in fixtures) {
        final support = fixture.$2.upwardEdges.singleWhere(
          (edge) =>
              edge.id.shapeId == 'lower' && edge.start.yTicks == 104 * 1024,
        );
        final result = TerrainCapsuleMotionResult();
        fixture.$2.controller.move(
          capsule: _supportedCircleAtCenterX(support, centerXWorld: 88),
          request: TerrainMotionRequest(
            displacementXTicks: 24 * 1024,
            displacementYTicks: 0,
            mode: TerrainMotionMode.groundedHorizontal,
          ),
          beganGrounded: true,
          priorSupportEdgeId: support.id,
          priorSupportGeometryVersion: fixture.$2.geometry.version,
          out: result,
        );

        expect(result.usedStep, isFalse, reason: fixture.$1);
      }
    });

    test(
      'shallow overlap recovers but deep containment restores last valid',
      () {
        final harness = _Harness([
          _polygon('ground', const [
            (0, 100),
            (200, 100),
            (200, 220),
            (0, 220),
          ]),
        ]);

        final shallow = TerrainCapsuleMotionResult();
        harness.controller.move(
          capsule: _circle(50, 91),
          request: TerrainMotionRequest(
            displacementXTicks: 0,
            displacementYTicks: 0,
            mode: TerrainMotionMode.worldSpace,
          ),
          beganGrounded: false,
          out: shallow,
        );
        expect(shallow.usedRecovery, isTrue);
        expect(shallow.diagnostic, TerrainControllerDiagnostic.none);
        expect(
          shallow.finalCenterYTicks,
          closeTo(90 * 1024 - terrainCollisionSkinTicks, 2),
        );

        final deep = TerrainCapsuleMotionResult();
        harness.controller.move(
          capsule: _circle(50, 150),
          request: TerrainMotionRequest(
            displacementXTicks: 0,
            displacementYTicks: 0,
            mode: TerrainMotionMode.worldSpace,
          ),
          beganGrounded: false,
          lastValidCapsuleCenterXTicks: 50 * 1024,
          lastValidCapsuleCenterYTicks: 50 * 1024,
          out: deep,
        );
        expect(deep.diagnostic, TerrainControllerDiagnostic.recoveryFailed);
        expect(deep.finalCenterXTicks, 50 * 1024);
        expect(deep.finalCenterYTicks, 50 * 1024);
        expect(deep.grounded, isFalse);
      },
    );

    test('free world-space motion is exact at negative coordinates', () {
      final harness = _Harness([
        _polygon('distant', const [
          (1000, 1000),
          (1100, 1000),
          (1100, 1100),
          (1000, 1100),
        ]),
      ]);
      final result = TerrainCapsuleMotionResult();

      harness.controller.move(
        capsule: _circle(-50, -30),
        request: TerrainMotionRequest(
          displacementXTicks: -12345,
          displacementYTicks: 6789,
          mode: TerrainMotionMode.worldSpace,
        ),
        beganGrounded: false,
        out: result,
      );

      expect(result.resolvedXTicks, -12345);
      expect(result.resolvedYTicks, 6789);
      expect(result.contactCount, 0);
      expect(result.diagnostic, TerrainControllerDiagnostic.none);
    });

    test(
      'grounded horizontal and surface modes preserve their authored scalar',
      () {
        for (final fixture in <(String, List<(double, double)>, int)>[
          ('slope-30', const [(0, 197), (97, 141), (180, 240), (0, 240)], 97),
          ('slope-45', const [(0, 197), (97, 100), (180, 240), (0, 240)], 97),
          ('slope-60', const [(0, 197), (56, 100), (120, 240), (0, 240)], 56),
        ]) {
          final harness = _Harness([_polygon(fixture.$1, fixture.$2)]);
          final support = harness.geometry.edges.singleWhere(
            (edge) =>
                edge.dxTicks == fixture.$3 * 1024 &&
                edge.outwardNormal.yTicks < 0,
          );
          final start = _supportedCircleAtCenterX(support, centerXWorld: 20);

          final horizontal = TerrainCapsuleMotionResult();
          harness.controller.move(
            capsule: start,
            request: TerrainMotionRequest(
              displacementXTicks: 8 * 1024,
              displacementYTicks: 0,
              mode: TerrainMotionMode.groundedHorizontal,
            ),
            beganGrounded: true,
            priorSupportEdgeId: support.id,
            priorSupportGeometryVersion: harness.geometry.version,
            out: horizontal,
          );
          expect(
            horizontal.resolvedXTicks,
            8 * 1024,
            reason: '${fixture.$1} horizontal',
          );
          expect(horizontal.grounded, isTrue, reason: fixture.$1);

          final surface = TerrainCapsuleMotionResult();
          harness.controller.move(
            capsule: start,
            request: TerrainMotionRequest(
              displacementXTicks: 8 * 1024,
              displacementYTicks: 0,
              mode: TerrainMotionMode.groundedSurface,
              surfaceDirectionSign: 1,
            ),
            beganGrounded: true,
            priorSupportEdgeId: support.id,
            priorSupportGeometryVersion: harness.geometry.version,
            out: surface,
          );
          expect(
            surface.supportedTravelTicks.abs(),
            closeTo(8 * 1024, 2),
            reason: '${fixture.$1} surface',
          );
          expect(surface.grounded, isTrue, reason: fixture.$1);
        }
      },
    );

    test('exact cross-polygon seam traverses in both directions', () {
      final harness = _Harness([
        _polygon('left', const [(0, 100), (100, 100), (100, 200), (0, 200)]),
        _polygon('right', const [
          (100, 100),
          (200, 100),
          (200, 200),
          (100, 200),
        ]),
      ]);
      final supports = harness.upwardEdges.toList();

      for (final direction in <int>[1, -1]) {
        final support = supports.singleWhere(
          (edge) => direction > 0
              ? edge.start.xTicks == 0
              : edge.end.xTicks == 200 * 1024,
        );
        final result = TerrainCapsuleMotionResult();
        harness.controller.move(
          capsule: _supportedCircleAtCenterX(
            support,
            centerXWorld: direction > 0 ? 90 : 110,
          ),
          request: TerrainMotionRequest(
            displacementXTicks: direction * 20 * 1024,
            displacementYTicks: 0,
            mode: TerrainMotionMode.groundedHorizontal,
          ),
          beganGrounded: true,
          priorSupportEdgeId: support.id,
          priorSupportGeometryVersion: harness.geometry.version,
          out: result,
        );

        expect(result.grounded, isTrue, reason: 'direction $direction');
        expect(result.resolvedXTicks, direction * 20 * 1024);
        expect(result.hitLeft || result.hitRight, isFalse);
        expect(result.diagnostic, TerrainControllerDiagnostic.none);
      }
    });

    test('polygon winding does not change travel over compiled geometry', () {
      const clockwise = <(double, double)>[
        (0, 100),
        (200, 100),
        (200, 200),
        (0, 200),
      ];

      TerrainCapsuleMotionResult solve(List<(double, double)> vertices) {
        final harness = _Harness([_polygon('ground', vertices)]);
        final support = harness.upwardEdges.single;
        final result = TerrainCapsuleMotionResult();
        harness.controller.move(
          capsule: _supportedCircleAtCenterX(support, centerXWorld: 50),
          request: TerrainMotionRequest(
            displacementXTicks: 40 * 1024,
            displacementYTicks: 0,
            mode: TerrainMotionMode.groundedHorizontal,
          ),
          beganGrounded: true,
          priorSupportEdgeId: support.id,
          priorSupportGeometryVersion: harness.geometry.version,
          out: result,
        );
        return result;
      }

      final forward = solve(clockwise);
      final reverse = solve(clockwise.reversed.toList());
      expect(reverse.finalCenterXTicks, forward.finalCenterXTicks);
      expect(reverse.finalCenterYTicks, forward.finalCenterYTicks);
      expect(reverse.supportNormalXTicks, forward.supportNormalXTicks);
      expect(reverse.supportNormalYTicks, forward.supportNormalYTicks);
      expect(reverse.grounded, isTrue);
    });

    test('overlapping solid and one-way X ranges select approached face', () {
      final harness = _Harness([
        _polygon('solid', const [(0, 120), (200, 120), (200, 160), (0, 160)]),
        _polygon('one-way', const [
          (0, 80),
          (200, 80),
          (200, 90),
          (0, 90),
        ], collisionMode: TerrainCollisionMode.oneWay),
      ]);

      for (final fixture in <(double, double, String)>[
        (40, 100, 'one-way'),
        (100, 30, 'solid'),
      ]) {
        final result = TerrainCapsuleMotionResult();
        harness.controller.move(
          capsule: _circle(50, fixture.$1),
          request: TerrainMotionRequest(
            displacementXTicks: 0,
            displacementYTicks: (fixture.$2 * 1024).round(),
            mode: TerrainMotionMode.worldSpace,
          ),
          beganGrounded: false,
          out: result,
        );

        expect(result.grounded, isTrue, reason: fixture.$3);
        expect(result.supportEdgeId!.shapeId, fixture.$3, reason: fixture.$3);
        expect(
          result.hitLeft || result.hitRight || result.hitCeiling,
          isFalse,
          reason: fixture.$3,
        );
        expect(
          result.contactKinds.take(result.contactCount),
          everyElement(TerrainContactKind.support),
          reason: fixture.$3,
        );
      }
    });

    test('equal-time corner result ignores authored polygon order', () {
      final floor = _polygon('floor', const [
        (0, 100),
        (180, 100),
        (180, 180),
        (0, 180),
      ]);
      final wall = _polygon('wall', const [
        (100, 0),
        (180, 0),
        (180, 100),
        (100, 100),
      ]);

      TerrainCapsuleMotionResult solve(List<TerrainPolygonInput> polygons) {
        final harness = _Harness(polygons);
        final result = TerrainCapsuleMotionResult();
        harness.controller.move(
          capsule: _circle(70, 70),
          request: TerrainMotionRequest(
            displacementXTicks: 50 * 1024,
            displacementYTicks: 50 * 1024,
            mode: TerrainMotionMode.worldSpace,
          ),
          beganGrounded: false,
          out: result,
        );
        return result;
      }

      final forward = solve([floor, wall]);
      final reversed = solve([wall, floor]);
      expect(reversed.finalCenterXTicks, forward.finalCenterXTicks);
      expect(reversed.finalCenterYTicks, forward.finalCenterYTicks);
      expect(reversed.grounded, forward.grounded);
      expect(reversed.hitRight, forward.hitRight);
      expect(reversed.contactCount, forward.contactCount);
      expect(
        reversed.contactEdgeIds.take(reversed.contactCount),
        orderedEquals(forward.contactEdgeIds.take(forward.contactCount)),
      );
      expect(
        reversed.contactNormalXTicks.take(reversed.contactCount),
        orderedEquals(forward.contactNormalXTicks.take(forward.contactCount)),
      );
      expect(
        reversed.contactNormalYTicks.take(reversed.contactCount),
        orderedEquals(forward.contactNormalYTicks.take(forward.contactCount)),
      );
    });

    test('one-way support traverses and departs without an endpoint wall', () {
      final harness = _Harness([
        _polygon('one-way', const [
          (0, 100),
          (200, 100),
          (200, 110),
          (0, 110),
        ], collisionMode: TerrainCollisionMode.oneWay),
      ]);
      final support = harness.upwardEdges.single;
      final traverse = TerrainCapsuleMotionResult();
      harness.controller.move(
        capsule: _supportedCircleAtCenterX(support, centerXWorld: 40),
        request: TerrainMotionRequest(
          displacementXTicks: 120 * 1024,
          displacementYTicks: 0,
          mode: TerrainMotionMode.groundedHorizontal,
        ),
        beganGrounded: true,
        priorSupportEdgeId: support.id,
        priorSupportGeometryVersion: harness.geometry.version,
        out: traverse,
      );
      expect(traverse.grounded, isTrue);
      expect(traverse.hitLeft || traverse.hitRight, isFalse);

      final depart = TerrainCapsuleMotionResult();
      harness.controller.move(
        capsule: _supportedCircleAtCenterX(support, centerXWorld: 190),
        request: TerrainMotionRequest(
          displacementXTicks: 30 * 1024,
          displacementYTicks: 0,
          mode: TerrainMotionMode.groundedHorizontal,
        ),
        beganGrounded: true,
        priorSupportEdgeId: support.id,
        priorSupportGeometryVersion: harness.geometry.version,
        out: depart,
      );
      expect(depart.grounded, isFalse);
      expect(depart.hitRight, isFalse);
      expect(depart.resolvedXTicks, 30 * 1024);
      expect(depart.diagnostic, TerrainControllerDiagnostic.unsupported);
    });

    test(
      'recovery handles wall and ceiling but ignores one-way back sides',
      () {
        final wallHarness = _Harness([
          _polygon('wall', const [(100, 0), (180, 0), (180, 180), (100, 180)]),
        ]);
        final wall = TerrainCapsuleMotionResult();
        wallHarness.controller.move(
          capsule: _circle(91, 60),
          request: TerrainMotionRequest(
            displacementXTicks: 0,
            displacementYTicks: 0,
            mode: TerrainMotionMode.worldSpace,
          ),
          beganGrounded: false,
          out: wall,
        );
        expect(wall.usedRecovery, isTrue);
        expect(
          wall.finalCenterXTicks,
          closeTo(90 * 1024 - terrainCollisionSkinTicks, 2),
        );

        final ceilingHarness = _Harness([
          _polygon('ceiling', const [(0, 0), (180, 0), (180, 20), (0, 20)]),
        ]);
        final ceiling = TerrainCapsuleMotionResult();
        ceilingHarness.controller.move(
          capsule: _circle(50, 29),
          request: TerrainMotionRequest(
            displacementXTicks: 0,
            displacementYTicks: 0,
            mode: TerrainMotionMode.worldSpace,
          ),
          beganGrounded: false,
          out: ceiling,
        );
        expect(ceiling.usedRecovery, isTrue);
        expect(
          ceiling.finalCenterYTicks,
          closeTo(30 * 1024 + terrainCollisionSkinTicks, 2),
        );

        final oneWayHarness = _Harness([
          _polygon('one-way', const [
            (0, 100),
            (180, 100),
            (180, 110),
            (0, 110),
          ], collisionMode: TerrainCollisionMode.oneWay),
        ]);
        final oneWay = TerrainCapsuleMotionResult();
        oneWayHarness.controller.move(
          capsule: _circle(50, 101),
          request: TerrainMotionRequest(
            displacementXTicks: 0,
            displacementYTicks: 0,
            mode: TerrainMotionMode.worldSpace,
          ),
          beganGrounded: false,
          out: oneWay,
        );
        expect(oneWay.usedRecovery, isFalse);
        expect(oneWay.finalCenterYTicks, 101 * 1024);
      },
    );

    test('sloped and equal-corner recovery remain canonical', () {
      final slopeHarness = _Harness([
        _polygon('slope', const [(0, 100), (100, 0), (180, 180), (0, 180)]),
      ]);
      final slopeSupport = slopeHarness.geometry.edges.singleWhere(
        (edge) =>
            edge.dxTicks == 100 * 1024 &&
            edge.dyTicks == -100 * 1024 &&
            edge.outwardNormal.yTicks < 0,
      );
      final clearSlope = _supportedCircleAtCenterX(
        slopeSupport,
        centerXWorld: 40,
      );
      final sloped = TerrainCapsuleMotionResult();
      slopeHarness.controller.move(
        capsule: UprightCapsule(
          center: TerrainPoint(
            clearSlope.center.xTicks,
            clearSlope.center.yTicks + 1024,
          ),
          radiusTicks: clearSlope.radiusTicks,
          verticalHalfSegmentTicks: clearSlope.verticalHalfSegmentTicks,
        ),
        request: TerrainMotionRequest(
          displacementXTicks: 0,
          displacementYTicks: 0,
          mode: TerrainMotionMode.worldSpace,
        ),
        beganGrounded: false,
        out: sloped,
      );
      expect(sloped.usedRecovery, isTrue);
      expect(sloped.diagnostic, TerrainControllerDiagnostic.none);

      final floor = _polygon('floor', const [
        (0, 100),
        (180, 100),
        (180, 180),
        (0, 180),
      ]);
      final wall = _polygon('wall', const [
        (100, 0),
        (180, 0),
        (180, 100),
        (100, 100),
      ]);

      TerrainCapsuleMotionResult recover(List<TerrainPolygonInput> polygons) {
        final harness = _Harness(polygons);
        final result = TerrainCapsuleMotionResult();
        harness.controller.move(
          capsule: _circle(91, 91),
          request: TerrainMotionRequest(
            displacementXTicks: 0,
            displacementYTicks: 0,
            mode: TerrainMotionMode.worldSpace,
          ),
          beganGrounded: false,
          out: result,
        );
        return result;
      }

      final forward = recover([floor, wall]);
      final reversed = recover([wall, floor]);
      expect(forward.usedRecovery, isTrue);
      expect(reversed.finalCenterXTicks, forward.finalCenterXTicks);
      expect(reversed.finalCenterYTicks, forward.finalCenterYTicks);
      expect(
        reversed.recoveryCorrectionXTicks,
        forward.recoveryCorrectionXTicks,
      );
      expect(
        reversed.recoveryCorrectionYTicks,
        forward.recoveryCorrectionYTicks,
      );
    });

    test('bounded recovery exhaustion restores the last-valid transform', () {
      final harness = _Harness([
        _polygon('ceiling', const [(0, 0), (180, 0), (180, 80), (0, 80)]),
        _polygon('floor', const [(0, 100), (180, 100), (180, 180), (0, 180)]),
      ]);
      final result = TerrainCapsuleMotionResult();

      harness.controller.move(
        capsule: _circle(50, 90),
        request: TerrainMotionRequest(
          displacementXTicks: 0,
          displacementYTicks: 0,
          mode: TerrainMotionMode.worldSpace,
        ),
        beganGrounded: false,
        lastValidCapsuleCenterXTicks: 50 * 1024,
        lastValidCapsuleCenterYTicks: 50 * 1024,
        out: result,
      );

      expect(result.diagnostic, TerrainControllerDiagnostic.recoveryFailed);
      expect(result.recoveryIterations, terrainMaxRecoveryIterations);
      expect(result.finalCenterXTicks, 50 * 1024);
      expect(result.finalCenterYTicks, 50 * 1024);
      expect(result.grounded, isFalse);
    });
  });
}

_Harness _stepHarness({required double stepHeight}) => _Harness([
  _polygon('lower', [
    (0, 100 + stepHeight),
    (100, 100 + stepHeight),
    (100, 200),
    (0, 200),
  ]),
  _polygon('upper', const [(100, 100), (220, 100), (220, 200), (100, 200)]),
]);

class _Harness {
  _Harness(List<TerrainPolygonInput> polygons, {int geometryVersion = 1})
    : geometry = const TerrainCompiler().compile(
        polygons,
        geometryVersion: geometryVersion,
      ),
      profile = createEloiseTerrainTraversalProfile(
        enabled: true,
        isKinematic: false,
        useGravity: true,
        gravityScale: 1,
        collideCeilings: true,
        collideLeftWalls: true,
        collideRightWalls: true,
      ) {
    final edgeIndex = TerrainEdgeIndex(edges: geometry.edges);
    controller = TerrainCapsuleController(
      geometry: geometry,
      index: edgeIndex,
      profile: profile,
    );
  }

  final TerrainGeometry geometry;
  final TerrainTraversalProfile profile;
  late final TerrainCapsuleController controller;

  Iterable<TerrainEdge> get upwardEdges =>
      geometry.edges.where((edge) => edge.outwardNormal.yTicks < -900);
}

TerrainPolygonInput _polygon(
  String shapeId,
  List<(double, double)> vertices, {
  TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$shapeId',
  identity: TerrainSourceIdentity(
    chunkIndex: 0,
    chunkKey: 'test',
    shapeId: shapeId,
  ),
  vertices: vertices,
  collisionMode: collisionMode,
);

UprightCapsule _circle(double x, double y) => UprightCapsule(
  center: TerrainPoint.fromWorld(x, y),
  radiusTicks: 10 * 1024,
  verticalHalfSegmentTicks: 0,
);

UprightCapsule _supportedCircle(
  TerrainEdge edge, {
  required double contactXWorld,
}) {
  final contactX = physicsCoordinateToTicks(contactXWorld);
  final numerator =
      (contactX - edge.start.xTicks) * (edge.end.yTicks - edge.start.yTicks);
  final contactY =
      edge.start.yTicks + numerator ~/ (edge.end.xTicks - edge.start.xTicks);
  const clearance = 10 * 1024 + terrainCollisionSkinTicks;
  final centerX =
      contactX +
      (clearance * edge.outwardNormal.xTicks) ~/ terrainDirectionScale;
  final centerY =
      contactY +
      (clearance * edge.outwardNormal.yTicks) ~/ terrainDirectionScale;
  return UprightCapsule(
    center: TerrainPoint(centerX, centerY),
    radiusTicks: 10 * 1024,
    verticalHalfSegmentTicks: 0,
  );
}

UprightCapsule _supportedCircleAtCenterX(
  TerrainEdge edge, {
  required double centerXWorld,
}) {
  final centerX = physicsCoordinateToTicks(centerXWorld);
  const radius = 10 * 1024;
  final normalX = edge.dyTicks;
  final normalY = -edge.dxTicks;
  final edgeLength = _integerSqrtForTest(
    edge.dxTicks * edge.dxTicks + edge.dyTicks * edge.dyTicks,
  );
  final extent = radius * edgeLength + terrainCollisionSkinTicks * edgeLength;
  final constant =
      normalX * edge.start.xTicks + normalY * edge.start.yTicks + extent;
  final numerator = constant - normalX * centerX;
  final centerY = _roundedDivideForTest(numerator, normalY);
  return UprightCapsule(
    center: TerrainPoint(centerX, centerY),
    radiusTicks: radius,
    verticalHalfSegmentTicks: 0,
  );
}

int _roundedDivideForTest(int numerator, int denominator) {
  final negative = (numerator < 0) != (denominator < 0);
  final quotient =
      (numerator.abs() + denominator.abs() ~/ 2) ~/ denominator.abs();
  return negative ? -quotient : quotient;
}

int _integerSqrtForTest(int value) {
  if (value < 2) return value;
  var estimate = 1 << ((value.bitLength + 1) >> 1);
  while (true) {
    final next = (estimate + value ~/ estimate) >> 1;
    if (next >= estimate) return estimate;
    estimate = next;
  }
}
