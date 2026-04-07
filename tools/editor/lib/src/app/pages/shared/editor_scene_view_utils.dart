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
  final Set<String> _loadingPaths = <String>{};
  final Set<String> _failedPaths = <String>{};

  int get loadedImageCount => _images.length;

  ui.Image? imageFor(String absolutePath) => _images[absolutePath];

  Future<ui.Image?> ensureLoaded(String absolutePath) async {
    final existingImage = _images[absolutePath];
    if (existingImage != null ||
        _loadingPaths.contains(absolutePath) ||
        _failedPaths.contains(absolutePath)) {
      return existingImage;
    }

    _loadingPaths.add(absolutePath);
    try {
      final image = await EditorSceneViewUtils.loadFileImage(absolutePath);
      if (image == null) {
        _failedPaths.add(absolutePath);
        return null;
      }
      _images[absolutePath] = image;
      return image;
    } catch (_) {
      _failedPaths.add(absolutePath);
      return null;
    } finally {
      _loadingPaths.remove(absolutePath);
    }
  }

  void dispose() {
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _loadingPaths.clear();
    _failedPaths.clear();
  }
}
