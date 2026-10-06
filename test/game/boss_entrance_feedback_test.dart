import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/feedback/boss_entrance_feedback.dart';
import 'package:rpg_runner/game/runner_flame/boss_entrance_camera_feedback.dart';
import 'package:runner_core/snapshots/boss_arena_snapshot.dart';

BossArenaSnapshot _arena({
  int start = 100,
  int duration = 70,
  String id = 'any_boss',
  BossArenaPhase phase = BossArenaPhase.introduction,
}) => BossArenaSnapshot(
  id: id,
  phase: phase,
  minX: 24,
  maxX: 576,
  hp100: 100,
  hpMax100: 100,
  entrance: BossEntranceSnapshot(startTick: start, durationTicks: duration),
);

void main() {
  for (final hz in [30, 60, 90]) {
    for (final id in ['forest_bringer', 'future_boss']) {
      test(
        '$id $hz Hz has three deduplicated pulses on the entrance clock',
        () {
          final duration = id == 'future_boss'
              ? hz * 2
              : 10 * (.12 * hz).round();
          final arena = _arena(duration: duration, id: id);
          final tracker = BossEntrancePulseTracker();
          final emitted = <int>[];
          for (var tick = 100; tick < 100 + duration; tick++) {
            final frame = BossEntranceFeedbackFrame.sample(
              arena: arena,
              tick: tick,
              tickHz: hz,
            );
            if (tracker.consume(frame)) {
              emitted.add(frame.pulseKey!.pulseIndex);
              expect(frame.vignetteIntensity, 1);
            }
            expect(tracker.consume(frame), isFalse);
          }
          expect(emitted, [0, 1, 2]);
          expect(
            BossEntranceFeedbackFrame.sample(
              arena: arena,
              tick: 100 + duration,
              tickHz: hz,
            ).active,
            isFalse,
          );
          final later = BossEntranceFeedbackFrame.sample(
            arena: _arena(start: 1000, duration: duration, id: id),
            tick: 1000,
            tickHz: hz,
          );
          expect(tracker.consume(later), isTrue);
        },
      );
    }
  }
  test('feedback waits for boss creation and ends with the introduction', () {
    final pending = BossArenaSnapshot(
      id: 'pending',
      phase: BossArenaPhase.introduction,
      minX: 0,
      maxX: 600,
      hp100: 1,
      hpMax100: 1,
    );
    for (final arena in [
      null,
      pending,
      _arena(phase: BossArenaPhase.combat),
      _arena(phase: BossArenaPhase.failed),
    ]) {
      final frame = BossEntranceFeedbackFrame.sample(
        arena: arena,
        tick: 100,
        tickHz: 60,
      );
      expect(frame.active, isFalse);
      expect(frame.vignetteIntensity, 0);
    }
  });
  test(
    'three separate camera shakes clear on combat and remain still on pause',
    () {
      final camera = BossEntranceCameraFeedback();
      final out = Vector2.zero();
      var intervals = 0, wasMoving = false;
      for (var tick = 100; tick < 170; tick++) {
        final frame = BossEntranceFeedbackFrame.sample(
          arena: _arena(),
          tick: tick,
          tickHz: 60,
        );
        camera.sample(frame, 1 / 60, out);
        final moving = out.length2 > 0;
        if (moving && !wasMoving) intervals++;
        wasMoving = moving;
        final held = out.clone();
        camera.sample(frame, 0, out);
        expect(out.x, held.x);
        expect(out.y, held.y);
      }
      expect(intervals, 3);
      camera.sample(BossEntranceFeedbackFrame.inactive, 1 / 60, out);
      expect(out.length2, 0);
    },
  );
}
