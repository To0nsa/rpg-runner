part of 'platform_module_scene_view.dart';

class _GridCell {
  const _GridCell({required this.gridX, required this.gridY});

  final int gridX;
  final int gridY;
}

class _ModuleCellHit {
  const _ModuleCellHit({
    required this.sliceId,
    required this.gridX,
    required this.gridY,
  });

  final String sliceId;
  final int gridX;
  final int gridY;
}

class _ModuleCellDragState {
  const _ModuleCellDragState({
    required this.sourceGridX,
    required this.sourceGridY,
    required this.targetGridX,
    required this.targetGridY,
    required this.sliceId,
    required this.grabOffsetWorld,
  });

  final int sourceGridX;
  final int sourceGridY;
  final int targetGridX;
  final int targetGridY;
  final String sliceId;
  final Offset grabOffsetWorld;

  _ModuleCellDragState copyWith({int? targetGridX, int? targetGridY}) {
    return _ModuleCellDragState(
      sourceGridX: sourceGridX,
      sourceGridY: sourceGridY,
      targetGridX: targetGridX ?? this.targetGridX,
      targetGridY: targetGridY ?? this.targetGridY,
      sliceId: sliceId,
      grabOffsetWorld: grabOffsetWorld,
    );
  }
}

class _PlatformModuleSceneMovePreview {
  const _PlatformModuleSceneMovePreview({
    required this.sourceGridX,
    required this.sourceGridY,
    required this.targetGridX,
    required this.targetGridY,
    required this.sliceId,
  });

  final int sourceGridX;
  final int sourceGridY;
  final int targetGridX;
  final int targetGridY;
  final String sliceId;
}

class _ModuleSceneGeometry {
  _ModuleSceneGeometry({
    required this.module,
    required this.tileSlicesById,
    required this.viewportSize,
    required this.zoom,
    required this.minimumWorldPaddingPx,
    required this.worldPaddingTileMultiplier,
    required this.canvasMargin,
  }) : tilePixels = module.tileSize <= 0 ? 16.0 : module.tileSize.toDouble() {
    moduleBoundsWorld = _computeModuleBoundsWorld();
    final moduleBounds =
        moduleBoundsWorld ??
        Rect.fromCenter(
          center: Offset.zero,
          width: tilePixels,
          height: tilePixels,
        );
    final padding = math.max(
      minimumWorldPaddingPx,
      tilePixels * worldPaddingTileMultiplier,
    );
    worldRect = Rect.fromLTRB(
      math.min(0.0, moduleBounds.left) - padding,
      math.min(0.0, moduleBounds.top) - padding,
      math.max(tilePixels, moduleBounds.right) + padding,
      math.max(tilePixels, moduleBounds.bottom) + padding,
    );

    final worldWidthPixels = worldRect.width * zoom;
    final worldHeightPixels = worldRect.height * zoom;
    final desiredWidth = worldWidthPixels + (canvasMargin * 2);
    final desiredHeight = worldHeightPixels + (canvasMargin * 2);
    canvasSize = Size(
      math.max(viewportSize.width, desiredWidth),
      math.max(viewportSize.height, desiredHeight),
    );
    worldOrigin = Offset(
      (canvasSize.width - worldWidthPixels) * 0.5,
      (canvasSize.height - worldHeightPixels) * 0.5,
    );
    worldCanvasRect = Rect.fromLTWH(
      worldOrigin.dx,
      worldOrigin.dy,
      worldWidthPixels,
      worldHeightPixels,
    );
  }

  final TileModuleDef module;
  final Map<String, AtlasSliceDef> tileSlicesById;
  final Size viewportSize;
  final double zoom;
  final double minimumWorldPaddingPx;
  final double worldPaddingTileMultiplier;
  final double canvasMargin;
  final double tilePixels;
  late final Rect worldRect;
  late final Size canvasSize;
  late final Offset worldOrigin;
  late final Rect worldCanvasRect;
  late final Rect? moduleBoundsWorld;

  _GridCell? gridCellFromLocal(Offset localPosition) {
    if (module.tileSize <= 0) {
      return null;
    }
    final world = worldFromLocal(localPosition);
    if (world == null) {
      return null;
    }
    final tileSize = module.tileSize.toDouble();
    return _GridCell(
      gridX: (world.dx / tileSize).floor(),
      gridY: (world.dy / tileSize).floor(),
    );
  }

