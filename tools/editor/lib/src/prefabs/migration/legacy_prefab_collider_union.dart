import 'dart:collection';

import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';

import '../../terrain_authoring/terrain_source_core_adapter.dart';
import '../../terrain_authoring/terrain_source_models.dart';
import '../../migration/legacy_prefab_collider_def.dart';
import 'reviewed_legacy_prefab_collision_reauthorings.dart';

/// One stable blocking finding from legacy prefab-collider conversion.
final class LegacyPrefabColliderUnionIssue
    implements Comparable<LegacyPrefabColliderUnionIssue> {
  const LegacyPrefabColliderUnionIssue({
    required this.sourcePath,
    required this.code,
    required this.message,
    this.elementIndex = 0,
  });

  final String sourcePath;
  final int elementIndex;
  final String code;
  final String message;

  @override
  int compareTo(LegacyPrefabColliderUnionIssue other) {
    var order = sourcePath.compareTo(other.sourcePath);
    if (order != 0) return order;
    order = elementIndex.compareTo(other.elementIndex);
    if (order != 0) return order;
    return code.compareTo(other.code);
  }
}

/// Immutable read-only plan for one legacy prefab's occupied-area migration.
final class LegacyPrefabColliderUnionResult {
  LegacyPrefabColliderUnionResult({
    required Iterable<TerrainSourceShapeDef> shapes,
    required Iterable<LegacyPrefabColliderUnionIssue> issues,
    required this.occupiedAreaHalfPixelSquared,
    required this.plannedAreaHalfPixelSquared,
    this.reauthoringPrefabKey,
  }) : shapes = List<TerrainSourceShapeDef>.unmodifiable(shapes),
       issues = List<LegacyPrefabColliderUnionIssue>.unmodifiable(
         List<LegacyPrefabColliderUnionIssue>.of(issues)..sort(),
       );

  final List<TerrainSourceShapeDef> shapes;
  final List<LegacyPrefabColliderUnionIssue> issues;

  /// Exact union area in half-pixel ticks squared.
  final BigInt occupiedAreaHalfPixelSquared;

  /// Exact planned polygon area in half-pixel ticks squared.
  final BigInt plannedAreaHalfPixelSquared;

  /// Prefab key when an explicit reviewed source correction was applied.
  final String? reauthoringPrefabKey;

  /// Exact difference between the planned polygon and legacy union areas.
  BigInt get areaDeltaHalfPixelSquared =>
      plannedAreaHalfPixelSquared - occupiedAreaHalfPixelSquared;

  /// Whether the result includes an explicitly reviewed content correction.
  bool get isReauthored => reauthoringPrefabKey != null;

  bool get canMigrate => issues.isEmpty;
}

