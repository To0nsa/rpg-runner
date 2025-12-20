import '../../navigation/surface_id.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class SurfaceNavStateStore extends SparseSet {
  final List<int> graphVersion = <int>[];
  final List<int> repathTicksLeft = <int>[];
  final List<int> jumpCooldownTicksLeft = <int>[];
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
    jumpCooldownTicksLeft.add(0);
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
    jumpCooldownTicksLeft[removeIndex] = jumpCooldownTicksLeft[lastIndex];
    currentSurfaceId[removeIndex] = currentSurfaceId[lastIndex];
    targetSurfaceId[removeIndex] = targetSurfaceId[lastIndex];
    activeEdgeIndex[removeIndex] = activeEdgeIndex[lastIndex];
    pathCursor[removeIndex] = pathCursor[lastIndex];
    pathEdges[removeIndex] = pathEdges[lastIndex];

    graphVersion.removeLast();
    repathTicksLeft.removeLast();
    jumpCooldownTicksLeft.removeLast();
    currentSurfaceId.removeLast();
    targetSurfaceId.removeLast();
    activeEdgeIndex.removeLast();
    pathCursor.removeLast();
    pathEdges.removeLast();
  }
}
