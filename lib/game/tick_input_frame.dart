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

  /// True if projectile slot was pressed this tick.
  bool projectilePressed = false;

  /// True if secondary slot was pressed this tick.
  bool secondaryPressed = false;

  /// True if bonus slot was pressed this tick.
  bool bonusPressed = false;

  /// Bitmask of slot hold changes authored for this tick.
  ///
  /// Bit `1 << slot.index` indicates that [AbilitySlotHeldCommand] was
  /// provided for that slot in this frame.
  int abilitySlotHeldChangedMask = 0;

  /// Bitmask of slot held values for changed slots.
  ///
  /// For any bit set in [abilitySlotHeldChangedMask], this mask stores whether
  /// the slot should be held (`1`) or released (`0`).
  int abilitySlotHeldValueMask = 0;

  // ─────────────────────────────────────────────────────────────────────────
  // Global aim direction
  // ─────────────────────────────────────────────────────────────────────────

  /// Whether an aim direction is set for this tick.
  bool aimDirSet = false;

  /// Aim X component (only valid if [aimDirSet] is true).
  double aimDirX = 0;

  /// Aim Y component (only valid if [aimDirSet] is true).
  double aimDirY = 0;

  // ─────────────────────────────────────────────────────────────────────────
  /// Applies a [Command] to this frame, merging it with existing state.
  ///
  /// For continuous inputs (move axis, aim), later commands overwrite earlier ones.
  /// Slot hold edges are merged as bitmasks where later commands for the same
  /// slot overwrite earlier ones.
  /// For edge-triggered inputs (jump, dash, strike, projectile), any press sets the flag.
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
      case AimDirCommand(:final x, :final y):
        aimDirSet = true;
        aimDirX = x;
        aimDirY = y;
      case ClearAimDirCommand():
        aimDirSet = false;
        aimDirX = 0;
        aimDirY = 0;
      case ProjectilePressedCommand():
        projectilePressed = true;
      case SecondaryPressedCommand():
        secondaryPressed = true;
      case BonusPressedCommand():
        bonusPressed = true;
      case AbilitySlotHeldCommand(:final slot, :final held):
        final bit = 1 << slot.index;
        abilitySlotHeldChangedMask |= bit;
        if (held) {
          abilitySlotHeldValueMask |= bit;
        } else {
          abilitySlotHeldValueMask &= ~bit;
        }
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
    aimDirSet = false;
    aimDirX = 0;
    aimDirY = 0;
    projectilePressed = false;
    secondaryPressed = false;
    bonusPressed = false;
    abilitySlotHeldChangedMask = 0;
    abilitySlotHeldValueMask = 0;
  }
}
