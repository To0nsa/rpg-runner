import '../ecs/stores/surface_nav_state_store.dart';
import 'nav_tolerances.dart';
import 'surface_graph.dart';
import 'surface_id.dart';
import 'surface_pathfinder.dart';
import 'surface_spatial_index.dart';

class SurfaceNavIntent {
  const SurfaceNavIntent({
    required this.desiredX,
    required this.jumpNow,
    required this.hasPlan,
    this.commitMoveDirX = 0,
  });

  final double desiredX;
  final bool jumpNow;
  final bool hasPlan;

  /// Movement commit direction while approaching/executing an edge.
  ///
  /// When non-zero (-1 or +1), the locomotion controller should keep moving in
  /// this direction even if it would normally stop near `desiredX`, and it
  /// should not reverse direction due to tiny `desiredX` overshoots.
  ///
  /// This is primarily used to ensure drop edges actually leave the takeoff
  /// surface (walk past the ledge) instead of stopping "close enough".
  final int commitMoveDirX;
}

class SurfaceNavigator {
  SurfaceNavigator({
    required this.pathfinder,
    this.repathCooldownTicks = 30,
    this.surfaceEps = navSpatialEps,
    this.takeoffEps = 2.0,
  });

  final SurfacePathfinder pathfinder;
  final int repathCooldownTicks;
  final double surfaceEps;
  final double takeoffEps;
  final List<int> _candidateBuffer = <int>[];

  SurfaceNavIntent update({
    required SurfaceNavStateStore navStore,
    required int navIndex,
    required SurfaceGraph graph,
    required SurfaceSpatialIndex spatialIndex,
    required int graphVersion,
    required double entityX,
    required double entityBottomY,
    required double entityHalfWidth,
    required bool entityGrounded,
    required double targetX,
    required double targetBottomY,
    required double targetHalfWidth,
    required bool targetGrounded,
  }) {
    final prevCurrentId = navStore.currentSurfaceId[navIndex];
    final prevTargetId = navStore.targetSurfaceId[navIndex];

    var currentSurfaceId = prevCurrentId;
    if (entityGrounded) {
      final currentIndex = _locateSurfaceIndex(
        graph,
        spatialIndex,
        _candidateBuffer,
        entityX,
        entityBottomY,
        entityHalfWidth,
        surfaceEps,
      );
      currentSurfaceId = currentIndex == null
          ? surfaceIdUnknown
          : graph.surfaces[currentIndex].id;
    }

    var targetSurfaceId = prevTargetId;
    if (targetGrounded) {
      final targetIndex = _locateSurfaceIndex(
        graph,
        spatialIndex,
        _candidateBuffer,
        targetX,
        targetBottomY,
        targetHalfWidth,
        surfaceEps,
      );
      targetSurfaceId = targetIndex == null
          ? surfaceIdUnknown
          : graph.surfaces[targetIndex].id;
    }

    if (navStore.graphVersion[navIndex] != graphVersion) {
      navStore.graphVersion[navIndex] = graphVersion;
      navStore.pathEdges[navIndex].clear();
      navStore.pathCursor[navIndex] = 0;
      navStore.activeEdgeIndex[navIndex] = -1;
      navStore.repathTicksLeft[navIndex] = 0;
    }

    navStore.currentSurfaceId[navIndex] = currentSurfaceId;
    navStore.targetSurfaceId[navIndex] = targetSurfaceId;

    if (navStore.repathTicksLeft[navIndex] > 0) {
      navStore.repathTicksLeft[navIndex] -= 1;
    }

    final plan = navStore.pathEdges[navIndex];
    final surfaceChanged =
        currentSurfaceId != prevCurrentId || targetSurfaceId != prevTargetId;

    if (surfaceChanged) {
      navStore.repathTicksLeft[navIndex] = 0;
    }

    if (entityGrounded &&
        navStore.repathTicksLeft[navIndex] == 0 &&
        currentSurfaceId != surfaceIdUnknown &&
        targetSurfaceId != surfaceIdUnknown) {
      final startIndex = graph.indexOfSurfaceId(currentSurfaceId);
      final goalIndex = graph.indexOfSurfaceId(targetSurfaceId);
      if (startIndex != null && goalIndex != null) {
        final found = pathfinder.findPath(
          graph,
          startIndex: startIndex,
          goalIndex: goalIndex,
          outEdges: plan,
          startX: entityX,
          goalX: targetX,
        );
        navStore.pathCursor[navIndex] = 0;
        navStore.activeEdgeIndex[navIndex] = -1;
        if (!found) {
          plan.clear();
        }
      }
      navStore.repathTicksLeft[navIndex] = repathCooldownTicks;
    }

    if (currentSurfaceId != surfaceIdUnknown &&
        currentSurfaceId == targetSurfaceId) {
      plan.clear();
      navStore.pathCursor[navIndex] = 0;
      navStore.activeEdgeIndex[navIndex] = -1;
      return SurfaceNavIntent(
        desiredX: targetX,
        jumpNow: false,
        hasPlan: false,
      );
    }

    final cursor = navStore.pathCursor[navIndex];
    if (plan.isEmpty || cursor >= plan.length) {
      navStore.activeEdgeIndex[navIndex] = -1;
      return SurfaceNavIntent(
        desiredX: targetX,
        jumpNow: false,
        hasPlan: false,
      );
    }

    final edgeIndex = plan[cursor];
    final edge = graph.edges[edgeIndex];

    if (navStore.activeEdgeIndex[navIndex] >= 0) {
      if (entityGrounded &&
          currentSurfaceId != surfaceIdUnknown &&
          currentSurfaceId == graph.surfaces[edge.to].id) {
        navStore.activeEdgeIndex[navIndex] = -1;
        navStore.pathCursor[navIndex] = cursor + 1;
        return SurfaceNavIntent(
          desiredX: targetX,
          jumpNow: false,
          hasPlan: true,
        );
      }

      if (edge.kind == SurfaceEdgeKind.drop && entityGrounded) {
        return SurfaceNavIntent(
          desiredX: edge.takeoffX,
          jumpNow: false,
          hasPlan: true,
          commitMoveDirX: _dropCommitDirX(edge),
        );
      }
      return SurfaceNavIntent(
        desiredX: edge.landingX,
        jumpNow: false,
        hasPlan: true,
      );
    }

    final closeEnough = (entityX - edge.takeoffX).abs() <= takeoffEps;
    if (entityGrounded && closeEnough) {
      navStore.activeEdgeIndex[navIndex] = edgeIndex;

      final jumpNow = edge.kind == SurfaceEdgeKind.jump;
      return SurfaceNavIntent(
        desiredX:
            edge.kind == SurfaceEdgeKind.drop ? edge.takeoffX : edge.landingX,
        jumpNow: jumpNow,
        hasPlan: true,
        commitMoveDirX:
            edge.kind == SurfaceEdgeKind.drop ? _dropCommitDirX(edge) : 0,
      );
    }

    return SurfaceNavIntent(
      desiredX: edge.takeoffX,
      jumpNow: false,
      hasPlan: true,
    );
  }
}

