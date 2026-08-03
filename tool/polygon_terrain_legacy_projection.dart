import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';

import 'polygon_terrain_compilation.dart';

const int legacyTerrainGridWorldUnits = 16;

/// One stable blocker from the temporary rectangle/gap compatibility bridge.
final class PolygonTerrainLegacyProjectionIssue
    implements Comparable<PolygonTerrainLegacyProjectionIssue> {
  const PolygonTerrainLegacyProjectionIssue({
    required this.code,
    required this.message,
    required this.chunkKey,
    required this.shapeId,
    this.placementKey,
    this.elementIndex = 0,
  });

  final String code;
  final String message;
  final String chunkKey;
  final String? placementKey;
  final String shapeId;
  final int elementIndex;

  @override
  int compareTo(PolygonTerrainLegacyProjectionIssue other) {
    var order = chunkKey.compareTo(other.chunkKey);
    if (order != 0) return order;
    order = _compareNullable(placementKey, other.placementKey);
    if (order != 0) return order;
    order = shapeId.compareTo(other.shapeId);
    if (order != 0) return order;
    order = elementIndex.compareTo(other.elementIndex);
    return order != 0 ? order : code.compareTo(other.code);
  }
}

/// One canonical grid-snapped rectangle for the legacy `SolidRel` bridge.
final class PolygonTerrainLegacyRectangle
    implements Comparable<PolygonTerrainLegacyRectangle> {
  const PolygonTerrainLegacyRectangle({
    required this.x,
    required this.topY,
    required this.width,
    required this.height,
    required this.collisionMode,
  });

  final int x;
  final int topY;
  final int width;
  final int height;
  final TerrainCollisionMode collisionMode;

  int get right => x + width;
  int get bottom => topY + height;

  @override
  int compareTo(PolygonTerrainLegacyRectangle other) {
    var order = topY.compareTo(other.topY);
    if (order != 0) return order;
    order = x.compareTo(other.x);
    if (order != 0) return order;
    order = collisionMode.index.compareTo(other.collisionMode.index);
    if (order != 0) return order;
    order = width.compareTo(other.width);
    return order != 0 ? order : height.compareTo(other.height);
  }
}

/// One gap cut from the legacy infinite ground plane.
final class PolygonTerrainLegacyGap {
  const PolygonTerrainLegacyGap({
    required this.gapId,
    required this.x,
    required this.width,
  });

  final String gapId;
  final int x;
  final int width;
}

/// Complete temporary legacy projection for one accepted staged chunk.
final class PolygonTerrainLegacyProjection {
  PolygonTerrainLegacyProjection({
    required this.chunkKey,
    required this.groundTopY,
    required Iterable<PolygonTerrainLegacyRectangle> rectangles,
    required Iterable<PolygonTerrainLegacyGap> groundGaps,
    required this.snappedSolidArea,
  }) : rectangles = List<PolygonTerrainLegacyRectangle>.unmodifiable(
         rectangles,
       ),
       groundGaps = List<PolygonTerrainLegacyGap>.unmodifiable(groundGaps);

  final String chunkKey;
  final int groundTopY;
  final List<PolygonTerrainLegacyRectangle> rectangles;
  final List<PolygonTerrainLegacyGap> groundGaps;

  /// Exact occupied area of the snapped solid rectangle union in pixel².
  final BigInt snappedSolidArea;
}

/// Fail-closed projection result; issues never coexist with fabricated data.
final class PolygonTerrainLegacyProjectionResult {
  PolygonTerrainLegacyProjectionResult({
    required this.projection,
    required Iterable<PolygonTerrainLegacyProjectionIssue> issues,
  }) : issues = List<PolygonTerrainLegacyProjectionIssue>.unmodifiable(
         List<PolygonTerrainLegacyProjectionIssue>.of(issues)..sort(),
       );

  final PolygonTerrainLegacyProjection? projection;
  final List<PolygonTerrainLegacyProjectionIssue> issues;
}

