import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../chunks/chunk_domain_models.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/models/models.dart';
import '../../prefabCreator/shared/prefab_polygon_visual_source.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/terrain_polygon_scene_painter.dart';

/// Read-only visual projection for the placed prefab assets in one chunk.
///
/// Placement order is deterministic and follows the chunk's z-index contract.
/// Source tiles remain prefab-local so the canvas can apply the placed anchor,
/// scale, and flips without changing authored prefab data.
@immutable
final class ChunkPolygonVisualProjection {
  ChunkPolygonVisualProjection({
    required Iterable<ChunkPolygonPlacedVisual> placements,
  }) : placements = List<ChunkPolygonPlacedVisual>.unmodifiable(placements);

  factory ChunkPolygonVisualProjection.fromChunk({
    required ChunkV2FileData chunk,
    required PrefabV3FileData prefabData,
    required PrefabTileFileData tileData,
    required Map<String, PrefabV3VisualBounds> visualBoundsByPrefabKey,
  }) {
    final prefabsByKey = <String, PrefabV3Def>{
      for (final prefab in prefabData.prefabs) prefab.prefabKey: prefab,
    };
    final prefabsById = <String, PrefabV3Def>{
      for (final prefab in prefabData.prefabs) prefab.id: prefab,
    };
    final placements =
        buildChunkPlacedPrefabSelections(chunk.prefabs)
            .map((selection) {
              final placement = selection.prefab;
              final prefab =
                  prefabsByKey[placement.prefabKey] ??
                  prefabsById[placement.prefabId];
              return ChunkPolygonPlacedVisual(
                selectionKey: selection.selectionKey,
                placement: placement,
                visualSource: prefab == null
                    ? null
                    : PrefabPolygonVisualProjection.fromData(
                        prefabData: prefabData,
                        tileData: tileData,
                        visualBoundsByPrefabKey: visualBoundsByPrefabKey,
                        prefab: prefab,
                      ),
              );
            })
            .toList(growable: false)
          ..sort(_comparePlacedVisuals);
    return ChunkPolygonVisualProjection(placements: placements);
  }

  final List<ChunkPolygonPlacedVisual> placements;

  Iterable<ChunkPolygonPlacedVisual> belowTerrain(int terrainZIndex) =>
      placements.where((placement) => placement.zIndex < terrainZIndex);

  Iterable<ChunkPolygonPlacedVisual> atOrAboveTerrain(int terrainZIndex) =>
      placements.where((placement) => placement.zIndex >= terrainZIndex);
}

/// One resolved chunk placement and its prefab-local visual source.
@immutable
final class ChunkPolygonPlacedVisual {
  const ChunkPolygonPlacedVisual({
    required this.selectionKey,
    required this.placement,
    required this.visualSource,
  });

  final String selectionKey;
  final PlacedPrefabDef placement;
  final PrefabPolygonVisualProjection? visualSource;

  int get zIndex => placement.zIndex;
}

/// Paints a z-index partition of [ChunkPolygonVisualProjection] on the canvas.
///
/// Missing prefab definitions, slices, or image files render as deterministic
/// fallback tiles so the author can still locate the broken placement.
class ChunkPolygonVisualSource extends StatefulWidget {
  const ChunkPolygonVisualSource({
    super.key,
    required this.workspaceRootPath,
    required this.placements,
    required this.transform,
  });

  final String workspaceRootPath;
  final Iterable<ChunkPolygonPlacedVisual> placements;
  final TerrainPolygonViewportTransform transform;

  @override
  State<ChunkPolygonVisualSource> createState() =>
      _ChunkPolygonVisualSourceState();
}

class _ChunkPolygonVisualSourceState extends State<ChunkPolygonVisualSource> {
  late EditorUiImageCache _imageCache;

  @override
  void initState() {
    super.initState();
    _imageCache = EditorUiImageCache();
    _ensureImagesLoaded();
  }

  @override
  void didUpdateWidget(covariant ChunkPolygonVisualSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceRootPath != widget.workspaceRootPath) {
      _imageCache.dispose();
      _imageCache = EditorUiImageCache();
    }
    _ensureImagesLoaded();
  }

  @override
  void dispose() {
    _imageCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagesBySourcePath = <String, ui.Image>{};
    for (final placedVisual in widget.placements) {
      for (final tile
          in placedVisual.visualSource?.tiles ??
              const <PrefabPolygonVisualTile>[]) {
        final sourcePath = tile.slice?.sourceImagePath.trim();
        if (sourcePath == null || sourcePath.isEmpty) continue;
        final image = _imageCache.imageFor(_absolutePath(sourcePath));
        if (image != null) imagesBySourcePath[sourcePath] = image;
      }
    }
    return CustomPaint(
      painter: _ChunkPolygonVisualSourcePainter(
        placements: widget.placements.toList(growable: false),
        transform: widget.transform,
        imagesBySourcePath: imagesBySourcePath,
        loadedImageCount: _imageCache.loadedImageCount,
      ),
    );
  }

  void _ensureImagesLoaded() {
    final sourcePaths = <String>{};
    for (final placedVisual in widget.placements) {
      for (final tile
          in placedVisual.visualSource?.tiles ??
              const <PrefabPolygonVisualTile>[]) {
        final sourcePath = tile.slice?.sourceImagePath.trim();
        if (sourcePath != null && sourcePath.isNotEmpty) {
          sourcePaths.add(sourcePath);
        }
      }
    }
    for (final sourcePath in sourcePaths) {
      () async {
        final image = await _imageCache.ensureLoaded(_absolutePath(sourcePath));
        if (mounted && image != null) setState(() {});
      }();
    }
  }

  String _absolutePath(String sourcePath) =>
      p.normalize(p.join(widget.workspaceRootPath, sourcePath));
}