int _dropCommitDirX(SurfaceEdge edge) {
  // Drop edges use a takeoff point nudged beyond the ledge. Commit in that
  // direction so locomotion cannot "stop short" and never leave the surface.
  if (edge.takeoffX < edge.landingX) return 1;
  if (edge.takeoffX > edge.landingX) return -1;
  // Fallback: in the unlikely case of an exact tie, just don't commit.
  return 0;
}

int? _locateSurfaceIndex(
  SurfaceGraph graph,
  SurfaceSpatialIndex spatialIndex,
  List<int> candidates,
  double x,
  double bottomY,
  double halfWidth,
  double eps,
) {
  final minX = x - halfWidth;
  final maxX = x + halfWidth;
  final minY = bottomY - eps;
  final maxY = bottomY + eps;

  spatialIndex.queryAabb(
    minX: minX,
    minY: minY,
    maxX: maxX,
    maxY: maxY,
    outSurfaceIndices: candidates,
  );

  int? bestIndex;
  double? bestY;
  for (final i in candidates) {
    final s = graph.surfaces[i];
    if (s.xMin > maxX || s.xMax < minX) continue;
    if ((s.yTop - bottomY).abs() > eps) continue;

    if (bestY == null || s.yTop < bestY) {
      bestY = s.yTop;
      bestIndex = i;
    } else if ((s.yTop - bestY).abs() <= eps) {
      if (s.id < graph.surfaces[bestIndex!].id) {
        bestIndex = i;
      }
    }
  }

  return bestIndex;
}
