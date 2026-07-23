import 'package:runner_core/collision/terrain/terrain_capsule_controller.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_traversal_profile.dart';
import 'package:runner_core/navigation/terrain_placement_query.dart';
import 'package:runner_core/navigation/terrain_surface_extractor.dart';
import 'package:runner_core/navigation/terrain_surface_spatial_index.dart';
import 'package:runner_core/navigation/terrain_trajectory_predictor.dart';
import 'package:runner_core/navigation/types/terrain_navigation_surface.dart';
import 'package:test/test.dart';

void main() {
  group('TerrainTrajectoryPredictor landing geometry', () {
    test('predicts vertical flat and diagonal sloped falls', () {
      final flat = _fixture(<TerrainPolygonInput>[
        _platform('flat', 0, 100, 240, 180),
      ]);
      final flatOutput = TerrainLandingPrediction();
      expect(
        _predictor(flat).predictLanding(
          startBodyCenter: TerrainPoint.fromWorld(50, 20),
          capsule: _capsule(),
          velocityX: 0,
          velocityY: 0,
          gravityY: 1200,
          maximumFallSpeed: 1500,
          out: flatOutput,
        ),
        isTrue,
      );
      expect(flatOutput.supportEdgeId!.shapeId, 'flat');
      expect(flatOutput.supportPointXTicks, _ticks(50));
      expect(flatOutput.supportPointYTicks, _ticks(100));

      final slope = _fixture(<TerrainPolygonInput>[
        _ground('slope', const <(double, double)>[(0, 140), (240, 60)]),
      ]);
      final slopeOutput = TerrainLandingPrediction();
      expect(
        _predictor(slope).predictLanding(
          startBodyCenter: TerrainPoint.fromWorld(30, 20),
          capsule: _capsule(),
          velocityX: 120,
          velocityY: 0,
          gravityY: 1200,
          maximumFallSpeed: 1500,
          out: slopeOutput,
        ),
        isTrue,
      );
      final surface = slope.surfaces.surfaceById(slopeOutput.supportEdgeId!)!;
      expect(slopeOutput.supportEdgeId!.shapeId, 'slope');
      expect(
        slopeOutput.supportPointYTicks,
        surface.yAtXTicks(slopeOutput.supportPointXTicks),
      );
      expect(slopeOutput.supportNormalYTicks, lessThan(0));
      expect(slopeOutput.ticksToLand, greaterThan(0));
    });

    test('continuous sweep catches a high-speed thin sloped platform', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        TerrainPolygonInput.fromWorld(
          sourcePath: 'test/thin.json',
          identity: TerrainSourceIdentity(
            chunkIndex: 0,
            chunkKey: 'test',
            shapeId: 'thin',
          ),
          vertices: const <(double, double)>[
            (0, 110),
            (120, 90),
            (120, 91),
            (0, 111),
          ],
        ),
      ]);
      final output = TerrainLandingPrediction();

      expect(
        _predictor(fixture, maxTicks: 2).predictLanding(
          startBodyCenter: TerrainPoint.fromWorld(60, -20),
          capsule: _capsule(),
          velocityX: 0,
          velocityY: 10000,
          gravityY: 0,
          maximumFallSpeed: 10000,
          out: output,
        ),
        isTrue,
      );
      expect(output.ticksToLand, 1);
      expect(output.supportEdgeId!.shapeId, 'thin');
    });

    test('jump arcs reland uphill and downhill on the exact slope', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _ground('slope', const <(double, double)>[(0, 150), (240, 70)]),
      ]);
      final surface = _surfaceForShape(fixture.surfaces, 'slope');
      final start = _placedBody(fixture, surface, _ticks(120));

      for (final velocityX in <double>[100, -100]) {
        final output = TerrainLandingPrediction();
        expect(
          _predictor(fixture).predictLanding(
            startBodyCenter: start,
            capsule: _capsule(),
            velocityX: velocityX,
            velocityY: -500,
            gravityY: 1200,
            maximumFallSpeed: 1500,
            out: output,
          ),
          isTrue,
        );
        expect(output.supportEdgeId, surface.id);
        expect(output.ticksToLand, greaterThan(20));
        expect(
          output.supportPointYTicks,
          surface.yAtXTicks(output.supportPointXTicks),
        );
      }
    });

    test('selects the first of multiple surfaces crossed in one tick', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _platform('upper', 0, 100, 200, 110, shapeIndex: 0),
        _platform('lower', 0, 180, 200, 190, shapeIndex: 1),
      ]);
      final output = TerrainLandingPrediction();

      expect(
        _predictor(fixture, maxTicks: 1).predictLanding(
          startBodyCenter: TerrainPoint.fromWorld(80, -50),
          capsule: _capsule(),
          velocityX: 0,
          velocityY: 20000,
          gravityY: 0,
          maximumFallSpeed: 20000,
          out: output,
        ),
        isTrue,
      );
      expect(output.supportEdgeId!.shapeId, 'upper');
      expect(output.supportPointYTicks, _ticks(100));
    });

    test('equal-height seam landing uses canonical support identity', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _platform('left', 0, 100, 60, 150, shapeIndex: 0),
        _platform('right', 60, 100, 120, 150, shapeIndex: 1),
      ]);
      final seamSurfaces =
          fixture.surfaces.surfaces
              .where((surface) => surface.start.yTicks == _ticks(100))
              .toList()
            ..sort((left, right) => left.id.compareTo(right.id));
      final output = TerrainLandingPrediction();

      expect(
        _predictor(fixture).predictLanding(
          startBodyCenter: TerrainPoint.fromWorld(60, 20),
          capsule: _capsule(),
          velocityX: 0,
          velocityY: 0,
          gravityY: 1200,
          maximumFallSpeed: 1500,
          out: output,
        ),
        isTrue,
      );
      expect(output.supportEdgeId, seamSurfaces.first.id);
    });
  });

  group('TerrainTrajectoryPredictor rejection and parity', () {
    test('ignores an ascending one-way backside then lands from above', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _platform(
          'one_way',
          0,
          100,
          200,
          104,
          collisionMode: TerrainCollisionMode.oneWay,
        ),
      ]);
      final output = TerrainLandingPrediction();

      expect(
        _predictor(fixture).predictLanding(
          startBodyCenter: TerrainPoint.fromWorld(80, 125),
          capsule: _capsule(),
          velocityX: 0,
          velocityY: -500,
          gravityY: 1200,
          maximumFallSpeed: 1500,
          out: output,
        ),
        isTrue,
      );
      expect(output.supportEdgeId!.shapeId, 'one_way');
      expect(output.ticksToLand, greaterThan(20));
    });

    test('ignores one-way support disabled by the traversal profile', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _platform(
          'one_way',
          0,
          100,
          200,
          104,
          collisionMode: TerrainCollisionMode.oneWay,
        ),
      ]);
      final output = TerrainLandingPrediction()
        ..hasLanding = true
        ..geometryVersion = 99;

      expect(
        _predictor(
          fixture,
          profile: _profile(oneWaySupportEnabled: false),
        ).predictLanding(
          startBodyCenter: TerrainPoint.fromWorld(80, 20),
          capsule: _capsule(),
          velocityX: 0,
          velocityY: 0,
          gravityY: 1200,
          maximumFallSpeed: 1500,
          out: output,
        ),
        isFalse,
      );
      expect(output.hasLanding, isFalse);
      expect(output.geometryVersion, -1);
      expect(output.supportEdgeId, isNull);
    });

    test('returns no landing when a wall is the first blocking contact', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _platform('floor', 0, 240, 240, 280, shapeIndex: 0),
        _platform('wall', 100, 0, 120, 230, shapeIndex: 1),
      ]);
      final output = TerrainLandingPrediction();

      expect(
        _predictor(fixture).predictLanding(
          startBodyCenter: TerrainPoint.fromWorld(30, 40),
          capsule: _capsule(),
          velocityX: 600,
          velocityY: 100,
          gravityY: 1200,
          maximumFallSpeed: 1500,
          out: output,
        ),
        isFalse,
      );
      expect(output.hasLanding, isFalse);
    });

    test('returns no landing when a sloped ceiling is the first contact', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        TerrainPolygonInput.fromWorld(
          sourcePath: 'test/ceiling.json',
          identity: TerrainSourceIdentity(
            chunkIndex: 0,
            chunkKey: 'test',
            shapeId: 'ceiling',
          ),
          vertices: const <(double, double)>[
            (0, 0),
            (120, 0),
            (120, 40),
            (0, 80),
          ],
        ),
      ]);
      final predictor = _predictor(fixture, maxTicks: 30);
      final output = TerrainLandingPrediction();
      final ceilingEdge = fixture.geometry.edges.singleWhere(
        (edge) =>
            edge.outwardNormal.yTicks > 0 &&
            edge.outwardNormal.yTicks.abs() >=
                edge.outwardNormal.xTicks.abs() &&
            edge.dyTicks != 0,
      );
      final edgeMidX = (ceilingEdge.start.xTicks + ceilingEdge.end.xTicks) >> 1;
      final edgeMidY = (ceilingEdge.start.yTicks + ceilingEdge.end.yTicks) >> 1;
      final start = TerrainPoint(
        edgeMidX + ceilingEdge.outwardNormal.xTicks * 30,
        edgeMidY + ceilingEdge.outwardNormal.yTicks * 30,
      );

      expect(
        predictor.predictLanding(
          startBodyCenter: start,
          capsule: _capsule(),
          velocityX: -ceilingEdge.outwardNormal.xTicks.sign * 600,
          velocityY: 10,
          gravityY: 0,
          maximumFallSpeed: 1500,
          out: output,
        ),
        isFalse,
      );
      expect(predictor.lastTicksSimulated, lessThan(30));
      expect(output.hasLanding, isFalse);
    });

    test('does not predict through a ceiling struck during ascent', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _platform('ceiling', 0, 60, 200, 80, shapeIndex: 0),
        _platform('floor', 0, 240, 200, 280, shapeIndex: 1),
      ]);
      final predictor = _predictor(fixture);
      final output = TerrainLandingPrediction();

      expect(
        predictor.predictLanding(
          startBodyCenter: TerrainPoint.fromWorld(80, 120),
          capsule: _capsule(),
          velocityX: 0,
          velocityY: -600,
          gravityY: 1200,
          maximumFallSpeed: 1500,
          out: output,
        ),
        isFalse,
      );
      expect(predictor.lastTicksSimulated, lessThan(30));
      expect(output.hasLanding, isFalse);
    });

    test('rejects a too-narrow support and a blocked landing capsule', () {
      final narrow = _fixture(<TerrainPolygonInput>[
        _platform('narrow', 45, 100, 60, 140),
      ]);
      final narrowOutput = TerrainLandingPrediction();
      expect(
        _predictor(
          narrow,
          supportRequirement: TerrainSupportRequirement.runtimeNavigation(
            numerator: 1,
            denominator: 1,
          ),
        ).predictLanding(
          startBodyCenter: TerrainPoint.fromWorld(52, 20),
          capsule: _capsule(),
          velocityX: 0,
          velocityY: 0,
          gravityY: 1200,
          maximumFallSpeed: 1500,
          out: narrowOutput,
        ),
        isFalse,
      );

      final blocked = _fixture(<TerrainPolygonInput>[
        _platform('floor', 0, 100, 200, 160, shapeIndex: 0),
        _platform('ceiling', 0, 60, 200, 81, shapeIndex: 1),
      ]);
      final blockedOutput = TerrainLandingPrediction();
      expect(
        _predictor(blocked, maxTicks: 2).predictLanding(
          startBodyCenter: TerrainPoint.fromWorld(50, 82),
          capsule: _capsule(),
          velocityX: 0,
          velocityY: 600,
          gravityY: 0,
          maximumFallSpeed: 1500,
          out: blockedOutput,
        ),
        isFalse,
      );
    });

    test(
      'prediction tick and support agree with capsule-controller replay',
      () {
        final fixture = _fixture(<TerrainPolygonInput>[
          _ground('slope', const <(double, double)>[(0, 130), (200, 90)]),
        ]);
        final predictor = _predictor(fixture);
        final prediction = TerrainLandingPrediction();
        final start = TerrainPoint.fromWorld(60, 10);

        expect(
          predictor.predictLanding(
            startBodyCenter: start,
            capsule: _capsule(),
            velocityX: 90,
            velocityY: 0,
            gravityY: 1200,
            maximumFallSpeed: 1500,
            out: prediction,
          ),
          isTrue,
        );

        final controller = TerrainCapsuleController(
          geometry: fixture.geometry,
          index: fixture.index,
          profile: _profile(),
        );
        final motion = TerrainCapsuleMotionResult();
        var centerX = start.xTicks;
        var centerY = start.yTicks;
        var velocityY = 0.0;
        var landingTick = 0;
        for (var tick = 1; tick <= 120; tick += 1) {
          velocityY = (velocityY + 1200 / 60).clamp(-1500, 1500);
          controller.moveAt(
            centerXTicks: centerX,
            centerYTicks: centerY,
            radiusTicks: _capsule().radiusTicks,
            verticalHalfSegmentTicks: _capsule().verticalHalfSegmentTicks,
            request: TerrainMotionRequest(
              displacementXTicks: physicsCoordinateToTicks(90 / 60),
              displacementYTicks: physicsCoordinateToTicks(velocityY / 60),
              mode: TerrainMotionMode.worldSpace,
            ),
            beganGrounded: false,
            out: motion,
          );
          centerX = motion.finalCenterXTicks;
          centerY = motion.finalCenterYTicks;
          if (motion.grounded) {
            landingTick = tick;
            break;
          }
        }

        expect(landingTick, prediction.ticksToLand);
        expect(motion.supportEdgeId, prediction.supportEdgeId);
        expect(motion.supportPointXTicks, prediction.supportPointXTicks);
        expect(motion.supportPointYTicks, prediction.supportPointYTicks);
        expect(predictor.queryBufferResizeCount, 0);

        for (var repeat = 0; repeat < 50; repeat += 1) {
          expect(
            predictor.predictLanding(
              startBodyCenter: start,
              capsule: _capsule(),
              velocityX: 90,
              velocityY: 0,
              gravityY: 1200,
              maximumFallSpeed: 1500,
              out: prediction,
            ),
            isTrue,
          );
        }
        expect(predictor.queryBufferResizeCount, 0);
        expect(predictor.lastCandidateCount, greaterThan(0));
        expect(predictor.lastQueryCellsVisited, greaterThan(0));
      },
    );
  });
}

