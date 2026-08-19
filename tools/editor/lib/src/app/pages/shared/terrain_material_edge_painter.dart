import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:terrain_materials/terrain_materials.dart';

/// Paints one isolated, world-facing image along an authored terrain edge.
///
/// Role normalization is shared with runtime math, so axis-aligned art retains
/// its atlas orientation while sloped art follows the actual edge tangent.
/// When supplied, [clipPath] is in scene/world coordinates and confines the
/// complete edge band to its owning polygon.
void paintTerrainMaterialEdgeImage(
  Canvas canvas, {
  required ui.Image image,
  required TerrainMaterialEdgeOrientation orientation,
  required Offset start,
  required Offset end,
  required double anchorY,
  Path? clipPath,
  BlendMode blendMode = BlendMode.srcOver,
}) {
  final delta = end - start;
  final length = delta.distance;
  if (length <= 0) return;
  final angle = math.atan2(delta.dy, delta.dx);
  final tileWidth = terrainMaterialEdgeTileWidth(
    orientation: orientation,
    sourceWidth: image.width,
    sourceHeight: image.height,
  ).toDouble();
  final tileHeight = terrainMaterialEdgeTileHeight(
    orientation: orientation,
    sourceWidth: image.width,
    sourceHeight: image.height,
  ).toDouble();
  final phase = terrainMaterialEdgeRepeatPhase(
    startX: start.dx,
    startY: start.dy,
    tangentX: delta.dx / length,
    tangentY: delta.dy / length,
    repeatWidth: tileWidth,
  );
  final quarterTurns = terrainMaterialEdgeNormalizationQuarterTurns(
    orientation,
  );
  final firstTileX = terrainMaterialTileStart(phase, tileWidth) - phase;

  canvas.save();
  if (clipPath != null) canvas.clipPath(clipPath);
  canvas.translate(start.dx, start.dy);
  canvas.rotate(angle);
  canvas.clipRect(Rect.fromLTWH(0, -anchorY, length, tileHeight));
  for (var x = firstTileX; x < length; x += tileWidth) {
    _drawNormalizedRegion(
      canvas,
      image: image,
      destination: Offset(x, -anchorY),
      quarterTurns: quarterTurns,
      blendMode: blendMode,
    );
  }
  canvas.restore();
}

/// Paints one world-facing endpoint/corner cap after repeating edge bands.
///
/// When supplied, [clipPath] prevents the rectangular cap image from crossing
/// another boundary of its owning polygon.
void paintTerrainMaterialCapImage(
  Canvas canvas, {
  required ui.Image image,
  required TerrainMaterialEdgeOrientation orientation,
  required Offset start,
  required Offset end,
  required double anchorX,
  required double anchorY,
  required bool atEnd,
  Path? clipPath,
  BlendMode blendMode = BlendMode.srcOver,
}) {
  final delta = end - start;
  final length = delta.distance;
  if (length <= 0) return;
  final footprint = terrainMaterialCapFootprint(
    edgeLength: length,
    anchorX: anchorX,
    anchorY: anchorY,
    atEnd: atEnd,
    orientation: orientation,
    sourceWidth: image.width,
    sourceHeight: image.height,
  );
  canvas.save();
  if (clipPath != null) canvas.clipPath(clipPath);
  canvas.translate(start.dx, start.dy);
  canvas.rotate(math.atan2(delta.dy, delta.dx));
  _drawNormalizedRegion(
    canvas,
    image: image,
    destination: Offset(footprint.left, footprint.top),
    quarterTurns: terrainMaterialEdgeNormalizationQuarterTurns(orientation),
    blendMode: blendMode,
  );
  canvas.restore();
}

/// Returns narrow edge-local corridors backing internal repeat boundaries.
///
/// The corridors cover one source pixel from each neighboring cell. They do
/// not include authored edge endpoints or the rest of the transparent
/// silhouette.
Path terrainMaterialEdgeSeamBackingPath({
  required TerrainMaterialImageRegion region,
  required TerrainMaterialEdgeOrientation orientation,
  required Offset start,
  required Offset end,
  required double anchorY,
}) {
  final delta = end - start;
  final length = delta.distance;
  if (length <= 0) return Path();
  final tangent = delta / length;
  final footprint = terrainMaterialEdgeFootprint(
    edgeLength: length,
    anchorY: anchorY,
    orientation: orientation,
    sourceWidth: region.width,
    sourceHeight: region.height,
  );
  final repeatWidth = terrainMaterialEdgeTileWidth(
    orientation: orientation,
    sourceWidth: region.width,
    sourceHeight: region.height,
  ).toDouble();
  final seams = terrainMaterialEdgeRepeatSeamOffsets(
    startX: start.dx,
    startY: start.dy,
    tangentX: tangent.dx,
    tangentY: tangent.dy,
    edgeLength: length,
    repeatWidth: repeatWidth,
  );
  final result = Path();
  for (final seam in seams) {
    final left = math.max(
      0.0,
      seam - terrainMaterialRepeatSeamBackingHalfWidth,
    );
    final right = math.min(
      length,
      seam + terrainMaterialRepeatSeamBackingHalfWidth,
    );
    result.addPath(
      _terrainMaterialFootprintPath(
        start: start,
        end: end,
        left: left,
        top: footprint.top,
        width: right - left,
        height: footprint.height,
      ),
      Offset.zero,
    );
  }
  return result;
}

Path _terrainMaterialFootprintPath({
  required Offset start,
  required Offset end,
  required double left,
  required double top,
  required double width,
  required double height,
}) {
  final delta = end - start;
  final length = delta.distance;
  if (length <= 0) return Path();
  final tangent = delta / length;
  Offset toWorld(double x, double y) => Offset(
    start.dx + x * tangent.dx - y * tangent.dy,
    start.dy + x * tangent.dy + y * tangent.dx,
  );
  final right = left + width;
  final bottom = top + height;
  final topLeft = toWorld(left, top);
  final path = Path()..moveTo(topLeft.dx, topLeft.dy);
  for (final point in <Offset>[
    toWorld(right, top),
    toWorld(right, bottom),
    toWorld(left, bottom),
  ]) {
    path.lineTo(point.dx, point.dy);
  }
  return path..close();
}

void _drawNormalizedRegion(
  Canvas canvas, {
  required ui.Image image,
  required Offset destination,
  required int quarterTurns,
  required BlendMode blendMode,
}) {
  canvas.save();
  switch (quarterTurns) {
    case 0:
      canvas.translate(destination.dx, destination.dy);
    case 1:
      canvas.translate(destination.dx + image.height, destination.dy);
      canvas.rotate(math.pi / 2);
    case 2:
      canvas.translate(
        destination.dx + image.width,
        destination.dy + image.height,
      );
      canvas.rotate(math.pi);
    case 3:
      canvas.translate(destination.dx, destination.dy + image.width);
      canvas.rotate(-math.pi / 2);
    default:
      throw ArgumentError.value(
        quarterTurns,
        'quarterTurns',
        'Must be within [0, 3].',
      );
  }
  canvas.drawImage(
    image,
    Offset.zero,
    blendMode == BlendMode.src ? _sourcePaint : _edgePaint,
  );
  canvas.restore();
}

final Paint _edgePaint = Paint()..filterQuality = FilterQuality.none;
final Paint _sourcePaint = Paint()
  ..filterQuality = FilterQuality.none
  ..blendMode = BlendMode.src;
