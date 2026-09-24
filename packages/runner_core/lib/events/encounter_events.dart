part of 'game_event.dart';

/// One terminal transition emitted by the authoritative encounter controller.
final class EncounterResolvedEvent extends GameEvent {
  const EncounterResolvedEvent({required this.outcome});
  final EncounterOutcome outcome;
}
