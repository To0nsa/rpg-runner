import '../ecs/stores/enemies/surface_nav_state_store.dart';
import 'types/nav_tolerances.dart';
import 'types/surface_graph.dart';
import 'types/surface_id.dart';
import 'surface_pathfinder.dart';
import 'utils/surface_spatial_index.dart';

/// Output of [SurfaceNavigator.update] indicating desired movement.
class SurfaceNavIntent {
  const SurfaceNavIntent({
    required this.desiredX,
    required this.jumpNow,
    required this.hasPlan,
    this.commitMoveDirX = 0,
  });

  /// Target X position the locomotion controller should move toward.
  final double desiredX;

  /// If `true`, the entity should jump this frame.
  final bool jumpNow;

  /// If `true`, a valid path exists (even if currently executing an edge).
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

/// Runtime navigation controller for surface-graph-based AI movement.
///
/// **Responsibilities**:
/// 1. Track which surface the entity and target are standing on.
/// 2. Request paths via [SurfacePathfinder] when surfaces change.
/// 3. Execute path edges (walk to takeoff, jump/drop, land on destination).
/// 4. Return [SurfaceNavIntent] each tick for the locomotion controller.
///
/// **State Storage**:
/// Uses [SurfaceNavStateStore] (external SOA store) so multiple entities can
/// share a single [SurfaceNavigator] instance.
///
/// **Usage**:
/// ```dart
/// final intent = navigator.update(
///   navStore: store, navIndex: idx,
///   graph: graph, spatialIndex: index,
///   graphVersion: version,
///   entityX: e.x, entityBottomY: e.bottom, entityHalfWidth: e.hw,
///   entityGrounded: e.grounded,
///   targetX: t.x, targetBottomY: t.bottom, targetHalfWidth: t.hw,
///   targetGrounded: t.grounded,
/// );
/// // Use intent.desiredX, intent.jumpNow, intent.commitMoveDirX
/// ```
class SurfaceNavigator {
  SurfaceNavigator({
    required this.pathfinder,
    this.repathCooldownTicks = 12,
    this.surfaceEps = navSpatialEps,
    this.takeoffEps = 4.0,
  });

  /// Pathfinder used for A* queries.
  final SurfacePathfinder pathfinder;

  /// Minimum ticks between path recalculations (prevents thrashing).
  final int repathCooldownTicks;

  /// Vertical tolerance for surface detection (pixels).
  final double surfaceEps;

  /// Horizontal tolerance for reaching takeoff point (pixels).
  final double takeoffEps;

  /// Reusable buffer for spatial index queries.
  final List<int> _candidateBuffer = <int>[];

  /// Updates navigation state and returns movement intent for one entity.
  ///
  /// **Flow**:
  /// 1. Locate current and target surfaces via spatial index.
  /// 2. Invalidate path if graph version changed.
  /// 3. Repath if cooldown expired and surfaces are known.
  /// 4. If same surface, return direct movement to target.
  /// 5. Otherwise, execute next edge in path (approach → jump/drop → land).
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
    final prevLastGroundId = navStore.lastGroundSurfaceId[navIndex];

    // -------------------------------------------------------------------------
    // Step 1: Locate surfaces.
    // -------------------------------------------------------------------------
    var currentSurfaceId = surfaceIdUnknown;
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

    // -------------------------------------------------------------------------
    // Step 2: Invalidate path on graph rebuild.
    // -------------------------------------------------------------------------
    if (navStore.graphVersion[navIndex] != graphVersion) {
      navStore.graphVersion[navIndex] = graphVersion;
      navStore.pathEdges[navIndex].clear();
      navStore.pathCursor[navIndex] = 0;
      navStore.activeEdgeIndex[navIndex] = -1;
      navStore.repathTicksLeft[navIndex] = 0;
      navStore.lastGroundSurfaceId[navIndex] = surfaceIdUnknown;
    }

    navStore.currentSurfaceId[navIndex] = currentSurfaceId;
    navStore.targetSurfaceId[navIndex] = targetSurfaceId;
    if (entityGrounded && currentSurfaceId != surfaceIdUnknown) {
      navStore.lastGroundSurfaceId[navIndex] = currentSurfaceId;
    } else if (prevLastGroundId != surfaceIdUnknown) {
      navStore.lastGroundSurfaceId[navIndex] = prevLastGroundId;
    }

    // Decrement repath cooldown.
    if (navStore.repathTicksLeft[navIndex] > 0) {
      navStore.repathTicksLeft[navIndex] -= 1;
    }

    final plan = navStore.pathEdges[navIndex];
    final surfaceChanged =
        currentSurfaceId != prevCurrentId || targetSurfaceId != prevTargetId;

