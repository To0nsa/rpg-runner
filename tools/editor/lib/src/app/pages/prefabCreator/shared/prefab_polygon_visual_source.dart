import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/models/models.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/terrain_polygon_scene_painter.dart';

/// One visual-source tile projected into prefab-local pixel coordinates.
@immutable
final class PrefabPolygonVisualTile {
  const PrefabPolygonVisualTile({
    required this.sourceId,
    required this.destinationRectPx,
    this.slice,
  });

  final String sourceId;
  final Rect destinationRectPx;
  final AtlasSliceDef? slice;
}

/// Immutable prefab-local projection shared by atlas and module previews.
///
/// Prefab collision vertices are relative to the prefab anchor. Visual source
/// top-left is therefore `(-anchorX, -anchorY)`. Platform-module cells are
/// normalized against their complete (possibly negative) module bounds before
/// the same anchor offset is applied.
@immutable
final class PrefabPolygonVisualProjection {
  PrefabPolygonVisualProjection({
    required this.visualBoundsPx,
    required Iterable<PrefabPolygonVisualTile> tiles,
  }) : tiles = List<PrefabPolygonVisualTile>.unmodifiable(tiles);

  factory PrefabPolygonVisualProjection.fromDocument({
    required PrefabV3Document document,
    required PrefabV3Def prefab,
  }) {
    final resolvedBounds = document.visualBoundsByPrefabKey[prefab.prefabKey];
    final visualBoundsPx = Rect.fromLTWH(
      -prefab.anchorXPx.toDouble(),
      -prefab.anchorYPx.toDouble(),
      resolvedBounds?.widthPx.toDouble() ?? 0,
      resolvedBounds?.heightPx.toDouble() ?? 0,
    );

    if (prefab.usesAtlasSlice) {
      final slice = _findSlice(document.data.slices, prefab.sliceId);
      return PrefabPolygonVisualProjection(
        visualBoundsPx: visualBoundsPx,
        tiles: <PrefabPolygonVisualTile>[
          PrefabPolygonVisualTile(
            sourceId: prefab.sliceId,
            destinationRectPx: visualBoundsPx,
            slice: slice,
          ),
        ],
      );
    }

    final module = _findModule(
      document.tileData.platformModules,
      prefab.moduleId,
    );
    if (module == null || module.cells.isEmpty) {
      return PrefabPolygonVisualProjection(
        visualBoundsPx: visualBoundsPx,
        tiles: const <PrefabPolygonVisualTile>[],
      );
    }

    final slicesById = <String, AtlasSliceDef>{
      for (final slice in document.tileData.tileSlices) slice.id: slice,
    };
    Rect? moduleBounds;
    final sourceRects = <Rect>[];
    for (final cell in module.cells) {
      final slice = slicesById[cell.sliceId];
      final rect = Rect.fromLTWH(
        cell.gridX * module.tileSize.toDouble(),
        cell.gridY * module.tileSize.toDouble(),
        math.max(1, slice?.width ?? module.tileSize).toDouble(),
        math.max(1, slice?.height ?? module.tileSize).toDouble(),
      );
      sourceRects.add(rect);
      moduleBounds = moduleBounds == null
          ? rect
          : moduleBounds.expandToInclude(rect);
    }
    final bounds = moduleBounds!;
    final tiles = <PrefabPolygonVisualTile>[];
    for (var index = 0; index < module.cells.length; index += 1) {
      final cell = module.cells[index];
      final sourceRect = sourceRects[index];
      tiles.add(
        PrefabPolygonVisualTile(
          sourceId: cell.sliceId,
          destinationRectPx: Rect.fromLTWH(
            visualBoundsPx.left + sourceRect.left - bounds.left,
            visualBoundsPx.top + sourceRect.top - bounds.top,
            sourceRect.width,
            sourceRect.height,
          ),
          slice: slicesById[cell.sliceId],
        ),
      );
    }
    return PrefabPolygonVisualProjection(
      visualBoundsPx: visualBoundsPx,
      tiles: tiles,
    );
  }

  final Rect visualBoundsPx;
  final List<PrefabPolygonVisualTile> tiles;
}

/// Workspace-scoped decoded visual source below the polygon interaction layer.
class PrefabPolygonVisualSource extends StatefulWidget {
  const PrefabPolygonVisualSource({
    super.key,
    required this.workspaceRootPath,
    required this.projection,
    required this.transform,
  });

  final String workspaceRootPath;
  final PrefabPolygonVisualProjection projection;
  final TerrainPolygonViewportTransform transform;

  @override
  State<PrefabPolygonVisualSource> createState() =>
      _PrefabPolygonVisualSourceState();
}

class _PrefabPolygonVisualSourceState extends State<PrefabPolygonVisualSource> {
  late EditorUiImageCache _imageCache;

  @override
  void initState() {
    super.initState();
    _imageCache = EditorUiImageCache();
    _ensureImagesLoaded();
  }

