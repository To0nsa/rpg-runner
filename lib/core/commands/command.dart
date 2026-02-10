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

/// Continuous projectile aim direction for the given tick.
///
/// The direction should be normalized (or near-normalized). It is expressed in
/// world space and used by casting/abilities.
final class ProjectileAimDirCommand extends Command {
  const ProjectileAimDirCommand({
    required super.tick,
    required this.x,
    required this.y,
  });

  final double x;
  final double y;
}

/// Charge hold duration for projectile-style commit abilities.
///
/// The value is expressed in simulation ticks of the current runtime tick rate
/// (not fixed 60 Hz authoring ticks). It is resolved by Core at commit time
/// and used for deterministic tier selection.
final class ProjectileChargeTicksCommand extends Command {
  const ProjectileChargeTicksCommand({
    required super.tick,
    required this.chargeTicks,
  });

  final int chargeTicks;
}

/// Continuous melee aim direction for the given tick.
///
/// The direction should be normalized (or near-normalized). It is expressed in
/// world space and used by melee strikes.
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

/// Continuous hold state for an ability slot at the given tick.
///
/// This is used for "hold-to-maintain" abilities (for example, shield block).
/// Input routers should schedule this continuously while held and send
/// `held: false` commands when releasing to overwrite already-buffered ticks.
final class AbilitySlotHeldCommand extends Command {
  const AbilitySlotHeldCommand({
    required super.tick,
    required this.slot,
    required this.held,
  });

  final AbilitySlot slot;
  final bool held;
}
