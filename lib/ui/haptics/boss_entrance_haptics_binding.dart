import '../../game/feedback/boss_entrance_feedback.dart';
import '../../game/game_controller.dart';
import 'haptics_cue.dart';
import 'haptics_service.dart';

/// Run-owned platform feedback; disposal fences old runs and widget retries.
final class BossEntranceHapticsBinding {
  BossEntranceHapticsBinding({
    required this.controller,
    required this.haptics,
  }) {
    controller.addListener(_synchronize);
    _synchronize();
  }
  final GameController controller;
  final UiHaptics haptics;
  final _pulses = BossEntrancePulseTracker();
  bool _disposed = false;

  void _synchronize() {
    if (_disposed || controller.snapshot.paused) return;
    final snapshot = controller.snapshot;
    final frame = BossEntranceFeedbackFrame.sample(
      arena: snapshot.bossArena,
      tick: snapshot.tick,
      tickHz: controller.tickHz,
    );
    if (_pulses.consume(frame)) haptics.trigger(UiHapticsCue.bossEntrancePulse);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    controller.removeListener(_synchronize);
  }
}
