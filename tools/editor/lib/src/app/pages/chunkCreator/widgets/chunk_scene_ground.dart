import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../../chunks/chunk_domain_models.dart';

/// Read-only ground layout derived from the current chunk floor/gap contract.
///
/// The chunk scene uses this to render the visible floor area exactly as the
/// player-facing viewport sees it: solid spans between gaps from `topY` down to
/// the locked chunk bottom.
@immutable
class ChunkGroundLayout {
  const ChunkGroundLayout({
    this.solidWorldRects = const <ui.Rect>[],
    this.gapWorldRects = const <ui.Rect>[],
  });

  final List<ui.Rect> solidWorldRects;
  final List<ui.Rect> gapWorldRects;

  bool get hasVisibleGround =>
      solidWorldRects.isNotEmpty || gapWorldRects.isNotEmpty;
}

/// Runtime-derived ground material source for a level theme.
///
/// This mirrors the current game-side ground renderer source in
/// `lib/game/themes/parallax_theme_registry.dart`. If that registry changes,
/// this lookup should change in the same pass or be extracted to a shared seam.
@immutable
class ChunkGroundMaterialSpec {
  const ChunkGroundMaterialSpec({
    required this.sourceImagePath,
    this.fallbackMaterialHeight = 16.0,
  });

  final String sourceImagePath;
  final double fallbackMaterialHeight;
}

/// Level-driven parallax asset mapping used by chunk-scene preview.
///
/// This mirrors the runtime theme asset sets in
/// `lib/game/themes/parallax_theme_registry.dart` so layer depth checks in the
/// editor stay visually aligned with game composition.
@immutable
class ChunkParallaxPreviewSpec {
  const ChunkParallaxPreviewSpec({
    this.backgroundLayers = const <ChunkParallaxLayerPreviewSpec>[],
    this.foregroundLayers = const <ChunkParallaxLayerPreviewSpec>[],
  });

  final List<ChunkParallaxLayerPreviewSpec> backgroundLayers;
  final List<ChunkParallaxLayerPreviewSpec> foregroundLayers;
}

@immutable
class ChunkParallaxLayerPreviewSpec {
  const ChunkParallaxLayerPreviewSpec({
    required this.assetPath,
    required this.parallaxFactor,
  });

  final String assetPath;
  final double parallaxFactor;
}

ChunkGroundLayout buildChunkGroundLayout(LevelChunkDef chunk) {
  return buildChunkGroundLayoutWithFillDepth(
    chunk,
    fillDepth: 16.0,
  );
}

/// Builds the same finite ground bands the runtime renderer uses: solid spans
/// between gaps, starting at `topY`, with a render depth driven by the ground
/// material band height rather than the full remaining viewport height.
ChunkGroundLayout buildChunkGroundLayoutWithFillDepth(
  LevelChunkDef chunk, {
  required double fillDepth,
}) {
  final chunkWidth = math.max(0, chunk.width).toDouble();
  final chunkHeight = math.max(0, chunk.height).toDouble();
  final groundTopY = chunk.groundProfile.topY.toDouble();
  final maxVisibleDepth = chunkHeight - groundTopY;
  final groundDepth = math.min(
    maxVisibleDepth,
    math.max(0.0, fillDepth),
  );
  if (chunkWidth <= 0 || groundDepth <= 0) {
    return const ChunkGroundLayout();
  }

  final sortedGaps = List<GroundGapDef>.from(chunk.groundGaps)
    ..sort((a, b) {
      final xCompare = a.x.compareTo(b.x);
      if (xCompare != 0) {
        return xCompare;
      }
      final widthCompare = a.width.compareTo(b.width);
      if (widthCompare != 0) {
        return widthCompare;
      }
      return a.gapId.compareTo(b.gapId);
    });

  final solidWorldRects = <ui.Rect>[];
  final gapWorldRects = <ui.Rect>[];
  var currentX = 0.0;
  for (final gap in sortedGaps) {
    final gapStart = gap.x.toDouble().clamp(0.0, chunkWidth);
    final gapEnd = (gap.x + gap.width).toDouble().clamp(0.0, chunkWidth);
    if (gapEnd <= gapStart) {
      continue;
    }
    if (gapStart > currentX) {
      solidWorldRects.add(
        ui.Rect.fromLTWH(
          currentX,
          groundTopY,
          gapStart - currentX,
          groundDepth,
        ),
      );
    }
    gapWorldRects.add(
      ui.Rect.fromLTWH(gapStart, groundTopY, gapEnd - gapStart, groundDepth),
    );
    currentX = math.max(currentX, gapEnd);
  }

  if (currentX < chunkWidth) {
    solidWorldRects.add(
      ui.Rect.fromLTWH(
        currentX,
        groundTopY,
        chunkWidth - currentX,
        groundDepth,
      ),
    );
  }

  return ChunkGroundLayout(
    solidWorldRects: solidWorldRects,
    gapWorldRects: gapWorldRects,
  );
}