typedef _Fixture = ({
  TerrainGeometry geometry,
  TerrainEdgeIndex index,
  TerrainSurfaceSet surfaces,
  TerrainPlacementQuery query,
});

_Fixture _fixture(List<TerrainPolygonInput> inputs) {
  final geometry = const TerrainCompiler().compile(inputs, geometryVersion: 11);
  final index = TerrainEdgeIndex(edges: geometry.edges);
  final surfaces = const TerrainSurfaceExtractor().extract(geometry);
  final query = TerrainPlacementQuery(
    geometry: geometry,
    terrainIndex: index,
    surfaceIndex: TerrainSurfaceSpatialIndex(surfaceSet: surfaces),
  );
  return (geometry: geometry, index: index, surfaces: surfaces, query: query);
}

TerrainTrajectoryPredictor _predictor(
  _Fixture fixture, {
  TerrainTraversalProfile? profile,
  TerrainSupportRequirement? supportRequirement,
  int maxTicks = 120,
}) => TerrainTrajectoryPredictor(
  placementQuery: fixture.query,
  traversalProfile: profile ?? _profile(),
  supportRequirement:
      supportRequirement ??
      const TerrainSupportRequirement.groundedEnemyRuntime(),
  dtSeconds: 1 / 60,
  maxTicks: maxTicks,
);

