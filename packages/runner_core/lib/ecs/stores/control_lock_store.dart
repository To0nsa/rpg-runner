import '../entity_id.dart';
import '../sparse_set.dart';
import '../../combat/control_lock.dart';

/// SoA store for control locks with per-flag expiry.
///
/// Each flag has its own `untilTick` field. A lock is active if
/// `currentTick < untilTick`. The [activeMask] is recomputed each tick
/// by [ControlLockSystem].
///
/// **Refresh rule**: When adding a lock, use `max(existing, new)` for the
/// untilTick to handle overlapping/refreshing locks correctly.
class ControlLockStore extends SparseSet {
  /// Cached active mask (refreshed each tick by ControlLockSystem).
  final List<int> activeMask = <int>[];

  /// Per-flag expiry ticks.
  ///
  /// A lock is active while `currentTick < untilTickX`.
  final List<int> untilTickStun = <int>[];
  final List<int> untilTickMove = <int>[];
  final List<int> untilTickJump = <int>[];
  final List<int> untilTickDash = <int>[];
  final List<int> untilTickStrike = <int>[];
  final List<int> untilTickCast = <int>[];
  final List<int> untilTickRanged = <int>[];
  final List<int> untilTickNav = <int>[];

  /// Tick where the current continuous stun window started.
  ///
  /// This is set when an entity transitions from "not stunned" to "stunned".
  /// Refreshing an already-active stun extends duration without restarting this
  /// origin tick.
  final List<int> stunStartTick = <int>[];

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Adds or refreshes a lock on [entity].
  ///
  /// Uses `max(existing, new)` for the untilTick to correctly handle
  /// refreshing or overlapping locks with different durations.
  void addLock(EntityId entity, int flag, int durationTicks, int currentTick) {
    if (durationTicks <= 0) return;

    final newUntilTick = currentTick + durationTicks;

    int idx = tryIndexOf(entity) ?? addEntity(entity);

    // Apply lock(s) using max() for refresh behavior
    if ((flag & LockFlag.stun) != 0) {
      final wasStunned = currentTick < untilTickStun[idx];
      untilTickStun[idx] = _max(untilTickStun[idx], newUntilTick);
      if (!wasStunned) {
        stunStartTick[idx] = currentTick;
      }
    }
    if ((flag & LockFlag.move) != 0) {
      untilTickMove[idx] = _max(untilTickMove[idx], newUntilTick);
    }
    if ((flag & LockFlag.jump) != 0) {
      untilTickJump[idx] = _max(untilTickJump[idx], newUntilTick);
    }
    if ((flag & LockFlag.dash) != 0) {
      untilTickDash[idx] = _max(untilTickDash[idx], newUntilTick);
    }
    if ((flag & LockFlag.strike) != 0) {
      untilTickStrike[idx] = _max(untilTickStrike[idx], newUntilTick);
    }
    if ((flag & LockFlag.cast) != 0) {
      untilTickCast[idx] = _max(untilTickCast[idx], newUntilTick);
    }
    if ((flag & LockFlag.ranged) != 0) {
      untilTickRanged[idx] = _max(untilTickRanged[idx], newUntilTick);
    }
    if ((flag & LockFlag.nav) != 0) {
      untilTickNav[idx] = _max(untilTickNav[idx], newUntilTick);
    }

    // Update cached mask immediately
    _refreshMaskAt(idx, currentTick);
  }

  /// Returns true if [entity] has [flag] locked.
  bool isLocked(EntityId entity, int flag, int currentTick) {
    final idx = tryIndexOf(entity);
    if (idx == null) return false;

    // Check stun first (master lock)
    if (currentTick < untilTickStun[idx]) return true;

    // Then check specific flag
    return _isFlagActiveAt(idx, flag, currentTick);
  }

  /// Returns true if [entity] is stunned.
  ///
  /// This is the primary check for gameplay systems. Stun blocks everything.
  bool isStunned(EntityId entity, int currentTick) {
    final idx = tryIndexOf(entity);
    if (idx == null) return false;
    return currentTick < untilTickStun[idx];
  }

  /// Returns stun animation origin tick for [entity], or `-1` if not stunned.
  int stunStartTickFor(EntityId entity, int currentTick) {
    final idx = tryIndexOf(entity);
    if (idx == null) return -1;
    if (currentTick >= untilTickStun[idx]) return -1;
    return stunStartTick[idx];
  }

  /// Returns the cached active mask for [entity].
  ///
  /// Note: This mask is refreshed by ControlLockSystem each tick.
  /// For immediate checks, use [isLocked] or [isStunned].
  int getActiveMask(EntityId entity) {
    final idx = tryIndexOf(entity);
    if (idx == null) return 0;
    return activeMask[idx];
  }

