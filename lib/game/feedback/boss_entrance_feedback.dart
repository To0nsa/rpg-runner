import 'package:runner_core/snapshots/boss_arena_snapshot.dart';

/// Shared presentation sampled from Core's entrance clock, independent of boss art.
final class BossEntranceFeedbackFrame {
  const BossEntranceFeedbackFrame._({
    this.pulseKey,
    this.vignetteIntensity = 0,
  });
  static const inactive = BossEntranceFeedbackFrame._();
  static const pulseCount = 3;
  static const pulseDurationSeconds = .34;
  static const shakeIntensity01 = .55;

  /// Start tick distinguishes repeated occurrences of the same authored arena.
  final ({int startTick, int pulseIndex})? pulseKey;
  final double vignetteIntensity;
  bool get active => pulseKey != null;

  static BossEntranceFeedbackFrame sample({
    required BossArenaSnapshot? arena,
    required int tick,
    required int tickHz,
  }) {
    if (arena?.phase != BossArenaPhase.introduction) return inactive;
    final entrance = arena!.entrance;
    if (entrance == null || entrance.durationTicks <= 0 || tickHz <= 0) {
      return inactive;
    }
    final age = tick - entrance.startTick;
    if (age < 0 || age >= entrance.durationTicks) return inactive;
    final pulseIndex = age * pulseCount ~/ entrance.durationTicks;
    final pulseStart =
        (entrance.durationTicks * pulseIndex + pulseCount - 1) ~/ pulseCount;
    final progress = ((age - pulseStart) / tickHz / pulseDurationSeconds).clamp(
      0.0,
      1.0,
    );
    final remaining = 1.0 - progress;
    return BossEntranceFeedbackFrame._(
      pulseKey: (startTick: entrance.startTick, pulseIndex: pulseIndex),
      vignetteIntensity: remaining * remaining * remaining,
    );
  }
}

/// Per-consumer deduplication; pause/repeated samples cannot retrigger a pulse.
final class BossEntrancePulseTracker {
  ({int startTick, int pulseIndex})? _last;
  bool consume(BossEntranceFeedbackFrame frame) {
    final key = frame.pulseKey;
    if (key == null || key == _last) return false;
    _last = key;
    return true;
  }
}