/// Deterministic occupied-area union for legacy prefab AABB colliders.
///
/// This operation is pure and performs no schema parsing or writes. It emits
/// separate simple loops for edge-disconnected components, rejects holes and
/// point-only topology, and delegates final loop acceptance to Core.
abstract final class LegacyPrefabColliderUnion {
  static LegacyPrefabColliderUnionResult plan({
    required Iterable<PrefabColliderDef> colliders,
    required String sourcePath,
    ReviewedLegacyPrefabCollisionReauthoring? reviewedReauthoring,
  }) {
    final colliderList = colliders.toList(growable: false);
    final issues = <LegacyPrefabColliderUnionIssue>[];
    final rectangles = <_HalfPixelRect>[];
    var colliderIndex = 0;
    for (final collider in colliderList) {
      final rectangle = _toHalfPixelRect(
        collider,
        sourcePath: sourcePath,
        colliderIndex: colliderIndex,
        issues: issues,
      );
      if (rectangle != null) rectangles.add(rectangle);
      colliderIndex += 1;
    }
    if (issues.isNotEmpty || rectangles.isEmpty) {
      return LegacyPrefabColliderUnionResult(
        shapes: const <TerrainSourceShapeDef>[],
        issues: issues,
        occupiedAreaHalfPixelSquared: BigInt.zero,
        plannedAreaHalfPixelSquared: BigInt.zero,
      );
    }

    rectangles.sort();
    final xCoordinates = SplayTreeSet<int>();
    final yCoordinates = SplayTreeSet<int>();
    for (final rectangle in rectangles) {
      xCoordinates
        ..add(rectangle.left)
        ..add(rectangle.right);
      yCoordinates
        ..add(rectangle.top)
        ..add(rectangle.bottom);
    }
    final xs = xCoordinates.toList(growable: false);
    final ys = yCoordinates.toList(growable: false);
    final xIndices = <int, int>{
      for (var index = 0; index < xs.length; index += 1) xs[index]: index,
    };
    final yIndices = <int, int>{
      for (var index = 0; index < ys.length; index += 1) ys[index]: index,
    };
    final occupied = List<List<bool>>.generate(
      xs.length - 1,
      (_) => List<bool>.filled(ys.length - 1, false),
      growable: false,
    );
    for (final rectangle in rectangles) {
      for (
        var xIndex = xIndices[rectangle.left]!;
        xIndex < xIndices[rectangle.right]!;
        xIndex += 1
      ) {
        for (
          var yIndex = yIndices[rectangle.top]!;
          yIndex < yIndices[rectangle.bottom]!;
          yIndex += 1
        ) {
          occupied[xIndex][yIndex] = true;
        }
      }
    }

    final occupiedArea = _occupiedArea(occupied, xs, ys);
    issues.addAll(
      _pointContactIssues(occupied, xs, ys, sourcePath: sourcePath),
    );
    issues.addAll(_holeIssues(occupied, xs, ys, sourcePath: sourcePath));
    if (issues.isNotEmpty) {
      return LegacyPrefabColliderUnionResult(
        shapes: const <TerrainSourceShapeDef>[],
        issues: issues,
        occupiedAreaHalfPixelSquared: occupiedArea,
        plannedAreaHalfPixelSquared: BigInt.zero,
      );
    }

    final loops = <List<TerrainSourceVertexDef>>[];
    final components = _occupiedComponents(occupied);
    for (var index = 0; index < components.length; index += 1) {
      final loop = _traceComponentLoop(
        components[index],
        xs,
        ys,
        sourcePath: sourcePath,
        componentIndex: index,
        issues: issues,
      );
      if (loop != null) loops.add(loop);
    }
    if (issues.isNotEmpty) {
      return LegacyPrefabColliderUnionResult(
        shapes: const <TerrainSourceShapeDef>[],
        issues: issues,
        occupiedAreaHalfPixelSquared: occupiedArea,
        plannedAreaHalfPixelSquared: BigInt.zero,
      );
    }

    loops.sort(_compareLoops);
    if (reviewedReauthoring != null &&
        !reviewedReauthoring.matchesColliders(colliderList)) {
      issues.add(
        LegacyPrefabColliderUnionIssue(
          sourcePath: sourcePath,
          code: 'legacy_reauthoring_source_drift',
          message:
              'Reviewed collision correction for '
              '${reviewedReauthoring.prefabKey} no longer matches its legacy '
              'colliders.',
        ),
      );
    }
    if (reviewedReauthoring != null &&
        reviewedReauthoring.replacementShapes.length != loops.length) {
      issues.add(
        LegacyPrefabColliderUnionIssue(
          sourcePath: sourcePath,
          code: 'legacy_reauthoring_component_mismatch',
          message:
              'Reviewed collision correction for '
              '${reviewedReauthoring.prefabKey} changes the number of occupied '
              'components.',
        ),
      );
    }
    if (issues.isNotEmpty) {
      return LegacyPrefabColliderUnionResult(
        shapes: const <TerrainSourceShapeDef>[],
        issues: issues,
        occupiedAreaHalfPixelSquared: occupiedArea,
        plannedAreaHalfPixelSquared: BigInt.zero,
      );
    }

    final candidates =
        reviewedReauthoring?.replacementShapes ??
        <TerrainSourceShapeDef>[
          for (var index = 0; index < loops.length; index += 1)
            TerrainSourceShapeDef(
              shapeId: 'collision_${(index + 1).toString().padLeft(3, '0')}',
              vertices: loops[index],
            ),
        ];
    if (candidates.length > TerrainGeometryLimits.maxShapesPerPrefab) {
      issues.add(
        LegacyPrefabColliderUnionIssue(
          sourcePath: sourcePath,
          code: 'legacy_prefab_shape_limit',
          message:
              'Rectangle union produces ${candidates.length} shapes; the limit is '
              '${TerrainGeometryLimits.maxShapesPerPrefab}.',
        ),
      );
    }

    final shapes = <TerrainSourceShapeDef>[];
    var plannedDoubledArea = BigInt.zero;
    for (var index = 0; index < candidates.length; index += 1) {
      final candidate = candidates[index];
      if (candidate.vertices.length >
          TerrainGeometryLimits.maxVerticesPerShape) {
        issues.add(
          LegacyPrefabColliderUnionIssue(
            sourcePath: sourcePath,
            elementIndex: index,
            code: 'legacy_prefab_vertex_limit',
            message:
                'Union component ${index + 1} has '
                '${candidate.vertices.length} vertices; '
                'the limit is ${TerrainGeometryLimits.maxVerticesPerShape}.',
          ),
        );
        continue;
      }
      final review = TerrainSourceCoreAdapter.review(
        shape: candidate,
        sourcePath: sourcePath,
        chunkIndex: 0,
        chunkKey: 'legacy_prefab_migration',
        requireCanonical: false,
      );
      if (review.hasBlockingDiagnostics || review.canonicalVertices == null) {
        for (final diagnostic in review.diagnostics) {
          issues.add(
            LegacyPrefabColliderUnionIssue(
              sourcePath: sourcePath,
              elementIndex: diagnostic.elementIndex,
              code: 'legacy_core_${diagnostic.code}',
              message: diagnostic.message,
            ),
          );
        }
        continue;
      }
      shapes.add(
        TerrainSourceCoreAdapter.applyCanonicalVertices(candidate, review),
      );
      plannedDoubledArea += review.signedDoubledArea.abs();
    }

    final plannedArea = plannedDoubledArea ~/ BigInt.two;
    if (issues.isEmpty) {
      final expectedDelta =
          reviewedReauthoring?.expectedAddedAreaHalfPixelSquared ?? BigInt.zero;
      if (plannedArea - occupiedArea != expectedDelta) {
        issues.add(
          LegacyPrefabColliderUnionIssue(
            sourcePath: sourcePath,
            code: reviewedReauthoring == null
                ? 'legacy_union_area_mismatch'
                : 'legacy_reauthoring_area_mismatch',
            message: reviewedReauthoring == null
                ? 'Rectangle union did not preserve exact occupied area.'
                : 'Reviewed collision correction for '
                      '${reviewedReauthoring.prefabKey} does not match its '
                      'approved area delta.',
          ),
        );
      }
    }
    return LegacyPrefabColliderUnionResult(
      shapes: issues.isEmpty
          ? canonicalTerrainSourceShapes(shapes)
          : const <TerrainSourceShapeDef>[],
      issues: issues,
      occupiedAreaHalfPixelSquared: occupiedArea,
      plannedAreaHalfPixelSquared: plannedArea,
      reauthoringPrefabKey: issues.isEmpty
          ? reviewedReauthoring?.prefabKey
          : null,
    );
  }
}

