import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:terrain_materials/terrain_materials.dart';

import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../parallax/parallax_domain_models.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/terrain_material_corner_layout.dart';
import '../../shared/terrain_material_compositor.dart';
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
    final imagesByRegion = <TerrainMaterialImageRegion, ui.Image>{};
    for (final region in _requiredMaterialRegions()) {
      final image = _imageCache.regionImageFor(
        _absolutePath(region.assetPath),
        x: region.x,
        y: region.y,
        width: region.width,
        height: region.height,
      );
      if (image != null) imagesByRegion[region] = image;
    }
    return CustomPaint(
      painter: _ChunkPolygonLevelVisualPainter(
        chunk: widget.chunk,
        parallaxTheme: widget.parallaxTheme,
        transform: widget.transform,
        layer: widget.layer,
        imagesBySourcePath: imagesBySourcePath,
        imagesByRegion: imagesByRegion,
        loadedImageCount:
            _imageCache.loadedImageCount + _imageCache.loadedRegionImageCount,
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
    for (final region in _requiredMaterialRegions()) {
      () async {
        final image = await _imageCache.ensureRegionLoaded(
          _absolutePath(region.assetPath),
          x: region.x,
          y: region.y,
          width: region.width,
          height: region.height,
        );
        if (mounted && image != null) setState(() {});
      }();
    }
  }

  Iterable<TerrainMaterialImageRegion> _requiredMaterialRegions() sync* {
    if (widget.layer != ChunkPolygonLevelVisualLayer.terrain) return;
    for (final shape in _terrainShapes) {
      final material = terrainMaterialPreviewForKey(
        _materialCatalog,
        shape.materialKey,
      );
      if (material != null) yield* terrainMaterialRegions(material);
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
    required this.imagesByRegion,
    required this.loadedImageCount,
    required this.materialCatalog,
    required this.terrainShapes,
  });

  final ChunkV2FileData chunk;
  final ParallaxThemeDef? parallaxTheme;
  final TerrainPolygonViewportTransform transform;
  final ChunkPolygonLevelVisualLayer layer;
  final Map<String, ui.Image> imagesBySourcePath;
  final Map<TerrainMaterialImageRegion, ui.Image> imagesByRegion;
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
      final cornerLayout = resolveTerrainMaterialEdgeCornerLayout(
        shape: shape,
        material: material,
        edgeOrientations: edgeKinds,
      );
      final edges = <TerrainMaterialCompositorEdge>[];
      for (var edgeIndex = 0; edgeIndex < edgeKinds.length; edgeIndex += 1) {
        final orientation = edgeKinds[edgeIndex];
        final profile = _profileForKind(material, orientation);
        if (profile == null) continue;
        final start = _vertexOffset(shape.vertices[edgeIndex]);
        final end = _vertexOffset(
          shape.vertices[(edgeIndex + 1) % shape.vertices.length],
        );
        final caps = terrainMaterialCapsForOrientation(material, orientation);
        edges.add(
          TerrainMaterialCompositorEdge(
            profile: profile,
            orientation: orientation,
            start: start,
            end: end,
            startCap: cornerLayout[edgeIndex].startCap ? caps.start : null,
            endCap: cornerLayout[edgeIndex].endCap ? caps.end : null,
            endJoinBackingDepth: cornerLayout[edgeIndex].endJoinBackingDepth,
          ),
        );
      }
      paintTerrainMaterialComposition(
        canvas,
        ownerPath: path,
        material: material,
        imagesByRegion: imagesByRegion,
        edges: edges,
        fallbackFillPaint: _fallbackTerrainPaint(shape.materialKey),
      );
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

Paint _fallbackTerrainPaint(String? materialKey) =>
    Paint()
      ..color = Color(0xFF304C34 + ((materialKey?.hashCode ?? 0) & 0x000B0B0B));
