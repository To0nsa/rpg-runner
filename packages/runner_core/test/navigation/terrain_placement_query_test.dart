import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_traversal_profile.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/terrain_placement_query.dart';
import 'package:runner_core/navigation/terrain_surface_extractor.dart';
import 'package:runner_core/navigation/terrain_surface_spatial_index.dart';
import 'package:runner_core/navigation/types/terrain_navigation_surface.dart';
import 'package:test/test.dart';

import '../fixtures/slopes_golden_fixture.dart';

void main() {
  const catalog = EnemyCatalog();
  final fortyFiveProfile = catalog
      .terrainContactProfile(EnemyId.grojib)
      .traversal;
  final sixtyProfile = catalog.terrainContactProfile(EnemyId.hashash).traversal;

  group('ground support lookup', () {
    test('uses exact slope Y, normal, capsule offset, and body center', () {
      final fixture = _fixture(buildSlopesGoldenInputs());
      final slope = fixture.surfaces.surfaces.singleWhere(
        (surface) =>
            surface.id.chunkIndex == 0 &&
            surface.id.shapeId == 'main' &&
            surface.start == TerrainPoint.fromWorld(96, 320) &&
            surface.end == TerrainPoint.fromWorld(160, 288),
      );
      final result = fixture.query.resolveGrounded(
        TerrainGroundPlacementRequest(
          desiredBodyCenterXTicks: _ticks(126),
          minimumSupportYTicks: _ticks(300),
          maximumSupportYTicks: _ticks(308),
          capsule: TerrainPlacementCapsule(
            radiusTicks: _ticks(4),
            verticalHalfSegmentTicks: _ticks(6),
            resolvedOffsetXTicks: _ticks(2),
            offsetYTicks: _ticks(3),
          ),
          traversalProfile: sixtyProfile,
          supportRequirement:
              const TerrainSupportRequirement.groundedEnemyRuntime(),
          intendedSupportEdgeId: slope.id,
        ),
      );

      expect(result.validity, TerrainPlacementValidity.valid);
      expect(result.supportPoint, TerrainPoint.fromWorld(128, 304));
      expect(result.supportEdgeId, slope.id);
      expect(result.supportTangent, slope.tangent);
      expect(result.supportNormal, slope.outwardNormal);
      expect(result.absoluteSlopeAngleUnits, 27204);
      expect(result.capsuleCenter!.xTicks, _ticks(128));
      expect(result.bodyCenter!.xTicks, _ticks(126));
      expect(
        result.bodyCenter!.yTicks,
        result.capsuleCenter!.yTicks - _ticks(3),
      );
    });

    test('resolves every main-chain transition and exact endpoint', () {
      final fixture = _fixture(buildSlopesGoldenInputs());
      final chain = fixture.surfaces.surfaces
          .where(
            (surface) =>
                surface.id.chunkIndex == 0 && surface.id.shapeId == 'main',
          )
          .toList();
      final points = <TerrainPoint>{
        for (final surface in chain) surface.start,
        for (final surface in chain) surface.end,
      };

      for (final point in points) {
        final candidates =
            chain
                .where(
                  (surface) =>
                      surface.xMinTicks <= point.xTicks &&
                      surface.xMaxTicks >= point.xTicks &&
                      surface.yAtXTicks(point.xTicks) == point.yTicks,
                )
                .toList()
              ..sort((left, right) => left.id.compareTo(right.id));
        final result = fixture.query.resolveGrounded(
          TerrainGroundPlacementRequest(
            desiredBodyCenterXTicks: point.xTicks,
            minimumSupportYTicks: point.yTicks,
            maximumSupportYTicks: point.yTicks,
            capsule: _capsule(radiusWorld: 1, spineWorld: 1),
            traversalProfile: sixtyProfile,
            supportRequirement:
                const TerrainSupportRequirement.groundedEnemyRuntime(),
          ),
        );

        expect(
          result.validity,
          TerrainPlacementValidity.valid,
          reason: '$point',
        );
        expect(result.supportPoint, point, reason: '$point');
        expect(result.supportEdgeId, candidates.first.id, reason: '$point');
      }
    });

    test('applies inclusive 45 and 60 degree profile limits', () {
      final fixture = _fixture(buildSlopesGoldenInputs());
      final exactFortyFive = fixture.surfaces.surfaces.singleWhere(
        (surface) => -surface.outwardNormal.yTicks == 724,
      );
      final exactSixty = fixture.surfaces.surfaces.singleWhere(
        (surface) =>
            surface.dxTicks == _ticks(56) &&
            surface.dyTicks.abs() == _ticks(97),
      );
      final overSixty = fixture.surfaces.surfaces.singleWhere(
        (surface) =>
            surface.dxTicks == _ticks(55) &&
            surface.dyTicks.abs() == _ticks(97),
      );

      expect(
        _placeAtMidpoint(fixture, exactFortyFive, fortyFiveProfile).validity,
        TerrainPlacementValidity.valid,
      );
      expect(
        _placeAtMidpoint(fixture, exactSixty, fortyFiveProfile).validity,
        TerrainPlacementValidity.profileIneligible,
      );
      expect(
        _placeAtMidpoint(fixture, exactSixty, sixtyProfile).validity,
        TerrainPlacementValidity.valid,
      );
      expect(
        _placeAtMidpoint(fixture, overSixty, sixtyProfile).validity,
        TerrainPlacementValidity.profileIneligible,
      );

      final betweenFixture = _fixture(<TerrainPolygonInput>[
        _polygon('between_limits', const <(double, double)>[
          (0, 100),
          (20, 76),
          (40, 76),
          (40, 140),
          (0, 140),
        ]),
      ]);
      final between = betweenFixture.surfaces.surfaces.singleWhere(
        (surface) =>
            surface.dxTicks == _ticks(20) && surface.dyTicks == -_ticks(24),
      );
      expect(
        _placeAtMidpoint(betweenFixture, between, fortyFiveProfile).validity,
        TerrainPlacementValidity.profileIneligible,
      );
      expect(
        _placeAtMidpoint(betweenFixture, between, sixtyProfile).validity,
        TerrainPlacementValidity.valid,
      );
    });

    test('chooses the highest eligible surface then canonical ID', () {
      final fixture = _fixture(buildSlopesGoldenInputs());
      final x = _ticks(880);
      final result = fixture.query.resolveGrounded(
        TerrainGroundPlacementRequest(
          desiredBodyCenterXTicks: x,
          minimumSupportYTicks: _ticks(200),
          maximumSupportYTicks: _ticks(340),
          capsule: _capsule(radiusWorld: 2, spineWorld: 2),
          traversalProfile: sixtyProfile,
          supportRequirement:
              const TerrainSupportRequirement.groundedEnemyRuntime(),
        ),
      );
      final eligible = fixture.surfaces.surfaces.where(
        (surface) =>
            surface.xMinTicks <= x &&
            surface.xMaxTicks >= x &&
            surface.isEligibleFor(sixtyProfile) &&
            surface.yAtXTicks(x) >= _ticks(200) &&
            surface.yAtXTicks(x) <= _ticks(340),
      );
      final expected = eligible.reduce((left, right) {
        final leftY = left.yAtXTicks(x);
        final rightY = right.yAtXTicks(x);
        if (leftY != rightY) return leftY < rightY ? left : right;
        return left.id.compareTo(right.id) < 0 ? left : right;
      });

      expect(result.validity, TerrainPlacementValidity.valid);
      expect(result.supportEdgeId, expected.id);
      expect(result.supportPoint!.yTicks, expected.yAtXTicks(x));
      expect(result.diagnostics.surfaceCandidates, greaterThan(1));
    });
  });

  group('standability and clamping', () {
    test('runtime partial support succeeds where full-width spawn fails', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _rectangle('narrow', 0, 100, 12, 140),
      ]);
      final support = fixture.surfaces.surfaces.single;

      final runtime = _place(
        fixture,
        support,
        xTicks: _ticks(6),
        profile: sixtyProfile,
        capsule: _capsule(radiusWorld: 10, spineWorld: 2),
        requirement: const TerrainSupportRequirement.groundedEnemyRuntime(),
      );
      final spawn = _place(
        fixture,
        support,
        xTicks: _ticks(6),
        profile: sixtyProfile,
        capsule: _capsule(radiusWorld: 10, spineWorld: 2),
        requirement: const TerrainSupportRequirement.groundedSpawn(),
      );

      expect(runtime.validity, TerrainPlacementValidity.valid);
      expect(
        runtime.diagnostics.requiredSupportWidthTicks,
        _ticks(20) ~/ 3 + 1,
      );
      expect(spawn.validity, TerrainPlacementValidity.insufficientSupportWidth);
    });

    test('partial-support standable bounds stay on the finite segment', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _rectangle('finite', 0, 100, 12, 140),
      ]);
      final support = fixture.surfaces.surfaces.single;
      final range = fixture.query.standableCenterRange(
        surface: support,
        capsule: _capsule(radiusWorld: 10, spineWorld: 2),
        traversalProfile: sixtyProfile,
        supportRequirement:
            const TerrainSupportRequirement.groundedEnemyRuntime(),
      );

      expect(range, isNotNull);
      expect(range!.minimumXTicks, support.xMinTicks);
      expect(range.maximumXTicks, support.xMaxTicks);
    });

    test('large canonical surfaces keep normal-aware placement in range', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _rectangle('long', 0, 100, 512, 140),
      ]);
      final support = fixture.surfaces.surfaces.single;
      final result = _place(
        fixture,
        support,
        xTicks: _ticks(256),
        profile: sixtyProfile,
        capsule: _capsule(radiusWorld: 20, spineWorld: 10),
        requirement: const TerrainSupportRequirement.groundedSpawn(),
      );

      expect(result.validity, TerrainPlacementValidity.valid);
      expect(result.supportPoint, TerrainPoint.fromWorld(256, 100));
    });

    test('rejects a narrow peak below the runtime support fraction', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _polygon('narrow_peak', const <(double, double)>[
          (0, 100),
          (6, 94),
          (12, 100),
        ]),
      ]);
      final support = fixture.surfaces.surfaces.first;
      final midpoint = (support.xMinTicks + support.xMaxTicks) >> 1;
      final small = _placeAtMidpoint(fixture, support, fortyFiveProfile);
      final large = _place(
        fixture,
        support,
        xTicks: midpoint,
        profile: fortyFiveProfile,
        capsule: _capsule(radiusWorld: 10, spineWorld: 2),
      );

      expect(small.validity, TerrainPlacementValidity.valid);
      expect(large.validity, TerrainPlacementValidity.insufficientSupportWidth);
    });

    test('same-support clamp remains on the exact source edge', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _rectangle('left', 0, 100, 40, 140),
        _rectangle('right', 40, 100, 80, 140, shapeIndex: 1),
      ]);
      final left = fixture.surfaces.surfaces.singleWhere(
        (surface) => surface.id.shapeId == 'left',
      );
      final result = fixture.query.resolveGrounded(
        TerrainGroundPlacementRequest(
          desiredBodyCenterXTicks: _ticks(55),
          minimumSupportYTicks: _ticks(100),
          maximumSupportYTicks: _ticks(100),
          capsule: _capsule(radiusWorld: 5, spineWorld: 2),
          traversalProfile: sixtyProfile,
          supportRequirement: const TerrainSupportRequirement.groundedSpawn(),
          intendedSupportEdgeId: left.id,
          allowSameSupportClamp: true,
        ),
      );

      expect(result.validity, TerrainPlacementValidity.valid);
      expect(result.supportEdgeId, left.id);
      expect(result.sameSupportClampedBodyXTicks, _ticks(35));
      expect(result.bodyCenter!.xTicks, _ticks(35));
    });
  });

  group('complete capsule clearance', () {
    test('rejects blocked headroom and an adjacent wall', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _rectangle('floor', 0, 100, 100, 140),
        _rectangle('ceiling', 40, 40, 60, 85, shapeIndex: 1),
        _rectangle('wall', 105, 60, 120, 140, shapeIndex: 2),
      ]);
      final floor = fixture.surfaces.surfaces.singleWhere(
        (surface) => surface.id.shapeId == 'floor',
      );

      final headroom = _place(
        fixture,
        floor,
        xTicks: _ticks(50),
        profile: sixtyProfile,
        capsule: _capsule(radiusWorld: 10, spineWorld: 10),
      );
      final wall = _place(
        fixture,
        floor,
        xTicks: _ticks(98),
        profile: sixtyProfile,
        capsule: _capsule(radiusWorld: 10, spineWorld: 2),
      );

      expect(headroom.validity, TerrainPlacementValidity.blockedClearance);
      expect(headroom.blockingEdgeId!.shapeId, 'ceiling');
      expect(headroom.diagnostics.clearanceCandidatesTested, greaterThan(0));
      expect(wall.validity, TerrainPlacementValidity.blockedClearance);
      expect(wall.blockingEdgeId!.shapeId, 'wall');
    });

    test('one-way fronts obey policy while backsides can be ignored', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _rectangle(
          'one_way',
          0,
          100,
          100,
          104,
          collisionMode: TerrainCollisionMode.oneWay,
        ),
      ]);
      final shape = _capsule(radiusWorld: 10, spineWorld: 0);

      TerrainPlacementResult clearance(
        double y,
        TerrainOneWayClearancePolicy policy,
      ) => fixture.query.validateClearance(
        TerrainClearancePlacementRequest(
          bodyCenter: TerrainPoint.fromWorld(50, y),
          capsule: shape,
          traversalProfile: sixtyProfile,
          oneWayClearancePolicy: policy,
        ),
      );

      expect(
        clearance(
          95,
          TerrainOneWayClearancePolicy.useTraversalProfile,
        ).validity,
        TerrainPlacementValidity.blockedClearance,
      );
      expect(
        clearance(95, TerrainOneWayClearancePolicy.ignore).validity,
        TerrainPlacementValidity.valid,
      );
      expect(
        clearance(
          109,
          TerrainOneWayClearancePolicy.useTraversalProfile,
        ).validity,
        TerrainPlacementValidity.valid,
      );
    });

    test('detects finite-segment endpoint penetration', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _polygon('corner_blocker', const <(double, double)>[
          (58, 65),
          (70, 50),
          (75, 55),
        ]),
      ]);
      final result = fixture.query.validateClearance(
        TerrainClearancePlacementRequest(
          bodyCenter: TerrainPoint.fromWorld(50, 70),
          capsule: _capsule(radiusWorld: 10, spineWorld: 0),
          traversalProfile: sixtyProfile,
        ),
      );

      expect(result.validity, TerrainPlacementValidity.blockedClearance);
      expect(result.blockingEdgeId!.shapeId, 'corner_blocker');
    });
  });

  test('geometry version mismatch invalidates retained placement evidence', () {
    final first = _fixture(<TerrainPolygonInput>[
      _rectangle('floor', 0, 100, 100, 140),
    ], geometryVersion: 1);
    final second = _fixture(<TerrainPolygonInput>[
      _rectangle('floor', 0, 100, 100, 140),
    ], geometryVersion: 2);
    final retained = _place(
      first,
      first.surfaces.surfaces.single,
      xTicks: _ticks(50),
      profile: sixtyProfile,
    );
    final mismatch = second.query.resolveGrounded(
      TerrainGroundPlacementRequest(
        desiredBodyCenterXTicks: _ticks(50),
        minimumSupportYTicks: _ticks(100),
        maximumSupportYTicks: _ticks(100),
        capsule: _capsule(radiusWorld: 2, spineWorld: 2),
        traversalProfile: sixtyProfile,
        supportRequirement:
            const TerrainSupportRequirement.groundedEnemyRuntime(),
        expectedGeometryVersion: 1,
      ),
    );

    expect(retained.validity, TerrainPlacementValidity.valid);
    expect(first.query.canCommit(retained), isTrue);
    expect(second.query.canCommit(retained), isFalse);
    expect(mismatch.validity, TerrainPlacementValidity.geometryVersionMismatch);
    expect(mismatch.geometryVersion, 2);
  });
}

