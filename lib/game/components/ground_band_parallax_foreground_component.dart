import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../game_controller.dart';
import '../spatial/world_view_transform.dart';
import '../util/math_util.dart';
import 'ground_surface_layout.dart';
import 'pixel_parallax_backdrop_component.dart';

/// Renders parallax foreground layers clipped to ground surface bands.
///
/// This keeps foreground coverage aligned with authoritative Core ground spans,
/// so foreground and floor share the same gaps.
class GroundBandParallaxForegroundComponent extends Component
    with HasGameReference<FlameGame> {
  GroundBandParallaxForegroundComponent({
    required this.controller,
    required this.virtualWidth,
    required this.virtualHeight,
    required this.layers,
    required this.bandFillDepthProvider,
    this.snapScrollToPixels = true,
  });

  /// Snapshot provider.
  final GameController controller;

  /// Fixed virtual viewport width.
  final int virtualWidth;

  /// Fixed virtual viewport height.
  final int virtualHeight;

  /// Foreground layer specifications, rendered in order.
  final List<PixelParallaxLayerSpec> layers;

  /// Provides the same band depth used by ground rendering.
  final double Function() bandFillDepthProvider;

  /// If true, scroll offsets are rounded to whole pixels for crisp rendering.
  final bool snapScrollToPixels;

  late final List<ui.Image> _images;
  late final List<double> _scroll;
  double? _prevCameraLeftX;

  final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _images = await Future.wait(
      layers.map((layer) => game.images.load(layer.assetPath)),
    );
    _scroll = List<double>.filled(layers.length, 0.0);
  }

  @override
  void update(double dt) {
    super.update(dt);

    final viewWidth = virtualWidth.toDouble();
    final camX = -game.camera.viewfinder.transform.offset.x;
    final cameraLeftX = camX - viewWidth * 0.5;

    final prev = _prevCameraLeftX;
    _prevCameraLeftX = cameraLeftX;
    if (prev == null) return;

    final delta = cameraLeftX - prev;
    if (delta == 0.0) return;

    for (var i = 0; i < layers.length; i++) {
      _scroll[i] += delta * layers[i].parallaxFactor;
      _scroll[i] = positiveModDouble(_scroll[i], _images[i].width.toDouble());
    }
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);

    if (layers.isEmpty) return;
    final surfaces = controller.snapshot.groundSurfaces;
    if (surfaces.isEmpty) return;

    final fillDepth = bandFillDepthProvider();
    if (fillDepth <= 0.0 || !fillDepth.isFinite) return;

    final camX = -game.camera.viewfinder.transform.offset.x;
    final camY = -game.camera.viewfinder.transform.offset.y;
    final transform = WorldViewTransform(
      cameraCenterX: camX,
      cameraCenterY: camY,
      viewWidth: virtualWidth.toDouble(),
      viewHeight: virtualHeight.toDouble(),
    );
    final visibleRect = ui.Rect.fromLTRB(
      transform.viewLeftX,
      transform.viewTopY,
      transform.viewRightX,
      transform.viewBottomY,
    );

    final bands = GroundSurfaceLayout.buildVisibleBands(
      surfaces: surfaces,
      visibleWorldRect: visibleRect,
      fillDepth: fillDepth,
    );
    if (bands.isEmpty) return;

    canvas.save();
    canvas.clipRect(
      ui.Rect.fromLTWH(
        0.0,
        0.0,
        virtualWidth.toDouble(),
        virtualHeight.toDouble(),
      ),
    );

    for (final band in bands) {
      final topY = roundToPixels(transform.worldToViewY(band.topY));
      final bottomY = roundToPixels(transform.worldToViewY(band.bottomY));
      if (bottomY <= topY) continue;

      final clipMinX = roundToPixels(transform.worldToViewX(band.minX));
      final clipMaxX = roundToPixels(transform.worldToViewX(band.maxX));
      if (clipMaxX <= clipMinX) continue;

      canvas.save();
      canvas.clipRect(ui.Rect.fromLTRB(clipMinX, topY, clipMaxX, bottomY));

      for (var i = 0; i < layers.length; i++) {
        final image = _images[i];
        final imageW = image.width;
        final imageH = image.height;
        final y = bottomY - imageH.toDouble();

        final scroll = snapScrollToPixels
            ? roundToPixels(_scroll[i])
            : _scroll[i];
        final offsetPx = -scroll;
        final startX = positiveModDouble(offsetPx, imageW.toDouble());

        for (var x = startX - imageW; x < virtualWidth; x += imageW) {
          canvas.drawImage(image, ui.Offset(x, y), _paint);
        }
      }

      canvas.restore();
    }

    canvas.restore();
  }
}