/// Builds the bounded Phase 4 rectangle/gap bridge from compiled local terrain.
PolygonTerrainLegacyProjectionResult projectPolygonTerrainToLegacy({
  required PolygonTerrainCompiledChunk compiled,
  required int legacyGroundTopY,
  int gridWorldUnits = legacyTerrainGridWorldUnits,
}) {
  final chunk = compiled.chunk;
  final issues = <PolygonTerrainLegacyProjectionIssue>[];
  if (legacyGroundTopY < 0 || legacyGroundTopY >= chunk.height) {
    issues.add(
      _chunkIssue(
        compiled,
        code: 'legacy_ground_top_out_of_bounds',
        message: 'Legacy ground top must lie inside the chunk height.',
      ),
    );
  }
  if (gridWorldUnits <= 0) {
    issues.add(
      _chunkIssue(
        compiled,
        code: 'legacy_grid_invalid',
        message: 'Legacy projection grid must be positive.',
      ),
    );
  }
  if (issues.isNotEmpty) return _failure(issues);

  final groundSpans = <_PixelSpan>[];
  final snappedSolidInputs = <_PixelRectangle>[];
  final snappedOneWay = <_PixelRectangle>[];
  for (final polygon in compiled.geometry.polygons) {
    final decomposition = _decomposePolygon(polygon, issues);
    if (decomposition == null) continue;
    if (_isMigratedGround(polygon)) {
      _collectGroundSpan(
        polygon: polygon,
        rectangles: decomposition,
        chunkHeight: chunk.height,
        legacyGroundTopY: legacyGroundTopY,
        output: groundSpans,
        issues: issues,
      );
      continue;
    }
    if (polygon.collisionMode == TerrainCollisionMode.oneWay &&
        decomposition.length != 1) {
      issues.add(
        _polygonIssue(
          polygon,
          code: 'legacy_one_way_shape_unrepresentable',
          message:
              'Legacy one-way collision requires one axis-aligned rectangle.',
        ),
      );
      continue;
    }
    for (final rectangle in decomposition) {
      final snapped = _snapRectangle(rectangle, gridWorldUnits: gridWorldUnits);
      if (snapped.x < 0 || snapped.right > chunk.width) {
        issues.add(
          _polygonIssue(
            polygon,
            code: 'legacy_rectangle_out_of_bounds',
            message:
                'Grid-snapped legacy rectangle lies outside chunk X bounds.',
          ),
        );
        continue;
      }
      if (snapped.topY > legacyGroundTopY) {
        issues.add(
          _polygonIssue(
            polygon,
            code: 'legacy_rectangle_below_ground_top',
            message: 'Grid-snapped legacy rectangle top lies below ground top.',
          ),
        );
        continue;
      }
      if (polygon.collisionMode == TerrainCollisionMode.oneWay) {
        snappedOneWay.add(snapped);
      } else {
        snappedSolidInputs.add(snapped);
      }
    }
  }

  final groundGaps = _deriveGroundGaps(
    compiled: compiled,
    spans: groundSpans,
    gridWorldUnits: gridWorldUnits,
    issues: issues,
  );
  _validateOneWayOverlap(
    compiled,
    oneWayRectangles: snappedOneWay,
    solidRectangles: snappedSolidInputs,
    issues: issues,
  );
  if (issues.isNotEmpty) return _failure(issues);

  final solidArea = _unionArea(snappedSolidInputs);
  final canonicalSolids = _decomposeRectangleUnion(snappedSolidInputs);
  final decomposedArea = canonicalSolids.fold<BigInt>(
    BigInt.zero,
    (sum, rectangle) => sum + rectangle.area,
  );
  if (decomposedArea != solidArea) {
    return _failure(<PolygonTerrainLegacyProjectionIssue>[
      _chunkIssue(
        compiled,
        code: 'legacy_rectangle_area_mismatch',
        message:
            'Canonical legacy rectangles changed snapped occupied solid area.',
      ),
    ]);
  }

  final rectangles = <PolygonTerrainLegacyRectangle>[
    ...canonicalSolids.map(
      (rectangle) => rectangle.toProjection(TerrainCollisionMode.solid),
    ),
    ...snappedOneWay.map(
      (rectangle) => rectangle.toProjection(TerrainCollisionMode.oneWay),
    ),
  ]..sort();
  return PolygonTerrainLegacyProjectionResult(
    projection: PolygonTerrainLegacyProjection(
      chunkKey: chunk.chunkKey,
      groundTopY: legacyGroundTopY,
      rectangles: rectangles,
      groundGaps: groundGaps,
      snappedSolidArea: solidArea,
    ),
    issues: const <PolygonTerrainLegacyProjectionIssue>[],
  );
}

