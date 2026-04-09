import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../../chunks/chunk_domain_models.dart';
import '../../../../prefabs/models/models.dart';

/// Read-only ground layout derived from the current chunk floor/gap contract.
///
/// The chunk scene uses this to render the visible floor area exactly as the
/// player-facing viewport sees it: solid spans between gaps from `topY` down to
/// the locked chunk bottom.
@immutable
class ChunkGroundLayout {
  const ChunkGroundLayout({
    this.solidWorldRects = const <Rect>[],
    this.gapWorldRects = const <Rect>[],
  });

  final List<Rect> solidWorldRects;
  final List<Rect> gapWorldRects;

  bool get hasVisibleGround =>
      solidWorldRects.isNotEmpty || gapWorldRects.isNotEmpty;
}

/// Heuristic visual theme for chunk floor rendering.
///
/// This keeps the current contract simple: chunk data does not author a ground
/// material yet, so the scene derives one from the existing tile slice catalog.
@immutable
class ChunkGroundTheme {
  const ChunkGroundTheme({
    this.surfaceSlices = const <AtlasSliceDef>[],
    this.bodySlice,
    this.capHeightPx = 16,
  });

  final List<AtlasSliceDef> surfaceSlices;
  final AtlasSliceDef? bodySlice;
  final int capHeightPx;

  bool get hasRenderableSlices => surfaceSlices.isNotEmpty && bodySlice != null;

  Iterable<String> sourceImagePaths() sync* {
    final seen = <String>{};
    for (final slice in surfaceSlices) {
      final path = slice.sourceImagePath.trim();
      if (path.isEmpty || !seen.add(path)) {
        continue;
      }
      yield path;
    }
    final bodySlice = this.bodySlice;
    if (bodySlice == null) {
      return;
    }
    final bodyPath = bodySlice.sourceImagePath.trim();
    if (bodyPath.isEmpty || !seen.add(bodyPath)) {
      return;
    }
    yield bodyPath;
  }
}

ChunkGroundLayout buildChunkGroundLayout(LevelChunkDef chunk) {
  final chunkWidth = math.max(0, chunk.width).toDouble();
  final chunkHeight = math.max(0, chunk.height).toDouble();
  final groundTopY = chunk.groundProfile.topY.toDouble();
  final groundDepth = chunkHeight - groundTopY;
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

  final solidWorldRects = <Rect>[];
  final gapWorldRects = <Rect>[];
  var currentX = 0.0;
  for (final gap in sortedGaps) {
    final gapStart = gap.x.toDouble().clamp(0.0, chunkWidth);
    final gapEnd = (gap.x + gap.width).toDouble().clamp(0.0, chunkWidth);
    if (gapEnd <= gapStart) {
      continue;
    }
    if (gapStart > currentX) {
      solidWorldRects.add(
        Rect.fromLTWH(currentX, groundTopY, gapStart - currentX, groundDepth),
      );
    }
    gapWorldRects.add(
      Rect.fromLTWH(gapStart, groundTopY, gapEnd - gapStart, groundDepth),
    );
    currentX = math.max(currentX, gapEnd);
  }

  if (currentX < chunkWidth) {
    solidWorldRects.add(
      Rect.fromLTWH(currentX, groundTopY, chunkWidth - currentX, groundDepth),
    );
  }

  return ChunkGroundLayout(
    solidWorldRects: solidWorldRects,
    gapWorldRects: gapWorldRects,
  );
}

ChunkGroundTheme resolveChunkGroundTheme(List<AtlasSliceDef> tileSlices) {
  final groundLikeSlices = tileSlices
      .where(_looksLikeGroundSlice)
      .toList(growable: false);
  final candidates =
      List<AtlasSliceDef>.from(
          groundLikeSlices.isNotEmpty ? groundLikeSlices : tileSlices,
        )
        ..sort((a, b) {
      final widthCompare = b.width.compareTo(a.width);
      if (widthCompare != 0) {
        return widthCompare;
      }
      final heightCompare = b.height.compareTo(a.height);
      if (heightCompare != 0) {
        return heightCompare;
      }
      return a.id.compareTo(b.id);
    });

  if (candidates.isEmpty) {
    return const ChunkGroundTheme();
  }

  final bodySlice = candidates.first;
  final capHeightPx = math.min(
    16,
    math.max(8, math.max(1, bodySlice.height ~/ 2)),
  );
  return ChunkGroundTheme(
    surfaceSlices: List<AtlasSliceDef>.unmodifiable(candidates),
    bodySlice: bodySlice,
    capHeightPx: capHeightPx,
  );
}

bool _looksLikeGroundSlice(AtlasSliceDef slice) {
  final id = slice.id.toLowerCase();
  final sourcePath = slice.sourceImagePath.toLowerCase();
  return id.contains('ground') ||
      id.contains('grass') ||
      id.contains('dirt') ||
      id.contains('soil') ||
      sourcePath.contains('ground');
}