ChunkGroundMaterialSpec resolveChunkGroundMaterialSpec(String levelId) {
  switch (levelId.trim()) {
    case 'forest':
      return const ChunkGroundMaterialSpec(
        sourceImagePath: 'assets/images/parallax/forest/Forest Layer 04.png',
      );
    case 'field':
    default:
      return const ChunkGroundMaterialSpec(
        sourceImagePath: 'assets/images/parallax/field/Field Layer 09.png',
      );
  }
}

ChunkParallaxPreviewSpec resolveChunkParallaxPreviewSpec(String levelId) {
  switch (levelId.trim()) {
    case 'forest':
      return const ChunkParallaxPreviewSpec(
        backgroundLayers: <ChunkParallaxLayerPreviewSpec>[
          ChunkParallaxLayerPreviewSpec(
            assetPath: 'assets/images/parallax/forest/Forest Layer 01.png',
            parallaxFactor: 0.10,
          ),
          ChunkParallaxLayerPreviewSpec(
            assetPath: 'assets/images/parallax/forest/Forest Layer 02.png',
            parallaxFactor: 0.20,
          ),
          ChunkParallaxLayerPreviewSpec(
            assetPath: 'assets/images/parallax/forest/Forest Layer 03.png',
            parallaxFactor: 0.30,
          ),
        ],
        foregroundLayers: <ChunkParallaxLayerPreviewSpec>[
          ChunkParallaxLayerPreviewSpec(
            assetPath: 'assets/images/parallax/forest/Forest Layer 05.png',
            parallaxFactor: 1.0,
          ),
        ],
      );
    case 'field':
    default:
      return const ChunkParallaxPreviewSpec(
        backgroundLayers: <ChunkParallaxLayerPreviewSpec>[
          ChunkParallaxLayerPreviewSpec(
            assetPath: 'assets/images/parallax/field/Field Layer 01.png',
            parallaxFactor: 0.10,
          ),
          ChunkParallaxLayerPreviewSpec(
            assetPath: 'assets/images/parallax/field/Field Layer 02.png',
            parallaxFactor: 0.15,
          ),
          ChunkParallaxLayerPreviewSpec(
            assetPath: 'assets/images/parallax/field/Field Layer 03.png',
            parallaxFactor: 0.20,
          ),
          ChunkParallaxLayerPreviewSpec(
            assetPath: 'assets/images/parallax/field/Field Layer 04.png',
            parallaxFactor: 0.30,
          ),
          ChunkParallaxLayerPreviewSpec(
            assetPath: 'assets/images/parallax/field/Field Layer 05.png',
            parallaxFactor: 0.40,
          ),
          ChunkParallaxLayerPreviewSpec(
            assetPath: 'assets/images/parallax/field/Field Layer 06.png',
            parallaxFactor: 0.50,
          ),
          ChunkParallaxLayerPreviewSpec(
            assetPath: 'assets/images/parallax/field/Field Layer 07.png',
            parallaxFactor: 0.60,
          ),
          ChunkParallaxLayerPreviewSpec(
            assetPath: 'assets/images/parallax/field/Field Layer 08.png',
            parallaxFactor: 0.70,
          ),
        ],
        foregroundLayers: <ChunkParallaxLayerPreviewSpec>[
          ChunkParallaxLayerPreviewSpec(
            assetPath: 'assets/images/parallax/field/Field Layer 10.png',
            parallaxFactor: 1.0,
          ),
        ],
      );
  }
}

Future<ui.Rect> detectGroundMaterialSourceRect(
  ui.Image image, {
  double fallbackMaterialHeight = 16.0,
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

  final fallbackTop = firstOpaqueRow ?? _fallbackMaterialTopRow(
    image.height,
    fallbackMaterialHeight,
  );
  return ui.Rect.fromLTWH(
    0,
    fallbackTop.toDouble(),
    image.width.toDouble(),
    (image.height - fallbackTop)
        .toDouble()
        .clamp(1.0, image.height.toDouble()),
  );
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
