import '../../../navigation/types/surface_id.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Per-entity pathfinding state.
///
/// Tracks the current surface segment, the target segment, and the calculated path edges.
/// Used by `SurfaceNavigationSystem` to move ground enemies.
class SurfaceNavStateStore extends SparseSet {
  final List<int> graphVersion = <int>[];
  final List<int> repathTicksLeft = <int>[];
  final List<int> currentSurfaceId = <int>[];
  final List<int> targetSurfaceId = <int>[];
  final List<int> activeEdgeIndex = <int>[];
  final List<int> pathCursor = <int>[];
  final List<List<int>> pathEdges = <List<int>>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  @override
  void onDenseAdded(int denseIndex) {
    graphVersion.add(-1);
    repathTicksLeft.add(0);
    currentSurfaceId.add(surfaceIdUnknown);
    targetSurfaceId.add(surfaceIdUnknown);
    activeEdgeIndex.add(-1);
    pathCursor.add(0);
    pathEdges.add(<int>[]);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    graphVersion[removeIndex] = graphVersion[lastIndex];
    repathTicksLeft[removeIndex] = repathTicksLeft[lastIndex];
    currentSurfaceId[removeIndex] = currentSurfaceId[lastIndex];
    targetSurfaceId[removeIndex] = targetSurfaceId[lastIndex];
    activeEdgeIndex[removeIndex] = activeEdgeIndex[lastIndex];
    pathCursor[removeIndex] = pathCursor[lastIndex];
    pathEdges[removeIndex] = pathEdges[lastIndex];

    graphVersion.removeLast();
    repathTicksLeft.removeLast();
    currentSurfaceId.removeLast();
    targetSurfaceId.removeLast();
    activeEdgeIndex.removeLast();
    pathCursor.removeLast();
    pathEdges.removeLast();
  }
}
