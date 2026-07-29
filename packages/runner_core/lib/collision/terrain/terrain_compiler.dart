import 'dart:collection';
import 'dart:math' as math;

import 'terrain_edge.dart';
import 'terrain_edge_id.dart';
import 'terrain_geometry.dart';
import 'terrain_numeric.dart';
import 'terrain_polygon.dart';
import 'terrain_polygon_overlap.dart';
import 'terrain_source_canonicalizer.dart';

/// Hard runtime-safety limits applied before compiled geometry is published.
abstract final class TerrainGeometryLimits {
  /// Maximum collision shapes contributed by one placed prefab.
  static const int maxShapesPerPrefab = 64;

  /// Maximum authored vertices retained by one collision shape.
  static const int maxVerticesPerShape = 64;

  /// Maximum direct and placed collision shapes in one chunk.
  static const int maxShapesPerChunk = 512;

  /// Maximum exposed runtime segments emitted for one chunk.
  static const int maxExposedEdgesPerChunk = 4096;
}

/// Deterministically validates, canonicalizes, and compiles terrain polygons.
///
/// This compiler is pure and has no production authority in Phase 1. Invalid
/// input throws [TerrainValidationException] before any geometry is returned.
class TerrainCompiler {
  const TerrainCompiler();

  /// Compiles [inputs] into one immutable bundle at [geometryVersion].
  ///
  /// Set [normalizeCollinear] only in an explicit source-normalization flow.
  /// Removed source vertices are reported as stable non-blocking diagnostics on
  /// the returned geometry.
  TerrainGeometry compile(
    Iterable<TerrainPolygonInput> inputs, {
    required int geometryVersion,
    bool normalizeCollinear = false,
  }) {
    if (geometryVersion < 0) {
      throw ArgumentError.value(
        geometryVersion,
        'geometryVersion',
        'Must be non-negative.',
      );
    }

    final orderedInputs = List<TerrainPolygonInput>.of(inputs)
      ..sort((left, right) {
        final identityOrder = left.identity.compareTo(right.identity);
        if (identityOrder != 0) return identityOrder;
        return left.sourcePath.compareTo(right.sourcePath);
      });

    final diagnostics = <TerrainDiagnostic>[];
    _validateShapeLimits(orderedInputs, diagnostics);
    final polygons = <TerrainPolygon>[];
    for (final input in orderedInputs) {
      final polygon = _canonicalize(
        input,
        normalizeCollinear: normalizeCollinear,
        diagnostics: diagnostics,
      );
      if (polygon != null) polygons.add(polygon);
    }

    if (diagnostics.any(terrainDiagnosticIsBlocking)) {
      throw TerrainValidationException(diagnostics);
    }

    _validatePolygonOverlaps(polygons, diagnostics);
    if (diagnostics.any(terrainDiagnosticIsBlocking)) {
      throw TerrainValidationException(diagnostics);
    }

    final splitEdges = _splitCollinearEdges(_emitRawEdges(polygons));
    final exposed = _removeInternalSolidEdges(splitEdges);
    exposed.sort((left, right) => left.id.compareTo(right.id));

    final edgeCountsByChunk = <(int, String), int>{};
    for (final edge in exposed) {
      final key = (edge.id.chunkIndex, edge.id.chunkKey);
      final count = (edgeCountsByChunk[key] ?? 0) + 1;
      edgeCountsByChunk[key] = count;
      if (count > TerrainGeometryLimits.maxExposedEdgesPerChunk) {
        diagnostics.add(
          TerrainDiagnostic(
            sourcePath: edge.id.chunkKey,
            shapeId: edge.id.shapeId,
            elementIndex: edge.id.localEdgeIndex,
            code: 'edge_limit',
            message:
                'Chunk ${edge.id.chunkKey} exceeds the 4096 exposed-edge limit.',
          ),
        );
        throw TerrainValidationException(diagnostics);
      }
    }

    final edges = _buildAdjacency(exposed);
    return TerrainGeometry(
      version: geometryVersion,
      polygons: polygons,
      edges: edges,
      diagnostics: diagnostics.where(
        (diagnostic) => !terrainDiagnosticIsBlocking(diagnostic),
      ),
    );
  }
}

