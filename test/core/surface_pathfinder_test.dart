import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/collision/static_world_geometry.dart';
import 'package:rpg_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:rpg_runner/core/navigation/utils/jump_template.dart';
import 'package:rpg_runner/core/navigation/types/surface_graph.dart';
import 'package:rpg_runner/core/navigation/surface_graph_builder.dart';
import 'package:rpg_runner/core/navigation/surface_pathfinder.dart';
import 'package:rpg_runner/core/navigation/types/walk_surface.dart';

void main() {
  test('surface pathfinder returns a deterministic path', () {
    const geometry = StaticWorldGeometry(
      groundPlane: null,
      solids: <StaticSolid>[
        StaticSolid(
          minX: 0,
          minY: 200,
          maxX: 100,
          maxY: 216,
          sides: StaticSolid.sideTop,
          oneWayTop: true,
          chunkIndex: 0,
          localSolidIndex: 0,
        ),
        StaticSolid(
          minX: 140,
          minY: 200,
          maxX: 240,
          maxY: 216,
          sides: StaticSolid.sideTop,
          oneWayTop: true,
          chunkIndex: 1,
          localSolidIndex: 0,
        ),
      ],
    );

    const profile = JumpProfile(
      jumpSpeed: 600.0,
      gravityY: 1200.0,
      maxAirTicks: 90,
      airSpeedX: 300.0,
      dtSeconds: 1.0 / 60.0,
      agentHalfWidth: 10.0,
    );

    final builder = SurfaceGraphBuilder(surfaceGrid: GridIndex2D(cellSize: 64));
    final graph = builder
        .build(
          geometry: geometry,
          jumpTemplate: JumpReachabilityTemplate.build(profile),
        )
        .graph;

    final pathfinder = SurfacePathfinder(
      maxExpandedNodes: 64,
      runSpeedX: 300.0,
    );

    final path = <int>[];
    final found = pathfinder.findPath(
      graph,
      startIndex: 0,
      goalIndex: 1,
      outEdges: path,
    );

    expect(found, isTrue);
    expect(path, isNotEmpty);

    final path2 = <int>[];
    final found2 = pathfinder.findPath(
      graph,
      startIndex: 0,
      goalIndex: 1,
      outEdges: path2,
    );

    expect(found2, isTrue);
    expect(path2, path);
  });

  test('pathfinder prefers takeoff closest to startX on the start surface', () {
    final graph = SurfaceGraph(
      surfaces: const <WalkSurface>[
        WalkSurface(id: 1, xMin: 0, xMax: 100, yTop: 0),
        WalkSurface(id: 2, xMin: 200, xMax: 260, yTop: 0),
      ],
      edgeOffsets: const <int>[0, 2, 2],
      edges: const <SurfaceEdge>[
        SurfaceEdge(
          to: 1,
          kind: SurfaceEdgeKind.jump,
          takeoffX: 10,
          landingX: 200,
          commitDirX: 1,
          travelTicks: 30,
          cost: 0.5,
        ),
        SurfaceEdge(
          to: 1,
          kind: SurfaceEdgeKind.jump,
          takeoffX: 90,
          landingX: 240,
          commitDirX: 1,
          travelTicks: 30,
          cost: 0.5,
        ),
      ],
      indexById: const <int, int>{1: 0, 2: 1},
    );

    final pathfinder = SurfacePathfinder(maxExpandedNodes: 8, runSpeedX: 100.0);

    final path = <int>[];
    final found = pathfinder.findPath(
      graph,
      startIndex: 0,
      goalIndex: 1,
      outEdges: path,
      startX: 90.0,
    );

    expect(found, isTrue);
    expect(path, hasLength(1));
    final chosenEdge = graph.edges[path.first];
    expect(chosenEdge.takeoffX, closeTo(90.0, 1e-9));
  });

  test('pathfinder uses arrival landingX on intermediate surfaces', () {
    final graph = SurfaceGraph(
      surfaces: const <WalkSurface>[
        WalkSurface(id: 1, xMin: 0, xMax: 100, yTop: 0), // start
        WalkSurface(id: 2, xMin: 200, xMax: 300, yTop: 0), // middle
        WalkSurface(id: 3, xMin: 400, xMax: 500, yTop: 0), // goal
      ],
      edgeOffsets: const <int>[0, 2, 4, 4],
      edges: const <SurfaceEdge>[
        // start -> middle (left arrival)
        SurfaceEdge(
          to: 1,
          kind: SurfaceEdgeKind.jump,
          takeoffX: 10,
          landingX: 210,
          commitDirX: 1,
          travelTicks: 30,
          cost: 0.5,
        ),
        // start -> middle (right arrival)
        SurfaceEdge(
          to: 1,
          kind: SurfaceEdgeKind.jump,
          takeoffX: 90,
          landingX: 290,
          commitDirX: 1,
          travelTicks: 30,
          cost: 0.5,
        ),
        // middle -> goal (left takeoff)
        SurfaceEdge(
          to: 2,
          kind: SurfaceEdgeKind.jump,
          takeoffX: 210,
          landingX: 410,
          commitDirX: 1,
          travelTicks: 30,
          cost: 0.5,
        ),
        // middle -> goal (right takeoff)
        SurfaceEdge(
          to: 2,
          kind: SurfaceEdgeKind.jump,
          takeoffX: 290,
          landingX: 490,
          commitDirX: 1,
          travelTicks: 30,
          cost: 0.5,
        ),
      ],
      indexById: const <int, int>{1: 0, 2: 1, 3: 2},
    );

    final pathfinder = SurfacePathfinder(
      maxExpandedNodes: 32,
      runSpeedX: 100.0,
    );

    final path = <int>[];
    final found = pathfinder.findPath(
      graph,
      startIndex: 0,
      goalIndex: 2,
      outEdges: path,
      startX: 90.0,
    );

    expect(found, isTrue);
    expect(path, hasLength(2));

    // Should keep right-side continuity: start->middle via edge 1, then
    // middle->goal via edge 3.
    expect(path[0], 1);
    expect(path[1], 3);
  });

  test(
    'pathfinder can restrict expansion to preferred horizontal direction',
    () {
      final graph = SurfaceGraph(
        surfaces: const <WalkSurface>[
          WalkSurface(id: 1, xMin: 0, xMax: 100, yTop: 0), // start
          WalkSurface(id: 2, xMin: -160, xMax: -60, yTop: 0), // left detour
          WalkSurface(id: 3, xMin: 180, xMax: 280, yTop: 0), // right goal
        ],
        edgeOffsets: const <int>[0, 1, 2, 2],
        edges: const <SurfaceEdge>[
          // start -> left (backward)
          SurfaceEdge(
            to: 1,
            kind: SurfaceEdgeKind.jump,
            takeoffX: 10,
            landingX: -100,
            commitDirX: -1,
            travelTicks: 20,
            cost: 0.1,
          ),
          // left -> goal (forward)
          SurfaceEdge(
            to: 2,
            kind: SurfaceEdgeKind.jump,
            takeoffX: -90,
            landingX: 190,
            commitDirX: 1,
            travelTicks: 20,
            cost: 0.1,
          ),
        ],
        indexById: const <int, int>{1: 0, 2: 1, 3: 2},
      );

      final pathfinder = SurfacePathfinder(
        maxExpandedNodes: 16,
        runSpeedX: 100.0,
      );

      final unrestricted = <int>[];
      final unrestrictedFound = pathfinder.findPath(
        graph,
        startIndex: 0,
        goalIndex: 2,
        outEdges: unrestricted,
        startX: 50.0,
        goalX: 210.0,
      );
      expect(unrestrictedFound, isTrue);
      expect(unrestricted, equals(<int>[0, 1]));

      final forwardOnly = <int>[];
      final forwardOnlyFound = pathfinder.findPath(
        graph,
        startIndex: 0,
        goalIndex: 2,
        outEdges: forwardOnly,
        startX: 50.0,
        goalX: 210.0,
        preferredDirectionX: 1,
        restrictToPreferredDirection: true,
      );
      expect(forwardOnlyFound, isFalse);
      expect(forwardOnly, isEmpty);
    },
  );
}
