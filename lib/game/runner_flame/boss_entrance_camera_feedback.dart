import 'package:flame/components.dart';

import '../feedback/boss_entrance_feedback.dart';
import 'camera_shake_controller.dart';

/// Render-only entrance shake; combat release immediately clears its last pulse.
final class BossEntranceCameraFeedback {
  final _pulses = BossEntrancePulseTracker();
  final _shake = CameraShakeController();

  void reset() => _shake.reset();

  void sample(BossEntranceFeedbackFrame frame, double dtSeconds, Vector2 out) {
    if (!frame.active) {
      reset();
      out.setZero();
      return;
    }
    if (_pulses.consume(frame)) {
      _shake.trigger(intensity01: BossEntranceFeedbackFrame.shakeIntensity01);
    }
    _shake.sample(dtSeconds, out);
  }
}
