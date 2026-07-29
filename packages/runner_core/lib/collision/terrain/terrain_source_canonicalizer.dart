import 'dart:math' as math;

import 'terrain_numeric.dart';
import 'terrain_polygon.dart';

/// Immutable result of reviewing one authored polygon on the half-unit grid.
///
/// [validatedVertices] preserves input order except when explicit collinear
/// normalization was requested. [canonicalVertices] is available only when
/// the resulting loop is geometrically safe; it is clockwise in Y-down space
/// and rotated to the lexicographically smallest complete cyclic sequence.
class TerrainSourceCanonicalizationResult {
  TerrainSourceCanonicalizationResult({
    required Iterable<SourceTerrainPoint> validatedVertices,
    required Iterable<SourceTerrainPoint>? canonicalVertices,
    required Iterable<TerrainDiagnostic> diagnostics,
    required this.signedDoubledArea,
  }) : validatedVertices = List<SourceTerrainPoint>.unmodifiable(
         validatedVertices,
       ),
       canonicalVertices = canonicalVertices == null
           ? null
           : List<SourceTerrainPoint>.unmodifiable(canonicalVertices),
       diagnostics = List<TerrainDiagnostic>.unmodifiable(
         List<TerrainDiagnostic>.of(diagnostics)..sort(),
       );

  /// Input-order loop after any explicitly requested collinear removal.
  final List<SourceTerrainPoint> validatedVertices;

  /// Safe clockwise/minimum-start loop, or `null` when validation blocks it.
  final List<SourceTerrainPoint>? canonicalVertices;

  /// Stable source/shape/element/code ordered findings.
  final List<TerrainDiagnostic> diagnostics;

  /// Shoelace sum in half-unit ticks squared; positive is clockwise in Y-down.
  final int signedDoubledArea;

  /// Whether any diagnostic blocks compilation or source commit.
  bool get hasBlockingDiagnostics =>
      diagnostics.any(terrainDiagnosticIsBlocking);

  /// Whether the reviewed loop is already in canonical winding/start order.
  bool get isCanonical {
    final canonical = canonicalVertices;
    return canonical != null &&
        !hasBlockingDiagnostics &&
        _pointListsEqual(validatedVertices, canonical);
  }
}

/// Core-owned exact review and explicit normalization seam for source loops.
///
/// The review performs no I/O and never mutates its input. Set
/// [normalizeCollinear] only for an explicit user action. Set
/// [requireCanonical] while loading committed source to surface stable
/// winding/start diagnostics instead of silently rewriting that source.
class TerrainSourceCanonicalizer {
  const TerrainSourceCanonicalizer();

