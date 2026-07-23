import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/terrain_placement_query.dart';
import 'package:runner_core/navigation/terrain_surface_extractor.dart';
import 'package:runner_core/navigation/terrain_surface_graph_builder.dart';
import 'package:runner_core/navigation/terrain_surface_navigator.dart';
import 'package:runner_core/navigation/terrain_surface_pathfinder.dart';
import 'package:runner_core/navigation/terrain_surface_spatial_index.dart';
import 'package:runner_core/navigation/types/terrain_navigation_surface.dart';
import 'package:runner_core/navigation/types/terrain_surface_graph.dart';
import 'package:runner_core/navigation/utils/jump_template.dart';
import 'package:test/test.dart';

void main() {
  group('TerrainSurfacePathfinder', () {
    test('traverses walk, jump, and drop edges with reusable buffers', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _platform('a', 0, 100, 80, 140, shapeIndex: 0),
        _platform('b', 120, 100, 200, 140, shapeIndex: 1),
        _platform('c', 240, 60, 320, 100, shapeIndex: 2),
        _platform('d', 360, 140, 440, 180, shapeIndex: 3),
      ]);
      final profile = _profile();
      final graph = _customGraph(fixture, profile, <_EdgeSpec>[
        const _EdgeSpec('a', 'b', TerrainSurfaceEdgeKind.walk, 1),
        const _EdgeSpec('b', 'c', TerrainSurfaceEdgeKind.jump, 1),
        const _EdgeSpec('c', 'd', TerrainSurfaceEdgeKind.drop, 1),
      ]);
      final pathfinder = TerrainSurfacePathfinder(maxExpandedNodes: 32);
      final path = <int>[999];

      expect(
        pathfinder.findPath(
          graph,
          startIndex: _indexForShape(graph, 'a'),
          goalIndex: _indexForShape(graph, 'd'),
          outEdges: path,
        ),
        isTrue,
      );
      expect(
        path.map((index) => graph.edges[index].kind),
        orderedEquals(const <TerrainSurfaceEdgeKind>[
          TerrainSurfaceEdgeKind.walk,
          TerrainSurfaceEdgeKind.jump,
          TerrainSurfaceEdgeKind.drop,
        ]),
      );

      expect(
        pathfinder.findPath(
          graph,
          startIndex: _indexForShape(graph, 'a'),
          goalIndex: _indexForShape(graph, 'c'),
          outEdges: path,
        ),
        isTrue,
      );
      expect(path, hasLength(2));
      expect(pathfinder.lastExpandedNodeCount, lessThanOrEqualTo(3));
    });

    test('keeps canonical tie preference in both horizontal directions', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _platform('left', 0, 100, 80, 140, shapeIndex: 0),
        _platform('mid_a', 120, 50, 200, 90, shapeIndex: 1),
        _platform('mid_b', 120, 150, 200, 190, shapeIndex: 2),
        _platform('right', 240, 100, 320, 140, shapeIndex: 3),
      ]);
      final profile = _profile();
      final graph = _customGraph(fixture, profile, const <_EdgeSpec>[
        _EdgeSpec('left', 'mid_a', TerrainSurfaceEdgeKind.jump, 1),
        _EdgeSpec('left', 'mid_b', TerrainSurfaceEdgeKind.jump, 1),
        _EdgeSpec('mid_a', 'right', TerrainSurfaceEdgeKind.jump, 1),
        _EdgeSpec('mid_b', 'right', TerrainSurfaceEdgeKind.jump, 1),
        _EdgeSpec('right', 'mid_a', TerrainSurfaceEdgeKind.jump, -1),
        _EdgeSpec('right', 'mid_b', TerrainSurfaceEdgeKind.jump, -1),
        _EdgeSpec('mid_a', 'left', TerrainSurfaceEdgeKind.jump, -1),
        _EdgeSpec('mid_b', 'left', TerrainSurfaceEdgeKind.jump, -1),
      ]);
      final pathfinder = TerrainSurfacePathfinder(maxExpandedNodes: 32);
      final path = <int>[];
      final canonicalMid = <TerrainNavigationSurface>[
        _surfaceForShape(fixture.surfaces, 'mid_a'),
        _surfaceForShape(fixture.surfaces, 'mid_b'),
      ]..sort((left, right) => left.id.compareTo(right.id));

      for (final direction in <int>[1, -1]) {
        final start = direction > 0 ? 'left' : 'right';
        final goal = direction > 0 ? 'right' : 'left';
        expect(
          pathfinder.findPath(
            graph,
            startIndex: _indexForShape(graph, start),
            goalIndex: _indexForShape(graph, goal),
            outEdges: path,
            preferredDirectionX: direction,
            restrictToPreferredDirection: true,
          ),
          isTrue,
        );
        expect(
          graph.surfaces[graph.edges[path.first].to].id,
          canonicalMid.first.id,
        );
      }
    });

    test('preferred-direction restriction rejects an opposite-only route', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _platform('left', 0, 100, 80, 140, shapeIndex: 0),
        _platform('right', 120, 100, 200, 140, shapeIndex: 1),
      ]);
      final graph = _customGraph(fixture, _profile(), const <_EdgeSpec>[
        _EdgeSpec('left', 'right', TerrainSurfaceEdgeKind.jump, -1),
      ]);
      final pathfinder = TerrainSurfacePathfinder(maxExpandedNodes: 8);
      final path = <int>[];
      final start = _indexForShape(graph, 'left');
      final goal = _indexForShape(graph, 'right');

      expect(
        pathfinder.findPath(
          graph,
          startIndex: start,
          goalIndex: goal,
          outEdges: path,
          preferredDirectionX: 1,
          restrictToPreferredDirection: true,
        ),
        isFalse,
      );
      expect(path, isEmpty);
      expect(
        pathfinder.findPath(
          graph,
          startIndex: start,
          goalIndex: goal,
          outEdges: path,
        ),
        isTrue,
      );
    });
  });

  group('TerrainSurfaceNavigator support and pursuit', () {
    test('follows a multi-slope chain without A* or seam oscillation', () {
      final fixture = _chainFixture();
      final profile = _profile();
      final graph = fixture.builder.build(profile);
      final chain =
          fixture.surfaces.surfaces
              .where((surface) => surface.id.shapeId == 'chain')
              .toList()
            ..sort((left, right) => left.xMinTicks.compareTo(right.xMinTicks));
      final navigator = _navigator();
      final state = TerrainSurfaceNavigatorState();
      final target = _actorOn(fixture, profile, chain.last, _ticks(110));

      for (final current in chain.take(chain.length - 1)) {
        final bodyX =
            ((current.xMinTicks + current.xMaxTicks) >> 1) -
            profile.capsuleForDirection(1).resolvedOffsetXTicks;
        final intent = navigator.update(
          state: state,
          graph: graph,
          placementQuery: fixture.query,
          bundleVersion: 1,
          entity: _actorOn(fixture, profile, current, bodyX),
          target: target,
        );
        expect(intent.hasPlan, isTrue);
        expect(intent.desiredBodyXTicks, target.bodyCenter.xTicks);
        expect(state.pathEdges, isEmpty);
      }
      expect(navigator.pathQueryCount, 0);
      expect(navigator.placementQueryCount, 0);
    });

    test(
      'updates target across a seam, another chain, air, and slope landing',
      () {
        final fixture = _chainFixture();
        final profile = _profile();
        final graph = fixture.builder.build(profile);
        final chain =
            fixture.surfaces.surfaces
                .where((surface) => surface.id.shapeId == 'chain')
                .toList()
              ..sort(
                (left, right) => left.xMinTicks.compareTo(right.xMinTicks),
              );
        final isolated = _surfaceForShape(fixture.surfaces, 'isolated');
        final navigator = _navigator();
        final state = TerrainSurfaceNavigatorState();
        final entity = _actorOn(fixture, profile, chain.first, _ticks(20));

        navigator.update(
          state: state,
          graph: graph,
          placementQuery: fixture.query,
          bundleVersion: 1,
          entity: entity,
          target: _actorOn(fixture, profile, chain[1], _ticks(55)),
        );
        expect(state.targetSurfaceId, chain[1].id);

        navigator.update(
          state: state,
          graph: graph,
          placementQuery: fixture.query,
          bundleVersion: 1,
          entity: entity,
          target: _actorOn(fixture, profile, chain[2], _ticks(90)),
        );
        expect(state.targetSurfaceId, chain[2].id);
        expect(navigator.pathQueryCount, 0);

        navigator.update(
          state: state,
          graph: graph,
          placementQuery: fixture.query,
          bundleVersion: 1,
          entity: entity,
          target: _airborne(profile, _ticks(500)),
        );
        expect(state.targetSurfaceId, chain[2].id);

        navigator.update(
          state: state,
          graph: graph,
          placementQuery: fixture.query,
          bundleVersion: 1,
          entity: entity,
          target: _actorOn(fixture, profile, isolated, _ticks(1020)),
        );
        expect(state.targetSurfaceId, isolated.id);
        expect(navigator.pathQueryCount, greaterThan(0));
      },
    );

    test(
      'uses shared lookup only when prior support evidence is unavailable',
      () {
        final fixture = _chainFixture();
        final profile = _profile();
        final graph = fixture.builder.build(profile);
        final surfaces = fixture.surfaces.surfaces
            .where((surface) => surface.id.shapeId == 'chain')
            .toList();
        final navigator = _navigator();
        final state = TerrainSurfaceNavigatorState();
        final entity = _actorOn(fixture, profile, surfaces.first, _ticks(20));
        final retainedTarget = _actorOn(
          fixture,
          profile,
          surfaces.last,
          _ticks(110),
        );

        navigator.update(
          state: state,
          graph: graph,
          placementQuery: fixture.query,
          bundleVersion: 1,
          entity: entity,
          target: retainedTarget,
        );
        expect(navigator.placementQueryCount, 0);

        navigator.update(
          state: state,
          graph: graph,
          placementQuery: fixture.query,
          bundleVersion: 1,
          entity: entity,
          target: _actorOn(
            fixture,
            profile,
            surfaces.last,
            _ticks(110),
            retainSupport: false,
          ),
        );
        expect(navigator.placementQueryCount, 1);
        expect(state.targetSurfaceId, surfaces.last.id);

        navigator.update(
          state: state,
          graph: graph,
          placementQuery: fixture.query,
          bundleVersion: 1,
          entity: entity,
          target: TerrainSurfaceNavigationActorSnapshot(
            bodyCenter: retainedTarget.bodyCenter,
            capsule: retainedTarget.capsule,
            traversalProfile: retainedTarget.traversalProfile,
            supportRequirement: retainedTarget.supportRequirement,
            grounded: true,
            priorSupportEdgeId: retainedTarget.priorSupportEdgeId,
            priorSupportGeometryVersion: fixture.geometry.version - 1,
          ),
        );
        expect(navigator.placementQueryCount, 2);
        expect(state.targetSurfaceId, surfaces.last.id);
      },
    );

    test('no-plan fallback clamps to the last eligible finite surface', () {
      final fixture = _chainFixture();
      final profile = _profile();
      final graph = fixture.builder.build(profile);
      final source = fixture.surfaces.surfaces
          .where((surface) => surface.id.shapeId == 'chain')
          .reduce(
            (left, right) => left.xMinTicks < right.xMinTicks ? left : right,
          );
      final isolated = _surfaceForShape(fixture.surfaces, 'isolated');
      final entity = _actorOn(fixture, profile, source, _ticks(20));
      final target = _actorOn(fixture, profile, isolated, _ticks(1050));
      final navigator = _navigator();
      final state = TerrainSurfaceNavigatorState();

      final intent = navigator.update(
        state: state,
        graph: graph,
        placementQuery: fixture.query,
        bundleVersion: 1,
        entity: entity,
        target: target,
      );
      final standable = fixture.query.standableCenterRange(
        surface: source,
        capsule: entity.capsule,
        traversalProfile: entity.traversalProfile,
        supportRequirement: entity.supportRequirement,
      )!;

      expect(intent.hasPlan, isFalse);
      expect(
        intent.desiredBodyXTicks,
        standable.maximumXTicks - entity.capsule.resolvedOffsetXTicks,
      );
      expect(intent.jumpNow, isFalse);
      expect(state.currentSurfaceId, source.id);
    });
  });

  group('TerrainSurfaceNavigator edge execution and invalidation', () {
    for (final kind in <TerrainSurfaceEdgeKind>[
      TerrainSurfaceEdgeKind.jump,
      TerrainSurfaceEdgeKind.drop,
    ]) {
      test('$kind overshoot commits in flight and needs the right landing', () {
        final fixture = _transitionFixture();
        final profile = _profile();
        final graph = _customGraph(fixture, profile, <_EdgeSpec>[
          _EdgeSpec(
            'source',
            'destination',
            kind,
            1,
            takeoffBodyXTicks: _ticks(100),
            landingBodyXTicks: _ticks(220),
          ),
        ]);
        final source = _surfaceForShape(fixture.surfaces, 'source');
        final destination = _surfaceForShape(fixture.surfaces, 'destination');
        final wrong = _surfaceForShape(fixture.surfaces, 'wrong');
        final target = _actorOn(fixture, profile, destination, _ticks(220));
        final navigator = _navigator(takeoffToleranceTicks: 0);
        final state = TerrainSurfaceNavigatorState();

        final approach = navigator.update(
          state: state,
          graph: graph,
          placementQuery: fixture.query,
          bundleVersion: 4,
          entity: _actorOn(fixture, profile, source, _ticks(40)),
          target: target,
        );
        expect(approach.desiredBodyXTicks, _ticks(100));
        expect(approach.jumpNow, isFalse);
        expect(approach.commitDirectionX, 1);
        expect(state.activeEdgeIndex, -1);

        final takeoff = navigator.update(
          state: state,
          graph: graph,
          placementQuery: fixture.query,
          bundleVersion: 4,
          entity: _actorOn(fixture, profile, source, _ticks(105)),
          target: target,
        );
        expect(state.activeEdgeIndex, greaterThanOrEqualTo(0));
        expect(takeoff.jumpNow, kind == TerrainSurfaceEdgeKind.jump);
        expect(takeoff.commitDirectionX, 1);

        final activeEdge = state.activeEdgeIndex;
        final inFlight = navigator.update(
          state: state,
          graph: graph,
          placementQuery: fixture.query,
          bundleVersion: 4,
          entity: _airborne(profile, _ticks(150)),
          target: target,
        );
        expect(inFlight.jumpNow, isFalse);
        expect(inFlight.commitDirectionX, 1);
        expect(state.activeEdgeIndex, activeEdge);

        navigator.update(
          state: state,
          graph: graph,
          placementQuery: fixture.query,
          bundleVersion: 4,
          entity: _actorOn(fixture, profile, wrong, _ticks(155)),
          target: target,
        );
        expect(state.activeEdgeIndex, activeEdge);
        expect(state.pathCursor, 0);

        navigator.update(
          state: state,
          graph: graph,
          placementQuery: fixture.query,
          bundleVersion: 4,
          entity: _actorOn(fixture, profile, destination, _ticks(220)),
          target: target,
        );
        expect(state.activeEdgeIndex, -1);
        expect(state.pathCursor, 1);
      });
    }

    test('move lock preserves a pending jump takeoff until unlock', () {
      final fixture = _transitionFixture();
      final profile = _profile();
      final graph = _customGraph(fixture, profile, <_EdgeSpec>[
        _EdgeSpec(
          'source',
          'destination',
          TerrainSurfaceEdgeKind.jump,
          1,
          takeoffBodyXTicks: _ticks(100),
          landingBodyXTicks: _ticks(220),
        ),
      ]);
      final source = _surfaceForShape(fixture.surfaces, 'source');
      final destination = _surfaceForShape(fixture.surfaces, 'destination');
      final entity = _actorOn(fixture, profile, source, _ticks(105));
      final target = _actorOn(fixture, profile, destination, _ticks(220));
      final navigator = _navigator(takeoffToleranceTicks: 0);
      final state = TerrainSurfaceNavigatorState();

      final locked = navigator.update(
        state: state,
        graph: graph,
        placementQuery: fixture.query,
        bundleVersion: 2,
        entity: entity,
        target: target,
        movementLocked: true,
      );
      expect(locked.desiredBodyXTicks, entity.bodyCenter.xTicks);
      expect(locked.jumpNow, isFalse);
      expect(state.pathEdges, isNotEmpty);
      expect(state.activeEdgeIndex, -1);

      final unlocked = navigator.update(
        state: state,
        graph: graph,
        placementQuery: fixture.query,
        bundleVersion: 2,
        entity: entity,
        target: target,
      );
      expect(unlocked.jumpNow, isTrue);
      expect(state.activeEdgeIndex, greaterThanOrEqualTo(0));
    });

    test(
      'nav and stun locks hold state while replacement clears everything',
      () {
        final fixture = _transitionFixture();
        final profile = _profile();
        final graph = _customGraph(fixture, profile, const <_EdgeSpec>[
          _EdgeSpec('source', 'destination', TerrainSurfaceEdgeKind.jump, 1),
        ]);
        final source = _surfaceForShape(fixture.surfaces, 'source');
        final destination = _surfaceForShape(fixture.surfaces, 'destination');
        final entity = _actorOn(fixture, profile, source, _ticks(40));
        final target = _actorOn(fixture, profile, destination, _ticks(220));
        final navigator = _navigator();
        final state = TerrainSurfaceNavigatorState()
          ..bundleVersion = 8
          ..currentSurfaceId = source.id
          ..currentSurfaceIndex = graph.indexOfSurfaceId(source.id)!
          ..lastGroundSurfaceId = source.id
          ..lastGroundSurfaceIndex = graph.indexOfSurfaceId(source.id)!
          ..targetSurfaceId = destination.id
          ..targetSurfaceIndex = graph.indexOfSurfaceId(destination.id)!
          ..pathEdges.add(0)
          ..pathCursor = 0
          ..activeEdgeIndex = 0
          ..repathTicksLeft = 5;

        for (final lock in <({bool nav, bool stun})>[
          (nav: true, stun: false),
          (nav: false, stun: true),
        ]) {
          navigator.update(
            state: state,
            graph: graph,
            placementQuery: fixture.query,
            bundleVersion: 8,
            entity: entity,
            target: target,
            navigationLocked: lock.nav,
            stunLocked: lock.stun,
          );
          expect(state.currentSurfaceId, source.id);
          expect(state.pathEdges, orderedEquals(<int>[0]));
          expect(state.activeEdgeIndex, 0);
          expect(state.repathTicksLeft, 5);
        }

        final replacementFixture = _transitionFixture(geometryVersion: 8);
        final replacementGraph = _customGraph(
          replacementFixture,
          profile,
          const <_EdgeSpec>[
            _EdgeSpec('source', 'destination', TerrainSurfaceEdgeKind.jump, 1),
          ],
        );
        navigator.update(
          state: state,
          graph: replacementGraph,
          placementQuery: replacementFixture.query,
          bundleVersion: 9,
          entity: entity,
          target: target,
          navigationLocked: true,
        );
        expect(state.bundleVersion, 9);
        expect(state.currentSurfaceId, isNull);
        expect(state.currentSurfaceIndex, -1);
        expect(state.lastGroundSurfaceId, isNull);
        expect(state.lastGroundSurfaceIndex, -1);
        expect(state.targetSurfaceId, isNull);
        expect(state.targetSurfaceIndex, -1);
        expect(state.pathEdges, isEmpty);
        expect(state.pathCursor, 0);
        expect(state.activeEdgeIndex, -1);
        expect(state.repathTicksLeft, 0);
      },
    );
  });
}

