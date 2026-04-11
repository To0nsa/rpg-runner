import 'dart:math' as math;
import 'dart:ui' as ui;

/// Shared render math for editor previews that need to stay aligned with the
/// current runtime ground-material and ground-band placement rules.
///
/// This intentionally mirrors the game-side behavior in:
/// - `lib/game/components/ground_surface.dart`
/// - `lib/game/components/ground_band_parallax_foreground.dart`
///
/// Keep these rules in sync when runtime band cropping or bottom-anchor
/// behavior changes.
const double defaultGroundMaterialFallbackHeight = 16.0;

Future<ui.Rect> detectGroundMaterialSourceRectForPreview(
  ui.Image image, {
  double fallbackMaterialHeight = defaultGroundMaterialFallbackHeight,
}) async {
  const alphaOpaqueThreshold = 1;
  const rowCoverageThreshold = 0.20;
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (bytes == null) {
    return _fallbackGroundMaterialSourceRect(
      image,
      fallbackMaterialHeight: fallbackMaterialHeight,
    );
  }

  final rgba = bytes.buffer.asUint8List();
  final width = image.width;
  final height = image.height;
  final minOpaquePixels = (width * rowCoverageThreshold).ceil();
  int? firstOpaqueRow;
  for (var y = 0; y < height; y += 1) {
    final rowOffset = y * width * 4;
    var opaqueCount = 0;
    for (var x = 0; x < width; x += 1) {
      final alpha = rgba[rowOffset + x * 4 + 3];
      if (alpha >= alphaOpaqueThreshold) {
        firstOpaqueRow ??= y;
        opaqueCount += 1;
        if (opaqueCount >= minOpaquePixels) {
          return ui.Rect.fromLTWH(
            0,
            y.toDouble(),
            width.toDouble(),
            (height - y).toDouble().clamp(1.0, height.toDouble()),
          );
        }
      }
    }
  }

  final fallbackTop =
      firstOpaqueRow ?? _fallbackMaterialTopRow(height, fallbackMaterialHeight);
  return ui.Rect.fromLTWH(
    0,
    fallbackTop.toDouble(),
    width.toDouble(),
    (height - fallbackTop).toDouble().clamp(1.0, height.toDouble()),
  );
}

double resolveGroundMaterialBandHeight({
  ui.Rect? materialSourceRect,
  double fallbackMaterialHeight = defaultGroundMaterialFallbackHeight,
  required double zoom,
  required double maxHeight,
}) {
  final sourceHeight = materialSourceRect?.height ?? fallbackMaterialHeight;
  final scaledHeight = sourceHeight * zoom;
  return scaledHeight.clamp(1.0, math.max(1.0, maxHeight)).toDouble();
}

ui.Rect buildViewportBottomGroundBandRect({
  required ui.Size viewportSize,
  required double groundBandHeight,
}) {
  final clampedHeight = groundBandHeight.clamp(
    1.0,
    math.max(1.0, viewportSize.height),
  ).toDouble();
  return ui.Rect.fromLTWH(
    0.0,
    viewportSize.height - clampedHeight,
    viewportSize.width,
    clampedHeight,
  );
}

double resolveBottomAnchoredLayerTopY({
  required double bottomAnchorY,
  required double layerHeight,
  required double yOffset,
}) {
  return bottomAnchorY - layerHeight + yOffset;
}

ui.Rect _fallbackGroundMaterialSourceRect(
  ui.Image image, {
  required double fallbackMaterialHeight,
}) {
  final topRow = _fallbackMaterialTopRow(image.height, fallbackMaterialHeight);
  return ui.Rect.fromLTWH(
    0,
    topRow.toDouble(),
    image.width.toDouble(),
    (image.height - topRow).toDouble().clamp(1.0, image.height.toDouble()),
  );
}

int _fallbackMaterialTopRow(int imageHeight, double fallbackMaterialHeight) {
  final fallbackTop = (imageHeight - fallbackMaterialHeight).floor();
  if (fallbackTop <= 0) {
    return 0;
  }
  if (fallbackTop >= imageHeight) {
    return imageHeight - 1;
  }
  return fallbackTop;
}
