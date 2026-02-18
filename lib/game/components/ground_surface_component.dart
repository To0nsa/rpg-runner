import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../game_controller.dart';
import '../spatial/world_view_transform.dart';
import '../util/math_util.dart';
import 'ground_surface_layout.dart';

/// Renders Core-authored ground surfaces using a tiled texture material.
///
/// This component consumes `snapshot.groundSurfaces` and aligns the visual top
/// edge to authoritative surface `topY`. Collision/geometry remains Core-owned.
class GroundSurfaceComponent extends Component
    with HasGameReference<FlameGame> {
  GroundSurfaceComponent({
    required this.assetPath,
    required this.controller,
    required this.virtualWidth,
    required this.virtualHeight,
  });

  /// Path to the ground texture asset used as material fill.
  final String assetPath;

  /// Snapshot provider.
  final GameController controller;

  /// Fixed virtual viewport width.
  final int virtualWidth;

  /// Fixed virtual viewport height.
  final int virtualHeight;

  late final ui.Image _image;
  late final ui.Rect _materialSrcRect;
  late final double _materialHeight;

  final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  static const int _alphaOpaqueThreshold = 1;
  static const double _rowCoverageThreshold = 0.20;
  static const double _fallbackMaterialHeight = 16.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _image = await game.images.load(assetPath);
    final materialTopY = await _detectMaterialTopRow(_image);
    final srcHeight = (_image.height - materialTopY).toDouble().clamp(
      1.0,
      _image.height.toDouble(),
    );
    _materialSrcRect = ui.Rect.fromLTWH(
      0.0,
      materialTopY.toDouble(),
      _image.width.toDouble(),
      srcHeight,
    );
    _materialHeight = _materialSrcRect.height;
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);

    final surfaces = controller.snapshot.groundSurfaces;
    if (surfaces.isEmpty) return;

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
      fillDepth: _materialHeight,
    );
    if (bands.isEmpty) return;

    final tileWidth = _image.width;
    final viewClipRect = ui.Rect.fromLTWH(
      0.0,
      0.0,
      virtualWidth.toDouble(),
      virtualHeight.toDouble(),
    );

    canvas.save();
    canvas.clipRect(viewClipRect);

    for (final band in bands) {
      final topY = roundToPixels(transform.worldToViewY(band.topY));
      final bottomY = roundToPixels(transform.worldToViewY(band.bottomY));
      if (bottomY <= topY) continue;

      final clipMinX = roundToPixels(transform.worldToViewX(band.minX));
      final clipMaxX = roundToPixels(transform.worldToViewX(band.maxX));
      if (clipMaxX <= clipMinX) continue;

      final startTile = floorDivInt(band.minX.floor(), tileWidth) - 1;
      final endTile = floorDivInt(band.maxX.ceil(), tileWidth) + 1;

      canvas.save();
      canvas.clipRect(ui.Rect.fromLTRB(clipMinX, topY, clipMaxX, bottomY));

      for (var tile = startTile; tile <= endTile; tile += 1) {
        final tileWorldX = (tile * tileWidth).toDouble();
        final tileViewX = roundToPixels(transform.worldToViewX(tileWorldX));
        final dstRect = ui.Rect.fromLTRB(
          tileViewX,
          topY,
          tileViewX + tileWidth,
          bottomY,
        );
        canvas.drawImageRect(_image, _materialSrcRect, dstRect, _paint);
      }

      canvas.restore();
    }

    canvas.restore();
  }

  Future<int> _detectMaterialTopRow(ui.Image image) async {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) return _fallbackMaterialTopRow(image.height);

    final rgba = bytes.buffer.asUint8List();
    final width = image.width;
    final height = image.height;
    final minOpaquePixels = (width * _rowCoverageThreshold).ceil();
    int? firstOpaqueRow;
    for (var y = 0; y < height; y += 1) {
      final rowOffset = y * width * 4;
      var opaqueCount = 0;
      for (var x = 0; x < width; x += 1) {
        final alpha = rgba[rowOffset + x * 4 + 3];
        if (alpha >= _alphaOpaqueThreshold) {
          firstOpaqueRow ??= y;
          opaqueCount += 1;
          if (opaqueCount >= minOpaquePixels) {
            return y;
          }
        }
      }
    }

    if (firstOpaqueRow != null) return firstOpaqueRow;
    return _fallbackMaterialTopRow(height);
  }

  int _fallbackMaterialTopRow(int imageHeight) {
    final fallbackTop = (imageHeight - _fallbackMaterialHeight).floor();
    if (fallbackTop <= 0) return 0;
    if (fallbackTop >= imageHeight) return imageHeight - 1;
    return fallbackTop;
  }
}
