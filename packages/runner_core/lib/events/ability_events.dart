part of 'game_event.dart';

/// Why a hold-to-maintain ability ended automatically.
enum AbilityHoldEndReason {
  /// The authored max hold duration elapsed.
  timeout,

  /// Stamina was depleted while maintaining the hold.
  staminaDepleted,
}

/// Emitted when a hold-to-maintain ability auto-ends.
///
/// UI can use this for feedback (for example, vibration on timeout).
class AbilityHoldEndedEvent extends GameEvent {
  const AbilityHoldEndedEvent({
    required this.tick,
    required this.entity,
    required this.slot,
    required this.abilityId,
    required this.reason,
  });

  /// Simulation tick when the hold ended.
  final int tick;

  /// Entity that owned the hold ability.
  final int entity;

  /// Slot that sourced the ability.
  final AbilitySlot slot;

  /// Ability identifier that ended.
  final AbilityKey abilityId;

  /// Auto-end cause.
  final AbilityHoldEndReason reason;
}

/// Why a charged hold was canceled before commit.
enum AbilityChargeEndReason {
  /// The authored charge hold timeout elapsed.
  timeout,
}

/// Emitted when a charged hold is auto-canceled.
class AbilityChargeEndedEvent extends GameEvent {
  const AbilityChargeEndedEvent({
    required this.tick,
    required this.entity,
    required this.slot,
    required this.abilityId,
    required this.reason,
  });

  /// Simulation tick when the hold was canceled.
  final int tick;

  /// Entity that owned the charge hold.
  final int entity;

  /// Slot that sourced the ability.
  final AbilitySlot slot;

  /// Ability identifier whose hold was canceled.
  final AbilityKey abilityId;

  /// Auto-end cause.
  final AbilityChargeEndReason reason;
}
