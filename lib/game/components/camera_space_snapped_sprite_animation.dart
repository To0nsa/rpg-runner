import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../util/math_util.dart' as math;

class CameraSpaceSnappedSpriteAnimation
    extends SpriteAnimationComponent
    with HasGameReference<FlameGame> {
  CameraSpaceSnappedSpriteAnimation({
    required SpriteAnimation animation,
    required Vector2 size,
    required this.worldPosX,
    required this.worldPosY,
    Anchor anchor = Anchor.center,
    super.paint,
    super.removeOnFinish = false,
  }) : super(
         animation: null,
         size: size,
         anchor: anchor,
       ) {
    this.animation = animation;
  }

  final double worldPosX;
  final double worldPosY;

  void snapToCamera(Vector2 cameraCenter) {
    position.setValues(
      math.snapWorldToPixelsInCameraSpace1d(worldPosX, cameraCenter.x),
      math.snapWorldToPixelsInCameraSpace1d(worldPosY, cameraCenter.y),
    );
  }

  @override
  void update(double dt) {
    snapToCamera(game.camera.viewfinder.position);
    super.update(dt);
  }
}