  /// Reviews one [input] using integer half-unit predicates only.
  TerrainSourceCanonicalizationResult review(
    TerrainPolygonInput input, {
    bool normalizeCollinear = false,
    bool requireCanonical = false,
  }) {
    final diagnostics = <TerrainDiagnostic>[];
    if (input.sourcePath.isEmpty) {
      diagnostics.add(
        _diagnostic(
          input,
          0,
          'empty_source_path',
          'Source path must not be empty.',
        ),
      );
    }

    var source = List<SourceTerrainPoint>.of(input.vertices);
    if (source.length > 1 && source.first == source.last) {
      diagnostics.add(
        _diagnostic(
          input,
          source.length - 1,
          'repeated_closing_vertex',
          'The closing vertex must not repeat the first vertex.',
        ),
      );
    }
    for (var index = 1; index < source.length; index += 1) {
      if (source[index - 1] == source[index]) {
        diagnostics.add(
          _diagnostic(
            input,
            index,
            'consecutive_duplicate',
            'Consecutive source vertices must be distinct.',
          ),
        );
      }
    }
    if (source.toSet().length < 3) {
      diagnostics.add(
        _diagnostic(
          input,
          0,
          'too_few_vertices',
          'A polygon requires at least three distinct vertices.',
        ),
      );
      return _result(source, diagnostics, signedDoubledArea: 0);
    }

    final collinearIndices = _collinearMiddleIndices(source);
    if (collinearIndices.isNotEmpty && !normalizeCollinear) {
      for (final index in collinearIndices) {
        diagnostics.add(
          _diagnostic(
            input,
            index,
            'collinear_middle_vertex',
            'Collinear middle vertices require explicit normalization.',
          ),
        );
      }
    } else if (collinearIndices.isNotEmpty) {
      source = _removeCollinearMiddleVertices(source);
      for (final index in collinearIndices) {
        diagnostics.add(
          _diagnostic(
            input,
            index,
            'normalized_collinear_vertex',
            'Explicit normalization removed a collinear middle vertex.',
          ),
        );
      }
    }

    if (source.length < 3) {
      diagnostics.add(
        _diagnostic(
          input,
          0,
          'zero_area',
          'Normalization left fewer than three polygon vertices.',
        ),
      );
      return _result(source, diagnostics, signedDoubledArea: 0);
    }

    _validateSourceEdges(input, source, diagnostics);
    final signedDoubledArea = _signedDoubledArea(source);
    if (signedDoubledArea.abs() <
        2 * terrainSourceTicksPerWorldUnit * terrainSourceTicksPerWorldUnit) {
      diagnostics.add(
        _diagnostic(
          input,
          0,
          'minimum_area',
          'Polygon area must be at least one square world unit.',
        ),
      );
    }
    if (_hasSelfIntersection(source)) {
      diagnostics.add(
        _diagnostic(
          input,
          0,
          'self_intersection',
          'Polygon edges must not self-intersect.',
        ),
      );
    }

    if (diagnostics.any(terrainDiagnosticIsBlocking)) {
      return _result(source, diagnostics, signedDoubledArea: signedDoubledArea);
    }

    final windingCanonical = signedDoubledArea < 0
        ? source.reversed.toList(growable: false)
        : List<SourceTerrainPoint>.of(source);
    final firstIndex = _canonicalRotationIndex(windingCanonical);
    final canonical = _rotate(windingCanonical, firstIndex);
    if (requireCanonical) {
      if (signedDoubledArea < 0) {
        diagnostics.add(
          _diagnostic(
            input,
            0,
            'noncanonical_winding',
            'Source vertices must use clockwise winding in Y-down space.',
          ),
        );
      }
      if (firstIndex != 0) {
        diagnostics.add(
          _diagnostic(
            input,
            firstIndex,
            'noncanonical_start',
            'Source vertices must start at the canonical cyclic minimum.',
          ),
        );
      }
    }

    return TerrainSourceCanonicalizationResult(
      validatedVertices: source,
      canonicalVertices: canonical,
      diagnostics: diagnostics,
      signedDoubledArea: signedDoubledArea,
    );
  }
}

/// Whether [diagnostic] must block compilation or authoring commit.
bool terrainDiagnosticIsBlocking(TerrainDiagnostic diagnostic) =>
    diagnostic.code != 'normalized_collinear_vertex';

TerrainSourceCanonicalizationResult _result(
  List<SourceTerrainPoint> source,
  List<TerrainDiagnostic> diagnostics, {
  required int signedDoubledArea,
}) => TerrainSourceCanonicalizationResult(
  validatedVertices: source,
  canonicalVertices: null,
  diagnostics: diagnostics,
  signedDoubledArea: signedDoubledArea,
);

void _validateSourceEdges(
  TerrainPolygonInput input,
  List<SourceTerrainPoint> vertices,
  List<TerrainDiagnostic> diagnostics,
) {
  final minimumLengthSquared =
      terrainSourceTicksPerWorldUnit * terrainSourceTicksPerWorldUnit;
  for (var index = 0; index < vertices.length; index += 1) {
    final start = vertices[index];
    final end = vertices[(index + 1) % vertices.length];
    final dx = end.xTicks - start.xTicks;
    final dy = end.yTicks - start.yTicks;
    if (dx * dx + dy * dy < minimumLengthSquared) {
      diagnostics.add(
        _diagnostic(
          input,
          index,
          'minimum_edge_length',
          'Every source edge must be at least one world unit long.',
        ),
      );
    }
  }
}

List<int> _collinearMiddleIndices(List<SourceTerrainPoint> vertices) {
  final indices = <int>[];
  for (var index = 0; index < vertices.length; index += 1) {
    final previous = vertices[(index - 1 + vertices.length) % vertices.length];
    final current = vertices[index];
    final next = vertices[(index + 1) % vertices.length];
    if (_cross(previous, current, next) == 0) {
      indices.add(index);
    }
  }
  return indices;
}

