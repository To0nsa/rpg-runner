import '../../abilities/ability_def.dart';
import '../../snapshots/enums.dart'; // For Facing
import '../sparse_set.dart';
import '../entity_id.dart';

/// Owns one committed action's identity, timing and protection per actor.
/// Gameplay and animation consume the same clock. Completion and interruption
/// clear the action; replacing it cannot inherit the prior action's protection.
class ActiveAbilityStateStore extends SparseSet {
  /// Null when the actor has no committed action.
  final List<AbilityKey?> abilityId = [];

  /// Unconditional combat protection owned only by this committed activation.
  /// Cleared with the action; unlike post-hit protection, combos cannot bypass it.
  final List<bool> invulnerable = [];

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

  /// Cooldown metadata captured at commit-time.
  final List<int> cooldownGroupId = [];
  final List<int> cooldownTicks = [];
  final List<bool> cooldownStarted = [];

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
    int cooldownGroupId = 0,
    int cooldownTicks = 0,
    bool cooldownStarted = true,
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
    invulnerable[i] = false;
    this.slot[i] = slot;
    startTick[i] = commitTick;
    facing[i] = facingDir;
    this.windupTicks[i] = windupTicks;
    this.activeTicks[i] = activeTicks;
    this.recoveryTicks[i] = recoveryTicks;
    totalTicks[i] = windupTicks + activeTicks + recoveryTicks;
    this.cooldownGroupId[i] = cooldownGroupId;
    this.cooldownTicks[i] = cooldownTicks;
    this.cooldownStarted[i] = cooldownStarted;
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
      invulnerable[i] = false;
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
    invulnerable.add(false);
    startTick.add(-1);
    facing.add(Facing.right);
    slot.add(AbilitySlot.primary);
    phase.add(AbilityPhase.idle);
    windupTicks.add(0);
    activeTicks.add(0);
    recoveryTicks.add(0);
    totalTicks.add(0);
    cooldownGroupId.add(0);
    cooldownTicks.add(0);
    cooldownStarted.add(true);
    elapsedTicks.add(0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    abilityId[removeIndex] = abilityId[lastIndex];
    invulnerable[removeIndex] = invulnerable[lastIndex];
    startTick[removeIndex] = startTick[lastIndex];
    facing[removeIndex] = facing[lastIndex];
    slot[removeIndex] = slot[lastIndex];
    phase[removeIndex] = phase[lastIndex];
    windupTicks[removeIndex] = windupTicks[lastIndex];
    activeTicks[removeIndex] = activeTicks[lastIndex];
    recoveryTicks[removeIndex] = recoveryTicks[lastIndex];
    totalTicks[removeIndex] = totalTicks[lastIndex];
    cooldownGroupId[removeIndex] = cooldownGroupId[lastIndex];
    cooldownTicks[removeIndex] = cooldownTicks[lastIndex];
    cooldownStarted[removeIndex] = cooldownStarted[lastIndex];
    elapsedTicks[removeIndex] = elapsedTicks[lastIndex];

    abilityId.removeLast();
    invulnerable.removeLast();
    startTick.removeLast();
    facing.removeLast();
    slot.removeLast();
    phase.removeLast();
    windupTicks.removeLast();
    activeTicks.removeLast();
    recoveryTicks.removeLast();
    totalTicks.removeLast();
    cooldownGroupId.removeLast();
    cooldownTicks.removeLast();
    cooldownStarted.removeLast();
    elapsedTicks.removeLast();
  }
}