    // Reset cooldown if either surface changed (allows immediate repath).
    if (surfaceChanged) {
      navStore.repathTicksLeft[navIndex] = 0;
    }

    // -------------------------------------------------------------------------
    // Step 3: Repath if needed.
    // -------------------------------------------------------------------------
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

    // -------------------------------------------------------------------------
    // Step 4: Same-surface shortcut.
    // -------------------------------------------------------------------------
    if (entityGrounded &&
        navStore.activeEdgeIndex[navIndex] < 0 &&
        currentSurfaceId != surfaceIdUnknown &&
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

    // -------------------------------------------------------------------------
    // Step 5: Execute path edges.
    // -------------------------------------------------------------------------
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

    // --- Executing an edge (mid-flight or post-takeoff) ---
    if (navStore.activeEdgeIndex[navIndex] >= 0) {
      // Check if we've landed on the destination surface.
      if (entityGrounded &&
          currentSurfaceId != surfaceIdUnknown &&
          currentSurfaceId == graph.surfaces[edge.to].id) {
        // Edge complete—advance cursor.
        navStore.activeEdgeIndex[navIndex] = -1;
        navStore.pathCursor[navIndex] = cursor + 1;
        return SurfaceNavIntent(
          desiredX: targetX,
          jumpNow: false,
          hasPlan: true,
        );
      }

      // Drop edge: keep walking toward ledge until we fall off.
      if (edge.kind == SurfaceEdgeKind.drop && entityGrounded) {
        return SurfaceNavIntent(
          desiredX: edge.takeoffX,
          jumpNow: false,
          hasPlan: true,
          commitMoveDirX: edge.commitDirX,
        );
      }

      // Drop edge in-flight: keep commit direction stable. (landingX can be
      // slightly behind the entity due to clamping, which would otherwise
      // cause a brief direction reversal.)
      if (edge.kind == SurfaceEdgeKind.drop) {
        return SurfaceNavIntent(
          desiredX: edge.landingX,
          jumpNow: false,
          hasPlan: true,
          commitMoveDirX: edge.commitDirX,
        );
      }

      // Jump edge in-flight: aim for landing point.
      return SurfaceNavIntent(
        desiredX: edge.landingX,
        jumpNow: false,
        hasPlan: true,
      );
    }

    // --- Approaching takeoff point ---
    // With commit direction, allow activation when the entity is at OR past the
    // takeoff point in travel direction. This prevents overshoot oscillation.
    final dir = edge.commitDirX;
    final closeEnough = dir > 0
        ? entityX >= edge.takeoffX - takeoffEps
        : (dir < 0
              ? entityX <= edge.takeoffX + takeoffEps
              : (entityX - edge.takeoffX).abs() <= takeoffEps);
    if (entityGrounded && closeEnough) {
      // Initiate edge execution.
      navStore.activeEdgeIndex[navIndex] = edgeIndex;

      final jumpNow = edge.kind == SurfaceEdgeKind.jump;
      return SurfaceNavIntent(
        desiredX: edge.kind == SurfaceEdgeKind.drop
            ? edge.takeoffX
            : edge.landingX,
        jumpNow: jumpNow,
        hasPlan: true,
        commitMoveDirX: edge.commitDirX,
      );
    }

    // Walk toward takeoff point.
    // For jump edges, commit direction keeps the entity moving at full speed
    // through the takeoff instead of decelerating as it approaches.
    return SurfaceNavIntent(
      desiredX: edge.takeoffX,
      jumpNow: false,
      hasPlan: true,
      commitMoveDirX: edge.commitDirX,
    );
  }
}

/// Finds the best surface index for a given entity footprint.
///
/// **Algorithm**:
/// 1. Query spatial index for candidate surfaces in AABB.
/// 2. Filter by horizontal overlap and vertical proximity.
/// 3. Prefer lowest yTop (highest platform). Tie-break by surface ID.
///
/// **Returns**: Surface index, or `null` if not standing on any surface.
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
    final standableMinX = s.xMin + halfWidth;
    final standableMaxX = s.xMax - halfWidth;
    if (standableMinX > standableMaxX + eps) continue;
    // Entity center must be inside standable range.
    if (x < standableMinX - eps || x > standableMaxX + eps) continue;
    // Skip if too far vertically.
    if ((s.yTop - bottomY).abs() > eps) continue;

    // Prefer higher platform (lower yTop in screen coords).
    if (bestY == null || s.yTop < bestY) {
      bestY = s.yTop;
      bestIndex = i;
    } else if ((s.yTop - bestY).abs() <= eps) {
      // Tie-break by ID for determinism.
      if (s.id < graph.surfaces[bestIndex!].id) {
        bestIndex = i;
      }
    }
  }

  return bestIndex;
}
