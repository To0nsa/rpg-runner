import 'dart:math' as dart_math;

import 'package:flame/components.dart';

class CameraShakeController {
  double _elapsedSeconds = 0.0;
  double _durationSeconds = 0.0;
  double _amplitudePixels = 0.0;
  double _seedPhase = 0.0;

  void trigger({required double intensity01}) {
    final clamped = intensity01.clamp(0.0, 1.0);
    if (clamped <= 0.0) {
      return;
    }

    _durationSeconds = _lerp(0.12, 0.24, clamped);
    _amplitudePixels = _lerp(1.5, 5.5, clamped);
    _elapsedSeconds = 0.0;
    _seedPhase += dart_math.pi * 0.31;
  }

  void sample(double dtSeconds, Vector2 out) {
    if (_durationSeconds <= 0.0 || _elapsedSeconds >= _durationSeconds) {
      out.setZero();
      return;
    }

    _elapsedSeconds += dtSeconds;
    if (_elapsedSeconds >= _durationSeconds) {
      out.setZero();
      return;
    }

    final t = _elapsedSeconds / _durationSeconds;
    final damper = (1.0 - t) * (1.0 - t);
    final angle = _seedPhase + (_elapsedSeconds * _oscillationRadPerSecond);
    out.setValues(
      dart_math.sin(angle) * _amplitudePixels * damper,
      dart_math.cos(angle * 1.73) * (_amplitudePixels * 0.65) * damper,
    );
  }

  static const double _oscillationRadPerSecond = 44.0 * 2.0 * dart_math.pi;

  double _lerp(double min, double max, double t) => min + (max - min) * t;
}