  /// Clears specific lock flags on [entity] immediately.
  void clearLock(EntityId entity, int flag) {
    final idx = tryIndexOf(entity);
    if (idx == null) return;

    if ((flag & LockFlag.stun) != 0) {
      untilTickStun[idx] = 0;
      stunStartTick[idx] = -1;
    }
    if ((flag & LockFlag.move) != 0) {
      untilTickMove[idx] = 0;
    }
    if ((flag & LockFlag.jump) != 0) {
      untilTickJump[idx] = 0;
    }
    if ((flag & LockFlag.dash) != 0) {
      untilTickDash[idx] = 0;
    }
    if ((flag & LockFlag.strike) != 0) {
      untilTickStrike[idx] = 0;
    }
    if ((flag & LockFlag.cast) != 0) {
      untilTickCast[idx] = 0;
    }
    if ((flag & LockFlag.ranged) != 0) {
      untilTickRanged[idx] = 0;
    }
    if ((flag & LockFlag.nav) != 0) {
      untilTickNav[idx] = 0;
    }

    activeMask[idx] &= ~flag;
  }

  /// Refreshes the active mask for entity at [idx] based on [currentTick].
  ///
  /// Called by ControlLockSystem each tick and after addLock.
  void refreshMask(int idx, int currentTick) {
    _refreshMaskAt(idx, currentTick);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SparseSet overrides
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void onDenseAdded(int denseIndex) {
    activeMask.add(0);
    untilTickStun.add(0);
    untilTickMove.add(0);
    untilTickJump.add(0);
    untilTickDash.add(0);
    untilTickStrike.add(0);
    untilTickCast.add(0);
    untilTickRanged.add(0);
    untilTickNav.add(0);
    stunStartTick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    activeMask[removeIndex] = activeMask[lastIndex];
    untilTickStun[removeIndex] = untilTickStun[lastIndex];
    untilTickMove[removeIndex] = untilTickMove[lastIndex];
    untilTickJump[removeIndex] = untilTickJump[lastIndex];
    untilTickDash[removeIndex] = untilTickDash[lastIndex];
    untilTickStrike[removeIndex] = untilTickStrike[lastIndex];
    untilTickCast[removeIndex] = untilTickCast[lastIndex];
    untilTickRanged[removeIndex] = untilTickRanged[lastIndex];
    untilTickNav[removeIndex] = untilTickNav[lastIndex];
    stunStartTick[removeIndex] = stunStartTick[lastIndex];

    activeMask.removeLast();
    untilTickStun.removeLast();
    untilTickMove.removeLast();
    untilTickJump.removeLast();
    untilTickDash.removeLast();
    untilTickStrike.removeLast();
    untilTickCast.removeLast();
    untilTickRanged.removeLast();
    untilTickNav.removeLast();
    stunStartTick.removeLast();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _refreshMaskAt(int idx, int currentTick) {
    int mask = 0;
    if (currentTick < untilTickStun[idx]) mask |= LockFlag.stun;
    if (currentTick < untilTickMove[idx]) mask |= LockFlag.move;
    if (currentTick < untilTickJump[idx]) mask |= LockFlag.jump;
    if (currentTick < untilTickDash[idx]) mask |= LockFlag.dash;
    if (currentTick < untilTickStrike[idx]) mask |= LockFlag.strike;
    if (currentTick < untilTickCast[idx]) mask |= LockFlag.cast;
    if (currentTick < untilTickRanged[idx]) mask |= LockFlag.ranged;
    if (currentTick < untilTickNav[idx]) mask |= LockFlag.nav;
    activeMask[idx] = mask;
  }

  bool _isFlagActiveAt(int idx, int flag, int currentTick) {
    if ((flag & LockFlag.move) != 0 && currentTick < untilTickMove[idx]) {
      return true;
    }
    if ((flag & LockFlag.jump) != 0 && currentTick < untilTickJump[idx]) {
      return true;
    }
    if ((flag & LockFlag.dash) != 0 && currentTick < untilTickDash[idx]) {
      return true;
    }
    if ((flag & LockFlag.strike) != 0 && currentTick < untilTickStrike[idx]) {
      return true;
    }
    if ((flag & LockFlag.cast) != 0 && currentTick < untilTickCast[idx]) {
      return true;
    }
    if ((flag & LockFlag.ranged) != 0 && currentTick < untilTickRanged[idx]) {
      return true;
    }
    if ((flag & LockFlag.nav) != 0 && currentTick < untilTickNav[idx]) {
      return true;
    }
    return false;
  }

  static int _max(int a, int b) => a > b ? a : b;
}
