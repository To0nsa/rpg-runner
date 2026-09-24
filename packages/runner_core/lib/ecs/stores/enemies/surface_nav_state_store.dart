import '../../../navigation/types/surface_id.dart';
import '../../../navigation/terrain_surface_navigator.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Per-entity pathfinding state.
///
/// Tracks the current surface segment, the target segment, and the calculated path edges.
/// Used by `SurfaceNavigationSystem` to move ground enemies.
class SurfaceNavStateStore extends SparseSet {
  /// Identity owning the retained target support, including ordinary pursuit.
  final List<EntityId?> targetEntity = [];
  final List<int> graphVersion = <int>[];
  final List<int> repathTicksLeft = <int>[];
  final List<int> currentSurfaceId = <int>[];
  final List<int> lastGroundSurfaceId = <int>[];
  final List<int> targetSurfaceId = <int>[];
  final List<int> activeEdgeIndex = <int>[];
  final List<int> pathCursor = <int>[];
  final List<List<int>> pathEdges = <List<int>>[];

  /// Polygon-terrain navigator state selected only by terrain authority.
  final List<TerrainSurfaceNavigatorState> terrainState =
      <TerrainSurfaceNavigatorState>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  void forgetTarget(EntityId entity) {
    for (var i = 0; i < targetEntity.length; i++) {
      if (targetEntity[i] == entity) targetEntity[i] = null;
    }
  }

  @override
  void onDenseAdded(int denseIndex) {
    targetEntity.add(null);
    graphVersion.add(-1);
    repathTicksLeft.add(0);
    currentSurfaceId.add(surfaceIdUnknown);
    lastGroundSurfaceId.add(surfaceIdUnknown);
    targetSurfaceId.add(surfaceIdUnknown);
    activeEdgeIndex.add(-1);
    pathCursor.add(0);
    pathEdges.add(<int>[]);
    terrainState.add(TerrainSurfaceNavigatorState());
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    targetEntity[removeIndex] = targetEntity[lastIndex];
    targetEntity.removeLast();
    graphVersion[removeIndex] = graphVersion[lastIndex];
    repathTicksLeft[removeIndex] = repathTicksLeft[lastIndex];
    currentSurfaceId[removeIndex] = currentSurfaceId[lastIndex];
    lastGroundSurfaceId[removeIndex] = lastGroundSurfaceId[lastIndex];
    targetSurfaceId[removeIndex] = targetSurfaceId[lastIndex];
    activeEdgeIndex[removeIndex] = activeEdgeIndex[lastIndex];
    pathCursor[removeIndex] = pathCursor[lastIndex];
    pathEdges[removeIndex] = pathEdges[lastIndex];
    terrainState[removeIndex] = terrainState[lastIndex];

    graphVersion.removeLast();
    repathTicksLeft.removeLast();
    currentSurfaceId.removeLast();
    lastGroundSurfaceId.removeLast();
    targetSurfaceId.removeLast();
    activeEdgeIndex.removeLast();
    pathCursor.removeLast();
    pathEdges.removeLast();
    terrainState.removeLast();
  }
}
