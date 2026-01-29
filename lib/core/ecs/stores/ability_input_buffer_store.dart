import '../../abilities/ability_def.dart';
import '../../snapshots/enums.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

/// Stores a single buffered ability input per entity.
///
/// Buffering is used when an input is pressed during an ability's Recovery phase.
/// The latest press overwrites any previous buffer.
class AbilityInputBufferStore extends SparseSet {
  final List<bool> hasBuffered = <bool>[];
  final List<AbilitySlot> slot = <AbilitySlot>[];
  final List<AbilityKey> abilityId = <AbilityKey>[];
  final List<double> aimDirX = <double>[];
  final List<double> aimDirY = <double>[];
  final List<Facing> facing = <Facing>[];
  final List<int> commitTick = <int>[];
  final List<int> expiresTick = <int>[];

  /// Ensures entity has this component. Idempotent.
  void ensure(EntityId entity) {
    if (!has(entity)) {
      addEntity(entity);
    }
  }

  /// Strict add — asserts entity is NOT already present.
  void add(EntityId entity) {
    assert(!has(entity), 'Entity $entity already has AbilityInputBufferStore');
    addEntity(entity);
  }

  void setBuffer(
    EntityId entity, {
    required AbilitySlot slot,
    required AbilityKey abilityId,
    required double aimDirX,
    required double aimDirY,
    required Facing facing,
    required int commitTick,
    required int expiresTick,
  }) {
    assert(
      has(entity),
      'AbilityInputBufferStore.setBuffer called for entity without AbilityInputBufferStore.',
    );
    final i = indexOf(entity);
    hasBuffered[i] = true;
    this.slot[i] = slot;
    this.abilityId[i] = abilityId;
    this.aimDirX[i] = aimDirX;
    this.aimDirY[i] = aimDirY;
    this.facing[i] = facing;
    this.commitTick[i] = commitTick;
    this.expiresTick[i] = expiresTick;
  }

  void clear(EntityId entity) {
    if (!has(entity)) return;
    final i = indexOf(entity);
    hasBuffered[i] = false;
    commitTick[i] = -1;
    expiresTick[i] = -1;
  }

  @override
  void onDenseAdded(int denseIndex) {
    hasBuffered.add(false);
    slot.add(AbilitySlot.primary);
    abilityId.add('common.unarmed_strike');
    aimDirX.add(0.0);
    aimDirY.add(0.0);
    facing.add(Facing.right);
    commitTick.add(-1);
    expiresTick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    hasBuffered[removeIndex] = hasBuffered[lastIndex];
    slot[removeIndex] = slot[lastIndex];
    abilityId[removeIndex] = abilityId[lastIndex];
    aimDirX[removeIndex] = aimDirX[lastIndex];
    aimDirY[removeIndex] = aimDirY[lastIndex];
    facing[removeIndex] = facing[lastIndex];
    commitTick[removeIndex] = commitTick[lastIndex];
    expiresTick[removeIndex] = expiresTick[lastIndex];

    hasBuffered.removeLast();
    slot.removeLast();
    abilityId.removeLast();
    aimDirX.removeLast();
    aimDirY.removeLast();
    facing.removeLast();
    commitTick.removeLast();
    expiresTick.removeLast();
  }
}