  @override
  void didUpdateWidget(covariant PrefabPolygonVisualSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceRootPath != widget.workspaceRootPath) {
      _imageCache.dispose();
      _imageCache = EditorUiImageCache();
    }
    if (oldWidget.workspaceRootPath != widget.workspaceRootPath ||
        !identical(oldWidget.projection, widget.projection)) {
      _ensureImagesLoaded();
    }
  }

  @override
  void dispose() {
    _imageCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagesByPath = <String, ui.Image>{};
    for (final tile in widget.projection.tiles) {
      final sourcePath = tile.slice?.sourceImagePath.trim();
      if (sourcePath == null || sourcePath.isEmpty) continue;
      final absolutePath = _absolutePath(sourcePath);
      final image = _imageCache.imageFor(absolutePath);
      if (image != null) imagesByPath[sourcePath] = image;
    }
    return CustomPaint(
      key: const ValueKey<String>('prefab_polygon_visual_source'),
      painter: _PrefabPolygonVisualSourcePainter(
        projection: widget.projection,
        transform: widget.transform,
        imagesByPath: imagesByPath,
        loadedImageCount: _imageCache.loadedImageCount,
      ),
    );
  }

  void _ensureImagesLoaded() {
    final sourcePaths = widget.projection.tiles
        .map((tile) => tile.slice?.sourceImagePath.trim())
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toSet();
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

final class _PrefabPolygonVisualSourcePainter extends CustomPainter {
  const _PrefabPolygonVisualSourcePainter({
    required this.projection,
    required this.transform,
    required this.imagesByPath,
    required this.loadedImageCount,
  });

  final PrefabPolygonVisualProjection projection;
  final TerrainPolygonViewportTransform transform;
  final Map<String, ui.Image> imagesByPath;
  final int loadedImageCount;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF111A22),
    );
    _paintGrid(canvas, size);
    for (final tile in projection.tiles) {
      final destination = _canvasRect(tile.destinationRectPx);
      final slice = tile.slice;
      final image = slice == null ? null : imagesByPath[slice.sourceImagePath];
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
          Paint()..color = _fallbackColor(tile.sourceId),
        );
      }
    }

    if (!projection.visualBoundsPx.isEmpty) {
      canvas.drawRect(
        _canvasRect(projection.visualBoundsPx),
        Paint()
          ..color = const Color(0xCCFFFFFF)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
    }
    _paintAnchor(canvas);
  }

  void _paintGrid(Canvas canvas, Size size) {
    final zoom = transform.zoom;
    final spacingPx = zoom >= 4 ? zoom : zoom * 16;
    final sourceStep = zoom >= 4 ? 1 : 16;
    final startX =
        ((-transform.origin.dx / zoom) / sourceStep).floor() * sourceStep;
    final endX =
        (((size.width - transform.origin.dx) / zoom) / sourceStep).ceil() *
        sourceStep;
    final startY =
        ((-transform.origin.dy / zoom) / sourceStep).floor() * sourceStep;
    final endY =
        (((size.height - transform.origin.dy) / zoom) / sourceStep).ceil() *
        sourceStep;
    final paint = Paint()
      ..color = const Color(0x249FB4C7)
      ..strokeWidth = 1;
    for (var x = startX; x <= endX; x += sourceStep) {
      final canvasX = transform.origin.dx + x * zoom;
      canvas.drawLine(Offset(canvasX, 0), Offset(canvasX, size.height), paint);
    }
    for (var y = startY; y <= endY; y += sourceStep) {
      final canvasY = transform.origin.dy + y * zoom;
      canvas.drawLine(Offset(0, canvasY), Offset(size.width, canvasY), paint);
    }
    if (spacingPx <= 0) return;
  }

  void _paintAnchor(Canvas canvas) {
    final anchor = transform.origin;
    final paint = Paint()
      ..color = const Color(0xFFFFD166)
      ..strokeWidth = 1.5;
    canvas.drawCircle(anchor, 5, Paint()..color = const Color(0xFF111A22));
    canvas.drawCircle(anchor, 5, paint..style = PaintingStyle.stroke);
    canvas.drawLine(
      anchor - const Offset(8, 0),
      anchor + const Offset(8, 0),
      paint,
    );
    canvas.drawLine(
      anchor - const Offset(0, 8),
      anchor + const Offset(0, 8),
      paint,
    );
  }

  Rect _canvasRect(Rect sourceRectPx) => Rect.fromLTRB(
    transform.origin.dx + sourceRectPx.left * transform.zoom,
    transform.origin.dy + sourceRectPx.top * transform.zoom,
    transform.origin.dx + sourceRectPx.right * transform.zoom,
    transform.origin.dy + sourceRectPx.bottom * transform.zoom,
  );

  Color _fallbackColor(String sourceId) {
    var hash = 0;
    for (final code in sourceId.codeUnits) {
      hash = ((hash * 31) + code) & 0x7fffffff;
    }
    return HSVColor.fromAHSV(0.8, (hash % 360).toDouble(), 0.45, 0.7).toColor();
  }

  @override
  bool shouldRepaint(covariant _PrefabPolygonVisualSourcePainter oldDelegate) =>
      !identical(oldDelegate.projection, projection) ||
      oldDelegate.transform != transform ||
      oldDelegate.loadedImageCount != loadedImageCount;
}

AtlasSliceDef? _findSlice(Iterable<AtlasSliceDef> slices, String id) {
  for (final slice in slices) {
    if (slice.id == id) return slice;
  }
  return null;
}

TileModuleDef? _findModule(Iterable<TileModuleDef> modules, String id) {
  for (final module in modules) {
    if (module.id == id) return module;
  }
  return null;
}