void _validateShapeLimits(
  List<TerrainPolygonInput> inputs,
  List<TerrainDiagnostic> diagnostics,
) {
  final chunkCounts = <(int, String), int>{};
  final placementCounts = <(int, String, String), int>{};
  final identities = <TerrainSourceIdentity>{};
  for (final input in inputs) {
    final chunkKey = (input.identity.chunkIndex, input.identity.chunkKey);
    final chunkCount = (chunkCounts[chunkKey] ?? 0) + 1;
    chunkCounts[chunkKey] = chunkCount;
    if (chunkCount > TerrainGeometryLimits.maxShapesPerChunk) {
      diagnostics.add(
        _diagnostic(
          input,
          chunkCount,
          'chunk_shape_limit',
          'Chunk exceeds the 512 source-shape hard limit.',
        ),
      );
    }
    if (!identities.add(input.identity)) {
      diagnostics.add(
        _diagnostic(
          input,
          0,
          'duplicate_shape_id',
          'Source identity is not unique in this geometry bundle.',
        ),
      );
    }
    if (input.vertices.length > TerrainGeometryLimits.maxVerticesPerShape) {
      diagnostics.add(
        _diagnostic(
          input,
          input.vertices.length,
          'vertex_limit',
          'Shape exceeds the 64-vertex hard limit.',
        ),
      );
    }
    final placementKey = input.identity.placementKey;
    if (placementKey != null) {
      final key = (
        input.identity.chunkIndex,
        input.identity.chunkKey,
        placementKey,
      );
      placementCounts[key] = (placementCounts[key] ?? 0) + 1;
      if (placementCounts[key]! > TerrainGeometryLimits.maxShapesPerPrefab) {
        diagnostics.add(
          _diagnostic(
            input,
            placementCounts[key]!,
            'prefab_shape_limit',
            'Placed prefab exceeds the 64-shape hard limit.',
          ),
        );
      }
    }
  }
}

TerrainPolygon? _canonicalize(
  TerrainPolygonInput input, {
  required bool normalizeCollinear,
  required List<TerrainDiagnostic> diagnostics,
}) {
  final review = const TerrainSourceCanonicalizer().review(
    input,
    normalizeCollinear: normalizeCollinear,
  );
  diagnostics.addAll(review.diagnostics);
  if (review.hasBlockingDiagnostics) {
    return null;
  }
  var source = List<SourceTerrainPoint>.of(review.validatedVertices);

  var transformed = source.map(input.transform.apply).toList();
  final transformedArea = _signedAreaPhysics(transformed);
  if (transformedArea == BigInt.zero) {
    diagnostics.add(
      _diagnostic(
        input,
        0,
        'transform_zero_area',
        'The quantized placement transform collapsed the polygon.',
      ),
    );
    return null;
  }

  // Clockwise loops in the game's Y-down coordinates have positive shoelace
  // area. Reverse both lists together so source lineage remains aligned.
  if (transformedArea.isNegative) {
    source = source.reversed.toList();
    transformed = transformed.reversed.toList();
  }

  final firstIndex = _canonicalRotationIndex(transformed);
  source = _rotate(source, firstIndex);
  transformed = _rotate(transformed, firstIndex);

  return TerrainPolygon(
    sourcePath: input.sourcePath,
    identity: input.identity,
    sourceVertices: source,
    vertices: transformed,
    collisionMode: input.collisionMode,
    surfaceKind: input.surfaceKind,
    materialKey: input.materialKey,
  );
}