TerrainTraversalProfile _profile({bool oneWaySupportEnabled = true}) {
  final base = createEloiseTerrainTraversalProfile(
    enabled: true,
    isKinematic: false,
    useGravity: true,
    gravityScale: 1,
    collideCeilings: true,
    collideLeftWalls: true,
    collideRightWalls: true,
  );
  if (oneWaySupportEnabled) return base;
  return TerrainTraversalProfile(
    enabled: base.enabled,
    isKinematic: base.isKinematic,
    useGravity: base.useGravity,
    gravityScaleBp: base.gravityScaleBp,
    collideCeilings: base.collideCeilings,
    collideLeftWalls: base.collideLeftWalls,
    collideRightWalls: base.collideRightWalls,
    maxWalkableSlopeAngleUnits: base.maxWalkableSlopeAngleUnits,
    minimumSupportUpComponent: base.minimumSupportUpComponent,
    stepHeightTicks: base.stepHeightTicks,
    snapDistanceTicks: base.snapDistanceTicks,
    oneWaySupportEnabled: false,
    dropThroughEnabled: base.dropThroughEnabled,
    groundedMobilityHelpersEnabled: base.groundedMobilityHelpersEnabled,
    slopeSpeedPoints: base.slopeSpeedPoints,
  );
}

TerrainPlacementCapsule _capsule() => TerrainPlacementCapsule(
  radiusTicks: _ticks(10),
  verticalHalfSegmentTicks: 0,
);

