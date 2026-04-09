import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../prefabs/models/models.dart';
import 'editor_scene_view_utils.dart';

/// Shared platform-module thumbnail used by module- and prefab-authoring lists.
class PlatformModulePreviewTile extends StatefulWidget {
  const PlatformModulePreviewTile({
    super.key,
    required this.imageCache,
    required this.workspaceRootPath,
    required this.module,
    required this.tileSlicesById,
    this.width = 72,
    this.height = 56,
  });

  final EditorUiImageCache imageCache;
  final String workspaceRootPath;
  final TileModuleDef? module;
  final Map<String, AtlasSliceDef> tileSlicesById;
  final double width;
  final double height;

  @override
  State<PlatformModulePreviewTile> createState() =>
      _PlatformModulePreviewTileState();
}

class _PlatformModulePreviewTileState extends State<PlatformModulePreviewTile> {
  Map<String, ui.Image> _imagesByPath = <String, ui.Image>{};
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _refreshImages();
  }

  @override
  void didUpdateWidget(covariant PlatformModulePreviewTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module != widget.module ||
        oldWidget.workspaceRootPath != widget.workspaceRootPath ||
        oldWidget.imageCache != widget.imageCache ||
        oldWidget.tileSlicesById != widget.tileSlicesById) {
      _refreshImages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF101820),
          border: Border.all(color: const Color(0xFF29404F)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: module == null
              ? const Center(
                  child: Icon(Icons.dashboard_customize_outlined, size: 18),
                )
              : CustomPaint(
                  painter: _PlatformModulePreviewPainter(
                    workspaceRootPath: widget.workspaceRootPath,
                    module: module,
                    tileSlicesById: widget.tileSlicesById,
                    imagesByPath: _imagesByPath,
                  ),
                ),
        ),
      ),
    );
  }

  void _refreshImages() {
    final loadGeneration = ++_loadGeneration;
    final requiredPaths = <String>{};
    final imagesByPath = <String, ui.Image>{};
    final module = widget.module;
    if (module != null) {
      for (final cell in module.cells) {
        final slice = widget.tileSlicesById[cell.sliceId];
        if (slice == null) {
          continue;
        }
        final absolutePath = _absolutePathForSlice(slice);
        requiredPaths.add(absolutePath);
        final cachedImage = widget.imageCache.imageFor(absolutePath);
        if (cachedImage != null) {
          imagesByPath[absolutePath] = cachedImage;
        }
      }
    }

    _imagesByPath = imagesByPath;
    final missingPaths = requiredPaths
        .where((path) => !imagesByPath.containsKey(path))
        .toList(growable: false);
    if (missingPaths.isEmpty) {
      if (mounted) {
        setState(() {});
      }
      return;
    }
    if (mounted) {
      setState(() {});
    }
    unawaited(_loadMissingImages(loadGeneration, missingPaths));
  }

  Future<void> _loadMissingImages(
    int loadGeneration,
    List<String> missingPaths,
  ) async {
    final loadedEntries = await Future.wait(
      missingPaths.map((path) async {
        final image = await widget.imageCache.ensureLoaded(path);
        return MapEntry<String, ui.Image?>(path, image);
      }),
    );
    if (!mounted || loadGeneration != _loadGeneration) {
      return;
    }
    setState(() {
      for (final entry in loadedEntries) {
        final image = entry.value;
        if (image != null) {
          _imagesByPath[entry.key] = image;
        }
      }
    });
  }

  String _absolutePathForSlice(AtlasSliceDef slice) {
    return p.normalize(p.join(widget.workspaceRootPath, slice.sourceImagePath));
  }
}

class _PlatformModulePreviewPainter extends CustomPainter {
  const _PlatformModulePreviewPainter({
    required this.workspaceRootPath,
    required this.module,
    required this.tileSlicesById,
    required this.imagesByPath,
  });

