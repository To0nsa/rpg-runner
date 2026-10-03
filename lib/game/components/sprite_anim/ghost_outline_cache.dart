import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

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
  int _generation = 0;
  int _rasterizationCount = 0;

  @visibleForTesting
  int get debugRasterizationCount => _rasterizationCount;

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

  /// Warms frames in priority order without evicting earlier useful textures.
  /// Yields between small batches, and discards pending images after [clear]
  /// or owner cancellation. Graphics work stays on the Flutter isolate.
  Future<void> prewarm(
    Iterable<(Sprite, Vector2)> frames, {
    required bool Function() isCancelled,
  }) async {
    final generation = _generation;
    var built = 0;
    for (final (sprite, size) in frames) {
      if (generation != _generation || isCancelled()) return;
      if (size.x <= 0 || size.y <= 0) continue;
      final key = (sprite, size.x, size.y);
      if (_frames.containsKey(key)) continue;
      final width = (size.x + 2).ceil();
      final height = (size.y + 2).ceil();
      final bytes = width * height * 4;
      if (_bytes + bytes > maxBytes) continue;
      final picture = _record(sprite, size);
      final ui.Image image;
      try {
        image = await picture.toImage(width, height);
        _rasterizationCount += 1;
      } finally {
        picture.dispose();
      }
      if (generation != _generation || isCancelled()) {
        image.dispose();
        return;
      }
      if (_frames.containsKey(key) || _bytes + bytes > maxBytes) {
        image.dispose();
        continue;
      }
      _frames[key] = image;
      _bytes += bytes;
      // Four textures per batch keeps the loading animation responsive.
      if (++built % 4 == 0) await Future<void>.delayed(Duration.zero);
    }
  }

  ui.Image _build(Sprite sprite, Vector2 size) {
    final picture = _record(sprite, size);
    try {
      _rasterizationCount += 1;
      return picture.toImageSync((size.x + 2).ceil(), (size.y + 2).ceil());
    } finally {
      picture.dispose();
    }
  }

  ui.Picture _record(Sprite sprite, Vector2 size) {
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
    return recorder.endRecording();
  }

  /// Releases generated images without disposing the shared source sprites.
  void clear() {
    _generation += 1;
    for (final image in _frames.values) {
      image.dispose();
    }
    _frames.clear();
    _bytes = 0;
  }
}
