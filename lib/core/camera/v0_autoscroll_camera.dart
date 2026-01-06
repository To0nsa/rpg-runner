import '../util/smoothing.dart';
import '../util/double_math.dart';
import '../tuning/v0_camera_tuning.dart';

class V0CameraState {
  const V0CameraState({
    required this.centerX,
    required this.targetX,
    required this.speedX,
  });

  /// Current visual center X of the camera view.
  final double centerX;

  /// The "ideal" center position the camera is trying to reach.
  /// This leads [centerX] and pulls it forward via smoothing.
  final double targetX;

  /// Current scroll speed (pixels/second).
  final double speedX;

  /// Creates a copy with updated fields.
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

  /// The X coordinate where the player starts pushing the camera forward.
  ///
  /// Calculated as a ratio of the viewport width from the left edge.
  double followThresholdX() => left() + _tuning.followThresholdRatio * viewWidth;

  /// Advances camera simulation by [dtSeconds].
  ///
  /// [playerX] is nullable to handle cases where the player is dead or despawned.
  void updateTick({
    required double dtSeconds,
    required double? playerX,
  }) {
    final t = _tuning;

    // 1. Update base scroll speed (accelerate/decelerate towards target speed).
    var speedX = _state.speedX;
    if (speedX < t.targetSpeedX) {
      speedX = clampDouble(speedX + t.accelX * dtSeconds, 0.0, t.targetSpeedX);
    } else if (speedX > t.targetSpeedX) {
      speedX = clampDouble(speedX - t.accelX * dtSeconds, t.targetSpeedX, speedX);
    }

    // 2. Integrate target position based on speed.
    var targetX = _state.targetX + speedX * dtSeconds;

    // 3. Player catch-up logic.
    // If the player pushes past the threshold, the target point is pulled forward.
    // This allows the player to run faster than the scroll speed without staying
    // pinned to the edge (camera speeds up to catch them).
    if (playerX != null) {
      final threshold = followThresholdX();
      if (playerX > threshold) {
        final alphaT = expSmoothingFactor(t.targetCatchupLerp, dtSeconds);
        final newTarget = targetX + (playerX - targetX) * alphaT;
        targetX = targetX > newTarget ? targetX : newTarget;
      }
    }

    // 4. Smooth the actual camera center towards the target.
    final alpha = expSmoothingFactor(t.catchupLerp, dtSeconds);
    var centerX = _state.centerX + (targetX - _state.centerX) * alpha;

    // 5. Monotonicity clamp: the camera is an auto-scroller, it never goes left.
    if (centerX < _state.centerX) centerX = _state.centerX;
    if (targetX < _state.targetX) targetX = _state.targetX;

    _state = _state.copyWith(centerX: centerX, targetX: targetX, speedX: speedX);
  }
}
