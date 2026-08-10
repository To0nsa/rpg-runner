import 'terrain_numeric.dart';
import 'terrain_polygon.dart';

/// Three indices into one compiled polygon's canonical physics loop.
///
/// Indices retain the deterministic ear-clipping order selected by
/// [TerrainTriangulator]; they do not identify collision edges.
final class TerrainTriangleIndices {
  const TerrainTriangleIndices(this.first, this.second, this.third);

  final int first;
  final int second;
  final int third;

  @override
  bool operator ==(Object other) =>
      other is TerrainTriangleIndices &&
      first == other.first &&
      second == other.second &&
      third == other.third;

  @override
  int get hashCode => Object.hash(first, second, third);
}

/// Deterministically triangulates a Core-normalized terrain polygon.
///
/// The input must be Core's simple clockwise Y-down canonical loop in
/// 1/1024-world-unit physics ticks. The first valid ear in surviving canonical
/// index order wins. Exact [BigInt] predicates and a final area/count proof
/// prevent render triangles from becoming a second normalization authority.
/// Invalid or noncanonical compiled input fails with [StateError].
final class TerrainTriangulator {
  const TerrainTriangulator();

  List<TerrainTriangleIndices> triangulate(TerrainPolygon polygon) {
    final vertices = polygon.vertices;
    if (vertices.length < 3) {
      throw StateError(
        'Cannot triangulate ${polygon.sourcePath}:'
        '${polygon.identity.shapeId} with fewer than three vertices.',
      );
    }
    final remaining = <int>[
      for (var index = 0; index < vertices.length; index += 1) index,
    ];
    final triangles = <TerrainTriangleIndices>[];
    while (remaining.length > 3) {
      var earPosition = -1;
      for (var position = 0; position < remaining.length; position += 1) {
        final previous = remaining[(position - 1) % remaining.length];
        final current = remaining[position];
        final next = remaining[(position + 1) % remaining.length];
        if (_cross(vertices[previous], vertices[current], vertices[next]) <=
            BigInt.zero) {
          continue;
        }
        var containsVertex = false;
        for (final candidate in remaining) {
          if (candidate == previous ||
              candidate == current ||
              candidate == next) {
            continue;
          }
          if (_insideTriangle(
            vertices[candidate],
            vertices[previous],
            vertices[current],
            vertices[next],
          )) {
            containsVertex = true;
            break;
          }
        }
        if (!containsVertex) {
          earPosition = position;
          break;
        }
      }
      if (earPosition < 0) {
        throw StateError(
          'Could not triangulate '
          '${polygon.sourcePath}:${polygon.identity.shapeId}.',
        );
      }
      final previous = remaining[(earPosition - 1) % remaining.length];
      final current = remaining[earPosition];
      final next = remaining[(earPosition + 1) % remaining.length];
      triangles.add(TerrainTriangleIndices(previous, current, next));
      remaining.removeAt(earPosition);
    }
    triangles.add(
      TerrainTriangleIndices(remaining[0], remaining[1], remaining[2]),
    );

    final expectedArea = _polygonArea(vertices);
    final triangleArea = triangles.fold<BigInt>(BigInt.zero, (sum, triangle) {
      return sum +
          _cross(
            vertices[triangle.first],
            vertices[triangle.second],
            vertices[triangle.third],
          );
    });
    if (triangles.length != vertices.length - 2 ||
        expectedArea <= BigInt.zero ||
        triangleArea != expectedArea) {
      throw StateError(
        'Triangulation area/count mismatch for '
        '${polygon.sourcePath}:${polygon.identity.shapeId}.',
      );
    }
    return List<TerrainTriangleIndices>.unmodifiable(triangles);
  }
}

bool _insideTriangle(
  TerrainPoint point,
  TerrainPoint first,
  TerrainPoint second,
  TerrainPoint third,
) =>
    _cross(first, second, point) >= BigInt.zero &&
    _cross(second, third, point) >= BigInt.zero &&
    _cross(third, first, point) >= BigInt.zero;

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

BigInt _cross(TerrainPoint first, TerrainPoint second, TerrainPoint third) =>
    BigInt.from(second.xTicks - first.xTicks) *
        BigInt.from(third.yTicks - first.yTicks) -
    BigInt.from(second.yTicks - first.yTicks) *
        BigInt.from(third.xTicks - first.xTicks);
