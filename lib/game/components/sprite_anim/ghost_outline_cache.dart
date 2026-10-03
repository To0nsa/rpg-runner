import 'dart:ui' as ui;

import 'package:flame/components.dart';

/// Run-owned, bounded textures for the ghost's eight-offset sprite outline.
///
/// Frames share textures across entities. Cache misses rasterize once at the
/// unscaled component size; facing and world scale remain canvas transforms.
/// The owner must call [clear] when releasing the ghost's render assets.
class GhostOutlineCache {
  GhostOutlineCache({this.maxBytes = 16 * 1024 * 1024}) {
    if (maxBytes <= 0) throw ArgumentError.value(maxBytes, 'maxBytes');
  }

  /// Estimated RGBA texture limit: 16 MiB avoids unbounded animation-frame growth.
  final int maxBytes;
  final _frames = <(Sprite, double, double), ui.Image>{};
  final _paint = ui.Paint()..filterQuality = ui.FilterQuality.none;
  int _bytes = 0;

  int get estimatedBytes => _bytes;
  int get frameCount => _frames.length;

  /// Draws the one-pixel local-space outline behind the current sprite.
  void render(ui.Canvas canvas, Sprite sprite, Vector2 size) {
    if (size.x <= 0 || size.y <= 0) return;
    final key = (sprite, size.x, size.y);
    var image = _frames.remove(key);
    if (image == null) {
      image = _build(sprite, size);
      final bytes = image.width * image.height * 4;
      while (_frames.isNotEmpty && _bytes + bytes > maxBytes) {
        final oldest = _frames.remove(_frames.keys.first)!;
        _bytes -= oldest.width * oldest.height * 4;
        oldest.dispose();
      }
      if (bytes > maxBytes) {
        canvas.drawImage(image, const ui.Offset(-1, -1), _paint);
        image.dispose();
        return;
      }
      _bytes += bytes;
    }
    _frames[key] = image;
    canvas.drawImage(image, const ui.Offset(-1, -1), _paint);
  }

  ui.Image _build(Sprite sprite, Vector2 size) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.none
      ..colorFilter = const ui.ColorFilter.mode(
        ui.Color.fromARGB(230, 0, 0, 0),
        ui.BlendMode.srcATop,
      );
    for (final offset in const [
      ui.Offset(-1, -1),
      ui.Offset(-1, 0),
      ui.Offset(-1, 1),
      ui.Offset(1, 0),
      ui.Offset(1, -1),
      ui.Offset(1, 1),
      ui.Offset(0, -1),
      ui.Offset(0, 1),
    ]) {
      canvas.save();
      canvas.translate(1 + offset.dx, 1 + offset.dy);
      sprite.render(canvas, size: size, overridePaint: paint);
      canvas.restore();
    }
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync((size.x + 2).ceil(), (size.y + 2).ceil());
    } finally {
      picture.dispose();
    }
  }

  /// Releases generated images without disposing the shared source sprites.
  void clear() {
    for (final image in _frames.values) {
      image.dispose();
    }
    _frames.clear();
    _bytes = 0;
  }
}