_HalfPixelRect? _toHalfPixelRect(
  PrefabColliderDef collider, {
  required String sourcePath,
  required int colliderIndex,
  required List<LegacyPrefabColliderUnionIssue> issues,
}) {
  if (collider.width <= 0 || collider.height <= 0) {
    issues.add(
      LegacyPrefabColliderUnionIssue(
        sourcePath: sourcePath,
        elementIndex: colliderIndex,
        code: 'invalid_legacy_collider',
        message: 'Legacy collider width and height must be positive.',
      ),
    );
    return null;
  }
  final offsetX = BigInt.from(collider.offsetX) * BigInt.two;
  final offsetY = BigInt.from(collider.offsetY) * BigInt.two;
  final width = BigInt.from(collider.width);
  final height = BigInt.from(collider.height);
  final coordinates = <BigInt>[
    offsetX - width,
    offsetY - height,
    offsetX + width,
    offsetY + height,
  ];
  final minimum = BigInt.from(-terrainMaxAbsSourceTicks);
  final maximum = BigInt.from(terrainMaxAbsSourceTicks);
  if (coordinates.any((value) => value < minimum || value > maximum)) {
    issues.add(
      LegacyPrefabColliderUnionIssue(
        sourcePath: sourcePath,
        elementIndex: colliderIndex,
        code: 'legacy_coordinate_range',
        message: 'Legacy collider exceeds Core source-coordinate limits.',
      ),
    );
    return null;
  }
  return _HalfPixelRect(
    left: coordinates[0].toInt(),
    top: coordinates[1].toInt(),
    right: coordinates[2].toInt(),
    bottom: coordinates[3].toInt(),
  );
}

