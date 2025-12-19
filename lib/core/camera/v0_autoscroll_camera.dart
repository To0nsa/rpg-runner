import '../util/smoothing.dart';
import '../util/double_math.dart';
import '../tuning/v0_camera_tuning.dart';

class V0CameraState {
  const V0CameraState({
    required this.centerX,
    required this.targetX,
    required this.speedX,
  });

  final double centerX;
  final double targetX;
  final double speedX;

  V0CameraState copyWith({
    double? centerX,
    double? targetX,
    double? speedX,
  }) {
    return V0CameraState(
      centerX: centerX ?? this.centerX,
      targetX: targetX ?? this.targetX,
      speedX: speedX ?? this.speedX,
    );
  }
}

/// Deterministic auto-scroll camera (Core).
///
/// Mirrors the reference behavior:
/// - baseline target speed with ease-in acceleration
/// - camera center eases toward a monotonic target X (never moves backward)
/// - player can pull the target forward only after passing a follow threshold
class V0AutoscrollCamera {
  V0AutoscrollCamera({
    required this.viewWidth,
    required V0CameraTuningDerived tuning,
    required V0CameraState initial,
  })  : _tuning = tuning,
        _state = initial;

  final double viewWidth;
  final V0CameraTuningDerived _tuning;

  V0CameraState get state => _state;
  V0CameraState _state;

  double left() => _state.centerX - viewWidth * 0.5;
  double right() => _state.centerX + viewWidth * 0.5;

  double followThresholdX() => left() + _tuning.followThresholdRatio * viewWidth;

  void updateTick({
    required double dtSeconds,
    required double? playerX,
  }) {
    final t = _tuning;

    var speedX = _state.speedX;
    if (speedX < t.targetSpeedX) {
      speedX = clampDouble(speedX + t.accelX * dtSeconds, 0.0, t.targetSpeedX);
    } else if (speedX > t.targetSpeedX) {
      speedX = clampDouble(speedX - t.accelX * dtSeconds, t.targetSpeedX, speedX);
    }

    var targetX = _state.targetX + speedX * dtSeconds;

    // If the player passes the follow threshold, allow the target to drift toward
    // the player (never decreases).
    if (playerX != null) {
      final threshold = followThresholdX();
      if (playerX > threshold) {
        final alphaT = expSmoothingFactor(t.targetCatchupLerp, dtSeconds);
        final newTarget = targetX + (playerX - targetX) * alphaT;
        targetX = targetX > newTarget ? targetX : newTarget;
      }
    }

    final alpha = expSmoothingFactor(t.catchupLerp, dtSeconds);
    var centerX = _state.centerX + (targetX - _state.centerX) * alpha;

    // Determinism/feel: camera never moves backward.
    if (centerX < _state.centerX) centerX = _state.centerX;
    if (targetX < _state.targetX) targetX = _state.targetX;

    _state = _state.copyWith(centerX: centerX, targetX: targetX, speedX: speedX);
  }
}
