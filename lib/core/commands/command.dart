/// Core input command model for the deterministic simulation.
///
/// Commands represent discrete user inputs scheduled for a specific simulation tick.
/// To ensure determinism, the UI must schedule commands in advance (via `GameController.enqueue`),
/// and the Core processes them only when the simulation clock reaches the specified [tick].
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

/// Continuous projectile aim direction for the given tick.
///
/// The direction should be normalized (or near-normalized). It is expressed in
/// world space and used by casting/abilities.
final class ProjectileAimDirCommand extends Command {
  const ProjectileAimDirCommand({required super.tick, required this.x, required this.y});

  final double x;
  final double y;
}

/// Continuous melee aim direction for the given tick.
///
/// The direction should be normalized (or near-normalized). It is expressed in
/// world space and used by melee attacks.
final class MeleeAimDirCommand extends Command {
  const MeleeAimDirCommand({
    required super.tick,
    required this.x,
    required this.y,
  });

  final double x;
  final double y;
}

/// Clears any held projectile aim direction for the given tick.
///
/// This exists so input schedulers that pre-buffer future ticks can overwrite
/// previously-scheduled aim commands when the player releases aim input.
final class ClearProjectileAimDirCommand extends Command {
  const ClearProjectileAimDirCommand({required super.tick});
}

/// Clears any held melee aim direction for the given tick.
final class ClearMeleeAimDirCommand extends Command {
  const ClearMeleeAimDirCommand({required super.tick});
}

/// One-shot cast press event for the given tick.
final class CastPressedCommand extends Command {
  const CastPressedCommand({required super.tick});
}
