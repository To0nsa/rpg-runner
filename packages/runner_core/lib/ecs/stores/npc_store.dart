import '../../npcs/npc_id.dart';
import '../../abilities/ability_def.dart';
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
  final List<AbilityKey?> _meleeOpenerAbilityId = [];
  final List<Set<EntityId>> _meleeOpenerTargets = [];

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
    AbilityKey? meleeOpenerAbilityId,
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
    _meleeOpenerAbilityId[i] = meleeOpenerAbilityId;
    _meleeOpenerTargets[i].clear();
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

  /// Successful opener history persists until either actor is destroyed.
  bool hasLandedMeleeOpener(EntityId actor, EntityId target) {
    final i = tryIndexOf(actor);
    return i != null && _meleeOpenerTargets[i].contains(target);
  }

  /// Prevent a later opener aimed at another foe from re-hitting this victim.
  bool isSpentMeleeOpener(
    EntityId actor,
    EntityId target,
    AbilityKey? abilityId,
  ) {
    if (abilityId == null) return false;
    final i = tryIndexOf(actor);
    return i != null &&
        _meleeOpenerAbilityId[i] == abilityId &&
        _meleeOpenerTargets[i].contains(target);
  }

  /// Called only after positive HP loss, using the hitbox's captured ability.
  /// Misses, canceled hits and invulnerability never consume the opener.
  void recordMeleeHit(EntityId actor, EntityId target, AbilityKey? abilityId) {
    if (abilityId == null) return;
    final i = tryIndexOf(actor);
    if (i != null && _meleeOpenerAbilityId[i] == abilityId) {
      _meleeOpenerTargets[i].add(target);
    }
  }

  /// Remove inbound history before the world recycles an entity ID.
  void forgetTarget(EntityId target) {
    for (final targets in _meleeOpenerTargets) {
      targets.remove(target);
    }
  }

  @override
  void onDenseAdded(int denseIndex) {
    npcId.add(NpcId.warrior);
    facing.add(Facing.right);
    artFacing.add(Facing.right);
    minX.add(0);
    maxX.add(0);
    protected.add(false);
    _meleeOpenerAbilityId.add(null);
    _meleeOpenerTargets.add({});
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
    _meleeOpenerAbilityId[removeIndex] = _meleeOpenerAbilityId[lastIndex];
    _meleeOpenerTargets[removeIndex] = _meleeOpenerTargets[lastIndex];
    guardRegion[removeIndex] = guardRegion[lastIndex];
    movementBounds[removeIndex] = movementBounds[lastIndex];
    npcId.removeLast();
    facing.removeLast();
    artFacing.removeLast();
    minX.removeLast();
    maxX.removeLast();
    protected.removeLast();
    _meleeOpenerAbilityId.removeLast();
    _meleeOpenerTargets.removeLast();
    guardRegion.removeLast();
    movementBounds.removeLast();
  }
}
