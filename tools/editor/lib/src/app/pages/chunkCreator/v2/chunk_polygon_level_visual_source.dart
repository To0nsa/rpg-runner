import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../parallax/parallax_domain_models.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';
import '../../shared/editor_scene_view_utils.dart';
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
  });

  final String workspaceRootPath;
  final ChunkV2FileData chunk;
  final ParallaxThemeDef? parallaxTheme;
  final TerrainPolygonViewportTransform transform;
  final ChunkPolygonLevelVisualLayer layer;

  @override
  State<ChunkPolygonLevelVisualSource> createState() =>
      _ChunkPolygonLevelVisualSourceState();
}

class _ChunkPolygonLevelVisualSourceState
    extends State<ChunkPolygonLevelVisualSource> {
  late EditorUiImageCache _imageCache;

  @override
  void initState() {
    super.initState();
    _imageCache = EditorUiImageCache();
    _ensureImagesLoaded();
  }

  @override
  void didUpdateWidget(covariant ChunkPolygonLevelVisualSource oldWidget) {
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
    for (final shape in widget.chunk.collisionShapes) {
      final material = terrainMaterialPreviewAssetsForKey(shape.materialKey);
      if (material == null) continue;
      yield material.fillAssetPath;
      yield material.surfaceAssetPath;
      yield material.foregroundAssetPath;
    }
  }

  String _absolutePath(String sourcePath) =>
      p.normalize(p.join(widget.workspaceRootPath, sourcePath));
}

final class _ChunkPolygonLevelVisualPainter extends CustomPainter {
  const _ChunkPolygonLevelVisualPainter({
    required this.chunk,
    required this.parallaxTheme,
    required this.transform,
    required this.layer,
    required this.imagesBySourcePath,
    required this.loadedImageCount,
  });

  final ChunkV2FileData chunk;
  final ParallaxThemeDef? parallaxTheme;
  final TerrainPolygonViewportTransform transform;
  final ChunkPolygonLevelVisualLayer layer;
  final Map<String, ui.Image> imagesBySourcePath;
  final int loadedImageCount;

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
    final xPhase = _positiveModulo(
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
    for (final shape in chunk.collisionShapes) {
      final material = terrainMaterialPreviewAssetsForKey(shape.materialKey);
      if (material == null || shape.vertices.length < 3) continue;
      final fill = imagesBySourcePath[material.fillAssetPath];
      final surface = imagesBySourcePath[material.surfaceAssetPath];
      final foreground = imagesBySourcePath[material.foregroundAssetPath];
      final path = _sourcePath(shape.vertices);
      if (fill == null) {
        canvas.drawPath(path, _fallbackTerrainPaint(shape.materialKey));
      } else {
        canvas.drawPath(path, _tiledFillPaint(fill));
      }
      if (surface == null && foreground == null) continue;
      for (final edge in _upwardEdges(shape.vertices)) {
        if (surface != null) {
          _drawEdgeImage(
            canvas,
            start: edge.$1,
            end: edge.$2,
            image: surface,
            anchorY: material.surfaceAnchorY,
          );
        }
        if (foreground != null) {
          _drawEdgeImage(
            canvas,
            start: edge.$1,
            end: edge.$2,
            image: foreground,
            anchorY: 0,
          );
        }
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
      oldDelegate.loadedImageCount != loadedImageCount;
}

@immutable
final class TerrainMaterialPreviewAssets {
  const TerrainMaterialPreviewAssets({
    required this.materialKey,
    required this.fillAssetPath,
    required this.surfaceAssetPath,
    required this.foregroundAssetPath,
    required this.surfaceAnchorY,
  });

  final String materialKey;
  final String fillAssetPath;
  final String surfaceAssetPath;
  final String foregroundAssetPath;
  final double surfaceAnchorY;
}

/// Visual asset projection for the renderable terrain material keys.
///
/// The editor is a standalone package, so it cannot import the app's runtime
/// registry. Keep this read-only projection aligned when a new runtime terrain
/// material is introduced; its source polygons remain the gameplay authority.
/// TODO(rpg_runner): replace this projection with an authored material manifest
/// when terrain-material authoring becomes a supported editor domain.
@visibleForTesting
TerrainMaterialPreviewAssets? terrainMaterialPreviewAssetsForKey(
  String? materialKey,
) => _terrainMaterialPreviewAssetsByKey[materialKey?.trim()];

const Map<String, TerrainMaterialPreviewAssets>
_terrainMaterialPreviewAssetsByKey = <String, TerrainMaterialPreviewAssets>{
  'grass_dirt': TerrainMaterialPreviewAssets(
    materialKey: 'grass_dirt',
    fillAssetPath: 'assets/images/terrain/grass_dirt/fill.png',
    surfaceAssetPath: 'assets/images/terrain/grass_dirt/surface.png',
    foregroundAssetPath: 'assets/images/terrain/grass_dirt/foreground.png',
    surfaceAnchorY: 12,
  ),
};

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

Iterable<(Offset, Offset)> _upwardEdges(
  List<TerrainSourceVertexDef> vertices,
) sync* {
  final signedArea = _signedArea(vertices);
  for (var index = 0; index < vertices.length; index += 1) {
    final startVertex = vertices[index];
    final endVertex = vertices[(index + 1) % vertices.length];
    final start = Offset(
      startVertex.xHalfPixels * 0.5,
      startVertex.yHalfPixels * 0.5,
    );
    final end = Offset(
      endVertex.xHalfPixels * 0.5,
      endVertex.yHalfPixels * 0.5,
    );
    final dx = end.dx - start.dx;
    if ((signedArea >= 0 && dx > 0) || (signedArea < 0 && dx < 0)) {
      yield (start, end);
    }
  }
}

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
  required Offset start,
  required Offset end,
  required ui.Image image,
  required double anchorY,
}) {
  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  final length = math.sqrt(dx * dx + dy * dy);
  if (length <= 0) return;
  final imageWidth = image.width.toDouble();
  final imageHeight = image.height.toDouble();
  final phase = _positiveModulo(start.dx, imageWidth);
  canvas.save();
  canvas.translate(start.dx, start.dy);
  canvas.rotate(math.atan2(dy, dx));
  canvas.clipRect(Rect.fromLTWH(0, -anchorY, length, imageHeight));
  for (var x = -phase; x < length; x += imageWidth) {
    canvas.drawImage(
      image,
      Offset(x, -anchorY),
      Paint()..filterQuality = FilterQuality.none,
    );
  }
  canvas.restore();
}

Paint _tiledFillPaint(ui.Image image) => Paint()
  ..filterQuality = FilterQuality.none
  ..shader = ui.ImageShader(
    image,
    ui.TileMode.repeated,
    ui.TileMode.repeated,
    _identityMatrix,
    filterQuality: ui.FilterQuality.none,
  );

Paint _fallbackTerrainPaint(String? materialKey) =>
    Paint()
      ..color = Color(0xFF304C34 + ((materialKey?.hashCode ?? 0) & 0x000B0B0B));

double _positiveModulo(double value, double divisor) {
  final remainder = value % divisor;
  return remainder < 0 ? remainder + divisor : remainder;
}

final Float64List _identityMatrix = Float64List.fromList(<double>[
  1, 0, 0, 0, //
  0, 1, 0, 0, //
  0, 0, 1, 0, //
  0, 0, 0, 1,
]);
