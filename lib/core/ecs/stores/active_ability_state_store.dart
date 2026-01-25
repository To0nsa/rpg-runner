import '../../abilities/ability_def.dart';
import '../../snapshots/enums.dart'; // For Facing
import '../sparse_set.dart';
import '../entity_id.dart';

/// Tracks the state of the currently active "Action Ability" for animation purposes.
///
/// This store is the single source of truth for "what action is the character doing?".
/// It replaces disparate timestamps like `lastCastTick`, `lastMeleeTick`, etc.
/// in the Animation System.
///
/// **Design Pillar**:
/// - **Single Channel**: Only one Action Ability active at a time.
/// - **Layering**: Overridden by Death, Stun, and potentially Hit Reactions.
/// - **Lifecycle**: Must be explicitly cleared when the action completes.
class ActiveAbilityStateStore extends SparseSet {
  /// The ID of the ability currently controlling the character.
  /// Null (or empty string/special value) if no ability is active.
  /// Using String (AbilityKey) here. Nullable?
  /// SparseSet usage usually implies non-nullable defaults in lists?
  /// Let's use nullable for logic, or empty string.
  /// Pattern in other stores: List<AbilityKey> with default.
  final List<AbilityKey?> abilityId = [];

  /// The tick when this ability was committed.
  /// Used to calculate (currentTick - commitTick) for phase timing.
  final List<int> startTick = [];

  /// The facing direction at the moment of commitment.
  final List<Facing> facing = [];

  /// Slot that owns this ability (Primary/Secondary/Projectile/Mobility/Bonus).
  final List<AbilitySlot> slot = [];

  /// Current phase of the active ability.
  final List<AbilityPhase> phase = [];

  /// Phase durations (scaled to tickHz at commit time).
  final List<int> windupTicks = [];
  final List<int> activeTicks = [];
  final List<int> recoveryTicks = [];
  final List<int> totalTicks = [];

  /// Cached elapsed ticks since commit (updated by phase system).
  final List<int> elapsedTicks = [];

  // Future: aimDir for multi-directional sprites.

  void add(EntityId entity) {
    addEntity(entity);
  }

  /// Sets the active ability for [entity].
  /// Overwrites any existing ability.
  void set(
    EntityId entity, {
    required AbilityKey id,
    required AbilitySlot slot,
    required int commitTick,
    required int windupTicks,
    required int activeTicks,
    required int recoveryTicks,
    required Facing facingDir,
  }) {
    if (!has(entity)) {
      // Auto-add if missing? Or should it be added at spawn?
      // Best practice: Add at spawn. But here we can safe-guard.
      // EcsWorld usually adds components via add().
      // If we assume it's added, we just assert.
      // But for robustness in this refactor, let's assert.
      assert(has(entity), 'Entity $entity missing ActiveAbilityStateStore');
      return;
    }
    final i = indexOf(entity);
    abilityId[i] = id;
    this.slot[i] = slot;
    startTick[i] = commitTick;
    facing[i] = facingDir;
    this.windupTicks[i] = windupTicks;
    this.activeTicks[i] = activeTicks;
    this.recoveryTicks[i] = recoveryTicks;
    totalTicks[i] = windupTicks + activeTicks + recoveryTicks;
    if (windupTicks > 0) {
      phase[i] = AbilityPhase.windup;
    } else if (activeTicks > 0) {
      phase[i] = AbilityPhase.active;
    } else if (recoveryTicks > 0) {
      phase[i] = AbilityPhase.recovery;
    } else {
      phase[i] = AbilityPhase.idle;
    }
    elapsedTicks[i] = 0;
  }

  /// Clears the active ability state for [entity].
  void clear(EntityId entity) {
    if (has(entity)) {
      final i = indexOf(entity);
      abilityId[i] = null;
      startTick[i] = -1;
      phase[i] = AbilityPhase.idle;
      elapsedTicks[i] = 0;
    }
  }

  /// Checks if [entity] has an active ability.
  bool hasActiveAbility(EntityId entity) {
    if (!has(entity)) return false;
    final i = indexOf(entity);
    return abilityId[i] != null;
  }

  @override
  void onDenseAdded(int denseIndex) {
    abilityId.add(null);
    startTick.add(-1);
    facing.add(Facing.right);
    slot.add(AbilitySlot.primary);
    phase.add(AbilityPhase.idle);
    windupTicks.add(0);
    activeTicks.add(0);
    recoveryTicks.add(0);
    totalTicks.add(0);
    elapsedTicks.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    abilityId[removeIndex] = abilityId[lastIndex];
    startTick[removeIndex] = startTick[lastIndex];
    facing[removeIndex] = facing[lastIndex];
    slot[removeIndex] = slot[lastIndex];
    phase[removeIndex] = phase[lastIndex];
    windupTicks[removeIndex] = windupTicks[lastIndex];
    activeTicks[removeIndex] = activeTicks[lastIndex];
    recoveryTicks[removeIndex] = recoveryTicks[lastIndex];
    totalTicks[removeIndex] = totalTicks[lastIndex];
    elapsedTicks[removeIndex] = elapsedTicks[lastIndex];

    abilityId.removeLast();
    startTick.removeLast();
    facing.removeLast();
    slot.removeLast();
    phase.removeLast();
    windupTicks.removeLast();
    activeTicks.removeLast();
    recoveryTicks.removeLast();
    totalTicks.removeLast();
    elapsedTicks.removeLast();
  }
}
