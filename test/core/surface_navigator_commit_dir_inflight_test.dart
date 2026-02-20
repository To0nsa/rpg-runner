import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:rpg_runner/core/ecs/stores/enemies/surface_nav_state_store.dart';
import 'package:rpg_runner/core/navigation/surface_navigator.dart';
import 'package:rpg_runner/core/navigation/surface_pathfinder.dart';
import 'package:rpg_runner/core/navigation/types/surface_graph.dart';
import 'package:rpg_runner/core/navigation/types/walk_surface.dart';
import 'package:rpg_runner/core/navigation/utils/surface_spatial_index.dart';

void main() {
  test('SurfaceNavigator keeps commitMoveDirX while executing drop edge in-flight', () {
    final navStore = SurfaceNavStateStore();
    const entityId = 1;
    navStore.add(entityId);
    final navIndex = navStore.indexOf(entityId);

    const surfaces = <WalkSurface>[
      WalkSurface(id: 1, xMin: 0, xMax: 100, yTop: 0),
      WalkSurface(id: 2, xMin: 0, xMax: 100, yTop: 100),
    ];
    final spatialIndex = SurfaceSpatialIndex(index: GridIndex2D(cellSize: 64));
    spatialIndex.rebuild(surfaces);

    final graph = SurfaceGraph(
      surfaces: surfaces,
      edgeOffsets: <int>[0, 1, 1],
      edges: <SurfaceEdge>[
        SurfaceEdge(
          to: 1,
          kind: SurfaceEdgeKind.drop,
          takeoffX: 90,
          landingX: 90,
          commitDirX: 1,
          travelTicks: 10,
          cost: 1.0,
        ),
      ],
      indexById: <int, int>{1: 0, 2: 1},
    );

    final navigator = SurfaceNavigator(
      pathfinder: SurfacePathfinder(maxExpandedNodes: 8, runSpeedX: 100.0),
      repathCooldownTicks: 0,
    );

    // Start executing the drop edge.
    final takeoffIntent = navigator.update(
      navStore: navStore,
      navIndex: navIndex,
      graph: graph,
      spatialIndex: spatialIndex,
      graphVersion: 1,
      entityX: 90.0,
      entityBottomY: 0.0,
      entityHalfWidth: 1.0,
      entityGrounded: true,
      targetX: 50.0,
      targetBottomY: 100.0,
      targetHalfWidth: 1.0,
      targetGrounded: true,
    );
    expect(navStore.activeEdgeIndex[navIndex], 0);
    expect(takeoffIntent.commitMoveDirX, 1);

    // In-flight, still executing the active edge: commit dir must remain.
    final inflightIntent = navigator.update(
      navStore: navStore,
      navIndex: navIndex,
      graph: graph,
      spatialIndex: spatialIndex,
      graphVersion: 1,
      entityX: 90.1,
      entityBottomY: 0.0,
      entityHalfWidth: 1.0,
      entityGrounded: false,
      targetX: 50.0,
      targetBottomY: 100.0,
      targetHalfWidth: 1.0,
      targetGrounded: true,
    );
    expect(inflightIntent.commitMoveDirX, 1);
  });

  test('SurfaceNavigator keeps commitMoveDirX while executing jump edge in-flight', () {
    final navStore = SurfaceNavStateStore();
    const entityId = 2;
    navStore.add(entityId);
    final navIndex = navStore.indexOf(entityId);

    const surfaces = <WalkSurface>[
      WalkSurface(id: 10, xMin: 0, xMax: 120, yTop: 0),
      WalkSurface(id: 20, xMin: 180, xMax: 300, yTop: 0),
    ];
    final spatialIndex = SurfaceSpatialIndex(index: GridIndex2D(cellSize: 64));
    spatialIndex.rebuild(surfaces);

    final graph = SurfaceGraph(
      surfaces: surfaces,
      edgeOffsets: <int>[0, 1, 1],
      edges: <SurfaceEdge>[
        SurfaceEdge(
          to: 1,
          kind: SurfaceEdgeKind.jump,
          takeoffX: 110,
          landingX: 190,
          commitDirX: 1,
          travelTicks: 20,
          cost: 1.0,
        ),
      ],
      indexById: <int, int>{10: 0, 20: 1},
    );

    final navigator = SurfaceNavigator(
      pathfinder: SurfacePathfinder(maxExpandedNodes: 8, runSpeedX: 100.0),
      repathCooldownTicks: 0,
    );

    final takeoffIntent = navigator.update(
      navStore: navStore,
      navIndex: navIndex,
      graph: graph,
      spatialIndex: spatialIndex,
      graphVersion: 1,
      entityX: 110.0,
      entityBottomY: 0.0,
      entityHalfWidth: 1.0,
      entityGrounded: true,
      targetX: 220.0,
      targetBottomY: 0.0,
      targetHalfWidth: 1.0,
      targetGrounded: true,
    );
    expect(navStore.activeEdgeIndex[navIndex], 0);
    expect(takeoffIntent.jumpNow, isTrue);
    expect(takeoffIntent.commitMoveDirX, 1);

    final inflightIntent = navigator.update(
      navStore: navStore,
      navIndex: navIndex,
      graph: graph,
      spatialIndex: spatialIndex,
      graphVersion: 1,
      entityX: 250.0,
      entityBottomY: -10.0,
      entityHalfWidth: 1.0,
      entityGrounded: false,
      targetX: 220.0,
      targetBottomY: 0.0,
      targetHalfWidth: 1.0,
      targetGrounded: true,
    );

    expect(inflightIntent.hasPlan, isTrue);
    expect(inflightIntent.jumpNow, isFalse);
    expect(inflightIntent.commitMoveDirX, 1);
  });
}