List<_RawEdge> _emitRawEdges(List<TerrainPolygon> polygons) {
  final edges = <_RawEdge>[];
  for (final polygon in polygons) {
    for (var i = 0; i < polygon.vertices.length; i += 1) {
      final start = polygon.vertices[i];
      final end = polygon.vertices[(i + 1) % polygon.vertices.length];
      if (start == end) {
        throw StateError('Canonical polygon emitted a zero-length edge.');
      }
      final normal = TerrainDirection.fromDelta(
        end.yTicks - start.yTicks,
        -(end.xTicks - start.xTicks),
      );
      // One-way source loops expose only their authored upward-facing top side.
      if (polygon.collisionMode == TerrainCollisionMode.oneWay &&
          normal.yTicks >= 0) {
        continue;
      }
      edges.add(
        _RawEdge(
          id: polygon.identity.edgeId(i),
          start: start,
          end: end,
          collisionMode: polygon.collisionMode,
          surfaceKind: polygon.surfaceKind,
          materialKey: polygon.materialKey,
        ),
      );
    }
  }
  return edges;
}

List<_RawEdge> _splitCollinearEdges(List<_RawEdge> edges) {
  final groups = <String, List<_RawEdge>>{};
  for (final edge in edges) {
    groups.putIfAbsent(_lineKey(edge.start, edge.end), () => []).add(edge);
  }

  final result = <_RawEdge>[];
  for (final group in groups.values) {
    final useX = group.first.start.xTicks != group.first.end.xTicks;
    final points = SplayTreeMap<int, TerrainPoint>();
    for (final edge in group) {
      points[useX ? edge.start.xTicks : edge.start.yTicks] = edge.start;
      points[useX ? edge.end.xTicks : edge.end.yTicks] = edge.end;
    }
    final scalars = points.keys.toList(growable: false);
    for (final edge in group) {
      final startScalar = useX ? edge.start.xTicks : edge.start.yTicks;
      final endScalar = useX ? edge.end.xTicks : edge.end.yTicks;
      final startIndex = _binarySearchExact(scalars, startScalar);
      final endIndex = _binarySearchExact(scalars, endScalar);
      final step = startIndex < endIndex ? 1 : -1;
      var index = startIndex;
      var subEdgeIndex = 0;
      while (index != endIndex) {
        final nextIndex = index + step;
        result.add(
          edge.copyWith(
            id: TerrainEdgeId(
              chunkIndex: edge.id.chunkIndex,
              chunkKey: edge.id.chunkKey,
              placementKey: edge.id.placementKey,
              shapeId: edge.id.shapeId,
              localEdgeIndex: edge.id.localEdgeIndex,
              subEdgeIndex: subEdgeIndex,
            ),
            start: points[scalars[index]]!,
            end: points[scalars[nextIndex]]!,
          ),
        );
        index = nextIndex;
        subEdgeIndex += 1;
      }
    }
  }
  return result;
}

List<_RawEdge> _removeInternalSolidEdges(List<_RawEdge> edges) {
  final byUndirectedSegment = <String, List<int>>{};
  for (var i = 0; i < edges.length; i += 1) {
    byUndirectedSegment
        .putIfAbsent(_undirectedSegmentKey(edges[i]), () => [])
        .add(i);
  }
  final removed = List<bool>.filled(edges.length, false);
  for (final indices in byUndirectedSegment.values) {
    for (var left = 0; left < indices.length; left += 1) {
      final aIndex = indices[left];
      if (removed[aIndex]) continue;
      final a = edges[aIndex];
      if (a.collisionMode != TerrainCollisionMode.solid) continue;
      for (var right = left + 1; right < indices.length; right += 1) {
        final bIndex = indices[right];
        if (removed[bIndex]) continue;
        final b = edges[bIndex];
        if (b.collisionMode == TerrainCollisionMode.solid &&
            a.start == b.end &&
            a.end == b.start) {
          removed[aIndex] = true;
          removed[bIndex] = true;
          break;
        }
      }
    }
  }
  return <_RawEdge>[
    for (var i = 0; i < edges.length; i += 1)
      if (!removed[i]) edges[i],
  ];
}

