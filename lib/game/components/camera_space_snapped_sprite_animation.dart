import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../util/math_util.dart' as math;

class CameraSpaceSnappedSpriteAnimation extends SpriteAnimationComponent
    with HasGameReference<FlameGame> {
  CameraSpaceSnappedSpriteAnimation({
    required SpriteAnimation animation,
    required Vector2 size,
    required this.worldPosX,
    required this.worldPosY,
    this.animationTick,
    this.animationStartTick = 0,
    this.tickHz = 60,
    Anchor anchor = Anchor.center,
    super.paint,
    super.removeOnFinish = false,
  }) : super(animation: null, size: size, anchor: anchor) {
    this.animation = animation;
  }

  final double worldPosX;
  final double worldPosY;
  final int Function()? animationTick;
  final int animationStartTick;
  final int tickHz;

  void snapToCamera(Vector2 cameraCenter) {
    position.setValues(
      math.snapWorldToPixelsInCameraSpace1d(worldPosX, cameraCenter.x),
      math.snapWorldToPixelsInCameraSpace1d(worldPosY, cameraCenter.y),
    );
  }

  @override
  void update(double dt) {
    snapToCamera(game.camera.viewfinder.position);
    final clock = animationTick;
    if (clock == null) {
      super.update(dt);
      return;
    }
    super.update(0);
    final frames = animation?.frames;
    final ticker = animationTicker;
    if (frames == null || frames.isEmpty || ticker == null) return;
    var elapsed = clock() - animationStartTick;
    for (var i = 0; i < frames.length; i++) {
      final ticks = (frames[i].stepTime * tickHz).round().clamp(1, 1000000);
      if (elapsed < ticks) {
        ticker.currentIndex = i;
        return;
      }
      elapsed -= ticks;
    }
    if (removeOnFinish) removeFromParent();
  }
}
