import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../util/math_util.dart';

/// World-space ground band placeholder (visual reference for Milestone 1).
///
/// This draws `Field Layer 09.png` as a horizontally tiled strip in *world
/// coordinates* so it naturally moves 1.0× with the camera.
///
/// Collision is handled later in Core (Milestone 2). For now, this provides a
/// stable visual ground reference for camera + pixel-perfect sanity checks.
class TiledGroundBandComponent extends Component
    with HasGameReference<FlameGame> {
  TiledGroundBandComponent({
    required this.assetPath,
    this.virtualWidth,
    required this.virtualHeight,
    this.renderInBackdrop = false,
  }) {
    if (renderInBackdrop && virtualWidth == null) {
      throw ArgumentError(
        'virtualWidth is required when renderInBackdrop is true',
      );
    }
  }

  final String assetPath;
  final int? virtualWidth;
  final int virtualHeight;
  final bool renderInBackdrop;

  late final ui.Image _image;
  final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _image = await game.images.load(assetPath);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);

    if (renderInBackdrop) {
      final viewWidth = virtualWidth!;

      final tileW = _image.width;
      final tileH = _image.height;
      final y = (virtualHeight - tileH).toDouble(); // bottom aligned

      final cameraLeftX =
          (game.camera.viewfinder.position.x - viewWidth / 2);
      final offsetPx = -cameraLeftX;
      final startX = positiveModDouble(offsetPx, tileW.toDouble());

      canvas.save();
      canvas.clipRect(
        ui.Rect.fromLTWH(0, 0, viewWidth.toDouble(), virtualHeight.toDouble()),
      );

      for (var x = startX - tileW; x < viewWidth; x += tileW) {
        canvas.drawImage(_image, ui.Offset(x, y), _paint);
      }

      canvas.restore();
      return;
    }

    final visible = game.camera.visibleWorldRect;

    final tileW = _image.width;
    final tileH = _image.height;
    final y = (virtualHeight - tileH).toDouble(); // bottom aligned to viewport

    final left = visible.left.floor();
    final right = visible.right.ceil();

    final startTile = _floorDiv(left, tileW) - 1;
    final endTile = _floorDiv(right, tileW) + 1;

    for (var tile = startTile; tile <= endTile; tile++) {
      final x = (tile * tileW).toDouble();
      canvas.drawImage(_image, ui.Offset(x, y), _paint);
    }
  }

  int _floorDiv(int a, int b) {
    if (b <= 0) throw ArgumentError.value(b, 'b', 'must be > 0');
    if (a >= 0) return a ~/ b;
    return -(((-a) + b - 1) ~/ b);
  }
}