List<TerrainEdge> _buildAdjacency(List<_RawEdge> rawEdges) {
  final incoming = <TerrainPoint, List<_RawEdge>>{};
  final outgoing = <TerrainPoint, List<_RawEdge>>{};
  for (final edge in rawEdges) {
    incoming.putIfAbsent(edge.end, () => []).add(edge);
    outgoing.putIfAbsent(edge.start, () => []).add(edge);
  }
  for (final values in incoming.values) {
    values.sort((left, right) => left.id.compareTo(right.id));
  }
  for (final values in outgoing.values) {
    values.sort((left, right) => left.id.compareTo(right.id));
  }

  return List<TerrainEdge>.unmodifiable(
    rawEdges.map((raw) {
      final previous = _firstCompatible(raw, incoming[raw.start]);
      final next = _firstCompatible(raw, outgoing[raw.end]);
      final tangent = TerrainDirection.fromDelta(
        raw.end.xTicks - raw.start.xTicks,
        raw.end.yTicks - raw.start.yTicks,
      );
      final normal = TerrainDirection.fromDelta(
        raw.end.yTicks - raw.start.yTicks,
        -(raw.end.xTicks - raw.start.xTicks),
      );
      return TerrainEdge(
        id: raw.id,
        start: raw.start,
        end: raw.end,
        tangent: tangent,
        outwardNormal: normal,
        collisionMode: raw.collisionMode,
        surfaceKind: raw.surfaceKind,
        materialKey: raw.materialKey,
        previousId: previous?.id,
        nextId: next?.id,
        startJoin: _joinFor(previous, raw),
        endJoin: _joinFor(raw, next),
        bounds: TerrainAabb(
          minX: math.min(raw.start.xTicks, raw.end.xTicks),
          minY: math.min(raw.start.yTicks, raw.end.yTicks),
          maxX: math.max(raw.start.xTicks, raw.end.xTicks),
          maxY: math.max(raw.start.yTicks, raw.end.yTicks),
        ),
      );
    }),
  );
}

_RawEdge? _firstCompatible(_RawEdge edge, List<_RawEdge>? candidates) {
  if (candidates == null) return null;
  for (final candidate in candidates) {
    if (candidate.id != edge.id &&
        candidate.collisionMode == edge.collisionMode &&
        candidate.surfaceKind == edge.surfaceKind) {
      return candidate;
    }
  }
  return null;
}

TerrainVertexJoin _joinFor(_RawEdge? previous, _RawEdge? next) {
  if (previous == null || next == null) return TerrainVertexJoin.exposed;
  final previousDirection = TerrainDirection.fromDelta(
    previous.end.xTicks - previous.start.xTicks,
    previous.end.yTicks - previous.start.yTicks,
  );
  final nextDirection = TerrainDirection.fromDelta(
    next.end.xTicks - next.start.xTicks,
    next.end.yTicks - next.start.yTicks,
  );
  return previousDirection == nextDirection
      ? TerrainVertexJoin.smooth
      : TerrainVertexJoin.connected;
}

void _validatePolygonOverlaps(
  List<TerrainPolygon> polygons,
  List<TerrainDiagnostic> diagnostics,
) {
  final bounds = <TerrainAabb>[
    for (final polygon in polygons) _bounds(polygon.vertices),
  ];
  for (var i = 0; i < polygons.length; i += 1) {
    for (var j = i + 1; j < polygons.length; j += 1) {
      if (!bounds[i].intersects(bounds[j])) continue;
      final left = polygons[i];
      final right = polygons[j];
      if (TerrainPolygonOverlap.physicsLoops(left.vertices, right.vertices)) {
        diagnostics.add(
          TerrainDiagnostic(
            sourcePath: right.sourcePath,
            shapeId: right.identity.shapeId,
            elementIndex: 0,
            code: 'polygon_area_overlap',
            message:
                'Polygon overlaps ${left.sourcePath}:${left.identity.shapeId} '
                'in occupied area.',
          ),
        );
      }
    }
  }
}

