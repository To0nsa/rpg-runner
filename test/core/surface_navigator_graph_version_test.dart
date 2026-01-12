import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:rpg_runner/core/ecs/stores/enemies/surface_nav_state_store.dart';
import 'package:rpg_runner/core/navigation/types/surface_graph.dart';
import 'package:rpg_runner/core/navigation/surface_navigator.dart';
import 'package:rpg_runner/core/navigation/surface_pathfinder.dart';
import 'package:rpg_runner/core/navigation/utils/surface_spatial_index.dart';
import 'package:rpg_runner/core/navigation/types/walk_surface.dart';

void main() {
  test('SurfaceNavigator invalidates cached plans when graphVersion changes', () {
    final navStore = SurfaceNavStateStore();
    const entityId = 1;
    navStore.add(entityId);
    final navIndex = navStore.indexOf(entityId);

    const surfaces = <WalkSurface>[
      WalkSurface(id: 1, xMin: 0, xMax: 100, yTop: 0),
      WalkSurface(id: 2, xMin: 200, xMax: 300, yTop: 0),
    ];
    final spatialIndex = SurfaceSpatialIndex(index: GridIndex2D(cellSize: 64));
    spatialIndex.rebuild(surfaces);

    final graphWithEdge = SurfaceGraph(
      surfaces: surfaces,
      edgeOffsets: const <int>[0, 1, 1],
      edges: const <SurfaceEdge>[
        SurfaceEdge(
          to: 1,
          kind: SurfaceEdgeKind.jump,
          takeoffX: 90,
          landingX: 210,
          travelTicks: 30,
          cost: 0.5,
        ),
      ],
      indexById: const <int, int>{1: 0, 2: 1},
    );

    final graphNoEdge = SurfaceGraph(
      surfaces: surfaces,
      edgeOffsets: const <int>[0, 0, 0],
      edges: const <SurfaceEdge>[],
      indexById: const <int, int>{1: 0, 2: 1},
    );

    final pathfinder = SurfacePathfinder(maxExpandedNodes: 8, runSpeedX: 100.0);
    final navigator = SurfaceNavigator(pathfinder: pathfinder, repathCooldownTicks: 0);

    // Version 1: a path exists.
    navigator.update(
      navStore: navStore,
      navIndex: navIndex,
      graph: graphWithEdge,
      spatialIndex: spatialIndex,
      graphVersion: 1,
      entityX: 50.0,
      entityBottomY: 0.0,
      entityHalfWidth: 1.0,
      entityGrounded: true,
      targetX: 250.0,
      targetBottomY: 0.0,
      targetHalfWidth: 1.0,
      targetGrounded: true,
    );
    expect(navStore.graphVersion[navIndex], 1);
    expect(navStore.pathEdges[navIndex], isNotEmpty);

    // Version 2: no path exists; cached plan must not survive the version bump.
    navigator.update(
      navStore: navStore,
      navIndex: navIndex,
      graph: graphNoEdge,
      spatialIndex: spatialIndex,
      graphVersion: 2,
      entityX: 50.0,
      entityBottomY: 0.0,
      entityHalfWidth: 1.0,
      entityGrounded: true,
      targetX: 250.0,
      targetBottomY: 0.0,
      targetHalfWidth: 1.0,
      targetGrounded: true,
    );

    expect(navStore.graphVersion[navIndex], 2);
    expect(navStore.pathEdges[navIndex], isEmpty);
    expect(navStore.activeEdgeIndex[navIndex], -1);
    expect(navStore.pathCursor[navIndex], 0);
  });
}

