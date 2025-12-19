part of 'game_event.dart';

enum RunEndReason {
  fellBehindCamera,
}

class RunEndedEvent extends GameEvent {
  const RunEndedEvent({
    required this.tick,
    required this.distance,
    required this.reason,
  });

  final int tick;
  final double distance;
  final RunEndReason reason;
}
