import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../../chunks/chunk_domain_models.dart';
import '../../shared/ground_material_render_rules.dart' as ground_material_rules;

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
/// This mirrors the current generated game-side theme source in
/// `lib/game/themes/authored_parallax_themes.dart`. If authored theme output
/// changes, this lookup should change in the same pass or be extracted to a
/// shared seam.
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
/// This mirrors the generated runtime theme asset sets in
/// `lib/game/themes/authored_parallax_themes.dart` so layer depth checks in
/// the editor stay visually aligned with game composition.
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

@immutable
class _ChunkSceneThemePreviewSpec {
  const _ChunkSceneThemePreviewSpec({
    required this.groundMaterial,
    required this.parallaxPreview,
  });

  final ChunkGroundMaterialSpec groundMaterial;
  final ChunkParallaxPreviewSpec parallaxPreview;
}

ChunkGroundLayout buildChunkGroundLayout(LevelChunkDef chunk) {
  return buildChunkGroundLayoutWithFillDepth(chunk, fillDepth: 16.0);
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
  final groundDepth = math.min(maxVisibleDepth, math.max(0.0, fillDepth));
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

/// Theme ids the chunk editor preview is configured to render.
///
/// Tests compare this registry against the runtime parallax registry so a new
/// runtime theme cannot quietly fall back to unrelated preview art.
@visibleForTesting
Iterable<String> chunkScenePreviewLevelIds() =>
    _chunkSceneThemePreviewSpecsByLevelId.keys;

ChunkGroundMaterialSpec resolveChunkGroundMaterialSpec(String levelId) {
  return _resolveChunkSceneThemePreviewSpec(levelId).groundMaterial;
}

ChunkParallaxPreviewSpec resolveChunkParallaxPreviewSpec(String levelId) {
  return _resolveChunkSceneThemePreviewSpec(levelId).parallaxPreview;
}

_ChunkSceneThemePreviewSpec _resolveChunkSceneThemePreviewSpec(String levelId) {
  final normalizedLevelId = levelId.trim();
  final spec = _chunkSceneThemePreviewSpecsByLevelId[normalizedLevelId];
  if (spec != null) {
    return spec;
  }
  throw StateError(
    'Chunk scene preview theme is not configured for levelId "$normalizedLevelId".',
  );
}

const Map<String, _ChunkSceneThemePreviewSpec>
_chunkSceneThemePreviewSpecsByLevelId = <String, _ChunkSceneThemePreviewSpec>{
  'field': _ChunkSceneThemePreviewSpec(
    groundMaterial: ChunkGroundMaterialSpec(
      sourceImagePath: 'assets/images/parallax/field/Field Layer 09.png',
    ),
    parallaxPreview: ChunkParallaxPreviewSpec(
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
    ),
  ),
  'forest': _ChunkSceneThemePreviewSpec(
    groundMaterial: ChunkGroundMaterialSpec(
      sourceImagePath: 'assets/images/parallax/forest/Forest Layer 04.png',
    ),
    parallaxPreview: ChunkParallaxPreviewSpec(
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
      foregroundLayers: <ChunkParallaxLayerPreviewSpec>[],
    ),
  ),
};

Future<ui.Rect> detectGroundMaterialSourceRect(
  ui.Image image, {
  double fallbackMaterialHeight = 16.0,
}) async {
  return ground_material_rules.detectGroundMaterialSourceRectForPreview(
    image,
    fallbackMaterialHeight: fallbackMaterialHeight,
  );
}