List<SourceTerrainPoint> _removeCollinearMiddleVertices(
  List<SourceTerrainPoint> vertices,
) {
  var result = List<SourceTerrainPoint>.of(vertices);
  var changed = true;
  while (changed && result.length >= 3) {
    changed = false;
    final next = <SourceTerrainPoint>[];
    for (var index = 0; index < result.length; index += 1) {
      final previous = result[(index - 1 + result.length) % result.length];
      final current = result[index];
      final following = result[(index + 1) % result.length];
      if (_cross(previous, current, following) == 0) {
        changed = true;
      } else {
        next.add(current);
      }
    }
    result = next;
  }
  return result;
}

bool _hasSelfIntersection(List<SourceTerrainPoint> vertices) {
  for (var left = 0; left < vertices.length; left += 1) {
    final a = vertices[left];
    final b = vertices[(left + 1) % vertices.length];
    for (var right = left + 1; right < vertices.length; right += 1) {
      if (right == left ||
          (right + 1) % vertices.length == left ||
          (left + 1) % vertices.length == right) {
        continue;
      }
      final c = vertices[right];
      final d = vertices[(right + 1) % vertices.length];
      if (_segmentsIntersect(a, b, c, d)) return true;
    }
  }
  return false;
}

bool _segmentsIntersect(
  SourceTerrainPoint a,
  SourceTerrainPoint b,
  SourceTerrainPoint c,
  SourceTerrainPoint d,
) {
  final abC = _cross(a, b, c);
  final abD = _cross(a, b, d);
  final cdA = _cross(c, d, a);
  final cdB = _cross(c, d, b);
  if (((abC > 0 && abD < 0) || (abC < 0 && abD > 0)) &&
      ((cdA > 0 && cdB < 0) || (cdA < 0 && cdB > 0))) {
    return true;
  }
  return (abC == 0 && _pointOnSegment(c, a, b)) ||
      (abD == 0 && _pointOnSegment(d, a, b)) ||
      (cdA == 0 && _pointOnSegment(a, c, d)) ||
      (cdB == 0 && _pointOnSegment(b, c, d));
}

bool _pointOnSegment(
  SourceTerrainPoint point,
  SourceTerrainPoint start,
  SourceTerrainPoint end,
) =>
    point.xTicks >= math.min(start.xTicks, end.xTicks) &&
    point.xTicks <= math.max(start.xTicks, end.xTicks) &&
    point.yTicks >= math.min(start.yTicks, end.yTicks) &&
    point.yTicks <= math.max(start.yTicks, end.yTicks);

int _signedDoubledArea(List<SourceTerrainPoint> vertices) {
  var area = 0;
  for (var index = 0; index < vertices.length; index += 1) {
    final current = vertices[index];
    final next = vertices[(index + 1) % vertices.length];
    area += current.xTicks * next.yTicks - next.xTicks * current.yTicks;
  }
  return area;
}

int _cross(
  SourceTerrainPoint origin,
  SourceTerrainPoint a,
  SourceTerrainPoint b,
) =>
    (a.xTicks - origin.xTicks) * (b.yTicks - origin.yTicks) -
    (a.yTicks - origin.yTicks) * (b.xTicks - origin.xTicks);

int _canonicalRotationIndex(List<SourceTerrainPoint> vertices) {
  var best = 0;
  for (var index = 1; index < vertices.length; index += 1) {
    final pointOrder = _comparePoints(vertices[index], vertices[best]);
    if (pointOrder < 0 ||
        (pointOrder == 0 && _cyclicCompare(vertices, index, best) < 0)) {
      best = index;
    }
  }
  return best;
}

int _cyclicCompare(List<SourceTerrainPoint> vertices, int left, int right) {
  for (var offset = 0; offset < vertices.length; offset += 1) {
    final order = _comparePoints(
      vertices[(left + offset) % vertices.length],
      vertices[(right + offset) % vertices.length],
    );
    if (order != 0) return order;
  }
  return 0;
}

int _comparePoints(SourceTerrainPoint left, SourceTerrainPoint right) {
  final xOrder = left.xTicks.compareTo(right.xTicks);
  return xOrder != 0 ? xOrder : left.yTicks.compareTo(right.yTicks);
}

List<T> _rotate<T>(List<T> values, int start) => <T>[
  ...values.skip(start),
  ...values.take(start),
];

bool _pointListsEqual(
  List<SourceTerrainPoint> left,
  List<SourceTerrainPoint> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
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