BigInt _occupiedArea(List<List<bool>> occupied, List<int> xs, List<int> ys) {
  var area = BigInt.zero;
  for (var x = 0; x < occupied.length; x += 1) {
    for (var y = 0; y < occupied[x].length; y += 1) {
      if (!occupied[x][y]) continue;
      area += BigInt.from(xs[x + 1] - xs[x]) * BigInt.from(ys[y + 1] - ys[y]);
    }
  }
  return area;
}

List<LegacyPrefabColliderUnionIssue> _pointContactIssues(
  List<List<bool>> occupied,
  List<int> xs,
  List<int> ys, {
  required String sourcePath,
}) {
  final issues = <LegacyPrefabColliderUnionIssue>[];
  for (var x = 0; x + 1 < occupied.length; x += 1) {
    for (var y = 0; y + 1 < occupied[x].length; y += 1) {
      final northWest = occupied[x][y];
      final northEast = occupied[x + 1][y];
      final southWest = occupied[x][y + 1];
      final southEast = occupied[x + 1][y + 1];
      final diagonal =
          (northWest && southEast && !northEast && !southWest) ||
          (northEast && southWest && !northWest && !southEast);
      if (diagonal) {
        issues.add(
          LegacyPrefabColliderUnionIssue(
            sourcePath: sourcePath,
            elementIndex: issues.length,
            code: 'legacy_point_contact',
            message:
                'Occupied components touch only at half-pixel point '
                '(${xs[x + 1]}, ${ys[y + 1]}).',
          ),
        );
      }
    }
  }
  return issues;
}