typedef _TerrainFixture = ({
  TerrainGeometry geometry,
  TerrainSurfaceSet surfaces,
  TerrainPlacementQuery query,
  TerrainSurfaceGraphBuilder builder,
});

_TerrainFixture _fixture(
  List<TerrainPolygonInput> inputs, {
  int geometryVersion = 7,
}) {
  final geometry = const TerrainCompiler().compile(
    inputs,
    geometryVersion: geometryVersion,
  );
  final surfaces = const TerrainSurfaceExtractor().extract(geometry);
  final query = TerrainPlacementQuery(
    geometry: geometry,
    terrainIndex: TerrainEdgeIndex(edges: geometry.edges),
    surfaceIndex: TerrainSurfaceSpatialIndex(surfaceSet: surfaces),
  );
  return (
    geometry: geometry,
    surfaces: surfaces,
    query: query,
    builder: TerrainSurfaceGraphBuilder(placementQuery: query),
  );
}

_TerrainFixture _chainFixture() => _fixture(<TerrainPolygonInput>[
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/chain.json',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      placementKey: 'shape_0',
      shapeId: 'chain',
    ),
    vertices: const <(double, double)>[
      (0, 100),
      (40, 80),
      (80, 105),
      (120, 90),
      (120, 180),
      (0, 180),
    ],
  ),
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/isolated.json',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      placementKey: 'shape_1',
      shapeId: 'isolated',
    ),
    vertices: const <(double, double)>[
      (1000, 140),
      (1120, 100),
      (1120, 180),
      (1000, 180),
    ],
  ),
]);

