// Aggregated input state for a single simulation tick.
//
// The game schedules input commands ahead of time (via RunnerInputRouter).
// Multiple commands may target the same tick, so this class merges them into
// a single coherent state that the simulation consumes.
import '../core/commands/command.dart';

/// Aggregated per-tick input for the simulation.
///
/// This replaces `List<Command>` buffering for a given tick to avoid duplicate
/// commands (e.g., multiple [MoveAxisCommand]s for the same tick). Instead of
/// storing a list, we collapse commands into their final values.
///
/// **Usage pattern:**
/// 1. [GameController] creates one [TickInputFrame] per buffered tick.
/// 2. As commands arrive, [apply] merges them into the frame.
/// 3. When the tick executes, the simulation reads the aggregated state.
/// 4. After use, [reset] clears the frame for potential reuse.
class TickInputFrame {
  // ─────────────────────────────────────────────────────────────────────────
  // Movement
  // ─────────────────────────────────────────────────────────────────────────

  /// Horizontal movement axis in [-1, 1]. Last [MoveAxisCommand] wins.
  double moveAxis = 0;

  // ─────────────────────────────────────────────────────────────────────────
  // Edge-triggered actions (one-shot per tick)
  // ─────────────────────────────────────────────────────────────────────────

  /// True if jump was pressed this tick.
  bool jumpPressed = false;

  /// True if dash was pressed this tick.
  bool dashPressed = false;

  /// True if melee strike was pressed this tick.
  bool strikePressed = false;

  /// True if cast (projectile) was pressed this tick.
  bool castPressed = false;

  /// True if ranged weapon was pressed this tick.
  bool rangedPressed = false;

  // ─────────────────────────────────────────────────────────────────────────
  // Projectile aim direction
  // ─────────────────────────────────────────────────────────────────────────

  /// Whether a projectile aim direction is set for this tick.
  bool projectileAimDirSet = false;

  /// Projectile aim X component (only valid if [projectileAimDirSet] is true).
  double projectileAimDirX = 0;

  /// Projectile aim Y component (only valid if [projectileAimDirSet] is true).
  double projectileAimDirY = 0;

  // ─────────────────────────────────────────────────────────────────────────
  // Melee aim direction
  // ─────────────────────────────────────────────────────────────────────────

  /// Whether a melee aim direction is set for this tick.
  bool meleeAimDirSet = false;

  /// Melee aim X component (only valid if [meleeAimDirSet] is true).
  double meleeAimDirX = 0;

  /// Melee aim Y component (only valid if [meleeAimDirSet] is true).
  double meleeAimDirY = 0;

  // ─────────────────────────────────────────────────────────────────────────
  // Ranged weapon aim direction
  // ─────────────────────────────────────────────────────────────────────────

  /// Whether a ranged weapon aim direction is set for this tick.
  bool rangedAimDirSet = false;

  /// Ranged weapon aim X component (only valid if [rangedAimDirSet] is true).
  double rangedAimDirX = 0;

  /// Ranged weapon aim Y component (only valid if [rangedAimDirSet] is true).
  double rangedAimDirY = 0;

  /// Applies a [Command] to this frame, merging it with existing state.
  ///
  /// For continuous inputs (move axis, aim), later commands overwrite earlier ones.
  /// For edge-triggered inputs (jump, dash, strike, cast), any press sets the flag.
  void apply(Command command) {
    switch (command) {
      case MoveAxisCommand(:final axis):
        moveAxis = axis.clamp(-1.0, 1.0);
      case JumpPressedCommand():
        jumpPressed = true;
      case DashPressedCommand():
        dashPressed = true;
      case StrikePressedCommand():
        strikePressed = true;
      case ProjectileAimDirCommand(:final x, :final y):
        projectileAimDirSet = true;
        projectileAimDirX = x;
        projectileAimDirY = y;
      case MeleeAimDirCommand(:final x, :final y):
        meleeAimDirSet = true;
        meleeAimDirX = x;
        meleeAimDirY = y;
      case ClearProjectileAimDirCommand():
        projectileAimDirSet = false;
        projectileAimDirX = 0;
        projectileAimDirY = 0;
      case ClearMeleeAimDirCommand():
        meleeAimDirSet = false;
        meleeAimDirX = 0;
        meleeAimDirY = 0;
      case CastPressedCommand():
        castPressed = true;
      case RangedAimDirCommand(:final x, :final y):
        rangedAimDirSet = true;
        rangedAimDirX = x;
        rangedAimDirY = y;
      case ClearRangedAimDirCommand():
        rangedAimDirSet = false;
        rangedAimDirX = 0;
        rangedAimDirY = 0;
      case RangedPressedCommand():
        rangedPressed = true;
    }
  }

  /// Resets all fields to their default (idle) state.
  ///
  /// Call this to reuse the frame for a new tick without allocating a new object.
  void reset() {
    moveAxis = 0;
    jumpPressed = false;
    dashPressed = false;
    strikePressed = false;
    projectileAimDirSet = false;
    projectileAimDirX = 0;
    projectileAimDirY = 0;
    meleeAimDirSet = false;
    meleeAimDirX = 0;
    meleeAimDirY = 0;
    castPressed = false;
    rangedPressed = false;
    rangedAimDirSet = false;
    rangedAimDirX = 0;
    rangedAimDirY = 0;
  }
}
