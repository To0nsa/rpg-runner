import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:rpg_runner/core/ecs/stores/enemies/surface_nav_state_store.dart';
import 'package:rpg_runner/core/navigation/surface_navigator.dart';
import 'package:rpg_runner/core/navigation/surface_pathfinder.dart';
import 'package:rpg_runner/core/navigation/types/surface_graph.dart';
import 'package:rpg_runner/core/navigation/types/walk_surface.dart';
import 'package:rpg_runner/core/navigation/utils/surface_spatial_index.dart';

void main() {
  const surfaces = <WalkSurface>[
    WalkSurface(id: 1, xMin: 0, xMax: 100, yTop: 0), // start
    WalkSurface(id: 2, xMin: -160, xMax: -60, yTop: 0), // left detour
    WalkSurface(id: 3, xMin: 180, xMax: 280, yTop: 0), // right goal
  ];

  SurfaceGraph buildGraph({required bool includeForwardDirect}) {
    final edges = <SurfaceEdge>[
      const SurfaceEdge(
        to: 1,
        kind: SurfaceEdgeKind.jump,
        takeoffX: 10,
        landingX: -100,
        commitDirX: -1,
        travelTicks: 20,
        cost: 0.1,
      ),
      const SurfaceEdge(
        to: 2,
        kind: SurfaceEdgeKind.jump,
        takeoffX: -90,
        landingX: 190,
        commitDirX: 1,
        travelTicks: 20,
        cost: 0.1,
      ),
    ];

    if (includeForwardDirect) {
      edges.insert(
        1,
        const SurfaceEdge(
          to: 2,
          kind: SurfaceEdgeKind.jump,
          takeoffX: 90,
          landingX: 190,
          commitDirX: 1,
          travelTicks: 20,
          cost: 1.5,
        ),
      );
    }

    return SurfaceGraph(
      surfaces: surfaces,
      edgeOffsets: includeForwardDirect
          ? const <int>[0, 2, 3, 3]
          : const <int>[0, 1, 2, 2],
      edges: edges,
      indexById: const <int, int>{1: 0, 2: 1, 3: 2},
    );
  }

  SurfaceNavigator buildNavigator() => SurfaceNavigator(
    pathfinder: SurfacePathfinder(maxExpandedNodes: 32, runSpeedX: 100.0),
    repathCooldownTicks: 0,
  );

  SurfaceSpatialIndex buildSpatialIndex() {
    final index = SurfaceSpatialIndex(index: GridIndex2D(cellSize: 64));
    index.rebuild(surfaces);
    return index;
  }

  test('SurfaceNavigator prefers forward-first path toward navTargetX', () {
    final navStore = SurfaceNavStateStore();
    navStore.add(1);
    final navIndex = navStore.indexOf(1);

    final graph = buildGraph(includeForwardDirect: true);
    final spatialIndex = buildSpatialIndex();
    final navigator = buildNavigator();

    final intent = navigator.update(
      navStore: navStore,
      navIndex: navIndex,
      graph: graph,
      spatialIndex: spatialIndex,
      graphVersion: 1,
      entityX: 50.0,
      entityBottomY: 0.0,
      entityHalfWidth: 1.0,
      entityGrounded: true,
      targetX: 220.0,
      targetBottomY: 0.0,
      targetHalfWidth: 1.0,
      targetGrounded: true,
    );

    expect(navStore.pathEdges[navIndex], equals(<int>[1]));
    expect(intent.hasPlan, isTrue);
    expect(intent.commitMoveDirX, 1);
  });

  test('SurfaceNavigator allows backward edge only as fallback', () {
    final navStore = SurfaceNavStateStore();
    navStore.add(1);
    final navIndex = navStore.indexOf(1);

    final graph = buildGraph(includeForwardDirect: false);
    final spatialIndex = buildSpatialIndex();
    final navigator = buildNavigator();

    final intent = navigator.update(
      navStore: navStore,
      navIndex: navIndex,
      graph: graph,
      spatialIndex: spatialIndex,
      graphVersion: 1,
      entityX: 50.0,
      entityBottomY: 0.0,
      entityHalfWidth: 1.0,
      entityGrounded: true,
      targetX: 220.0,
      targetBottomY: 0.0,
      targetHalfWidth: 1.0,
      targetGrounded: true,
    );

    expect(navStore.pathEdges[navIndex], equals(<int>[0, 1]));
    expect(intent.hasPlan, isTrue);
    expect(intent.commitMoveDirX, -1);
  });
}