_TerrainFixture _transitionFixture({int geometryVersion = 7}) =>
    _fixture(<TerrainPolygonInput>[
      _platform('source', 0, 100, 120, 180, shapeIndex: 0),
      _platform('wrong', 140, 120, 175, 180, shapeIndex: 1),
      _platform('destination', 190, 140, 320, 200, shapeIndex: 2),
    ], geometryVersion: geometryVersion);

TerrainSurfaceGraphBuildProfile _profile() {
  const catalog = EnemyCatalog();
  final terrain = catalog.terrainContactProfile(EnemyId.hashash);
  final capsule = terrain.capsule;
  final traversal = terrain.traversal;
  return TerrainSurfaceGraphBuildProfile(
    profileKey: EnemyId.hashash.name,
    traversalProfile: traversal,
    radiusTicks: capsule.radiusTicks,
    verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
    authoredOffsetXTicks: capsule.offsetXTicks,
    offsetYTicks: capsule.offsetYTicks,
    supportRequirement: const TerrainSupportRequirement.groundedEnemyRuntime(),
    locomotionSpeedTicksPerSecond: _ticks(300),
    jumpTemplate: JumpReachabilityTemplate.build(
      JumpProfile(
        jumpSpeed: 500,
        gravityY: 1200,
        maxAirTicks: 75,
        airSpeedX: 300,
        dtSeconds: 1 / 60,
        agentHalfWidth: capsule.radiusTicks / terrainPhysicsTicksPerWorldUnit,
        agentHalfHeight:
            (capsule.radiusTicks + capsule.verticalHalfSegmentTicks) /
            terrainPhysicsTicksPerWorldUnit,
        requiredSupportFraction: 1 / 3,
        collideCeilings: traversal.collideCeilings,
        collideLeftWalls: traversal.collideLeftWalls,
        collideRightWalls: traversal.collideRightWalls,
      ),
    ),
  );
}

