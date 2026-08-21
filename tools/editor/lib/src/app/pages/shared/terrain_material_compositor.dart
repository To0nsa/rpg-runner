import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:terrain_materials/terrain_materials.dart';

import 'terrain_material_edge_painter.dart';

/// One authored boundary passed to the shared editor terrain compositor.
final class TerrainMaterialCompositorEdge {
  const TerrainMaterialCompositorEdge({
    required this.profile,
    required this.orientation,
    required this.start,
    required this.end,
    this.startCap,
    this.endCap,
    this.endJoinBackingDepth,
  });

  final TerrainMaterialEdgeProfile profile;
  final TerrainMaterialEdgeOrientation orientation;
  final Offset start;
  final Offset end;
  final TerrainMaterialCap? startCap;
  final TerrainMaterialCap? endCap;

  /// Radius of a fill-backed generic convex join at [end].
  final double? endJoinBackingDepth;
}

/// Composes a polygon as fill, ordered edge bands, generic joins, and caps.
///
/// All terrain is first rendered into an isolated layer. Base edges and caps
/// use source replacement, so transparent authored pixels remove lower terrain
/// art without erasing the scene behind the terrain layer. Detail art overlays
/// its base normally. Narrow repeat-seam corridors and generic convex-join
/// footprints restore fill behind only transparent base pixels.
void paintTerrainMaterialComposition(
  Canvas canvas, {
  required Path ownerPath,
  required TerrainMaterialDefinition material,
  required Map<TerrainMaterialImageRegion, ui.Image> imagesByRegion,
  required Iterable<TerrainMaterialCompositorEdge> edges,
  Paint? fallbackFillPaint,
}) {
  final bounds = ownerPath.getBounds();
  if (bounds.isEmpty) return;
  final fillImage = imagesByRegion[material.fill];
  final orderedInput = edges.toList(growable: false);
  final order = terrainMaterialEdgePaintOrder(
    orderedInput.map((edge) => edge.orientation),
  );
  final orderedEdges = <TerrainMaterialCompositorEdge>[
    for (final index in order) orderedInput[index],
  ];

  canvas.saveLayer(bounds, Paint());
  if (fillImage == null) {
    canvas.drawPath(ownerPath, fallbackFillPaint ?? _missingFillPaint);
  } else {
    canvas.drawPath(ownerPath, _repeatedImagePaint(fillImage));
  }

  for (final edge in orderedEdges) {
    final baseImage = imagesByRegion[edge.profile.base.region];
    if (baseImage != null) {
      paintTerrainMaterialEdgeImage(
        canvas,
        image: baseImage,
        orientation: edge.orientation,
        start: edge.start,
        end: edge.end,
        anchorY: edge.profile.base.anchorY,
        clipPath: ownerPath,
        blendMode: BlendMode.src,
      );
      final seamPath = terrainMaterialEdgeSeamBackingPath(
        region: edge.profile.base.region,
        orientation: edge.orientation,
        start: edge.start,
        end: edge.end,
        anchorY: edge.profile.base.anchorY,
      );
      if (!seamPath.getBounds().isEmpty) {
        canvas.save();
        canvas.clipPath(ownerPath);
        canvas.clipPath(seamPath);
        final seamPaint = fillImage == null
            ? _fallbackSeamPaint(fallbackFillPaint)
            : _repeatedImagePaint(fillImage, blendMode: BlendMode.dstOver);
        canvas.drawRect(bounds, seamPaint);
        canvas.restore();
      }
    }
    final detail = edge.profile.detail;
    final detailImage = detail == null ? null : imagesByRegion[detail.region];
    if (detail != null && detailImage != null) {
      paintTerrainMaterialEdgeImage(
        canvas,
        image: detailImage,
        orientation: edge.orientation,
        start: edge.start,
        end: edge.end,
        anchorY: detail.anchorY,
        clipPath: ownerPath,
      );
    }
  }

  for (final edge in orderedEdges) {
    final depth = edge.endJoinBackingDepth;
    if (depth == null || depth <= 0) continue;
    canvas.save();
    canvas.clipPath(ownerPath);
    final joinPaint = fillImage == null
        ? _fallbackSeamPaint(fallbackFillPaint)
        : _repeatedImagePaint(fillImage, blendMode: BlendMode.dstOver);
    canvas.drawCircle(edge.end, depth, joinPaint);
    canvas.restore();
  }

  for (final edge in orderedEdges) {
    _paintCap(canvas, ownerPath, imagesByRegion, edge, edge.startCap, false);
    _paintCap(canvas, ownerPath, imagesByRegion, edge, edge.endCap, true);
  }
  canvas.restore();
}

void _paintCap(
  Canvas canvas,
  Path ownerPath,
  Map<TerrainMaterialImageRegion, ui.Image> imagesByRegion,
  TerrainMaterialCompositorEdge edge,
  TerrainMaterialCap? cap,
  bool atEnd,
) {
  if (cap == null) return;
  final image = imagesByRegion[cap.region];
  if (image == null) return;
  paintTerrainMaterialCapImage(
    canvas,
    image: image,
    orientation: edge.orientation,
    start: edge.start,
    end: edge.end,
    anchorX: cap.anchorX,
    anchorY: cap.anchorY,
    atEnd: atEnd,
    clipPath: ownerPath,
    blendMode: BlendMode.src,
  );
}

Paint _repeatedImagePaint(
  ui.Image image, {
  BlendMode blendMode = BlendMode.srcOver,
}) => Paint()
  ..filterQuality = FilterQuality.none
  ..blendMode = blendMode
  ..shader = ui.ImageShader(
    image,
    ui.TileMode.repeated,
    ui.TileMode.repeated,
    _identityMatrix,
    filterQuality: ui.FilterQuality.none,
  );

Paint _fallbackSeamPaint(Paint? source) => Paint()
  ..color = source?.color ?? _missingFillPaint.color
  ..blendMode = BlendMode.dstOver
  ..isAntiAlias = source?.isAntiAlias ?? true;

final Paint _missingFillPaint = Paint()..color = const Color(0xFF304C34);

final Float64List _identityMatrix = Float64List.fromList(<double>[
  1,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  1,
]);