final class _ChunkPolygonVisualSourcePainter extends CustomPainter {
  const _ChunkPolygonVisualSourcePainter({
    required this.placements,
    required this.transform,
    required this.imagesBySourcePath,
    required this.loadedImageCount,
  });

  final List<ChunkPolygonPlacedVisual> placements;
  final TerrainPolygonViewportTransform transform;
  final Map<String, ui.Image> imagesBySourcePath;
  final int loadedImageCount;

  @override
  void paint(Canvas canvas, Size size) {
    for (final placedVisual in placements) {
      _paintPlacement(canvas, placedVisual);
    }
  }

  void _paintPlacement(Canvas canvas, ChunkPolygonPlacedVisual placedVisual) {
    final visualSource = placedVisual.visualSource;
    if (visualSource == null ||
        visualSource.tiles.isEmpty ||
        visualSource.visualBoundsPx.isEmpty) {
      _paintWithPlacementFlip(canvas, placedVisual, () {
        canvas.drawRect(
          _canvasRect(_fallbackRect(visualSource), placedVisual.placement),
          Paint()..color = _fallbackColor(placedVisual).withValues(alpha: 0.5),
        );
        canvas.drawRect(
          _canvasRect(_fallbackRect(visualSource), placedVisual.placement),
          Paint()
            ..color = _fallbackColor(placedVisual)
            ..style = PaintingStyle.stroke,
        );
      });
      return;
    }

    _paintWithPlacementFlip(canvas, placedVisual, () {
      for (final tile in visualSource.tiles) {
        final destination = _canvasRect(
          tile.destinationRectPx,
          placedVisual.placement,
        );
        final slice = tile.slice;
        final image = slice == null
            ? null
            : imagesBySourcePath[slice.sourceImagePath];
        if (slice != null && image != null) {
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(
              slice.x.toDouble(),
              slice.y.toDouble(),
              slice.width.toDouble(),
              slice.height.toDouble(),
            ),
            destination,
            Paint()..filterQuality = FilterQuality.none,
          );
        } else {
          canvas.drawRect(
            destination,
            Paint()..color = _fallbackColor(placedVisual),
          );
        }
      }
    });
  }

  void _paintWithPlacementFlip(
    Canvas canvas,
    ChunkPolygonPlacedVisual placedVisual,
    VoidCallback paint,
  ) {
    final placement = placedVisual.placement;
    if (!placement.flipX && !placement.flipY) {
      paint();
      return;
    }
    final anchor = Offset(
      transform.origin.dx + placement.x * transform.zoom,
      transform.origin.dy + placement.y * transform.zoom,
    );
    canvas.save();
    canvas.translate(anchor.dx, anchor.dy);
    canvas.scale(placement.flipX ? -1 : 1, placement.flipY ? -1 : 1);
    canvas.translate(-anchor.dx, -anchor.dy);
    paint();
    canvas.restore();
  }

  Rect _canvasRect(Rect localRect, PlacedPrefabDef placement) {
    final scale = _placementScale(placement);
    return Rect.fromLTRB(
      transform.origin.dx +
          (placement.x + localRect.left * scale) * transform.zoom,
      transform.origin.dy +
          (placement.y + localRect.top * scale) * transform.zoom,
      transform.origin.dx +
          (placement.x + localRect.right * scale) * transform.zoom,
      transform.origin.dy +
          (placement.y + localRect.bottom * scale) * transform.zoom,
    );
  }

  Rect _fallbackRect(PrefabPolygonVisualProjection? visualSource) {
    final bounds = visualSource?.visualBoundsPx;
    return bounds == null || bounds.isEmpty
        ? const Rect.fromLTWH(-8, -8, 16, 16)
        : bounds;
  }

  Color _fallbackColor(ChunkPolygonPlacedVisual placedVisual) {
    var hash = 0;
    for (final code in placedVisual.placement.resolvedPrefabRef.codeUnits) {
      hash = ((hash * 31) + code) & 0x7fffffff;
    }
    return HSVColor.fromAHSV(
      0.85,
      (hash % 360).toDouble(),
      0.45,
      0.8,
    ).toColor();
  }

  @override
  bool shouldRepaint(covariant _ChunkPolygonVisualSourcePainter oldDelegate) =>
      oldDelegate.placements != placements ||
      oldDelegate.transform != transform ||
      oldDelegate.loadedImageCount != loadedImageCount;
}

int _comparePlacedVisuals(
  ChunkPolygonPlacedVisual left,
  ChunkPolygonPlacedVisual right,
) {
  final zIndexOrder = left.zIndex.compareTo(right.zIndex);
  if (zIndexOrder != 0) return zIndexOrder;
  return comparePlacedPrefabsDeterministic(left.placement, right.placement);
}

double _placementScale(PlacedPrefabDef placement) =>
    placement.scale.isFinite && placement.scale > 0
    ? placement.scale
    : defaultPrefabPlacementScale;