TerrainSurfaceNavigator _navigator({int? takeoffToleranceTicks}) =>
    TerrainSurfaceNavigator(
      pathfinder: TerrainSurfacePathfinder(maxExpandedNodes: 128),
      takeoffToleranceTicks:
          takeoffToleranceTicks ?? 4 * terrainPhysicsTicksPerWorldUnit,
    );

TerrainSurfaceNavigationActorSnapshot _actorOn(
  _TerrainFixture fixture,
  TerrainSurfaceGraphBuildProfile profile,
  TerrainNavigationSurface surface,
  int desiredBodyXTicks, {
  bool retainSupport = true,
}) {
  final capsule = profile.capsuleForDirection(1);
  final capsuleX = desiredBodyXTicks + capsule.resolvedOffsetXTicks;
  final supportY = surface.yAtXTicks(
    capsuleX.clamp(surface.xMinTicks, surface.xMaxTicks),
  );
  final result = fixture.query.resolveGrounded(
    TerrainGroundPlacementRequest(
      desiredBodyCenterXTicks: desiredBodyXTicks,
      minimumSupportYTicks: supportY,
      maximumSupportYTicks: supportY,
      capsule: capsule,
      traversalProfile: profile.traversalProfile,
      supportRequirement: profile.supportRequirement,
      intendedSupportEdgeId: surface.id,
      allowSameSupportClamp: true,
      expectedGeometryVersion: fixture.geometry.version,
    ),
  );
  if (!result.isValid || result.bodyCenter == null) {
    throw StateError('Test actor placement failed: ${result.validity}.');
  }
  return TerrainSurfaceNavigationActorSnapshot(
    bodyCenter: result.bodyCenter!,
    capsule: capsule,
    traversalProfile: profile.traversalProfile,
    supportRequirement: profile.supportRequirement,
    grounded: true,
    priorSupportEdgeId: retainSupport ? surface.id : null,
    priorSupportGeometryVersion: retainSupport ? fixture.geometry.version : -1,
  );
}

