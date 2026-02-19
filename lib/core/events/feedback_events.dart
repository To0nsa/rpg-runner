part of 'game_event.dart';

/// Emitted when the player takes a direct combat impact.
///
/// This event is intended for non-authoritative render/UI feedback (camera
/// shake, haptics, edge flash). It is not emitted for status-effect ticks.
class PlayerImpactFeedbackEvent extends GameEvent {
  const PlayerImpactFeedbackEvent({
    required this.tick,
    required this.amount100,
    required this.sourceKind,
  });

  /// Simulation tick when the impact occurred.
  final int tick;

  /// Final damage applied to the player in fixed-point units (`100 == 1.0`).
  final int amount100;

  /// Source category that produced the impact.
  final DeathSourceKind sourceKind;
}