List<_PhysicsRectangle>? _decomposePolygon(
  TerrainPolygon polygon,
  List<PolygonTerrainLegacyProjectionIssue> issues,
) {
  final vertices = polygon.vertices;
  for (var index = 0; index < vertices.length; index += 1) {
    final start = vertices[index];
    final end = vertices[(index + 1) % vertices.length];
    if (start.xTicks != end.xTicks && start.yTicks != end.yTicks) {
      issues.add(
        _polygonIssue(
          polygon,
          code: 'legacy_diagonal_edge',
          message: 'A diagonal edge cannot be approximated by legacy AABBs.',
          elementIndex: index,
        ),
      );
    }
  }
  if (issues.any(
    (issue) =>
        issue.chunkKey == polygon.identity.chunkKey &&
        issue.placementKey == polygon.identity.placementKey &&
        issue.shapeId == polygon.identity.shapeId,
  )) {
    return null;
  }

  final xs = vertices.map((point) => point.xTicks).toSet().toList()..sort();
  final ys = vertices.map((point) => point.yTicks).toSet().toList()..sort();
  final occupied = List<List<bool>>.generate(
    ys.length - 1,
    (y) => List<bool>.generate(
      xs.length - 1,
      (x) => _pointInsidePolygon(
        xTwice: xs[x] + xs[x + 1],
        yTwice: ys[y] + ys[y + 1],
        polygon: polygon,
      ),
      growable: false,
    ),
    growable: false,
  );
  final rectangles = _decomposeCells(occupied, xs, ys)
      .map(
        (rectangle) => _PhysicsRectangle(
          leftTicks: rectangle.left,
          topTicks: rectangle.top,
          rightTicks: rectangle.right,
          bottomTicks: rectangle.bottom,
        ),
      )
      .toList(growable: false);
  final expectedArea = _polygonArea(vertices).abs() ~/ BigInt.two;
  final actualArea = rectangles.fold<BigInt>(
    BigInt.zero,
    (sum, rectangle) => sum + rectangle.area,
  );
  if (expectedArea != actualArea) {
    issues.add(
      _polygonIssue(
        polygon,
        code: 'legacy_polygon_area_mismatch',
        message:
            'Orthogonal decomposition changed exact polygon occupied area.',
      ),
    );
    return null;
  }
  return rectangles;
}

void _collectGroundSpan({
  required TerrainPolygon polygon,
  required List<_PhysicsRectangle> rectangles,
  required int chunkHeight,
  required int legacyGroundTopY,
  required List<_PixelSpan> output,
  required List<PolygonTerrainLegacyProjectionIssue> issues,
}) {
  if (polygon.collisionMode != TerrainCollisionMode.solid ||
      rectangles.length != 1) {
    issues.add(
      _polygonIssue(
        polygon,
        code: 'legacy_ground_shape_unrepresentable',
        message:
            'Migrated ground must be one solid axis-aligned bottom-band rectangle.',
      ),
    );
    return;
  }
  final rectangle = rectangles.single;
  final expectedTop = legacyGroundTopY * terrainPhysicsTicksPerWorldUnit;
  final expectedBottom = chunkHeight * terrainPhysicsTicksPerWorldUnit;
  if (rectangle.topTicks != expectedTop ||
      rectangle.bottomTicks != expectedBottom ||
      !_wholeWorldUnit(rectangle.leftTicks) ||
      !_wholeWorldUnit(rectangle.rightTicks)) {
    issues.add(
      _polygonIssue(
        polygon,
        code: 'legacy_ground_shape_unrepresentable',
        message:
            'Migrated ground must exactly span ground top to chunk bottom in whole pixels.',
      ),
    );
    return;
  }
  output.add(
    _PixelSpan(
      rectangle.leftTicks ~/ terrainPhysicsTicksPerWorldUnit,
      rectangle.rightTicks ~/ terrainPhysicsTicksPerWorldUnit,
    ),
  );
}