TerrainPoint _placedBody(
  _Fixture fixture,
  TerrainNavigationSurface surface,
  int bodyX,
) {
  final result = fixture.query.resolveGrounded(
    TerrainGroundPlacementRequest(
      desiredBodyCenterXTicks: bodyX,
      minimumSupportYTicks: surface.yAtXTicks(bodyX),
      maximumSupportYTicks: surface.yAtXTicks(bodyX),
      capsule: _capsule(),
      traversalProfile: _profile(),
      supportRequirement:
          const TerrainSupportRequirement.groundedEnemyRuntime(),
      intendedSupportEdgeId: surface.id,
      expectedGeometryVersion: fixture.geometry.version,
    ),
  );
  if (!result.isValid || result.bodyCenter == null) {
    throw StateError('Test placement failed: ${result.validity}.');
  }
  return result.bodyCenter!;
}

TerrainNavigationSurface _surfaceForShape(
  TerrainSurfaceSet set,
  String shapeId,
) => set.surfaces.singleWhere((surface) => surface.id.shapeId == shapeId);

TerrainPolygonInput _ground(String shapeId, List<(double, double)> top) =>
    TerrainPolygonInput.fromWorld(
      sourcePath: 'test/$shapeId.json',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'test',
        shapeId: shapeId,
      ),
      vertices: <(double, double)>[
        ...top,
        (top.last.$1, 220),
        (top.first.$1, 220),
      ],
    );

TerrainPolygonInput _platform(
  String shapeId,
  double left,
  double top,
  double right,
  double bottom, {
  int shapeIndex = 0,
  TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$shapeId.json',
  identity: TerrainSourceIdentity(
    chunkIndex: 0,
    chunkKey: 'test',
    placementKey: 'shape_$shapeIndex',
    shapeId: shapeId,
  ),
  collisionMode: collisionMode,
  vertices: <(double, double)>[
    (left, top),
    (right, top),
    (right, bottom),
    (left, bottom),
  ],
);

int _ticks(double world) => physicsCoordinateToTicks(world);
