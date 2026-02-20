import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:rpg_runner/core/ecs/stores/enemies/surface_nav_state_store.dart';
import 'package:rpg_runner/core/navigation/surface_navigator.dart';
import 'package:rpg_runner/core/navigation/surface_pathfinder.dart';
import 'package:rpg_runner/core/navigation/types/surface_graph.dart';
import 'package:rpg_runner/core/navigation/types/surface_id.dart';
import 'package:rpg_runner/core/navigation/types/walk_surface.dart';
import 'package:rpg_runner/core/navigation/utils/surface_spatial_index.dart';

void main() {
  SurfaceGraph buildDropGraph({
    required double takeoffX,
    required double landingX,
    required int commitDirX,
  }) {
    const surfaces = <WalkSurface>[
      WalkSurface(id: 1, xMin: 0, xMax: 100, yTop: 0),
      WalkSurface(id: 2, xMin: 0, xMax: 100, yTop: 100),
    ];
    return SurfaceGraph(
      surfaces: surfaces,
      edgeOffsets: const <int>[0, 1, 1],
      edges: <SurfaceEdge>[
        SurfaceEdge(
          to: 1,
          kind: SurfaceEdgeKind.drop,
          takeoffX: takeoffX,
          landingX: landingX,
          commitDirX: commitDirX,
          travelTicks: 10,
          cost: 1.0,
        ),
      ],
      indexById: const <int, int>{1: 0, 2: 1},
    );
  }

  test('drop edge activates when already past takeoff in commit direction', () {
    final navStore = SurfaceNavStateStore();
    navStore.add(1);
    final navIndex = navStore.indexOf(1);

    final graph = buildDropGraph(
      takeoffX: 90.0,
      landingX: 90.0,
      commitDirX: 1,
    );
    final spatialIndex = SurfaceSpatialIndex(index: GridIndex2D(cellSize: 64));
    spatialIndex.rebuild(graph.surfaces);

    final navigator = SurfaceNavigator(
      pathfinder: SurfacePathfinder(maxExpandedNodes: 8, runSpeedX: 100.0),
      repathCooldownTicks: 0,
      takeoffEps: 0.1,
    );

    final intent = navigator.update(
      navStore: navStore,
      navIndex: navIndex,
      graph: graph,
      spatialIndex: spatialIndex,
      graphVersion: 1,
      entityX: 90.6,
      entityBottomY: 0.0,
      entityHalfWidth: 1.0,
      entityGrounded: true,
      targetX: 50.0,
      targetBottomY: 100.0,
      targetHalfWidth: 1.0,
      targetGrounded: true,
    );

    expect(navStore.activeEdgeIndex[navIndex], 0);
    expect(intent.hasPlan, isTrue);
    expect(intent.jumpNow, isFalse);
    expect(intent.commitMoveDirX, 1);
  });

  test(
    'drop edge activates when already past takeoff in left commit direction',
    () {
      final navStore = SurfaceNavStateStore();
      navStore.add(1);
      final navIndex = navStore.indexOf(1);

      final graph = buildDropGraph(
        takeoffX: 10.0,
        landingX: 10.0,
        commitDirX: -1,
      );
      final spatialIndex = SurfaceSpatialIndex(index: GridIndex2D(cellSize: 64));
      spatialIndex.rebuild(graph.surfaces);

      final navigator = SurfaceNavigator(
        pathfinder: SurfacePathfinder(maxExpandedNodes: 8, runSpeedX: 100.0),
        repathCooldownTicks: 0,
        takeoffEps: 0.1,
      );

      final intent = navigator.update(
        navStore: navStore,
        navIndex: navIndex,
        graph: graph,
        spatialIndex: spatialIndex,
        graphVersion: 1,
        entityX: 9.4,
        entityBottomY: 0.0,
        entityHalfWidth: 1.0,
        entityGrounded: true,
        targetX: 50.0,
        targetBottomY: 100.0,
        targetHalfWidth: 1.0,
        targetGrounded: true,
      );

      expect(navStore.activeEdgeIndex[navIndex], 0);
      expect(intent.hasPlan, isTrue);
      expect(intent.jumpNow, isFalse);
      expect(intent.commitMoveDirX, -1);
    },
  );

  test('drop approach keeps commit direction before takeoff', () {
    final navStore = SurfaceNavStateStore();
    navStore.add(1);
    final navIndex = navStore.indexOf(1);

    final graph = buildDropGraph(
      takeoffX: 90.0,
      landingX: 90.0,
      commitDirX: 1,
    );
    final spatialIndex = SurfaceSpatialIndex(index: GridIndex2D(cellSize: 64));
    spatialIndex.rebuild(graph.surfaces);

    final navigator = SurfaceNavigator(
      pathfinder: SurfacePathfinder(maxExpandedNodes: 8, runSpeedX: 100.0),
      repathCooldownTicks: 0,
      takeoffEps: 0.1,
    );

    final intent = navigator.update(
      navStore: navStore,
      navIndex: navIndex,
      graph: graph,
      spatialIndex: spatialIndex,
      graphVersion: 1,
      entityX: 80.0,
      entityBottomY: 0.0,
      entityHalfWidth: 1.0,
      entityGrounded: true,
      targetX: 50.0,
      targetBottomY: 100.0,
      targetHalfWidth: 1.0,
      targetGrounded: true,
    );

    expect(navStore.activeEdgeIndex[navIndex], -1);
    expect(intent.hasPlan, isTrue);
    expect(intent.jumpNow, isFalse);
    expect(intent.desiredX, 90.0);
    expect(intent.commitMoveDirX, 1);
  });

  test('drop approach keeps left commit direction before takeoff', () {
    final navStore = SurfaceNavStateStore();
    navStore.add(1);
    final navIndex = navStore.indexOf(1);

    final graph = buildDropGraph(
      takeoffX: 10.0,
      landingX: 10.0,
      commitDirX: -1,
    );
    final spatialIndex = SurfaceSpatialIndex(index: GridIndex2D(cellSize: 64));
    spatialIndex.rebuild(graph.surfaces);

    final navigator = SurfaceNavigator(
      pathfinder: SurfacePathfinder(maxExpandedNodes: 8, runSpeedX: 100.0),
      repathCooldownTicks: 0,
      takeoffEps: 0.1,
    );

    final intent = navigator.update(
      navStore: navStore,
      navIndex: navIndex,
      graph: graph,
      spatialIndex: spatialIndex,
      graphVersion: 1,
      entityX: 20.0,
      entityBottomY: 0.0,
      entityHalfWidth: 1.0,
      entityGrounded: true,
      targetX: 50.0,
      targetBottomY: 100.0,
      targetHalfWidth: 1.0,
      targetGrounded: true,
    );

    expect(navStore.activeEdgeIndex[navIndex], -1);
    expect(intent.hasPlan, isTrue);
    expect(intent.jumpNow, isFalse);
    expect(intent.desiredX, 10.0);
    expect(intent.commitMoveDirX, -1);
  });

  test('surface locator requires full standable width for current surface', () {
    final navStore = SurfaceNavStateStore();
    navStore.add(1);
    final navIndex = navStore.indexOf(1);

    const surfaces = <WalkSurface>[
      WalkSurface(id: 11, xMin: -5, xMax: 5, yTop: 0),
      WalkSurface(id: 22, xMin: 30, xMax: 80, yTop: 0),
    ];
    final graph = SurfaceGraph(
      surfaces: surfaces,
      edgeOffsets: const <int>[0, 0, 0],
      edges: const <SurfaceEdge>[],
      indexById: const <int, int>{11: 0, 22: 1},
    );
    final spatialIndex = SurfaceSpatialIndex(index: GridIndex2D(cellSize: 64));
    spatialIndex.rebuild(graph.surfaces);

    final navigator = SurfaceNavigator(
      pathfinder: SurfacePathfinder(maxExpandedNodes: 8, runSpeedX: 100.0),
      repathCooldownTicks: 0,
    );

    final intent = navigator.update(
      navStore: navStore,
      navIndex: navIndex,
      graph: graph,
      spatialIndex: spatialIndex,
      graphVersion: 1,
      entityX: 0.0,
      entityBottomY: 0.0,
      entityHalfWidth: 20.0,
      entityGrounded: true,
      targetX: 40.0,
      targetBottomY: 0.0,
      targetHalfWidth: 1.0,
      targetGrounded: true,
    );

    expect(navStore.currentSurfaceId[navIndex], surfaceIdUnknown);
    expect(intent.hasPlan, isFalse);
  });
}
