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