List<LegacyPrefabColliderUnionIssue> _holeIssues(
  List<List<bool>> occupied,
  List<int> xs,
  List<int> ys, {
  required String sourcePath,
}) {
  final width = occupied.length;
  final height = occupied.first.length;
  final exterior = <(int, int)>{};
  final queue = Queue<(int, int)>();
  void addExterior(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height || occupied[x][y]) {
      return;
    }
    final cell = (x, y);
    if (exterior.add(cell)) queue.add(cell);
  }

  for (var x = 0; x < width; x += 1) {
    addExterior(x, 0);
    addExterior(x, height - 1);
  }
  for (var y = 0; y < height; y += 1) {
    addExterior(0, y);
    addExterior(width - 1, y);
  }
  _drainCells(queue, addExterior);

  final issues = <LegacyPrefabColliderUnionIssue>[];
  final visitedHoles = <(int, int)>{};
  for (var x = 0; x < width; x += 1) {
    for (var y = 0; y < height; y += 1) {
      final cell = (x, y);
      if (occupied[x][y] ||
          exterior.contains(cell) ||
          !visitedHoles.add(cell)) {
        continue;
      }
      final holeQueue = Queue<(int, int)>()..add(cell);
      void addHole(int nextX, int nextY) {
        if (nextX < 0 ||
            nextX >= width ||
            nextY < 0 ||
            nextY >= height ||
            occupied[nextX][nextY] ||
            exterior.contains((nextX, nextY))) {
          return;
        }
        final next = (nextX, nextY);
        if (visitedHoles.add(next)) holeQueue.add(next);
      }

      _drainCells(holeQueue, addHole);
      issues.add(
        LegacyPrefabColliderUnionIssue(
          sourcePath: sourcePath,
          elementIndex: issues.length,
          code: 'legacy_union_hole',
          message:
              'Rectangle union encloses a hole beginning at half-pixel cell '
              '[${xs[x]}, ${ys[y]}].',
        ),
      );
    }
  }
  return issues;
}

List<Set<(int, int)>> _occupiedComponents(List<List<bool>> occupied) {
  final width = occupied.length;
  final height = occupied.first.length;
  final visited = <(int, int)>{};
  final components = <Set<(int, int)>>[];
  for (var x = 0; x < width; x += 1) {
    for (var y = 0; y < height; y += 1) {
      final start = (x, y);
      if (!occupied[x][y] || !visited.add(start)) continue;
      final component = <(int, int)>{start};
      final queue = Queue<(int, int)>()..add(start);
      void addOccupied(int nextX, int nextY) {
        if (nextX < 0 ||
            nextX >= width ||
            nextY < 0 ||
            nextY >= height ||
            !occupied[nextX][nextY]) {
          return;
        }
        final next = (nextX, nextY);
        if (visited.add(next)) {
          component.add(next);
          queue.add(next);
        }
      }

      _drainCells(queue, addOccupied);
      components.add(component);
    }
  }
  return components;
}

void _drainCells(Queue<(int, int)> queue, void Function(int x, int y) add) {
  while (queue.isNotEmpty) {
    final cell = queue.removeFirst();
    add(cell.$1 - 1, cell.$2);
    add(cell.$1 + 1, cell.$2);
    add(cell.$1, cell.$2 - 1);
    add(cell.$1, cell.$2 + 1);
  }
}

