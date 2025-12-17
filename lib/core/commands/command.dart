/// Core input command model.
///
/// Commands are the only way UI can affect the simulation:
/// UI -> `GameController.enqueue(...)` -> Core applies them at a specific `tick`.
///
/// These command types are intentionally minimal placeholders for Milestone 0.
sealed class Command {
  const Command({required this.tick});

  /// Simulation tick at which this command must be applied.
  final int tick;
}

/// Player movement input for the given tick.
///
/// `axis` is typically in `[-1, 1]` (left/right), originating from a joystick.
final class MoveAxisCommand extends Command {
  const MoveAxisCommand({required super.tick, required this.axis});

  /// Horizontal movement axis, usually in `[-1, 1]`.
  final double axis;
}

/// One-shot jump press event for the given tick.
final class JumpPressedCommand extends Command {
  const JumpPressedCommand({required super.tick});
}

/// One-shot dash press event for the given tick.
final class DashPressedCommand extends Command {
  const DashPressedCommand({required super.tick});
}

/// One-shot attack press event for the given tick.
final class AttackPressedCommand extends Command {
  const AttackPressedCommand({required super.tick});
}
