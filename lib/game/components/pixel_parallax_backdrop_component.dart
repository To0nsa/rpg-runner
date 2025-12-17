import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../util/math_util.dart';

/// A pixel-art friendly parallax backdrop that enforces integer-pixel motion.
///
/// This component is intended to be mounted under `game.camera.backdrop`, so it
/// renders *behind* the world and is not affected by camera movement (we apply
/// parallax offsets manually based on the camera viewfinder).
///
/// Each layer:
/// - draws at 1:1 (world units == virtual pixels)
/// - uses `FilterQuality.none` (no blur)
/// - can optionally snap scroll offsets to integer pixels (reduces shimmer but
///   produces "steppy" motion on slow layers)
class PixelParallaxBackdropComponent extends Component
    with HasGameReference<FlameGame> {
  PixelParallaxBackdropComponent({
    required this.virtualWidth,
    required this.virtualHeight,
    required this.layers,
    this.snapScrollToPixels = true,
  });

  final int virtualWidth;
  final int virtualHeight;
  final List<PixelParallaxLayerSpec> layers;

  /// When true, each layer's scroll offset is snapped to integer pixels.
  ///
  /// When false, sub-pixel scrolling is allowed (smoother motion) but will
  /// introduce shimmer on pixel art. This is a deliberate tradeoff.
  final bool snapScrollToPixels;

  late final List<ui.Image> _images;
  int? _prevCameraLeftX;
  late final List<double> _scroll;

  final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _images = await Future.wait(
      layers.map((layer) => game.images.load(layer.assetPath)),
    );
    _scroll = List<double>.filled(layers.length, 0);
  }

  @override
  void update(double dt) {
    super.update(dt);

    final viewWidth = virtualWidth;
    final cameraLeftX =
        (game.camera.viewfinder.position.x - viewWidth / 2).round();

    final prev = _prevCameraLeftX;
    _prevCameraLeftX = cameraLeftX;
    if (prev == null) return;

    final delta = cameraLeftX - prev;
    if (delta == 0) return;

    for (var i = 0; i < layers.length; i++) {
      _scroll[i] += delta * layers[i].parallaxFactor;
      _scroll[i] = positiveModDouble(_scroll[i], _images[i].width.toDouble());
    }
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);

    final viewWidth = virtualWidth;
    final viewHeight = virtualHeight;

    canvas.save();
    canvas.clipRect(
      ui.Rect.fromLTWH(0, 0, viewWidth.toDouble(), viewHeight.toDouble()),
    );

    for (var i = 0; i < layers.length; i++) {
      final image = _images[i];

      final imageW = image.width;
      final imageH = image.height;
      final y = (viewHeight - imageH).toDouble(); // bottom-aligned

      final scroll = snapScrollToPixels ? _scroll[i].roundToDouble() : _scroll[i];
      final offsetPx = -scroll;
      final startX = positiveModDouble(offsetPx, imageW.toDouble());

      for (var x = startX - imageW; x < viewWidth; x += imageW) {
        canvas.drawImage(image, ui.Offset(x, y), _paint);
      }
    }

    canvas.restore();
  }
}

/// One parallax layer spec.
class PixelParallaxLayerSpec {
  const PixelParallaxLayerSpec({
    required this.assetPath,
    required this.parallaxFactor,
  });

  final String assetPath;

  /// `0.0` means static background, `1.0` moves with the camera.
  ///
  /// Values are snapped to integer pixels after multiplication.
  final double parallaxFactor;
}