  _ModuleCellHit? moduleCellHitFromLocal(Offset localPosition) {
    final world = worldFromLocal(localPosition);
    if (world == null) {
      return null;
    }
    for (var i = module.cells.length - 1; i >= 0; i -= 1) {
      final cell = module.cells[i];
      if (!worldRectForCell(cell).contains(world)) {
        continue;
      }
      return _ModuleCellHit(
        sliceId: cell.sliceId,
        gridX: cell.gridX,
        gridY: cell.gridY,
      );
    }
    return null;
  }

  Offset canvasFromWorld(Offset world) {
    final localX = (world.dx - worldRect.left) * zoom;
    final localY = (world.dy - worldRect.top) * zoom;
    return Offset(worldOrigin.dx + localX, worldOrigin.dy + localY);
  }

  Rect canvasRectFromWorld(Rect world) {
    final topLeft = canvasFromWorld(world.topLeft);
    return Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      world.width * zoom,
      world.height * zoom,
    );
  }

  Offset? worldFromLocal(Offset local) {
    if (!worldCanvasRect.contains(local)) {
      return null;
    }
    final worldX = worldRect.left + ((local.dx - worldOrigin.dx) / zoom);
    final worldY = worldRect.top + ((local.dy - worldOrigin.dy) / zoom);
    return Offset(worldX, worldY);
  }

  Rect worldRectForCell(TileModuleCellDef cell) {
    return worldRectForGridCell(
      gridX: cell.gridX,
      gridY: cell.gridY,
      sliceId: cell.sliceId,
    );
  }

  Rect worldRectForGridCell({
    required int gridX,
    required int gridY,
    required String sliceId,
  }) {
    final tileSize = tilePixels;
    final slice = tileSlicesById[sliceId];
    final width = math.max(1, slice?.width ?? tileSize.toInt()).toDouble();
    final height = math.max(1, slice?.height ?? tileSize.toInt()).toDouble();
    return Rect.fromLTWH(gridX * tileSize, gridY * tileSize, width, height);
  }

  Rect? _computeModuleBoundsWorld() {
    if (module.cells.isEmpty) {
      return null;
    }
    Rect? bounds;
    for (final cell in module.cells) {
      final rect = worldRectForCell(cell);
      bounds = bounds == null ? rect : bounds.expandToInclude(rect);
    }
    return bounds;
  }
}

class _PlatformModuleScenePainter extends CustomPainter {
  const _PlatformModuleScenePainter({
    required this.workspaceRootPath,
    required this.module,
    required this.tileSlicesById,
    required this.imageByAbsolutePath,
    required this.geometry,
    required this.selectedTileSliceId,
    required this.overlayValues,
    required this.activeOverlayHandle,
    required this.movePreview,
  });

