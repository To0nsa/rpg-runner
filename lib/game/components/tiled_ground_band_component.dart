// Renders a horizontally-tiled ground band (e.g., grass, dirt, platforms).
//
// Supports two rendering modes:
// - **Backdrop mode** (`renderInBackdrop = true`): Renders in screen-space with
//   a fixed virtual viewport. Used for decorative ground in the parallax stack.
// - **World-space mode** (`renderInBackdrop = false`): Renders tiles in world
//   coordinates, following the camera. Used for gameplay-relevant ground.
//
// **Ground Gaps**: Both modes support "gaps" (holes in the ground) by using
// `BlendMode.clear` to punch transparent regions into the tile strip.
//
// **Performance Note**: When gaps are present, `canvas.saveLayer` is used to
// enable the clear blend mode. This incurs GPU overhead due to offscreen
// rasterization. Scenes with many gaps may see performance impact.
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../../core/snapshots/static_ground_gap_snapshot.dart';
import '../game_controller.dart';
import '../util/math_util.dart';

/// Renders a horizontally-tiled ground band with optional gap support.
///
/// See file header for rendering mode details and performance considerations.
class TiledGroundBandComponent extends Component
    with HasGameReference<FlameGame> {
  TiledGroundBandComponent({
    required this.assetPath,
    required this.controller,
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

  /// Path to the tile image asset (loaded via Flame's image cache).
  final String assetPath;

  /// Game controller providing snapshot data (including ground gaps).
  final GameController controller;

  /// Fixed viewport width for backdrop mode. Required when [renderInBackdrop] is true.
  final int? virtualWidth;

  /// Virtual viewport height; tiles are bottom-aligned to this value.
  final int virtualHeight;

  /// If true, render in screen-space (backdrop); otherwise, render in world-space.
  final bool renderInBackdrop;

  late final ui.Image _image;

  /// Paint with nearest-neighbor filtering for pixel-perfect rendering.
  final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  /// Paint used to "punch holes" for ground gaps.
  final Paint _clearPaint = Paint()..blendMode = ui.BlendMode.clear;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _image = await game.images.load(assetPath);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);

    final gaps = controller.snapshot.groundGaps;
    final tileW = _image.width;
    final tileH = _image.height;
    final y = (virtualHeight - tileH).toDouble(); // bottom-aligned

    if (renderInBackdrop) {
      _renderBackdropMode(canvas, gaps, tileW, tileH, y);
    } else {
      _renderWorldMode(canvas, gaps, tileW, tileH, y);
    }
  }

  /// Renders tiles in screen-space (fixed virtual viewport).
  void _renderBackdropMode(
    ui.Canvas canvas,
    List<StaticGroundGapSnapshot> gaps,
    int tileW,
    int tileH,
    double y,
  ) {
    final viewWidth = virtualWidth!;
    final halfWidth = viewWidth * 0.5;
    final camX = -game.camera.viewfinder.transform.offset.x;
    final leftWorld = camX - halfWidth;
    final rightWorld = camX + halfWidth;

    double worldToScreenX(double worldX) =>
        (worldX - camX).roundToDouble() + halfWidth;

    final startTile = floorDivInt(leftWorld.floor(), tileW) - 1;
    final endTile = floorDivInt(rightWorld.ceil(), tileW) + 1;
    final clipRect = ui.Rect.fromLTWH(
      0,
      0,
      viewWidth.toDouble(),
      virtualHeight.toDouble(),
    );

    _withGapSupport(canvas, clipRect, gaps.isNotEmpty, () {
      for (var tile = startTile; tile <= endTile; tile++) {
        final worldX = (tile * tileW).toDouble();
        final x = worldToScreenX(worldX);
        canvas.drawImage(_image, ui.Offset(x, y), _paint);
      }

      if (gaps.isNotEmpty) {
        final maxX = viewWidth.toDouble();
        for (final gap in gaps) {
          final x0 = worldToScreenX(gap.minX);
          final x1 = worldToScreenX(gap.maxX);
          if (x1 < 0.0 || x0 > maxX) continue;
          if (x1 <= x0) continue;
          canvas.drawRect(ui.Rect.fromLTRB(x0, y, x1, y + tileH), _clearPaint);
        }
      }
    });
  }

  /// Renders tiles in world-space (following camera).
  void _renderWorldMode(
    ui.Canvas canvas,
    List<StaticGroundGapSnapshot> gaps,
    int tileW,
    int tileH,
    double y,
  ) {
    final visible = game.camera.visibleWorldRect;
    final camX = -game.camera.viewfinder.transform.offset.x;
    final left = visible.left.floor();
    final right = visible.right.ceil();

    final startTile = floorDivInt(left, tileW) - 1;
    final endTile = floorDivInt(right, tileW) + 1;

    final clipRect = ui.Rect.fromLTRB(
      visible.left,
      0,
      visible.right,
      virtualHeight.toDouble(),
    );

    _withGapSupport(canvas, clipRect, gaps.isNotEmpty, () {
      for (var tile = startTile; tile <= endTile; tile++) {
        final x = (tile * tileW).toDouble();
        final snappedX = snapWorldToPixelsInCameraSpace1d(x, camX);
        canvas.drawImage(_image, ui.Offset(snappedX, y), _paint);
      }

      if (gaps.isNotEmpty) {
        _clearGapRects(
          canvas,
          gaps: gaps,
          offsetX: 0.0,
          visibleMinX: visible.left,
          visibleMaxX: visible.right,
          y: y,
          height: tileH.toDouble(),
          snapRelativeToCameraX: camX,
        );
      }
    });
  }

  /// Wraps rendering in saveLayer (if gaps exist) or save, then restores.
  ///
  /// When [hasGaps] is true, uses `saveLayer` to enable `BlendMode.clear`.
  /// This has GPU overhead but is necessary for punching transparent holes.
  void _withGapSupport(
    ui.Canvas canvas,
    ui.Rect clipRect,
    bool hasGaps,
    void Function() drawCallback,
  ) {
    if (hasGaps) {
      canvas.saveLayer(clipRect, Paint());
    } else {
      canvas.save();
    }
    canvas.clipRect(clipRect);

    drawCallback();

    canvas.restore();
  }

  /// Draws horizontally-tiled images from [startX] to [endX].
  void _drawTileStrip(
    ui.Canvas canvas,
    double startX,
    double endX,
    int tileW,
    double y,
  ) {
    for (var x = startX; x < endX; x += tileW) {
      canvas.drawImage(_image, ui.Offset(x, y), _paint);
    }
  }

  /// Punches transparent holes in the tile strip for each gap.
  ///
  /// Uses [_clearPaint] with `BlendMode.clear` to erase pixels. Only draws
  /// gaps that intersect the visible range `[visibleMinX, visibleMaxX]`.
  void _clearGapRects(
    ui.Canvas canvas, {
    required List<StaticGroundGapSnapshot> gaps,
    required double offsetX,
    required double visibleMinX,
    required double visibleMaxX,
    required double y,
    required double height,
    double? snapRelativeToCameraX,
  }) {
    for (final gap in gaps) {
      var x0 = gap.minX + offsetX;
      var x1 = gap.maxX + offsetX;
      if (snapRelativeToCameraX != null) {
        x0 = snapWorldToPixelsInCameraSpace1d(x0, snapRelativeToCameraX);
        x1 = snapWorldToPixelsInCameraSpace1d(x1, snapRelativeToCameraX);
      }
      if (x1 < visibleMinX || x0 > visibleMaxX) continue;
      canvas.drawRect(ui.Rect.fromLTRB(x0, y, x1, y + height), _clearPaint);
    }
  }
}
