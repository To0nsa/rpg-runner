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
  bool projectileAimDirSet = false;
  double projectileAimDirX = 0;
  double projectileAimDirY = 0;
  bool meleeAimDirSet = false;
  double meleeAimDirX = 0;
  double meleeAimDirY = 0;
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
    }
  }

  void reset() {
    moveAxis = 0;
    jumpPressed = false;
    dashPressed = false;
    attackPressed = false;
    projectileAimDirSet = false;
    projectileAimDirX = 0;
    projectileAimDirY = 0;
    meleeAimDirSet = false;
    meleeAimDirX = 0;
    meleeAimDirY = 0;
    castPressed = false;
  }
}