List<PolygonTerrainLegacyGap> _deriveGroundGaps({
  required PolygonTerrainCompiledChunk compiled,
  required List<_PixelSpan> spans,
  required int gridWorldUnits,
  required List<PolygonTerrainLegacyProjectionIssue> issues,
}) {
  spans.sort();
  final merged = <_PixelSpan>[];
  for (final span in spans) {
    if (span.left < 0 || span.right > compiled.chunk.width || span.isEmpty) {
      issues.add(
        _chunkIssue(
          compiled,
          code: 'legacy_ground_span_out_of_bounds',
          message: 'Migrated ground span lies outside chunk bounds.',
        ),
      );
      continue;
    }
    if (merged.isNotEmpty && span.left < merged.last.right) {
      issues.add(
        _chunkIssue(
          compiled,
          code: 'legacy_ground_span_overlap',
          message: 'Migrated ground spans overlap.',
        ),
      );
      continue;
    }
    if (merged.isNotEmpty && span.left == merged.last.right) {
      merged[merged.length - 1] = _PixelSpan(merged.last.left, span.right);
    } else {
      merged.add(span);
    }
  }

  final gapSpans = <_PixelSpan>[];
  var cursor = 0;
  for (final span in merged) {
    if (cursor < span.left) gapSpans.add(_PixelSpan(cursor, span.left));
    cursor = span.right;
  }
  if (cursor < compiled.chunk.width) {
    gapSpans.add(_PixelSpan(cursor, compiled.chunk.width));
  }
  for (final gap in gapSpans) {
    final removesAllGround = gap.left == 0 && gap.width == compiled.chunk.width;
    if (!removesAllGround &&
        (gap.left % gridWorldUnits != 0 || gap.width % gridWorldUnits != 0)) {
      issues.add(
        _chunkIssue(
          compiled,
          code: 'legacy_ground_gap_grid_mismatch',
          message:
              'Derived legacy ground gaps must align to the $gridWorldUnits-pixel grid.',
        ),
      );
    }
  }
  return List<PolygonTerrainLegacyGap>.generate(
    gapSpans.length,
    (index) => PolygonTerrainLegacyGap(
      gapId:
          gapSpans.length == 1 &&
              gapSpans.single.left == 0 &&
              gapSpans.single.width == compiled.chunk.width
          ? 'collision_cleared'
          : 'gap_${index + 1}',
      x: gapSpans[index].left,
      width: gapSpans[index].width,
    ),
    growable: false,
  );
}

void _validateOneWayOverlap(
  PolygonTerrainCompiledChunk compiled, {
  required List<_PixelRectangle> oneWayRectangles,
  required List<_PixelRectangle> solidRectangles,
  required List<PolygonTerrainLegacyProjectionIssue> issues,
}) {
  oneWayRectangles.sort();
  for (var left = 0; left < oneWayRectangles.length; left += 1) {
    for (var right = left + 1; right < oneWayRectangles.length; right += 1) {
      if (oneWayRectangles[left].overlaps(oneWayRectangles[right])) {
        issues.add(
          _chunkIssue(
            compiled,
            code: 'legacy_one_way_snap_overlap',
            message: 'Grid snapping makes distinct one-way rectangles overlap.',
          ),
        );
      }
    }
  }
  if (oneWayRectangles.any((oneWay) => solidRectangles.any(oneWay.overlaps))) {
    issues.add(
      _chunkIssue(
        compiled,
        code: 'legacy_mixed_mode_snap_overlap',
        message: 'Grid snapping makes solid and one-way rectangles overlap.',
      ),
    );
  }
}

List<_PixelRectangle> _decomposeRectangleUnion(
  List<_PixelRectangle> rectangles,
) {
  if (rectangles.isEmpty) return const <_PixelRectangle>[];
  final xs = <int>{};
  final ys = <int>{};
  for (final rectangle in rectangles) {
    xs
      ..add(rectangle.x)
      ..add(rectangle.right);
    ys
      ..add(rectangle.topY)
      ..add(rectangle.bottom);
  }
  final orderedX = xs.toList()..sort();
  final orderedY = ys.toList()..sort();
  final occupied = List<List<bool>>.generate(
    orderedY.length - 1,
    (y) => List<bool>.generate(
      orderedX.length - 1,
      (x) => rectangles.any(
        (rectangle) =>
            rectangle.x <= orderedX[x] &&
            rectangle.right >= orderedX[x + 1] &&
            rectangle.topY <= orderedY[y] &&
            rectangle.bottom >= orderedY[y + 1],
      ),
      growable: false,
    ),
    growable: false,
  );
  return _decomposeCells(occupied, orderedX, orderedY)
      .map(
        (rectangle) => _PixelRectangle(
          x: rectangle.left,
          topY: rectangle.top,
          width: rectangle.right - rectangle.left,
          height: rectangle.bottom - rectangle.top,
        ),
      )
      .toList(growable: false);
}

