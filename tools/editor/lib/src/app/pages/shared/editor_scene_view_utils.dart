import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
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

/// Digest-bound decoded image and straight source-byte-derived RGBA samples.
///
/// Preview painting and pixel-assisted authoring share this record so they
/// cannot silently inspect different revisions of a file at the same path.
final class EditorUiImageRaster {
  EditorUiImageRaster({
    required this.image,
    required Uint8List rgba,
    required this.digest,
  }) : rgba = Uint8List.fromList(rgba).asUnmodifiableView();

  final ui.Image image;
  final Uint8List rgba;
  final String digest;

  int alphaAt(int x, int y) => rgba[(y * image.width + x) * 4 + 3];
}

/// Small decoded-image cache for scene previews.
///
/// Pages still own when they request loads and when they rebuild, but the
/// cache keeps the repeated file/decode/dispose/failure rules single-sourced.
final class EditorUiImageCache {
  final Map<String, EditorUiImageRaster> _rasters =
      <String, EditorUiImageRaster>{};
  final Map<_EditorUiRegionKey, ui.Image> _regionImages =
      <_EditorUiRegionKey, ui.Image>{};
  final Map<_EditorUiRegionKey, Future<ui.Image?>> _regionLoadingFutures =
      <_EditorUiRegionKey, Future<ui.Image?>>{};
  final Map<String, Future<EditorUiImageRaster?>> _loadingFutures =
      <String, Future<EditorUiImageRaster?>>{};
  final Set<String> _failedPaths = <String>{};
  bool _disposed = false;
  int _revision = 0;

  int get loadedImageCount => _rasters.length;

  int get loadedRegionImageCount => _regionImages.length;

  int get revision => _revision;

  ui.Image? imageFor(String absolutePath) => _rasters[absolutePath]?.image;

  EditorUiImageRaster? rasterFor(String absolutePath) => _rasters[absolutePath];

  ui.Image? regionImageFor(
    String absolutePath, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) => _regionImages[_EditorUiRegionKey(absolutePath, x, y, width, height)];

  Future<ui.Image?> ensureLoaded(String absolutePath) async {
    return (await ensureRasterLoaded(absolutePath))?.image;
  }

  /// Loads one image and its RGBA samples, optionally rechecking file bytes.
  Future<EditorUiImageRaster?> ensureRasterLoaded(
    String absolutePath, {
    bool refresh = false,
  }) async {
    if (_disposed) return null;
    final existingRaster = _rasters[absolutePath];
    if (!refresh && existingRaster != null) {
      return existingRaster;
    }
    final existingLoad = _loadingFutures[absolutePath];
    if (existingLoad != null) {
      final loaded = await existingLoad;
      if (!refresh) return loaded;
      // A refresh must inspect bytes after any older preview load completes;
      // otherwise Save could compare a draft with that older in-flight digest.
      return ensureRasterLoaded(absolutePath, refresh: true);
    }
    if (!refresh && _failedPaths.contains(absolutePath)) {
      return null;
    }
    if (refresh) _failedPaths.remove(absolutePath);

    final loadFuture = () async {
      try {
        final file = File(absolutePath);
        if (!await file.exists()) {
          _failedPaths.add(absolutePath);
          return null;
        }
        final bytes = await file.readAsBytes();
        final digest = sha256.convert(bytes).toString();
        final current = _rasters[absolutePath];
        if (current != null && current.digest == digest) {
          _failedPathSucceeded(absolutePath);
          return current;
        }
        final codec = await ui.instantiateImageCodec(bytes);
        late final ui.Image image;
        try {
          image = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
        if (_disposed) {
          image.dispose();
          return null;
        }
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (byteData == null) {
          image.dispose();
          _failedPaths.add(absolutePath);
          return null;
        }
        final raster = EditorUiImageRaster(
          image: image,
          rgba: byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
          digest: digest,
        );
        if (_disposed) {
          image.dispose();
          return null;
        }
        _invalidateRegionsForPath(absolutePath);
        final replaced = _rasters[absolutePath];
        _rasters[absolutePath] = raster;
        if (!identical(replaced?.image, image)) replaced?.image.dispose();
        _revision += 1;
        _failedPaths.remove(absolutePath);
        return raster;
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

  /// Allows repaired files to be retried after the editor's Reload action.
  void clearFailures() => _failedPaths.clear();

  void _invalidateRegionsForPath(String absolutePath) {
    final keys = _regionImages.keys
        .where((key) => key.absolutePath == absolutePath)
        .toList(growable: false);
    for (final key in keys) {
      _regionImages.remove(key)?.dispose();
      _regionLoadingFutures.remove(key);
    }
  }

  void _failedPathSucceeded(String absolutePath) {
    _failedPaths.remove(absolutePath);
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
    for (final raster in _rasters.values) {
      raster.image.dispose();
    }
    _rasters.clear();
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
