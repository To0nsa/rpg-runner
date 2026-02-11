import '../abilities/ability_def.dart';

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

/// One-shot strike press event for the given tick.
final class StrikePressedCommand extends Command {
  const StrikePressedCommand({required super.tick});
}

/// One-shot secondary press event for the given tick.
final class SecondaryPressedCommand extends Command {
  const SecondaryPressedCommand({required super.tick});
}

/// Continuous global aim direction for the given tick.
///
/// The direction should be normalized (or near-normalized). It is expressed in
/// world space and consumed by whichever ability commits this tick.
final class AimDirCommand extends Command {
  const AimDirCommand({required super.tick, required this.x, required this.y});

  final double x;
  final double y;
}

/// Clears any held global aim direction for the given tick.
///
/// This exists so input schedulers that pre-buffer future ticks can overwrite
/// previously-scheduled aim commands when the player releases aim input.
final class ClearAimDirCommand extends Command {
  const ClearAimDirCommand({required super.tick});
}

/// One-shot projectile slot press event for the given tick.
///
/// Preferred over spell/ranged-specific presses when using slot-based input.
final class ProjectilePressedCommand extends Command {
  const ProjectilePressedCommand({required super.tick});
}

/// One-shot bonus press event for the given tick.
final class BonusPressedCommand extends Command {
  const BonusPressedCommand({required super.tick});
}

/// Hold-state edge for an ability slot at the given tick.
///
/// Core latches slot hold state until another [AbilitySlotHeldCommand] updates
/// it, so input routers should send this on transitions only:
/// - `held: true` when hold starts
/// - `held: false` when hold ends
final class AbilitySlotHeldCommand extends Command {
  const AbilitySlotHeldCommand({
    required super.tick,
    required this.slot,
    required this.held,
  });

  final AbilitySlot slot;
  final bool held;
}