  final String workspaceRootPath;
  final TileModuleDef module;
  final Map<String, AtlasSliceDef> tileSlicesById;
  final Map<String, ui.Image> imageByAbsolutePath;
  final _ModuleSceneGeometry geometry;
  final String? selectedTileSliceId;
  final PrefabSceneValues? overlayValues;
  final PrefabOverlayHandleType? activeOverlayHandle;
  final _PlatformModuleSceneMovePreview? movePreview;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF111A22),
    );

    canvas.drawRect(
      geometry.worldCanvasRect,
      Paint()
        ..color = const Color(0xFF0D131A)
        ..style = PaintingStyle.fill,
    );
    EditorViewportGridPainter(zoom: geometry.zoom).paint(canvas, size);

    if (geometry.moduleBoundsWorld != null) {
      canvas.drawRect(
        geometry.canvasRectFromWorld(geometry.moduleBoundsWorld!),
        Paint()
          ..color = const Color(0x447CE5FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    for (final cell in module.cells) {
      if (_isMovePreviewSourceCell(cell)) {
        continue;
      }
      final slice = tileSlicesById[cell.sliceId];
      final worldRect = geometry.worldRectForCell(cell);
      final canvasRect = geometry.canvasRectFromWorld(worldRect);
      final image = slice == null ? null : _resolveSliceImage(slice);

      if (slice != null && image != null) {
        final srcRect = Rect.fromLTWH(
          slice.x.toDouble(),
          slice.y.toDouble(),
          slice.width.toDouble(),
          slice.height.toDouble(),
        );
        canvas.drawImageRect(
          image,
          srcRect,
          canvasRect,
          Paint()..filterQuality = FilterQuality.none,
        );
      } else {
        canvas.drawRect(
          canvasRect,
          Paint()
            ..color = slice == null
                ? const Color(0xFF7A2A2A)
                : _fallbackColorForSlice(cell.sliceId)
            ..style = PaintingStyle.fill,
        );
      }

      canvas.drawRect(
        canvasRect,
        Paint()
          ..color = const Color(0xFF9CC6E4)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      );

      if (cell.sliceId == selectedTileSliceId) {
        canvas.drawRect(
          canvasRect.inflate(0.8),
          Paint()
            ..color = const Color(0xFFFFD166)
            ..strokeWidth = 1.4
            ..style = PaintingStyle.stroke,
        );
      }
    }
    _paintMovePreviewCell(canvas);

    _paintAnchorColliderOverlay(canvas);
  }

  bool _isMovePreviewSourceCell(TileModuleCellDef cell) {
    final preview = movePreview;
    if (preview == null) {
      return false;
    }
    return preview.sourceGridX == cell.gridX &&
        preview.sourceGridY == cell.gridY;
  }

  void _paintMovePreviewCell(Canvas canvas) {
    final preview = movePreview;
    if (preview == null) {
      return;
    }
    final slice = tileSlicesById[preview.sliceId];
    final worldRect = geometry.worldRectForGridCell(
      gridX: preview.targetGridX,
      gridY: preview.targetGridY,
      sliceId: preview.sliceId,
    );
    final canvasRect = geometry.canvasRectFromWorld(worldRect);
    final image = slice == null ? null : _resolveSliceImage(slice);

    if (slice != null && image != null) {
      final srcRect = Rect.fromLTWH(
        slice.x.toDouble(),
        slice.y.toDouble(),
        slice.width.toDouble(),
        slice.height.toDouble(),
      );
      canvas.drawImageRect(
        image,
        srcRect,
        canvasRect,
        Paint()..filterQuality = FilterQuality.none,
      );
    } else {
      canvas.drawRect(
        canvasRect,
        Paint()
          ..color = slice == null
              ? const Color(0xFF7A2A2A)
              : _fallbackColorForSlice(preview.sliceId)
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawRect(
      canvasRect,
      Paint()
        ..color = const Color(0xFF9CC6E4)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );
    canvas.drawRect(
      canvasRect.inflate(1.2),
      Paint()
        ..color = const Color(0xFF56F7A8)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );
  }

  void _paintAnchorColliderOverlay(Canvas canvas) {
    final values = overlayValues;
    final moduleBounds = geometry.moduleBoundsWorld;
    if (values == null || moduleBounds == null) {
      return;
    }
    final overlayGeometry = PrefabOverlayHandleGeometry.fromValues(
      values: values,
      anchorCanvasBase: geometry.canvasFromWorld(moduleBounds.topLeft),
      zoom: geometry.zoom,
    );
    PrefabOverlayPainter.paint(
      canvas: canvas,
      geometry: overlayGeometry,
      activeHandle: activeOverlayHandle,
    );
  }

  ui.Image? _resolveSliceImage(AtlasSliceDef slice) {
    final absolutePath = p.normalize(
      p.join(workspaceRootPath, slice.sourceImagePath),
    );
    return imageByAbsolutePath[absolutePath];
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
  bool shouldRepaint(covariant _PlatformModuleScenePainter oldDelegate) {
    return oldDelegate.module != module ||
        oldDelegate.geometry.zoom != geometry.zoom ||
        oldDelegate.selectedTileSliceId != selectedTileSliceId ||
        oldDelegate.overlayValues != overlayValues ||
        oldDelegate.activeOverlayHandle != activeOverlayHandle ||
        oldDelegate.movePreview != movePreview ||
        oldDelegate.tileSlicesById.length != tileSlicesById.length ||
        oldDelegate.imageByAbsolutePath.length != imageByAbsolutePath.length;
  }
}