List<_CellRectangle> _decomposeCells(
  List<List<bool>> occupied,
  List<int> xs,
  List<int> ys,
) {
  if (occupied.isEmpty || occupied.first.isEmpty) {
    return const <_CellRectangle>[];
  }
  final used = List<List<bool>>.generate(
    occupied.length,
    (y) => List<bool>.filled(occupied[y].length, false),
    growable: false,
  );
  final output = <_CellRectangle>[];
  for (var y = 0; y < occupied.length; y += 1) {
    for (var x = 0; x < occupied[y].length; x += 1) {
      if (!occupied[y][x] || used[y][x]) continue;
      var right = x;
      while (right < occupied[y].length &&
          occupied[y][right] &&
          !used[y][right]) {
        right += 1;
      }
      var bottom = y + 1;
      while (bottom < occupied.length &&
          _rowAvailable(occupied, used, bottom, x, right)) {
        bottom += 1;
      }
      for (var fillY = y; fillY < bottom; fillY += 1) {
        for (var fillX = x; fillX < right; fillX += 1) {
          used[fillY][fillX] = true;
        }
      }
      output.add(
        _CellRectangle(
          left: xs[x],
          top: ys[y],
          right: xs[right],
          bottom: ys[bottom],
        ),
      );
    }
  }
  return output;
}

bool _rowAvailable(
  List<List<bool>> occupied,
  List<List<bool>> used,
  int y,
  int left,
  int right,
) {
  for (var x = left; x < right; x += 1) {
    if (!occupied[y][x] || used[y][x]) return false;
  }
  return true;
}

bool _pointInsidePolygon({
  required int xTwice,
  required int yTwice,
  required TerrainPolygon polygon,
}) {
  var inside = false;
  final vertices = polygon.vertices;
  for (var index = 0; index < vertices.length; index += 1) {
    final start = vertices[index];
    final end = vertices[(index + 1) % vertices.length];
    if (start.xTicks != end.xTicks) continue;
    final minY = start.yTicks < end.yTicks ? start.yTicks : end.yTicks;
    final maxY = start.yTicks > end.yTicks ? start.yTicks : end.yTicks;
    if (yTwice >= minY * 2 && yTwice < maxY * 2 && start.xTicks * 2 > xTwice) {
      inside = !inside;
    }
  }
  return inside;
}

_PixelRectangle _snapRectangle(
  _PhysicsRectangle rectangle, {
  required int gridWorldUnits,
}) {
  final gridTicks = gridWorldUnits * terrainPhysicsTicksPerWorldUnit;
  return _PixelRectangle(
    x:
        _roundToMultiple(rectangle.leftTicks, gridTicks) ~/
        terrainPhysicsTicksPerWorldUnit,
    topY:
        _roundToMultiple(rectangle.topTicks, gridTicks) ~/
        terrainPhysicsTicksPerWorldUnit,
    width:
        _positiveSnap(rectangle.widthTicks, gridTicks) ~/
        terrainPhysicsTicksPerWorldUnit,
    height:
        _positiveSnap(rectangle.heightTicks, gridTicks) ~/
        terrainPhysicsTicksPerWorldUnit,
  );
}

int _positiveSnap(int value, int step) {
  final snapped = _roundToMultiple(value.abs(), step);
  return snapped <= 0 ? step : snapped;
}

int _roundToMultiple(int value, int step) {
  final sign = value.isNegative ? -1 : 1;
  final magnitude = value.abs();
  var quotient = magnitude ~/ step;
  final remainder = magnitude % step;
  if (remainder * 2 >= step) quotient += 1;
  return sign * quotient * step;
}

