import '../util/double_math.dart';
import '../util/smoothing.dart';
import 'autoscroll_camera.dart' show CameraState, CameraView;

/// Fixed-tick horizontal following for a bounded, freely revisitable world.
///
/// Y remains at the authored framing. A world narrower than the viewport is
/// centered. This policy never scrolls on its own and does not constrain actor
/// movement; physical world bounds remain a separate simulation responsibility.
final class FiniteFollowCamera implements CameraView {
  FiniteFollowCamera({
    required this.worldLeft,
    required this.worldRight,
    required this.viewWidth,
    required this.viewHeight,
    required double centerY,
    required double playerX,
    this.followRate = 8,
  }) {
    if (!worldLeft.isFinite ||
        !worldRight.isFinite ||
        worldLeft >= worldRight ||
        !(worldRight - worldLeft).isFinite ||
        !viewWidth.isFinite ||
        viewWidth <= 0 ||
        !viewHeight.isFinite ||
        viewHeight <= 0 ||
        !centerY.isFinite ||
        !playerX.isFinite ||
        !followRate.isFinite ||
        followRate <= 0) {
      throw ArgumentError(
        'Camera bounds, dimensions and follow rate are invalid.',
      );
    }
    final initialX = _clampCenter(playerX);
    _state = CameraState(
      centerX: initialX,
      targetX: initialX,
      centerY: centerY,
      targetY: centerY,
      speedX: 0,
    );
  }

  final double worldLeft;
  final double worldRight;
  final double viewWidth;
  final double viewHeight;
  final double followRate;
  late CameraState _state;
  @override
  CameraState get state => _state;

  @override
  double left() => _state.centerX - viewWidth / 2;
  @override
  double right() => _state.centerX + viewWidth / 2;
  @override
  double top() => _state.centerY - viewHeight / 2;
  @override
  double bottom() => _state.centerY + viewHeight / 2;

  /// [playerX] is the body center in world units; null freezes the camera.
  /// [dtSeconds] comes from the simulation tick rate, never a render delta.
  void updateTick({
    required double dtSeconds,
    required double? playerX,
    double? frameCenterX,
    double? frameCenterY,
  }) {
    if (!dtSeconds.isFinite || dtSeconds <= 0) {
      throw ArgumentError.value(dtSeconds, 'dtSeconds', 'Must be positive.');
    }
    if (playerX != null && !playerX.isFinite) {
      throw ArgumentError.value(playerX, 'playerX', 'Must be finite.');
    }
    if ((frameCenterX != null &&
            (!frameCenterX.isFinite ||
                _clampCenter(frameCenterX) != frameCenterX)) ||
        (frameCenterY != null && !frameCenterY.isFinite)) {
      throw ArgumentError('Arena framing must fit the finite world.');
    }
    final targetX =
        frameCenterX ??
        (playerX == null ? _state.centerX : _clampCenter(playerX));
    var centerX = _clampCenter(
      _state.centerX +
          (targetX - _state.centerX) *
              expSmoothingFactor(followRate, dtSeconds),
    );
    // Arena introduction needs an exact framing tick, never an asymptote.
    if (frameCenterX != null && (centerX - frameCenterX).abs() <= 0.5) {
      centerX = frameCenterX;
    }
    _state = _state.copyWith(
      centerX: centerX,
      targetX: targetX,
      speedX: (centerX - _state.centerX) / dtSeconds,
      centerY: frameCenterY,
      targetY: frameCenterY,
    );
  }

  double _clampCenter(double x) {
    if (worldRight - worldLeft <= viewWidth) {
      return worldLeft + (worldRight - worldLeft) / 2;
    }
    return clampDouble(
      x,
      worldLeft + viewWidth / 2,
      worldRight - viewWidth / 2,
    );
  }
}
