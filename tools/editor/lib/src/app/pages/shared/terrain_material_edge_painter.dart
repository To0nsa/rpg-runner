import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:terrain_materials/terrain_materials.dart';

/// Paints one world-facing atlas region along an authored terrain edge.
///
/// Role normalization is shared with runtime math, so axis-aligned art retains
/// its atlas orientation while sloped art follows the actual edge tangent.
/// When supplied, [clipPath] is in scene/world coordinates and confines the
/// complete edge band to its owning polygon.
void paintTerrainMaterialEdgeRegion(
  Canvas canvas, {
  required ui.Image image,
  required TerrainMaterialImageRegion region,
  required TerrainMaterialEdgeOrientation orientation,
  required Offset start,
  required Offset end,
  required double anchorY,
  Path? clipPath,
}) {
  if (region.right > image.width || region.bottom > image.height) return;
  final delta = end - start;
  final length = delta.distance;
  if (length <= 0) return;
  final angle = math.atan2(delta.dy, delta.dx);
  final tileWidth = terrainMaterialEdgeTileWidth(
    orientation: orientation,
    sourceWidth: region.width,
    sourceHeight: region.height,
  ).toDouble();
  final tileHeight = terrainMaterialEdgeTileHeight(
    orientation: orientation,
    sourceWidth: region.width,
    sourceHeight: region.height,
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
      region: region,
      destination: Offset(x, -anchorY),
      quarterTurns: quarterTurns,
    );
  }
  canvas.restore();
}

/// Paints one world-facing endpoint cap after repeating edge bands.
///
/// When supplied, [clipPath] prevents the rectangular cap image from crossing
/// another boundary of its owning polygon.
void paintTerrainMaterialCapRegion(
  Canvas canvas, {
  required ui.Image image,
  required TerrainMaterialImageRegion region,
  required TerrainMaterialEdgeOrientation orientation,
  required Offset start,
  required Offset end,
  required double anchorX,
  required double anchorY,
  required bool atEnd,
  Path? clipPath,
}) {
  if (region.right > image.width || region.bottom > image.height) return;
  final delta = end - start;
  final length = delta.distance;
  if (length <= 0) return;
  canvas.save();
  if (clipPath != null) canvas.clipPath(clipPath);
  canvas.translate(start.dx, start.dy);
  canvas.rotate(math.atan2(delta.dy, delta.dx));
  _drawNormalizedRegion(
    canvas,
    image: image,
    region: region,
    destination: Offset((atEnd ? length : 0) - anchorX, -anchorY),
    quarterTurns: terrainMaterialEdgeNormalizationQuarterTurns(orientation),
  );
  canvas.restore();
}

void _drawNormalizedRegion(
  Canvas canvas, {
  required ui.Image image,
  required TerrainMaterialImageRegion region,
  required Offset destination,
  required int quarterTurns,
}) {
  canvas.save();
  switch (quarterTurns) {
    case 0:
      canvas.translate(destination.dx, destination.dy);
    case 1:
      canvas.translate(destination.dx + region.height, destination.dy);
      canvas.rotate(math.pi / 2);
    case 2:
      canvas.translate(
        destination.dx + region.width,
        destination.dy + region.height,
      );
      canvas.rotate(math.pi);
    case 3:
      canvas.translate(destination.dx, destination.dy + region.width);
      canvas.rotate(-math.pi / 2);
    default:
      throw ArgumentError.value(
        quarterTurns,
        'quarterTurns',
        'Must be within [0, 3].',
      );
  }
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(
      region.x.toDouble(),
      region.y.toDouble(),
      region.width.toDouble(),
      region.height.toDouble(),
    ),
    Rect.fromLTWH(0, 0, region.width.toDouble(), region.height.toDouble()),
    _edgePaint,
  );
  canvas.restore();
}

final Paint _edgePaint = Paint()..filterQuality = FilterQuality.none;