List<TerrainSourceVertexDef>? _traceComponentLoop(
  Set<(int, int)> component,
  List<int> xs,
  List<int> ys, {
  required String sourcePath,
  required int componentIndex,
  required List<LegacyPrefabColliderUnionIssue> issues,
}) {
  final edges = <_BoundaryEdge>{};
  for (final cell in component) {
    final x = cell.$1;
    final y = cell.$2;
    final topLeft = _GridPoint(xs[x], ys[y]);
    final topRight = _GridPoint(xs[x + 1], ys[y]);
    final bottomRight = _GridPoint(xs[x + 1], ys[y + 1]);
    final bottomLeft = _GridPoint(xs[x], ys[y + 1]);
    if (!component.contains((x, y - 1))) {
      edges.add(_BoundaryEdge(topLeft, topRight));
    }
    if (!component.contains((x + 1, y))) {
      edges.add(_BoundaryEdge(topRight, bottomRight));
    }
    if (!component.contains((x, y + 1))) {
      edges.add(_BoundaryEdge(bottomRight, bottomLeft));
    }
    if (!component.contains((x - 1, y))) {
      edges.add(_BoundaryEdge(bottomLeft, topLeft));
    }
  }

  final outgoing = <_GridPoint, List<_BoundaryEdge>>{};
  final incomingCounts = <_GridPoint, int>{};
  for (final edge in edges) {
    outgoing.putIfAbsent(edge.start, () => <_BoundaryEdge>[]).add(edge);
    incomingCounts[edge.end] = (incomingCounts[edge.end] ?? 0) + 1;
  }
  final ambiguous =
      outgoing.entries.any((entry) => entry.value.length != 1) ||
      incomingCounts.values.any((count) => count != 1);
  if (ambiguous || edges.isEmpty) {
    issues.add(
      LegacyPrefabColliderUnionIssue(
        sourcePath: sourcePath,
        elementIndex: componentIndex,
        code: 'legacy_ambiguous_boundary',
        message: 'Rectangle union component has a non-manifold boundary.',
      ),
    );
    return null;
  }

  final start = outgoing.keys.reduce(
    (left, right) => left.compareTo(right) <= 0 ? left : right,
  );
  final unused = Set<_BoundaryEdge>.of(edges);
  final vertices = <_GridPoint>[];
  var current = start;
  while (true) {
    final edge = outgoing[current]!.single;
    if (!unused.remove(edge)) {
      issues.add(
        LegacyPrefabColliderUnionIssue(
          sourcePath: sourcePath,
          elementIndex: componentIndex,
          code: 'legacy_ambiguous_boundary',
          message: 'Rectangle union boundary repeats before closing.',
        ),
      );
      return null;
    }
    vertices.add(current);
    current = edge.end;
    if (current == start) break;
  }
  if (unused.isNotEmpty) {
    issues.add(
      LegacyPrefabColliderUnionIssue(
        sourcePath: sourcePath,
        elementIndex: componentIndex,
        code: 'legacy_multiple_boundaries',
        message: 'One occupied component produced multiple boundary loops.',
      ),
    );
    return null;
  }

  final simplified = _removeCollinear(vertices);
  return simplified
      .map(
        (point) =>
            TerrainSourceVertexDef(xHalfPixels: point.x, yHalfPixels: point.y),
      )
      .toList(growable: false);
}

List<_GridPoint> _removeCollinear(List<_GridPoint> vertices) {
  var result = List<_GridPoint>.of(vertices);
  var changed = true;
  while (changed && result.length >= 3) {
    changed = false;
    final next = <_GridPoint>[];
    for (var index = 0; index < result.length; index += 1) {
      final previous = result[(index - 1 + result.length) % result.length];
      final current = result[index];
      final following = result[(index + 1) % result.length];
      if ((previous.x == current.x && current.x == following.x) ||
          (previous.y == current.y && current.y == following.y)) {
        changed = true;
      } else {
        next.add(current);
      }
    }
    result = next;
  }
  return result;
}

int _compareLoops(
  List<TerrainSourceVertexDef> left,
  List<TerrainSourceVertexDef> right,
) {
  final commonLength = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < commonLength; index += 1) {
    var order = left[index].xHalfPixels.compareTo(right[index].xHalfPixels);
    if (order != 0) return order;
    order = left[index].yHalfPixels.compareTo(right[index].yHalfPixels);
    if (order != 0) return order;
  }
  return left.length.compareTo(right.length);
}

final class _HalfPixelRect implements Comparable<_HalfPixelRect> {
  const _HalfPixelRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;

  @override
  int compareTo(_HalfPixelRect other) {
    var order = top.compareTo(other.top);
    if (order != 0) return order;
    order = left.compareTo(other.left);
    if (order != 0) return order;
    order = bottom.compareTo(other.bottom);
    if (order != 0) return order;
    return right.compareTo(other.right);
  }
}

final class _GridPoint implements Comparable<_GridPoint> {
  const _GridPoint(this.x, this.y);

  final int x;
  final int y;

  @override
  int compareTo(_GridPoint other) {
    final xOrder = x.compareTo(other.x);
    return xOrder != 0 ? xOrder : y.compareTo(other.y);
  }

  @override
  bool operator ==(Object other) =>
      other is _GridPoint && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

final class _BoundaryEdge {
  const _BoundaryEdge(this.start, this.end);

  final _GridPoint start;
  final _GridPoint end;

  @override
  bool operator ==(Object other) =>
      other is _BoundaryEdge && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}
