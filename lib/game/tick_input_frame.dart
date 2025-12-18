import '../core/commands/command.dart';

/// Aggregated per-tick input for the simulation.
///
/// This replaces `List<Command>` buffering for a given tick to avoid duplicate
/// commands (e.g. multiple MoveAxis updates for the same tick).
class TickInputFrame {
  double moveAxis = 0;
  bool jumpPressed = false;
  bool dashPressed = false;
  bool attackPressed = false;
  bool aimDirSet = false;
  double aimDirX = 0;
  double aimDirY = 0;
  bool castPressed = false;

  void apply(Command command) {
    switch (command) {
      case MoveAxisCommand(:final axis):
        moveAxis = axis.clamp(-1.0, 1.0);
      case JumpPressedCommand():
        jumpPressed = true;
      case DashPressedCommand():
        dashPressed = true;
      case AttackPressedCommand():
        attackPressed = true;
      case AimDirCommand(:final x, :final y):
        aimDirSet = true;
        aimDirX = x;
        aimDirY = y;
      case CastPressedCommand():
        castPressed = true;
    }
  }

  void reset() {
    moveAxis = 0;
    jumpPressed = false;
    dashPressed = false;
    attackPressed = false;
    aimDirSet = false;
    aimDirX = 0;
    aimDirY = 0;
    castPressed = false;
  }
}
