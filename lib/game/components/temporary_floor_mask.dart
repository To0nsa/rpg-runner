import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import '../game_controller.dart';
import '../spatial/world_view_transform.dart';
import '../util/math_util.dart' as math;

/// Temporary legacy black backdrop mask from floor level downward.
///
/// Staged polygon terrain suppresses this mask so it cannot cover polygon gaps
/// or slopes. Keep it only for anonymous legacy sources during cutover.
class TemporaryFloorMask extends Component with HasGameReference<FlameGame> {
  TemporaryFloorMask({
    required this.controller,
    required this.virtualWidth,
    required this.virtualHeight,
  });

  final GameController controller;
  final int virtualWidth;
  final int virtualHeight;

  final Paint _paint = Paint()..color = const Color(0xFF000000);

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (controller.snapshot.stagedTerrainRenderSnapshot != null) return;

    final surfaces = controller.snapshot.groundSurfaces;
    if (surfaces.isEmpty) {
      return;
    }

    var floorTopY = surfaces.first.topY;
    for (final surface in surfaces) {
      if (surface.topY > floorTopY) {
        floorTopY = surface.topY;
      }
    }

    final camX = -game.camera.viewfinder.transform.offset.x;
    final camY = -game.camera.viewfinder.transform.offset.y;
    final transform = WorldViewTransform(
      cameraCenterX: camX,
      cameraCenterY: camY,
      viewWidth: virtualWidth.toDouble(),
      viewHeight: virtualHeight.toDouble(),
    );

    final maskTopY = math.roundToPixels(transform.worldToViewY(floorTopY));
    final clampedTopY = maskTopY.clamp(0.0, virtualHeight.toDouble());
    if (clampedTopY >= virtualHeight.toDouble()) {
      return;
    }

    canvas.drawRect(
      Rect.fromLTWH(
        0.0,
        clampedTopY,
        virtualWidth.toDouble(),
        virtualHeight.toDouble() - clampedTopY,
      ),
      _paint,
    );
  }
}