  final String workspaceRootPath;
  final TileModuleDef module;
  final Map<String, AtlasSliceDef> tileSlicesById;
  final Map<String, ui.Image> imagesByPath;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0D131A),
    );

    if (module.cells.isEmpty) {
      final placeholderRect = Rect.fromCenter(
        center: size.center(Offset.zero),
        width: size.width * 0.42,
        height: size.height * 0.42,
      );
      canvas.drawRect(
        placeholderRect,
        Paint()..color = const Color(0xFF173041),
      );
      canvas.drawRect(
        placeholderRect,
        Paint()
          ..color = const Color(0xFF5E8199)
          ..style = PaintingStyle.stroke,
      );
      return;
    }

    final tileSize = module.tileSize <= 0 ? 16.0 : module.tileSize.toDouble();
    final bounds =
        _computeModuleBounds(tileSize) ??
        Rect.fromLTWH(0, 0, tileSize, tileSize);
    final previewWorldRect = bounds.inflate(tileSize * 0.2);
    final fittedSizes = applyBoxFit(
      BoxFit.contain,
      previewWorldRect.size,
      size,
    );
    final previewCanvasRect = Alignment.center.inscribe(
      fittedSizes.destination,
      Offset.zero & size,
    );
    final scaleX = previewCanvasRect.width / previewWorldRect.width;
    final scaleY = previewCanvasRect.height / previewWorldRect.height;

    for (final cell in module.cells) {
      final slice = tileSlicesById[cell.sliceId];
      final worldCellRect = _worldRectForCell(cell, tileSize, slice);
      final outputRect = Rect.fromLTWH(
        previewCanvasRect.left +
            ((worldCellRect.left - previewWorldRect.left) * scaleX),
        previewCanvasRect.top +
            ((worldCellRect.top - previewWorldRect.top) * scaleY),
        worldCellRect.width * scaleX,
        worldCellRect.height * scaleY,
      );
      final image = slice == null ? null : _resolveSliceImage(slice);

      if (slice != null && image != null) {
        final sourceRect = Rect.fromLTWH(
          slice.x.toDouble(),
          slice.y.toDouble(),
          slice.width.toDouble(),
          slice.height.toDouble(),
        );
        canvas.drawImageRect(
          image,
          sourceRect,
          outputRect,
          Paint()..filterQuality = FilterQuality.none,
        );
      } else {
        canvas.drawRect(
          outputRect,
          Paint()
            ..color = slice == null
                ? const Color(0xFF7A2A2A)
                : _fallbackColorForSlice(cell.sliceId)
            ..style = PaintingStyle.fill,
        );
      }

      canvas.drawRect(
        outputRect,
        Paint()
          ..color = const Color(0xAA9CC6E4)
          ..style = PaintingStyle.stroke,
      );
    }

    canvas.drawRect(
      previewCanvasRect,
      Paint()
        ..color = const Color(0x4420404F)
        ..style = PaintingStyle.stroke,
    );
  }

  Rect? _computeModuleBounds(double tileSize) {
    Rect? bounds;
    for (final cell in module.cells) {
      final rect = _worldRectForCell(
        cell,
        tileSize,
        tileSlicesById[cell.sliceId],
      );
      bounds = bounds == null ? rect : bounds.expandToInclude(rect);
    }
    return bounds;
  }

  Rect _worldRectForCell(
    TileModuleCellDef cell,
    double tileSize,
    AtlasSliceDef? slice,
  ) {
    final width = (slice?.width ?? tileSize).toDouble();
    final height = (slice?.height ?? tileSize).toDouble();
    return Rect.fromLTWH(
      cell.gridX * tileSize,
      cell.gridY * tileSize,
      width,
      height,
    );
  }

  ui.Image? _resolveSliceImage(AtlasSliceDef slice) {
    final absolutePath = p.normalize(
      p.join(workspaceRootPath, slice.sourceImagePath),
    );
    return imagesByPath[absolutePath];
  }

  Color _fallbackColorForSlice(String sliceId) {
    var hash = 0;
    for (final code in sliceId.codeUnits) {
      hash = ((hash * 31) + code) & 0x7fffffff;
    }
    final hue = (hash % 360).toDouble();
    return HSVColor.fromAHSV(1.0, hue, 0.45, 0.85).toColor();
  }

  @override
  bool shouldRepaint(covariant _PlatformModulePreviewPainter oldDelegate) {
    return oldDelegate.module != module ||
        oldDelegate.workspaceRootPath != workspaceRootPath ||
        oldDelegate.tileSlicesById.length != tileSlicesById.length ||
        oldDelegate.imagesByPath.length != imagesByPath.length;
  }
}