BigInt _unionArea(List<_PixelRectangle> rectangles) {
  if (rectangles.isEmpty) return BigInt.zero;
  return _decomposeRectangleUnion(
    rectangles,
  ).fold<BigInt>(BigInt.zero, (sum, rectangle) => sum + rectangle.area);
}

BigInt _polygonArea(List<TerrainPoint> vertices) {
  var area = BigInt.zero;
  for (var index = 0; index < vertices.length; index += 1) {
    final current = vertices[index];
    final next = vertices[(index + 1) % vertices.length];
    area +=
        BigInt.from(current.xTicks) * BigInt.from(next.yTicks) -
        BigInt.from(next.xTicks) * BigInt.from(current.yTicks);
  }
  return area;
}

bool _isMigratedGround(TerrainPolygon polygon) =>
    polygon.identity.placementKey == null &&
    polygon.identity.shapeId.startsWith('ground_');

bool _wholeWorldUnit(int ticks) => ticks % terrainPhysicsTicksPerWorldUnit == 0;

PolygonTerrainLegacyProjectionIssue _polygonIssue(
  TerrainPolygon polygon, {
  required String code,
  required String message,
  int elementIndex = 0,
}) => PolygonTerrainLegacyProjectionIssue(
  code: code,
  message: message,
  chunkKey: polygon.identity.chunkKey,
  placementKey: polygon.identity.placementKey,
  shapeId: polygon.identity.shapeId,
  elementIndex: elementIndex,
);

PolygonTerrainLegacyProjectionIssue _chunkIssue(
  PolygonTerrainCompiledChunk compiled, {
  required String code,
  required String message,
}) => PolygonTerrainLegacyProjectionIssue(
  code: code,
  message: message,
  chunkKey: compiled.chunk.chunkKey,
  shapeId: '',
);

PolygonTerrainLegacyProjectionResult _failure(
  Iterable<PolygonTerrainLegacyProjectionIssue> issues,
) => PolygonTerrainLegacyProjectionResult(projection: null, issues: issues);

final class _PhysicsRectangle {
  const _PhysicsRectangle({
    required this.leftTicks,
    required this.topTicks,
    required this.rightTicks,
    required this.bottomTicks,
  });

  final int leftTicks;
  final int topTicks;
  final int rightTicks;
  final int bottomTicks;

  int get widthTicks => rightTicks - leftTicks;
  int get heightTicks => bottomTicks - topTicks;
  BigInt get area => BigInt.from(widthTicks) * BigInt.from(heightTicks);
}

final class _PixelRectangle implements Comparable<_PixelRectangle> {
  const _PixelRectangle({
    required this.x,
    required this.topY,
    required this.width,
    required this.height,
  });

  final int x;
  final int topY;
  final int width;
  final int height;

  int get right => x + width;
  int get bottom => topY + height;
  BigInt get area => BigInt.from(width) * BigInt.from(height);

  bool overlaps(_PixelRectangle other) =>
      x < other.right &&
      other.x < right &&
      topY < other.bottom &&
      other.topY < bottom;

  PolygonTerrainLegacyRectangle toProjection(TerrainCollisionMode mode) =>
      PolygonTerrainLegacyRectangle(
        x: x,
        topY: topY,
        width: width,
        height: height,
        collisionMode: mode,
      );

  @override
  int compareTo(_PixelRectangle other) {
    var order = topY.compareTo(other.topY);
    if (order != 0) return order;
    order = x.compareTo(other.x);
    if (order != 0) return order;
    order = width.compareTo(other.width);
    return order != 0 ? order : height.compareTo(other.height);
  }
}

final class _PixelSpan implements Comparable<_PixelSpan> {
  const _PixelSpan(this.left, this.right);

  final int left;
  final int right;

  int get width => right - left;
  bool get isEmpty => left >= right;

  @override
  int compareTo(_PixelSpan other) {
    final order = left.compareTo(other.left);
    return order != 0 ? order : right.compareTo(other.right);
  }
}

final class _CellRectangle {
  const _CellRectangle({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;
}

int _compareNullable(String? left, String? right) {
  if (identical(left, right)) return 0;
  if (left == null) return -1;
  if (right == null) return 1;
  return left.compareTo(right);
}
