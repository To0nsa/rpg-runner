import '../util/smoothing.dart';
import '../util/double_math.dart';
import '../tuning/camera_tuning.dart';

class CameraState {
  const CameraState({
    required this.centerX,
    required this.targetX,
    required this.centerY,
    required this.targetY,
    required this.speedX,
  });

  /// Current visual center X of the camera view.
  final double centerX;

  /// The "ideal" center position the camera is trying to reach.
  /// This leads [centerX] and pulls it forward via smoothing.
  final double targetX;

  /// Current visual center Y of the camera view.
  final double centerY;

  /// The "ideal" Y center the camera is trying to reach.
  final double targetY;

  /// Current scroll speed (pixels/second).
  final double speedX;

  /// Creates a copy with updated fields.
  CameraState copyWith({
    double? centerX,
    double? targetX,
    double? centerY,
    double? targetY,
    double? speedX,
  }) {
    return CameraState(
      centerX: centerX ?? this.centerX,
      targetX: targetX ?? this.targetX,
      centerY: centerY ?? this.centerY,
      targetY: targetY ?? this.targetY,
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
class AutoscrollCamera {
  AutoscrollCamera({
    required this.viewWidth,
    required this.viewHeight,
    required CameraTuningDerived tuning,
    required CameraState initial,
  }) : _tuning = tuning,
       _state = initial;

  final double viewWidth;
  final double viewHeight;
  final CameraTuningDerived _tuning;

  CameraState get state => _state;
  CameraState _state;

  double left() => _state.centerX - viewWidth * 0.5;
  double right() => _state.centerX + viewWidth * 0.5;
  double top() => _state.centerY - viewHeight * 0.5;
  double bottom() => _state.centerY + viewHeight * 0.5;

  /// The X coordinate where the player starts pushing the camera forward.
  ///
  /// Calculated from the viewport's left edge with:
  /// `thresholdX = left() + followThresholdRatio * viewWidth`.
  ///
  /// The camera only applies pull-forward when `playerRightX > thresholdX`.
  double followThresholdX() =>
      left() + _tuning.followThresholdRatio * viewWidth;

  /// Advances camera simulation by [dtSeconds].
  ///
  /// [playerRightX]/[playerY] are nullable to handle cases where the player is
  /// dead or despawned.
  ///
  /// [playerRightX] must be the collider/front-right X used by run-end
  /// behind-camera checks so camera pull and failure rules share one reference
  /// point.
  void updateTick({
    required double dtSeconds,
    required double? playerRightX,
    required double? playerY,
  }) {
    final t = _tuning;

    // 1. Update base scroll speed (accelerate/decelerate towards target speed).
    var speedX = _state.speedX;
    if (speedX < t.targetSpeedX) {
      speedX = clampDouble(speedX + t.accelX * dtSeconds, 0.0, t.targetSpeedX);
    } else if (speedX > t.targetSpeedX) {
      speedX = clampDouble(
        speedX - t.accelX * dtSeconds,
        t.targetSpeedX,
        speedX,
      );
    }

    // 2. Integrate target position based on speed.
    var targetX = _state.targetX + speedX * dtSeconds;

    // 3. Player catch-up logic.
    // If the player pushes past the threshold, the target point is pulled forward.
    // This allows the player to run faster than the scroll speed without staying
    // pinned to the edge (camera speeds up to catch them).
    if (playerRightX != null) {
      final threshold = followThresholdX();
      if (playerRightX > threshold) {
        final alphaT = expSmoothingFactor(t.targetCatchupLerp, dtSeconds);
        final newTarget = targetX + (playerRightX - targetX) * alphaT;
        targetX = targetX > newTarget ? targetX : newTarget;
      }
    }

    // 4. Smooth the actual camera center towards the target.
    final alpha = expSmoothingFactor(t.catchupLerp, dtSeconds);
    var centerX = _state.centerX + (targetX - _state.centerX) * alpha;

    // 5. Monotonicity clamp: the camera is an auto-scroller, it never goes left.
    if (centerX < _state.centerX) centerX = _state.centerX;
    if (targetX < _state.targetX) targetX = _state.targetX;

    var targetY = _state.targetY;
    var centerY = _state.centerY;
    if (t.verticalMode == CameraVerticalMode.followPlayer && playerY != null) {
      final deadZone = t.verticalDeadZone < 0 ? 0.0 : t.verticalDeadZone;
      var desiredTargetY = targetY;
      final deltaY = playerY - targetY;
      if (deltaY > deadZone) {
        desiredTargetY = playerY - deadZone;
      } else if (deltaY < -deadZone) {
        desiredTargetY = playerY + deadZone;
      }
      final alphaTargetY = expSmoothingFactor(
        t.verticalTargetCatchupLerp,
        dtSeconds,
      );
      targetY = targetY + (desiredTargetY - targetY) * alphaTargetY;
      final alphaCenterY = expSmoothingFactor(t.verticalCatchupLerp, dtSeconds);
      centerY = centerY + (targetY - centerY) * alphaCenterY;
    }

    _state = _state.copyWith(
      centerX: centerX,
      targetX: targetX,
      centerY: centerY,
      targetY: targetY,
      speedX: speedX,
    );
  }
}