BigInt _signedAreaPhysics(List<TerrainPoint> vertices) {
  var area = BigInt.zero;
  for (var i = 0; i < vertices.length; i += 1) {
    final current = vertices[i];
    final next = vertices[(i + 1) % vertices.length];
    area +=
        BigInt.from(current.xTicks) * BigInt.from(next.yTicks) -
        BigInt.from(next.xTicks) * BigInt.from(current.yTicks);
  }
  return area;
}

int _canonicalRotationIndex(List<TerrainPoint> vertices) {
  var best = 0;
  for (var i = 1; i < vertices.length; i += 1) {
    final pointOrder = vertices[i].compareTo(vertices[best]);
    if (pointOrder < 0 ||
        (pointOrder == 0 && _cyclicCompare(vertices, i, best) < 0)) {
      best = i;
    }
  }
  return best;
}

int _cyclicCompare(List<TerrainPoint> vertices, int left, int right) {
  for (var offset = 0; offset < vertices.length; offset += 1) {
    final order = vertices[(left + offset) % vertices.length].compareTo(
      vertices[(right + offset) % vertices.length],
    );
    if (order != 0) return order;
  }
  return 0;
}

List<T> _rotate<T>(List<T> values, int start) => <T>[
  ...values.skip(start),
  ...values.take(start),
];

TerrainAabb _bounds(List<TerrainPoint> points) {
  var minX = points.first.xTicks;
  var minY = points.first.yTicks;
  var maxX = minX;
  var maxY = minY;
  for (final point in points.skip(1)) {
    minX = math.min(minX, point.xTicks);
    minY = math.min(minY, point.yTicks);
    maxX = math.max(maxX, point.xTicks);
    maxY = math.max(maxY, point.yTicks);
  }
  return TerrainAabb(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

String _lineKey(TerrainPoint start, TerrainPoint end) {
  final dx = end.xTicks - start.xTicks;
  final dy = end.yTicks - start.yTicks;
  final gcd = terrainGreatestCommonDivisor(dx, dy);
  var a = dy ~/ gcd;
  var b = -dx ~/ gcd;
  if (a < 0 || (a == 0 && b < 0)) {
    a = -a;
    b = -b;
  }
  final c =
      BigInt.from(a) * BigInt.from(start.xTicks) +
      BigInt.from(b) * BigInt.from(start.yTicks);
  return '$a:$b:$c';
}

String _undirectedSegmentKey(_RawEdge edge) {
  final startFirst = edge.start.compareTo(edge.end) <= 0;
  final first = startFirst ? edge.start : edge.end;
  final second = startFirst ? edge.end : edge.start;
  return '${first.xTicks}:${first.yTicks}:${second.xTicks}:${second.yTicks}';
}

int _binarySearchExact(List<int> sorted, int value) {
  var low = 0;
  var high = sorted.length;
  while (low < high) {
    final middle = low + ((high - low) >> 1);
    if (sorted[middle] < value) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  if (low >= sorted.length || sorted[low] != value) {
    throw StateError('Missing collinear split coordinate $value.');
  }
  return low;
}

TerrainDiagnostic _diagnostic(
  TerrainPolygonInput input,
  int elementIndex,
  String code,
  String message,
) => TerrainDiagnostic(
  sourcePath: input.sourcePath,
  shapeId: input.identity.shapeId,
  elementIndex: elementIndex,
  code: code,
  message: message,
);

class _RawEdge {
  const _RawEdge({
    required this.id,
    required this.start,
    required this.end,
    required this.collisionMode,
    required this.surfaceKind,
    required this.materialKey,
  });

  final TerrainEdgeId id;
  final TerrainPoint start;
  final TerrainPoint end;
  final TerrainCollisionMode collisionMode;
  final String? surfaceKind;
  final String? materialKey;

  _RawEdge copyWith({
    required TerrainEdgeId id,
    required TerrainPoint start,
    required TerrainPoint end,
  }) => _RawEdge(
    id: id,
    start: start,
    end: end,
    collisionMode: collisionMode,
    surfaceKind: surfaceKind,
    materialKey: materialKey,
  );
}
