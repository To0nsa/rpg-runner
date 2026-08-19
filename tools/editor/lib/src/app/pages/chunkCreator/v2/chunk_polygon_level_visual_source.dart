import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:terrain_materials/terrain_materials.dart';

import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../parallax/parallax_domain_models.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/terrain_material_corner_layout.dart';
import '../../shared/terrain_material_edge_painter.dart';
import '../../shared/terrain_material_preview_catalog.dart';
import '../../shared/terrain_polygon_scene_painter.dart';

/// Selects the z-band for level and terrain art in the chunk scene.
enum ChunkPolygonLevelVisualLayer { background, terrain, foreground }

/// Read-only level art for the chunk polygon scene.
///
/// Chunk source owns its collision polygons and placed prefabs. The active
/// level supplies only the surrounding parallax theme, while a polygon's
/// material key selects the terrain art rendered inside that polygon. Keeping
/// this as a scene projection means pan, zoom, selection, and all source edits
/// continue to flow through the normal polygon workspace.
class ChunkPolygonLevelVisualSource extends StatefulWidget {
  const ChunkPolygonLevelVisualSource({
    super.key,
    required this.workspaceRootPath,
    required this.chunk,
    required this.parallaxTheme,
    required this.transform,
    required this.layer,
    this.terrainShapes,
  });

  final String workspaceRootPath;
  final ChunkV2FileData chunk;
  final ParallaxThemeDef? parallaxTheme;
  final TerrainPolygonViewportTransform transform;
  final ChunkPolygonLevelVisualLayer layer;

  /// Optional local authoring projection used by the terrain layer only.
  ///
  /// The committed [chunk] remains the bounds and persistence owner; this list
  /// may additionally contain uncommitted draft or gesture-preview geometry.
  final List<TerrainSourceShapeDef>? terrainShapes;

  @override
  State<ChunkPolygonLevelVisualSource> createState() =>
      _ChunkPolygonLevelVisualSourceState();
}

class _ChunkPolygonLevelVisualSourceState
    extends State<ChunkPolygonLevelVisualSource> {
  late EditorUiImageCache _imageCache;
  late TerrainMaterialCatalog? _materialCatalog;

  @override
  void initState() {
    super.initState();
    _imageCache = EditorUiImageCache();
    _materialCatalog = loadTerrainMaterialPreviewCatalog(
      widget.workspaceRootPath,
    ).catalog;
    _ensureImagesLoaded();
  }

  @override
  void didUpdateWidget(covariant ChunkPolygonLevelVisualSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceRootPath != widget.workspaceRootPath) {
      _imageCache.dispose();
      _imageCache = EditorUiImageCache();
      _materialCatalog = loadTerrainMaterialPreviewCatalog(
        widget.workspaceRootPath,
      ).catalog;
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
    for (final sourcePath in _requiredSourcePaths()) {
      final image = _imageCache.imageFor(_absolutePath(sourcePath));
      if (image != null) imagesBySourcePath[sourcePath] = image;
    }
    return CustomPaint(
      painter: _ChunkPolygonLevelVisualPainter(
        chunk: widget.chunk,
        parallaxTheme: widget.parallaxTheme,
        transform: widget.transform,
        layer: widget.layer,
        imagesBySourcePath: imagesBySourcePath,
        loadedImageCount: _imageCache.loadedImageCount,
        materialCatalog: _materialCatalog,
        terrainShapes: _terrainShapes,
      ),
    );
  }

  void _ensureImagesLoaded() {
    for (final sourcePath in _requiredSourcePaths()) {
      () async {
        final image = await _imageCache.ensureLoaded(_absolutePath(sourcePath));
        if (mounted && image != null) setState(() {});
      }();
    }
  }

  Iterable<String> _requiredSourcePaths() sync* {
    final expectedGroup = switch (widget.layer) {
      ChunkPolygonLevelVisualLayer.background => parallaxGroupBackground,
      ChunkPolygonLevelVisualLayer.foreground => parallaxGroupForeground,
      ChunkPolygonLevelVisualLayer.terrain => null,
    };
    if (expectedGroup != null) {
      final layers = widget.parallaxTheme?.layers ?? const <ParallaxLayerDef>[];
      for (final layer in layers) {
        if (layer.group == expectedGroup) yield layer.assetPath;
      }
    }
    if (widget.layer != ChunkPolygonLevelVisualLayer.terrain) return;
    for (final shape in _terrainShapes) {
      final material = terrainMaterialPreviewForKey(
        _materialCatalog,
        shape.materialKey,
      );
      if (material == null) continue;
      yield* _materialAssetPaths(material);
    }
  }

  String _absolutePath(String sourcePath) =>
      p.normalize(p.join(widget.workspaceRootPath, sourcePath));

  List<TerrainSourceShapeDef> get _terrainShapes =>
      widget.terrainShapes ?? widget.chunk.collisionShapes;
}