TerrainSurfaceNavigationActorSnapshot _airborne(
  TerrainSurfaceGraphBuildProfile profile,
  int bodyXTicks,
) => TerrainSurfaceNavigationActorSnapshot(
  bodyCenter: TerrainPoint(bodyXTicks, 0),
  capsule: profile.capsuleForDirection(1),
  traversalProfile: profile.traversalProfile,
  supportRequirement: profile.supportRequirement,
  grounded: false,
);

class _EdgeSpec {
  const _EdgeSpec(
    this.fromShape,
    this.toShape,
    this.kind,
    this.commitDirectionX, {
    this.takeoffBodyXTicks,
    this.landingBodyXTicks,
  });

  final String fromShape;
  final String toShape;
  final TerrainSurfaceEdgeKind kind;
  final int commitDirectionX;
  final int? takeoffBodyXTicks;
  final int? landingBodyXTicks;
}

TerrainSurfaceGraph _customGraph(
  _TerrainFixture fixture,
  TerrainSurfaceGraphBuildProfile profile,
  List<_EdgeSpec> specs,
) {
  final rows = List<List<TerrainSurfaceGraphEdge>>.generate(
    fixture.surfaces.surfaces.length,
    (_) => <TerrainSurfaceGraphEdge>[],
  );
  for (final spec in specs) {
    final from = _surfaceForShape(fixture.surfaces, spec.fromShape);
    final to = _surfaceForShape(fixture.surfaces, spec.toShape);
    final fromIndex = fixture.surfaces.indexOfId(from.id)!;
    final toIndex = fixture.surfaces.indexOfId(to.id)!;
    final takeoffX =
        spec.takeoffBodyXTicks ?? ((from.xMinTicks + from.xMaxTicks) >> 1);
    final landingX =
        spec.landingBodyXTicks ?? ((to.xMinTicks + to.xMaxTicks) >> 1);
    final takeoff = TerrainPoint(takeoffX, from.start.yTicks);
    final landing = TerrainPoint(landingX, to.start.yTicks);
    rows[fromIndex].add(
      spec.kind == TerrainSurfaceEdgeKind.walk
          ? TerrainSurfaceGraphEdge.walk(
              to: toIndex,
              takeoffPoint: takeoff,
              landingPoint: landing,
              commitDirectionX: spec.commitDirectionX,
              distanceTicks: _ticks(100),
              locomotionSpeedTicksPerSecond:
                  profile.locomotionSpeedTicksPerSecond,
              simulationTicksPerSecond: profile.simulationTicksPerSecond,
            )
          : TerrainSurfaceGraphEdge.airborne(
              to: toIndex,
              kind: spec.kind,
              takeoffPoint: takeoff,
              landingPoint: landing,
              commitDirectionX: spec.commitDirectionX,
              travelTicks: 60,
              simulationTicksPerSecond: profile.simulationTicksPerSecond,
            ),
    );
  }
  final offsets = <int>[0];
  final edges = <TerrainSurfaceGraphEdge>[];
  for (final row in rows) {
    row.sort(
      (left, right) =>
          compareTerrainSurfaceGraphEdges(left, right, fixture.surfaces),
    );
    edges.addAll(row);
    offsets.add(edges.length);
  }
  return TerrainSurfaceGraph(
    surfaceSet: fixture.surfaces,
    buildProfile: profile,
    eligibility: List<bool>.filled(fixture.surfaces.surfaces.length, true),
    edgeOffsets: offsets,
    edges: edges,
  );
}

TerrainNavigationSurface _surfaceForShape(
  TerrainSurfaceSet set,
  String shapeId,
) => set.surfaces.singleWhere((surface) => surface.id.shapeId == shapeId);

int _indexForShape(TerrainSurfaceGraph graph, String shapeId) =>
    graph.surfaces.indexWhere((surface) => surface.id.shapeId == shapeId);

TerrainPolygonInput _platform(
  String shapeId,
  double left,
  double top,
  double right,
  double bottom, {
  required int shapeIndex,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$shapeId.json',
  identity: TerrainSourceIdentity(
    chunkIndex: 0,
    chunkKey: 'test',
    placementKey: 'shape_$shapeIndex',
    shapeId: shapeId,
  ),
  vertices: <(double, double)>[
    (left, top),
    (right, top),
    (right, bottom),
    (left, bottom),
  ],
);

int _ticks(double world) => physicsCoordinateToTicks(world);