typedef _QueryFixture = ({
  TerrainGeometry geometry,
  TerrainSurfaceSet surfaces,
  TerrainPlacementQuery query,
});

_QueryFixture _fixture(
  List<TerrainPolygonInput> inputs, {
  int geometryVersion = 1,
}) {
  final geometry = const TerrainCompiler().compile(
    inputs,
    geometryVersion: geometryVersion,
  );
  final surfaces = const TerrainSurfaceExtractor().extract(geometry);
  return (
    geometry: geometry,
    surfaces: surfaces,
    query: TerrainPlacementQuery(
      geometry: geometry,
      terrainIndex: TerrainEdgeIndex(edges: geometry.edges),
      surfaceIndex: TerrainSurfaceSpatialIndex(surfaceSet: surfaces),
    ),
  );
}

TerrainPlacementResult _placeAtMidpoint(
  _QueryFixture fixture,
  TerrainNavigationSurface support,
  TerrainTraversalProfile profile,
) {
  final x = (support.xMinTicks + support.xMaxTicks) >> 1;
  return _place(fixture, support, xTicks: x, profile: profile);
}

TerrainPlacementResult _place(
  _QueryFixture fixture,
  TerrainNavigationSurface support, {
  required int xTicks,
  required TerrainTraversalProfile profile,
  TerrainPlacementCapsule? capsule,
  TerrainSupportRequirement requirement =
      const TerrainSupportRequirement.groundedEnemyRuntime(),
}) {
  final y = support.yAtXTicks(xTicks);
  return fixture.query.resolveGrounded(
    TerrainGroundPlacementRequest(
      desiredBodyCenterXTicks: xTicks,
      minimumSupportYTicks: y,
      maximumSupportYTicks: y,
      capsule: capsule ?? _capsule(radiusWorld: 2, spineWorld: 2),
      traversalProfile: profile,
      supportRequirement: requirement,
      intendedSupportEdgeId: support.id,
    ),
  );
}

TerrainPlacementCapsule _capsule({
  required double radiusWorld,
  required double spineWorld,
}) => TerrainPlacementCapsule(
  radiusTicks: _ticks(radiusWorld),
  verticalHalfSegmentTicks: _ticks(spineWorld),
);

TerrainPolygonInput _rectangle(
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
    shapeId: shapeId,
    placementKey: 'shape_$shapeIndex',
  ),
  vertices: <(double, double)>[
    (left, top),
    (right, top),
    (right, bottom),
    (left, bottom),
  ],
  collisionMode: collisionMode,
);

TerrainPolygonInput _polygon(
  String shapeId,
  List<(double, double)> vertices, {
  TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$shapeId.json',
  identity: TerrainSourceIdentity(
    chunkIndex: 0,
    chunkKey: 'test',
    shapeId: shapeId,
  ),
  vertices: vertices,
  collisionMode: collisionMode,
);

int _ticks(double world) => physicsCoordinateToTicks(world);
