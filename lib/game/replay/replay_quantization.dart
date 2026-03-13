import 'package:run_protocol/replay_blob.dart';

/// Shared analog quantization for live input and replay recording.
///
/// Runtime play and replay capture must use the same policy to avoid divergent
/// command streams caused by tiny floating-point noise.
class ReplayQuantization {
  const ReplayQuantization._();

  static const double _scale = 256.0;

  static double quantizeMoveAxis(double value) {
    return _quantize(value.clamp(-1.0, 1.0).toDouble());
  }

  static double quantizeAimComponent(double value) {
    return _quantize(value.clamp(-1.0, 1.0).toDouble());
  }

  static ReplayCommandFrameV1 quantizeFrame(ReplayCommandFrameV1 frame) {
    return ReplayCommandFrameV1(
      tick: frame.tick,
      moveAxis: frame.moveAxis == null
          ? null
          : quantizeMoveAxis(frame.moveAxis!),
      aimDirX: frame.aimDirX == null ? null : quantizeAimComponent(frame.aimDirX!),
      aimDirY: frame.aimDirY == null ? null : quantizeAimComponent(frame.aimDirY!),
      pressedMask: frame.pressedMask,
      abilitySlotHeldChangedMask: frame.abilitySlotHeldChangedMask,
      abilitySlotHeldValueMask: frame.abilitySlotHeldValueMask,
    );
  }

  static double _quantize(double value) {
    if (value == 0) return 0;
    final quantized = (value * _scale).roundToDouble() / _scale;
    // Collapse signed zero to canonical zero.
    return quantized == 0 ? 0 : quantized;
  }
}
