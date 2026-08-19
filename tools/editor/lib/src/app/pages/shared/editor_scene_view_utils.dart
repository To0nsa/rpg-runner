import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Shared scene-page helpers for repeated viewport zoom, centering, and image
/// preview behavior across the editor's authoring routes.
final class EditorSceneViewUtils {
  EditorSceneViewUtils._();

  /// Floating-point tolerance used when comparing zoom values.
  static const double zoomComparisonEpsilon = 0.000001;

  static double snapZoom({
    required double value,
    required double min,
    required double max,
    required double step,
  }) {
    final snapped = (value / step).roundToDouble() * step;
    return snapped.clamp(min, max).toDouble();
  }

  static bool zoomValuesEqual(double a, double b) {
    return (a - b).abs() <= zoomComparisonEpsilon;
  }

  static void scheduleViewportCentering({
    required BuildContext context,
    required ScrollController horizontal,
    required ScrollController vertical,
  }) {
    // Deferred to next frame so scroll extents are finalized before jumpTo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted || !horizontal.hasClients || !vertical.hasClients) {
        return;
      }
      final horizontalPosition = horizontal.position;
      final verticalPosition = vertical.position;
      horizontal.jumpTo(horizontalPosition.maxScrollExtent * 0.5);
      vertical.jumpTo(verticalPosition.maxScrollExtent * 0.5);
    });
  }

  static Future<ui.Image?> loadFileImage(String absolutePath) async {
    final file = File(absolutePath);
    if (!file.existsSync()) {
      return null;
    }
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }
}

/// Small decoded-image cache for scene previews.
///
/// Pages still own when they request loads and when they rebuild, but the
/// cache keeps the repeated file/decode/dispose/failure rules single-sourced.
final class EditorUiImageCache {
  final Map<String, ui.Image> _images = <String, ui.Image>{};
  final Map<_EditorUiRegionKey, ui.Image> _regionImages =
      <_EditorUiRegionKey, ui.Image>{};
  final Map<_EditorUiRegionKey, Future<ui.Image?>> _regionLoadingFutures =
      <_EditorUiRegionKey, Future<ui.Image?>>{};
  final Map<String, Future<ui.Image?>> _loadingFutures =
      <String, Future<ui.Image?>>{};
  final Set<String> _failedPaths = <String>{};
  bool _disposed = false;

  int get loadedImageCount => _images.length;

  int get loadedRegionImageCount => _regionImages.length;

  ui.Image? imageFor(String absolutePath) => _images[absolutePath];

  ui.Image? regionImageFor(
    String absolutePath, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) => _regionImages[_EditorUiRegionKey(absolutePath, x, y, width, height)];

  Future<ui.Image?> ensureLoaded(String absolutePath) async {
    if (_disposed) return null;
    final existingImage = _images[absolutePath];
    if (existingImage != null) {
      return existingImage;
    }
    final existingLoad = _loadingFutures[absolutePath];
    if (existingLoad != null) {
      return existingLoad;
    }
    if (_failedPaths.contains(absolutePath)) {
      return null;
    }

    final loadFuture = () async {
      try {
        final image = await EditorSceneViewUtils.loadFileImage(absolutePath);
        if (image == null) {
          _failedPaths.add(absolutePath);
          return null;
        }
        if (_disposed) {
          image.dispose();
          return null;
        }
        _images[absolutePath] = image;
        return image;
      } catch (_) {
        _failedPaths.add(absolutePath);
        return null;
      } finally {
        _loadingFutures.remove(absolutePath);
      }
    }();
    _loadingFutures[absolutePath] = loadFuture;
    return loadFuture;
  }

  Future<ui.Image?> ensureRegionLoaded(
    String absolutePath, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) async {
    if (_disposed) return null;
    final key = _EditorUiRegionKey(absolutePath, x, y, width, height);
    final existing = _regionImages[key];
    if (existing != null) return existing;
    final existingLoad = _regionLoadingFutures[key];
    if (existingLoad != null) return existingLoad;
    final loadFuture = () async {
      try {
        final source = await ensureLoaded(absolutePath);
        if (source == null ||
            x < 0 ||
            y < 0 ||
            width <= 0 ||
            height <= 0 ||
            x + width > source.width ||
            y + height > source.height) {
          return null;
        }
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawImageRect(
          source,
          ui.Rect.fromLTWH(
            x.toDouble(),
            y.toDouble(),
            width.toDouble(),
            height.toDouble(),
          ),
          ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          ui.Paint()..filterQuality = ui.FilterQuality.none,
        );
        final picture = recorder.endRecording();
        try {
          final image = await picture.toImage(width, height);
          if (_disposed) {
            image.dispose();
            return null;
          }
          _regionImages[key] = image;
          return image;
        } finally {
          picture.dispose();
        }
      } finally {
        _regionLoadingFutures.remove(key);
      }
    }();
    _regionLoadingFutures[key] = loadFuture;
    return loadFuture;
  }

  void dispose() {
    _disposed = true;
    for (final image in _regionImages.values) {
      image.dispose();
    }
    _regionImages.clear();
    _regionLoadingFutures.clear();
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _loadingFutures.clear();
    _failedPaths.clear();
  }
}

final class _EditorUiRegionKey {
  const _EditorUiRegionKey(
    this.absolutePath,
    this.x,
    this.y,
    this.width,
    this.height,
  );

  final String absolutePath;
  final int x;
  final int y;
  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      other is _EditorUiRegionKey &&
      other.absolutePath == absolutePath &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(absolutePath, x, y, width, height);
}
