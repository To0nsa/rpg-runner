import 'dart:ui' as ui;

/// Paints one horizontal pool in world coordinates using already-cached images.
///
/// Both editor and game use this compositor. The caller selects the surface
/// frame from fixed ticks and retains the repeated fill paint. Transparent wave
/// pixels replace fill inside an isolated layer; a foreground pass tints actors
/// without hiding their silhouettes. No images are decoded or owned here.
void paintWaterMaterial(
  ui.Canvas canvas, {
  required ui.Rect bounds,
  required ui.Paint fillPaint,
  required ui.Image surfaceImage,
  required double anchorY,
  ui.Image? detailImage,
  double detailAnchorY = 0,
  bool foreground = false,
}) {
  if (bounds.isEmpty) return;
  canvas.save();
  canvas.clipRect(bounds);
  canvas.saveLayer(bounds, foreground ? _foregroundPaint : _layerPaint);
  canvas.drawRect(bounds, fillPaint);
  _paintSurface(canvas, bounds, surfaceImage, anchorY, _replacePaint);
  if (detailImage != null) {
    _paintSurface(canvas, bounds, detailImage, detailAnchorY, _layerPaint);
  }
  canvas.restore();
  canvas.restore();
}

void _paintSurface(
  ui.Canvas canvas,
  ui.Rect bounds,
  ui.Image image,
  double anchorY,
  ui.Paint paint,
) {
  final width = image.width.toDouble();
  // Global X phase makes adjoining regions and streamed instances tile alike.
  final first = (bounds.left / width).floor() * width;
  for (var x = first; x < bounds.right; x += width) {
    canvas.drawImage(image, ui.Offset(x, bounds.top - anchorY), paint);
  }
}

final _layerPaint = ui.Paint()..filterQuality = ui.FilterQuality.none;
final _replacePaint = ui.Paint()
  ..filterQuality = ui.FilterQuality.none
  ..blendMode = ui.BlendMode.src;
// A 32% foreground contribution keeps submerged actors and attacks legible.
final _foregroundPaint = ui.Paint()..color = const ui.Color(0x52FFFFFF);
