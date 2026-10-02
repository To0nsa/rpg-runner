import '../../npcs/npc_id.dart';
import '../../npcs/npc_guard_region.dart';
import '../../collision/terrain/terrain_motion_request.dart';
import '../../collision/terrain/terrain_numeric.dart';
import '../../snapshots/enums.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

/// NPC identity persists through rescue; only cleared survivors gain section bounds.
class NpcStore extends SparseSet {
  final List<NpcId> npcId = [];
  final List<Facing> facing = [];
  final List<Facing> artFacing = [];
  final List<double> minX = [];
  final List<double> maxX = [];
  final List<bool> protected = [];

  /// Non-null only after required-enemy completion; protection ends guarding.
  final List<NpcGuardRegion?> guardRegion = [];
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
    guardRegion[i] = null;
  }

  /// Expands a living, unprotected survivor's movement to its section occurrence.
  /// Combat teardown and target configuration are owned by the lifecycle system.
  void beginGuarding(EntityId entity, NpcGuardRegion region) {
    final i = indexOf(entity);
    if (protected[i] || region.minX > minX[i] || region.maxX < maxX[i]) {
      throw StateError('Guarding must expand an unprotected NPC territory.');
    }
    final bounds = TerrainHorizontalBounds(
      minXTicks: physicsCoordinateToTicks(region.minX),
      maxXTicks: physicsCoordinateToTicks(region.maxX),
    );
    minX[i] = region.minX;
    maxX[i] = region.maxX;
    movementBounds[i] = bounds;
    guardRegion[i] = region;
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
    guardRegion.add(null);
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
    guardRegion[removeIndex] = guardRegion[lastIndex];
    movementBounds[removeIndex] = movementBounds[lastIndex];
    npcId.removeLast();
    facing.removeLast();
    artFacing.removeLast();
    minX.removeLast();
    maxX.removeLast();
    protected.removeLast();
    guardRegion.removeLast();
    movementBounds.removeLast();
  }
}
