/// Lock flag bit constants for ability/action gating.
///
/// These flags control what actions an entity can perform.
/// Multiple locks can be active simultaneously with independent expiry times.
///
/// Use [LockFlag.stun] as a "master lock" that blocks everything.
library;

/// Bit flag constants for control locks.
abstract class LockFlag {
  /// Stun lock - blocks ALL actions and movement.
  /// This is the "master lock" - systems should check isStunned() first.
  static const int stun = 1 << 0;

  /// Movement lock - blocks horizontal control input.
  static const int move = 1 << 1;

  /// Jump lock - blocks jump input.
  static const int jump = 1 << 2;

  /// Dash lock - blocks dash ability.
  static const int dash = 1 << 3;

  /// Strike lock - blocks melee attacks.
  static const int strike = 1 << 4;

  /// Cast lock - blocks spell casting.
  static const int cast = 1 << 5;

  /// Ranged lock - blocks ranged weapon attacks.
  static const int ranged = 1 << 6;

  /// Nav lock - blocks enemy navigation/pathfinding.
  static const int nav = 1 << 7;

  // ─────────────────────────────────────────────────────────────────────────
  // Composite masks for convenience
  // ─────────────────────────────────────────────────────────────────────────

  /// All offensive actions (strike, cast, ranged).
  static const int allActions = strike | cast | ranged;

  /// All movement abilities (move, jump, dash).
  static const int allMovement = move | jump | dash;

  /// Everything except stun.
  static const int allExceptStun = allActions | allMovement | nav;

  /// All flags combined.
  static const int all = stun | allExceptStun;
}
