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

/// Paints one world-facing endpoint/corner cap after repeating edge bands.
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
  final footprint = terrainMaterialCapFootprint(
    edgeLength: length,
    anchorX: anchorX,
    anchorY: anchorY,
    atEnd: atEnd,
    orientation: orientation,
    sourceWidth: region.width,
    sourceHeight: region.height,
  );
  canvas.save();
  if (clipPath != null) canvas.clipPath(clipPath);
  canvas.translate(start.dx, start.dy);
  canvas.rotate(math.atan2(delta.dy, delta.dx));
  _drawNormalizedRegion(
    canvas,
    image: image,
    region: region,
    destination: Offset(footprint.left, footprint.top),
    quarterTurns: terrainMaterialEdgeNormalizationQuarterTurns(orientation),
  );
  canvas.restore();
}

/// Returns the world-space rectangle exclusively owned by one cap.
///
/// The footprint includes transparent pixels. Consumers subtract it from fill
/// and edge-band clips before painting the cap so authored silhouette cutouts
/// reveal the scene instead of lower-priority terrain art.
Path terrainMaterialCapFootprintPath({
  required TerrainMaterialImageRegion region,
  required TerrainMaterialEdgeOrientation orientation,
  required Offset start,
  required Offset end,
  required double anchorX,
  required double anchorY,
  required bool atEnd,
}) {
  final delta = end - start;
  final length = delta.distance;
  if (length <= 0) return Path();
  final footprint = terrainMaterialCapFootprint(
    edgeLength: length,
    anchorX: anchorX,
    anchorY: anchorY,
    atEnd: atEnd,
    orientation: orientation,
    sourceWidth: region.width,
    sourceHeight: region.height,
  );
  return _terrainMaterialFootprintPath(
    start: start,
    end: end,
    left: footprint.left,
    top: footprint.top,
    width: footprint.width,
    height: footprint.height,
  );
}

/// Returns the world-space strip exclusively owned by one edge layer.
///
/// Consumers union base/detail footprints for a semantic edge before resolving
/// priority against adjacent edges and caps.
Path terrainMaterialEdgeFootprintPath({
  required TerrainMaterialImageRegion region,
  required TerrainMaterialEdgeOrientation orientation,
  required Offset start,
  required Offset end,
  required double anchorY,
}) {
  final delta = end - start;
  final length = delta.distance;
  if (length <= 0) return Path();
  final footprint = terrainMaterialEdgeFootprint(
    edgeLength: length,
    anchorY: anchorY,
    orientation: orientation,
    sourceWidth: region.width,
    sourceHeight: region.height,
  );
  return _terrainMaterialFootprintPath(
    start: start,
    end: end,
    left: footprint.left,
    top: footprint.top,
    width: footprint.width,
    height: footprint.height,
  );
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

/// Removes reserved region footprints from a polygon's lower-priority area.
///
/// Ownership is independent of source alpha. [ownerPath] is not mutated.
Path terrainMaterialLowerPriorityClipPath({
  required Path ownerPath,
  required Iterable<Path> reservedFootprints,
}) {
  var result = Path.from(ownerPath);
  for (final footprint in reservedFootprints) {
    if (footprint.getBounds().isEmpty) continue;
    result = Path.combine(PathOperation.difference, result, footprint);
  }
  return result;
}

/// Resolves non-overlapping clips for caps in back-to-front paint order.
///
/// A later cap owns its full footprint, including transparent pixels. Earlier
/// caps are removed from that area so thin polygons cannot expose an underside
/// corner through a higher-priority top corner.
List<Path> terrainMaterialExclusiveCapClipPaths({
  required Path ownerPath,
  required Iterable<Path> orderedCapFootprints,
}) {
  final footprints = orderedCapFootprints.toList(growable: false);
  return List<Path>.unmodifiable(<Path>[
    for (var index = 0; index < footprints.length; index += 1)
      _exclusiveCapClipPath(
        ownerPath: ownerPath,
        footprint: footprints[index],
        higherPriorityFootprints: footprints.skip(index + 1),
      ),
  ]);
}

/// Resolves exclusive edge clips in back-to-front paint order.
///
/// Later edges own overlaps, and every cap owns its footprint above every
/// edge. Complete footprints participate regardless of source alpha.
List<Path> terrainMaterialExclusiveEdgeClipPaths({
  required Path ownerPath,
  required Iterable<Path> orderedEdgeFootprints,
  required Iterable<Path> capFootprints,
}) {
  final edges = orderedEdgeFootprints.toList(growable: false);
  final caps = capFootprints.toList(growable: false);
  return List<Path>.unmodifiable(<Path>[
    for (var index = 0; index < edges.length; index += 1)
      _exclusiveCapClipPath(
        ownerPath: ownerPath,
        footprint: edges[index],
        higherPriorityFootprints: <Path>[...edges.skip(index + 1), ...caps],
      ),
  ]);
}

Path _exclusiveCapClipPath({
  required Path ownerPath,
  required Path footprint,
  required Iterable<Path> higherPriorityFootprints,
}) {
  var result = Path.combine(PathOperation.intersect, ownerPath, footprint);
  for (final higherPriorityFootprint in higherPriorityFootprints) {
    if (higherPriorityFootprint.getBounds().isEmpty) continue;
    result = Path.combine(
      PathOperation.difference,
      result,
      higherPriorityFootprint,
    );
  }
  return result;
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