final class _ChunkPolygonLevelVisualPainter extends CustomPainter {
  const _ChunkPolygonLevelVisualPainter({
    required this.chunk,
    required this.parallaxTheme,
    required this.transform,
    required this.layer,
    required this.imagesBySourcePath,
    required this.loadedImageCount,
    required this.materialCatalog,
    required this.terrainShapes,
  });

  final ChunkV2FileData chunk;
  final ParallaxThemeDef? parallaxTheme;
  final TerrainPolygonViewportTransform transform;
  final ChunkPolygonLevelVisualLayer layer;
  final Map<String, ui.Image> imagesBySourcePath;
  final int loadedImageCount;
  final TerrainMaterialCatalog? materialCatalog;
  final List<TerrainSourceShapeDef> terrainShapes;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = _chunkBounds(transform, chunk);
    canvas.save();
    canvas.clipRect(bounds);
    switch (layer) {
      case ChunkPolygonLevelVisualLayer.background:
        canvas.drawRect(bounds, Paint()..color = const Color(0xFF16232D));
        _paintParallax(canvas, bounds, group: parallaxGroupBackground);
        break;
      case ChunkPolygonLevelVisualLayer.terrain:
        _paintTerrainMaterials(canvas);
        break;
      case ChunkPolygonLevelVisualLayer.foreground:
        _paintParallax(canvas, bounds, group: parallaxGroupForeground);
        break;
    }
    canvas.restore();
  }

  void _paintParallax(Canvas canvas, Rect bounds, {required String group}) {
    final layers =
        (parallaxTheme?.layers ?? const <ParallaxLayerDef>[])
            .where((layer) => layer.group == group)
            .toList(growable: false)
          ..sort(compareParallaxLayersDeterministic);
    for (final parallaxLayer in layers) {
      final image = imagesBySourcePath[parallaxLayer.assetPath];
      if (image == null) continue;
      _paintParallaxLayer(canvas, bounds, parallaxLayer, image);
    }
  }

  void _paintParallaxLayer(
    Canvas canvas,
    Rect bounds,
    ParallaxLayerDef layer,
    ui.Image image,
  ) {
    final imageWidth = image.width * transform.zoom;
    final imageHeight = image.height * transform.zoom;
    if (imageWidth <= 0 || imageHeight <= 0) return;
    final xPhase = terrainMaterialPositiveModulo(
      transform.origin.dx * (1 - layer.parallaxFactor),
      imageWidth,
    );
    final bottom = bounds.bottom + layer.yOffset * transform.zoom;
    final destinationTop = bottom - imageHeight;
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..color = Color.fromARGB((layer.opacity * 255).round(), 255, 255, 255);
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    for (
      var x = bounds.left - imageWidth + xPhase;
      x < bounds.right;
      x += imageWidth
    ) {
      canvas.drawImageRect(
        image,
        source,
        Rect.fromLTWH(x, destinationTop, imageWidth, imageHeight),
        paint,
      );
    }
  }

  void _paintTerrainMaterials(Canvas canvas) {
    canvas.save();
    canvas.translate(transform.origin.dx, transform.origin.dy);
    canvas.scale(transform.zoom);
    for (final shape in terrainShapes) {
      final material = terrainMaterialPreviewForKey(
        materialCatalog,
        shape.materialKey,
      );
      if (material == null || shape.vertices.length < 3) continue;
      final path = _sourcePath(shape.vertices);
      final edgeKinds = _edgeKinds(shape.vertices);
      final edgePaintOrder = terrainMaterialEdgePaintOrder(edgeKinds);
      final cornerCaps = resolveTerrainMaterialEdgeCornerCaps(
        shape: shape,
        material: material,
        edgeOrientations: edgeKinds,
      );
      final capPlacements =
          <
            ({
              int edgeIndex,
              bool atEnd,
              TerrainMaterialCap cap,
              ui.Image image,
              Path footprint,
            })
          >[];
      for (final index in edgePaintOrder) {
        final orientation = edgeKinds[index];
        final caps = terrainMaterialCapsForOrientation(material, orientation);
        final start = _vertexOffset(shape.vertices[index]);
        final end = _vertexOffset(
          shape.vertices[(index + 1) % shape.vertices.length],
        );
        void reserve(TerrainMaterialCap? cap, {required bool atEnd}) {
          if (cap == null) return;
          final image = imagesBySourcePath[cap.region.assetPath];
          if (image == null ||
              cap.region.right > image.width ||
              cap.region.bottom > image.height) {
            return;
          }
          capPlacements.add((
            edgeIndex: index,
            atEnd: atEnd,
            cap: cap,
            image: image,
            footprint: terrainMaterialCapFootprintPath(
              region: cap.region,
              orientation: orientation,
              start: start,
              end: end,
              anchorX: cap.anchorX,
              anchorY: cap.anchorY,
              atEnd: atEnd,
            ),
          ));
        }

        if (cornerCaps[index].start) reserve(caps.start, atEnd: false);
        if (cornerCaps[index].end) reserve(caps.end, atEnd: true);
      }
      final edgePlacements = <({int edgeIndex, Path footprint})>[];
      for (final edgeIndex in edgePaintOrder) {
        final orientation = edgeKinds[edgeIndex];
        final profile = _profileForKind(material, orientation);
        if (profile == null) continue;
        final start = _vertexOffset(shape.vertices[edgeIndex]);
        final end = _vertexOffset(
          shape.vertices[(edgeIndex + 1) % shape.vertices.length],
        );
        final layerFootprints = <Path>[];
        void reserveLayer(TerrainMaterialEdgeLayer? layer) {
          if (layer == null) return;
          final image = imagesBySourcePath[layer.region.assetPath];
          if (image == null ||
              layer.region.right > image.width ||
              layer.region.bottom > image.height) {
            return;
          }
          layerFootprints.add(
            terrainMaterialEdgeFootprintPath(
              region: layer.region,
              orientation: orientation,
              start: start,
              end: end,
              anchorY: layer.anchorY,
            ),
          );
        }

        reserveLayer(profile.base);
        reserveLayer(profile.detail);
        if (layerFootprints.isEmpty) continue;
        var footprint = layerFootprints.first;
        for (final layerFootprint in layerFootprints.skip(1)) {
          footprint = Path.combine(
            PathOperation.union,
            footprint,
            layerFootprint,
          );
        }
        edgePlacements.add((edgeIndex: edgeIndex, footprint: footprint));
      }
      final capFootprints = capPlacements
          .map((placement) => placement.footprint)
          .toList(growable: false);
      final edgeFootprints = edgePlacements
          .map((placement) => placement.footprint)
          .toList(growable: false);
      final lowerPriorityPath = terrainMaterialLowerPriorityClipPath(
        ownerPath: path,
        reservedFootprints: <Path>[...edgeFootprints, ...capFootprints],
      );
      final capClipPaths = terrainMaterialExclusiveCapClipPaths(
        ownerPath: path,
        orderedCapFootprints: capFootprints,
      );
      final edgeClipPaths = terrainMaterialExclusiveEdgeClipPaths(
        ownerPath: path,
        orderedEdgeFootprints: edgeFootprints,
        capFootprints: capFootprints,
      );
      final fill = imagesBySourcePath[material.fill.assetPath];
      if (fill == null) {
        canvas.drawPath(
          lowerPriorityPath,
          _fallbackTerrainPaint(shape.materialKey),
        );
      } else {
        _drawTiledRegionInPath(canvas, lowerPriorityPath, fill, material.fill);
      }
      for (var index = 0; index < edgePlacements.length; index += 1) {
        final edgeIndex = edgePlacements[index].edgeIndex;
        final startVertex = shape.vertices[edgeIndex];
        final endVertex =
            shape.vertices[(edgeIndex + 1) % shape.vertices.length];
        final start = _vertexOffset(startVertex);
        final end = _vertexOffset(endVertex);
        final kind = edgeKinds[edgeIndex];
        final profile = _profileForKind(material, kind);
        if (profile != null) {
          final base = imagesBySourcePath[profile.base.region.assetPath];
          if (base != null) {
            _drawEdgeImage(
              canvas,
              clipPath: edgeClipPaths[index],
              start: start,
              end: end,
              image: base,
              layer: profile.base,
              orientation: kind,
            );
          }
          final detailLayer = profile.detail;
          final detail = detailLayer == null
              ? null
              : imagesBySourcePath[detailLayer.region.assetPath];
          if (detail != null && detailLayer != null) {
            _drawEdgeImage(
              canvas,
              clipPath: edgeClipPaths[index],
              start: start,
              end: end,
              image: detail,
              layer: detailLayer,
              orientation: kind,
            );
          }
        }
      }
      for (var index = 0; index < capPlacements.length; index += 1) {
        final placement = capPlacements[index];
        final edgeIndex = placement.edgeIndex;
        final kind = edgeKinds[edgeIndex];
        final start = _vertexOffset(shape.vertices[edgeIndex]);
        final end = _vertexOffset(
          shape.vertices[(edgeIndex + 1) % shape.vertices.length],
        );
        _drawEdgeCap(
          canvas,
          clipPath: capClipPaths[index],
          edgeStart: start,
          edgeEnd: end,
          image: placement.image,
          cap: placement.cap,
          orientation: kind,
          atEnd: placement.atEnd,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChunkPolygonLevelVisualPainter oldDelegate) =>
      oldDelegate.chunk != chunk ||
      oldDelegate.parallaxTheme != parallaxTheme ||
      oldDelegate.transform != transform ||
      oldDelegate.layer != layer ||
      oldDelegate.materialCatalog != materialCatalog ||
      oldDelegate.terrainShapes != terrainShapes ||
      oldDelegate.loadedImageCount != loadedImageCount;
}

Rect _chunkBounds(
  TerrainPolygonViewportTransform transform,
  ChunkV2FileData chunk,
) {
  final topLeft = transform.sourceVertexToCanvas(
    const TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
  );
  final bottomRight = transform.sourceVertexToCanvas(
    TerrainSourceVertexDef(
      xHalfPixels: chunk.width * 2,
      yHalfPixels: chunk.height * 2,
    ),
  );
  return Rect.fromPoints(topLeft, bottomRight);
}

Path _sourcePath(List<TerrainSourceVertexDef> vertices) {
  final first = vertices.first;
  final path = Path()..moveTo(first.xHalfPixels * 0.5, first.yHalfPixels * 0.5);
  for (final vertex in vertices.skip(1)) {
    path.lineTo(vertex.xHalfPixels * 0.5, vertex.yHalfPixels * 0.5);
  }
  return path..close();
}

List<TerrainMaterialEdgeOrientation> _edgeKinds(
  List<TerrainSourceVertexDef> vertices,
) {
  final signedArea = _signedArea(vertices);
  final kinds = <TerrainMaterialEdgeOrientation>[];
  for (var index = 0; index < vertices.length; index += 1) {
    final start = _vertexOffset(vertices[index]);
    final end = _vertexOffset(vertices[(index + 1) % vertices.length]);
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final outwardX = signedArea >= 0 ? dy : -dy;
    final outwardY = signedArea >= 0 ? -dx : dx;
    kinds.add(
      outwardY < 0
          ? TerrainMaterialEdgeOrientation.top
          : outwardY > 0
          ? TerrainMaterialEdgeOrientation.underside
          : outwardX < 0
          ? TerrainMaterialEdgeOrientation.leftWall
          : TerrainMaterialEdgeOrientation.rightWall,
    );
  }
  return kinds;
}

Offset _vertexOffset(TerrainSourceVertexDef vertex) =>
    Offset(vertex.xHalfPixels * 0.5, vertex.yHalfPixels * 0.5);

TerrainMaterialEdgeProfile? _profileForKind(
  TerrainMaterialDefinition material,
  TerrainMaterialEdgeOrientation kind,
) => switch (kind) {
  TerrainMaterialEdgeOrientation.top => material.top,
  TerrainMaterialEdgeOrientation.leftWall => material.leftWall,
  TerrainMaterialEdgeOrientation.rightWall => material.rightWall,
  TerrainMaterialEdgeOrientation.underside => material.underside,
};

double _signedArea(List<TerrainSourceVertexDef> vertices) {
  var area = 0.0;
  for (var index = 0; index < vertices.length; index += 1) {
    final left = vertices[index];
    final right = vertices[(index + 1) % vertices.length];
    area +=
        left.xHalfPixels * right.yHalfPixels -
        right.xHalfPixels * left.yHalfPixels;
  }
  return area;
}

void _drawEdgeImage(
  Canvas canvas, {
  required Path clipPath,
  required Offset start,
  required Offset end,
  required ui.Image image,
  required TerrainMaterialEdgeLayer layer,
  required TerrainMaterialEdgeOrientation orientation,
}) => paintTerrainMaterialEdgeRegion(
  canvas,
  image: image,
  region: layer.region,
  orientation: orientation,
  start: start,
  end: end,
  anchorY: layer.anchorY,
  clipPath: clipPath,
);

void _drawEdgeCap(
  Canvas canvas, {
  required Path clipPath,
  required Offset edgeStart,
  required Offset edgeEnd,
  required ui.Image image,
  required TerrainMaterialCap cap,
  required TerrainMaterialEdgeOrientation orientation,
  required bool atEnd,
}) => paintTerrainMaterialCapRegion(
  canvas,
  image: image,
  region: cap.region,
  orientation: orientation,
  start: edgeStart,
  end: edgeEnd,
  anchorX: cap.anchorX,
  anchorY: cap.anchorY,
  atEnd: atEnd,
  clipPath: clipPath,
);

Iterable<String> _materialAssetPaths(TerrainMaterialDefinition material) =>
    terrainMaterialAssetPaths(material);

void _drawTiledRegionInPath(
  Canvas canvas,
  Path path,
  ui.Image image,
  TerrainMaterialImageRegion region,
) {
  final bounds = path.getBounds();
  final source = Rect.fromLTWH(
    region.x.toDouble(),
    region.y.toDouble(),
    region.width.toDouble(),
    region.height.toDouble(),
  );
  final startX = terrainMaterialTileStart(bounds.left, region.width.toDouble());
  final startY = terrainMaterialTileStart(bounds.top, region.height.toDouble());
  final paint = Paint()..filterQuality = FilterQuality.none;
  canvas.save();
  canvas.clipPath(path);
  for (var y = startY; y < bounds.bottom; y += region.height) {
    for (var x = startX; x < bounds.right; x += region.width) {
      canvas.drawImageRect(
        image,
        source,
        Rect.fromLTWH(x, y, region.width.toDouble(), region.height.toDouble()),
        paint,
      );
    }
  }
  canvas.restore();
}

Paint _fallbackTerrainPaint(String? materialKey) =>
    Paint()
      ..color = Color(0xFF304C34 + ((materialKey?.hashCode ?? 0) & 0x000B0B0B));
