// Renders a multi-layer parallax background for pixel-art games.
//
// Each layer scrolls at a fraction of the camera movement (controlled by
// `parallaxFactor`), creating depth. Layers are rendered in order, so
// earlier layers appear behind later ones.
//
// The component uses a fixed "virtual" viewport size to maintain pixel-perfect
// rendering regardless of actual screen resolution. Images are tiled horizontally
// and bottom-aligned within the viewport.
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import '../util/math_util.dart';

/// Renders a pixel-perfect, multi-layer parallax background.
///
/// Layers are defined via [PixelParallaxLayerSpec] and rendered back-to-front.
/// Each layer's scroll position is determined by its [PixelParallaxLayerSpec.parallaxFactor]:
/// - `0.0` = static (doesn't move with camera)
/// - `1.0` = moves 1:1 with camera (no parallax effect)
/// - Values between create the classic parallax depth illusion
class PixelParallaxBackdropComponent extends Component
    with HasGameReference<FlameGame> {
  PixelParallaxBackdropComponent({
    required this.virtualWidth,
    required this.virtualHeight,
    required this.layers,
    this.snapScrollToPixels = true,
  });

  /// Width of the virtual viewport in pixels.
  final int virtualWidth;

  /// Height of the virtual viewport in pixels.
  final int virtualHeight;

  /// Layer specifications, rendered in order (index 0 = backmost).
  final List<PixelParallaxLayerSpec> layers;

  /// If true, scroll offsets are rounded to whole pixels for crisp rendering.
  final bool snapScrollToPixels;

  /// Loaded images for each layer (parallel to [layers]).
  late final List<ui.Image> _images;

  /// Previous frame's camera X position (for delta calculation).
  int? _prevCameraLeftX;

  /// Accumulated scroll offset for each layer (in pixels).
  late final List<double> _scroll;

  /// Paint configured for nearest-neighbor (pixel-perfect) filtering.
  final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _images = await Future.wait(
      layers.map((layer) => game.images.load(layer.assetPath)),
    );
    _scroll = List<double>.filled(layers.length, 0);
  }

  /// Updates scroll offsets based on camera movement.
  ///
  /// Each layer's scroll is incremented by `cameraDelta * parallaxFactor`,
  /// then wrapped to avoid floating-point overflow on long play sessions.
  @override
  void update(double dt) {
    super.update(dt);

    final viewWidth = virtualWidth;
    final cameraLeftX =
        (game.camera.viewfinder.position.x - viewWidth / 2).round();

    final prev = _prevCameraLeftX;
    _prevCameraLeftX = cameraLeftX;
    if (prev == null) return; // First frame: just record position, skip scroll.

    final delta = cameraLeftX - prev;
    if (delta == 0) return; // No camera movement, nothing to update.

    for (var i = 0; i < layers.length; i++) {
      _scroll[i] += delta * layers[i].parallaxFactor;
      // Wrap scroll to [0, imageWidth) to prevent overflow.
      _scroll[i] = positiveModDouble(_scroll[i], _images[i].width.toDouble());
    }
  }

  /// Renders all parallax layers, back-to-front.
  ///
  /// Each layer is horizontally tiled and bottom-aligned within the virtual
  /// viewport. The viewport is clipped to prevent overdraw outside bounds.
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
      final y = (viewHeight - imageH).toDouble(); // Bottom-aligned.

      // Optionally snap to whole pixels for crisp pixel-art rendering.
      final scroll =
          snapScrollToPixels ? _scroll[i].roundToDouble() : _scroll[i];
      final offsetPx = -scroll;
      final startX = positiveModDouble(offsetPx, imageW.toDouble());

      // Tile the image across the viewport width.
      for (var x = startX - imageW; x < viewWidth; x += imageW) {
        canvas.drawImage(image, ui.Offset(x, y), _paint);
      }
    }

    canvas.restore();
  }
}

/// Configuration for a single parallax layer.
class PixelParallaxLayerSpec {
  const PixelParallaxLayerSpec({
    required this.assetPath,
    required this.parallaxFactor,
  });

  /// Path to the layer image (relative to assets/images/).
  final String assetPath;

  /// How much this layer scrolls relative to camera movement.
  ///
  /// - `0.0`: Layer is static (sky, distant mountains).
  /// - `0.5`: Layer moves at half camera speed (mid-ground).
  /// - `1.0`: Layer moves 1:1 with camera (no parallax, foreground).
  final double parallaxFactor;
}
