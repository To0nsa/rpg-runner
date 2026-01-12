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

    final builder = SurfaceGraphBuilder(
      surfaceGrid: GridIndex2D(cellSize: 64),
    );
    final graph = builder.build(
      geometry: geometry,
      jumpTemplate: JumpReachabilityTemplate.build(profile),
    ).graph;

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
          travelTicks: 30,
          cost: 0.5,
        ),
        SurfaceEdge(
          to: 1,
          kind: SurfaceEdgeKind.jump,
          takeoffX: 90,
          landingX: 240,
          travelTicks: 30,
          cost: 0.5,
        ),
      ],
      indexById: const <int, int>{1: 0, 2: 1},
    );

    final pathfinder = SurfacePathfinder(
      maxExpandedNodes: 8,
      runSpeedX: 100.0,
    );

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
}
