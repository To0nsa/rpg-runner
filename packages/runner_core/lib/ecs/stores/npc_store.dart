import '../../npcs/npc_id.dart';
import '../../collision/terrain/terrain_motion_request.dart';
import '../../collision/terrain/terrain_numeric.dart';
import '../../snapshots/enums.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

/// NPC identity and owning chunk bounds persist through rescue and death.
class NpcStore extends SparseSet {
  final List<NpcId> npcId = [];
  final List<Facing> facing = [];
  final List<Facing> artFacing = [];
  final List<double> minX = [];
  final List<double> maxX = [];
  final List<bool> protected = [];
  final List<TerrainHorizontalBounds> movementBounds = [];
  static final _emptyBounds = TerrainHorizontalBounds(
    minXTicks: 0,
    maxXTicks: 1,
  );

  void add(
    EntityId entity, {
    required NpcId id,
    required double chunkStartX,
    required double chunkEndX,
    Facing initialFacing = Facing.right,
    Facing sourceFacing = Facing.right,
  }) {
    if (!chunkStartX.isFinite ||
        !chunkEndX.isFinite ||
        chunkStartX >= chunkEndX) {
      throw ArgumentError('NPC movement bounds must be finite and ordered.');
    }
    final bounds = TerrainHorizontalBounds(
      minXTicks: physicsCoordinateToTicks(chunkStartX),
      maxXTicks: physicsCoordinateToTicks(chunkEndX),
    );
    final i = addEntity(entity);
    movementBounds[i] = bounds;
    npcId[i] = id;
    facing[i] = initialFacing;
    artFacing[i] = sourceFacing;
    minX[i] = chunkStartX;
    maxX[i] = chunkEndX;
    protected[i] = false;
  }

  bool isProtected(EntityId entity) {
    final i = tryIndexOf(entity);
    return i != null && protected[i];
  }

  @override
  void onDenseAdded(int denseIndex) {
    npcId.add(NpcId.warrior);
    facing.add(Facing.right);
    artFacing.add(Facing.right);
    minX.add(0);
    maxX.add(0);
    protected.add(false);
    movementBounds.add(_emptyBounds);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    npcId[removeIndex] = npcId[lastIndex];
    facing[removeIndex] = facing[lastIndex];
    artFacing[removeIndex] = artFacing[lastIndex];
    minX[removeIndex] = minX[lastIndex];
    maxX[removeIndex] = maxX[lastIndex];
    protected[removeIndex] = protected[lastIndex];
    movementBounds[removeIndex] = movementBounds[lastIndex];
    npcId.removeLast();
    facing.removeLast();
    artFacing.removeLast();
    minX.removeLast();
    maxX.removeLast();
    protected.removeLast();
    movementBounds.removeLast();
  }
}
