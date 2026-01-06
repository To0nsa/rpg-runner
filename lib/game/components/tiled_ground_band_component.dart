import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../../core/snapshots/static_ground_gap_snapshot.dart';
import '../game_controller.dart';
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

  final String assetPath;
  final GameController controller;
  final int? virtualWidth;
  final int virtualHeight;
  final bool renderInBackdrop;

  late final ui.Image _image;
  final Paint _paint = Paint()..filterQuality = FilterQuality.none;
  final Paint _clearPaint = Paint()..blendMode = ui.BlendMode.clear;

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
      final gaps = controller.snapshot.groundGaps;

      final tileW = _image.width;
      final tileH = _image.height;
      final y = (virtualHeight - tileH).toDouble(); // bottom aligned

      final cameraLeftX =
          (game.camera.viewfinder.position.x - viewWidth / 2);
      final offsetPx = -cameraLeftX;
      final startX = positiveModDouble(offsetPx, tileW.toDouble());
      final clipRect =
          ui.Rect.fromLTWH(0, 0, viewWidth.toDouble(), virtualHeight.toDouble());

      if (gaps.isNotEmpty) {
        canvas.saveLayer(clipRect, Paint());
      } else {
        canvas.save();
      }
      canvas.clipRect(clipRect);

      for (var x = startX - tileW; x < viewWidth; x += tileW) {
        canvas.drawImage(_image, ui.Offset(x, y), _paint);
      }

      if (gaps.isNotEmpty) {
        _clearGapRects(
          canvas,
          gaps: gaps,
          offsetX: -cameraLeftX,
          visibleMinX: 0.0,
          visibleMaxX: viewWidth.toDouble(),
          y: y,
          height: tileH.toDouble(),
        );
      }

      canvas.restore();
      return;
    }

    final visible = game.camera.visibleWorldRect;
    final gaps = controller.snapshot.groundGaps;

    final tileW = _image.width;
    final tileH = _image.height;
    final y = (virtualHeight - tileH).toDouble(); // bottom aligned to viewport

    final left = visible.left.floor();
    final right = visible.right.ceil();

    final startTile = _floorDiv(left, tileW) - 1;
    final endTile = _floorDiv(right, tileW) + 1;

    if (gaps.isNotEmpty) {
      final clipRect = ui.Rect.fromLTRB(
        visible.left,
        0,
        visible.right,
        virtualHeight.toDouble(),
      );
      canvas.saveLayer(clipRect, Paint());
      canvas.clipRect(clipRect);
      for (var tile = startTile; tile <= endTile; tile++) {
        final x = (tile * tileW).toDouble();
        canvas.drawImage(_image, ui.Offset(x, y), _paint);
      }
      _clearGapRects(
        canvas,
        gaps: gaps,
        offsetX: 0.0,
        visibleMinX: visible.left,
        visibleMaxX: visible.right,
        y: y,
        height: tileH.toDouble(),
      );
      canvas.restore();
    } else {
      for (var tile = startTile; tile <= endTile; tile++) {
        final x = (tile * tileW).toDouble();
        canvas.drawImage(_image, ui.Offset(x, y), _paint);
      }
    }
  }

  void _clearGapRects(
    ui.Canvas canvas, {
    required List<StaticGroundGapSnapshot> gaps,
    required double offsetX,
    required double visibleMinX,
    required double visibleMaxX,
    required double y,
    required double height,
  }) {
    for (final gap in gaps) {
      final x0 = gap.minX + offsetX;
      final x1 = gap.maxX + offsetX;
      if (x1 < visibleMinX || x0 > visibleMaxX) continue;
      canvas.drawRect(ui.Rect.fromLTRB(x0, y, x1, y + height), _clearPaint);
    }
  }

  int _floorDiv(int a, int b) {
    if (b <= 0) throw ArgumentError.value(b, 'b', 'must be > 0');
    if (a >= 0) return a ~/ b;
    return -(((-a) + b - 1) ~/ b);
  }
}
