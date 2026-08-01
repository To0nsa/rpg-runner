import 'package:meta/meta.dart';

import 'terrain_source_models.dart';

/// Deterministic translation used to place a duplicated polygon without AABB
/// overlap against the owner's current source loops.
@immutable
class TerrainPolygonDuplicateOffset {
  const TerrainPolygonDuplicateOffset({
    required this.deltaXHalfPixels,
    required this.deltaYHalfPixels,
  });

  final int deltaXHalfPixels;
  final int deltaYHalfPixels;

  @override
  bool operator ==(Object other) =>
      other is TerrainPolygonDuplicateOffset &&
      other.deltaXHalfPixels == deltaXHalfPixels &&
      other.deltaYHalfPixels == deltaYHalfPixels;

  @override
  int get hashCode => Object.hash(deltaXHalfPixels, deltaYHalfPixels);
}

/// Finds the nearest conservative free position for a duplicate action.
///
/// Candidate coordinates are derived from existing shape bounds, snapped
/// outward to the active authoring step, and ordered deterministically. AABB
/// separation is intentionally conservative: the owner policy still performs
/// exact polygon validation on the chosen semantic commit.
TerrainPolygonDuplicateOffset? findTerrainPolygonDuplicateOffset({
  required TerrainSourceShapeDef selectedShape,
  required Iterable<TerrainSourceShapeDef> ownerShapes,
  required int snapStepHalfPixels,
  int? minXHalfPixels,
  int? minYHalfPixels,
  int? maxXHalfPixels,
  int? maxYHalfPixels,
}) {
  if (snapStepHalfPixels <= 0 || selectedShape.vertices.isEmpty) return null;
  final selectedBounds = _ShapeBounds.fromShape(selectedShape);
  final occupiedBounds = ownerShapes
      .where((shape) => shape.vertices.isNotEmpty)
      .map(_ShapeBounds.fromShape)
      .toList(growable: false);
  if (occupiedBounds.isEmpty) return null;

  final xOffsets = <int>{0};
  final yOffsets = <int>{0};
  for (final bounds in occupiedBounds) {
    xOffsets
      ..add(
        _snapOutward(
          bounds.maxX - selectedBounds.minX + snapStepHalfPixels,
          snapStepHalfPixels,
        ),
      )
      ..add(
        _snapOutward(
          bounds.minX - selectedBounds.maxX - snapStepHalfPixels,
          snapStepHalfPixels,
        ),
      );
    yOffsets
      ..add(
        _snapOutward(
          bounds.maxY - selectedBounds.minY + snapStepHalfPixels,
          snapStepHalfPixels,
        ),
      )
      ..add(
        _snapOutward(
          bounds.minY - selectedBounds.maxY - snapStepHalfPixels,
          snapStepHalfPixels,
        ),
      );
  }

  final candidates = <TerrainPolygonDuplicateOffset>[
    for (final dx in xOffsets)
      for (final dy in yOffsets)
        if (dx != 0 || dy != 0)
          TerrainPolygonDuplicateOffset(
            deltaXHalfPixels: dx,
            deltaYHalfPixels: dy,
          ),
  ]..sort(_compareOffsets);

  for (final candidate in candidates) {
    final translated = selectedBounds.translate(
      candidate.deltaXHalfPixels,
      candidate.deltaYHalfPixels,
    );
    if (minXHalfPixels != null && translated.minX < minXHalfPixels) continue;
    if (minYHalfPixels != null && translated.minY < minYHalfPixels) continue;
    if (maxXHalfPixels != null && translated.maxX > maxXHalfPixels) continue;
    if (maxYHalfPixels != null && translated.maxY > maxYHalfPixels) continue;
    if (occupiedBounds.any(translated.positivelyOverlaps)) continue;
    return candidate;
  }
  return null;
}

int _snapOutward(int value, int step) {
  if (value == 0) return 0;
  final magnitude = value.abs();
  final snapped = ((magnitude + step - 1) ~/ step) * step;
  return value.isNegative ? -snapped : snapped;
}

int _compareOffsets(
  TerrainPolygonDuplicateOffset left,
  TerrainPolygonDuplicateOffset right,
) {
  var order = _distance(left).compareTo(_distance(right));
  if (order != 0) return order;
  order = _directionRank(left).compareTo(_directionRank(right));
  if (order != 0) return order;
  order = left.deltaYHalfPixels.abs().compareTo(right.deltaYHalfPixels.abs());
  if (order != 0) return order;
  order = left.deltaXHalfPixels.compareTo(right.deltaXHalfPixels);
  if (order != 0) return order;
  return left.deltaYHalfPixels.compareTo(right.deltaYHalfPixels);
}

int _distance(TerrainPolygonDuplicateOffset offset) =>
    offset.deltaXHalfPixels.abs() + offset.deltaYHalfPixels.abs();

int _directionRank(TerrainPolygonDuplicateOffset offset) {
  final dx = offset.deltaXHalfPixels;
  final dy = offset.deltaYHalfPixels;
  if (dx > 0 && dy == 0) return 0;
  if (dx < 0 && dy == 0) return 1;
  if (dx == 0 && dy > 0) return 2;
  if (dx == 0 && dy < 0) return 3;
  return 4;
}

class _ShapeBounds {
  const _ShapeBounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  factory _ShapeBounds.fromShape(TerrainSourceShapeDef shape) {
    var minX = shape.vertices.first.xHalfPixels;
    var minY = shape.vertices.first.yHalfPixels;
    var maxX = minX;
    var maxY = minY;
    for (final vertex in shape.vertices.skip(1)) {
      if (vertex.xHalfPixels < minX) minX = vertex.xHalfPixels;
      if (vertex.yHalfPixels < minY) minY = vertex.yHalfPixels;
      if (vertex.xHalfPixels > maxX) maxX = vertex.xHalfPixels;
      if (vertex.yHalfPixels > maxY) maxY = vertex.yHalfPixels;
    }
    return _ShapeBounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
  }

  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  _ShapeBounds translate(int dx, int dy) => _ShapeBounds(
    minX: minX + dx,
    minY: minY + dy,
    maxX: maxX + dx,
    maxY: maxY + dy,
  );

  bool positivelyOverlaps(_ShapeBounds other) =>
      minX < other.maxX &&
      other.minX < maxX &&
      minY < other.maxY &&
      other.minY < maxY;
}
