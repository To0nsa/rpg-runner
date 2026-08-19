import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon_overlap.dart';
import 'package:test/test.dart';

void main() {
  test('strict point containment excludes every boundary feature', () {
    final loop = _points(const <(int, int)>[
      (0, 0),
      (10, 0),
      (10, 10),
      (0, 10),
    ]);

    expect(
      TerrainPolygonOverlap.physicsLoopContainsPointStrictly(
        loop.map((point) => point.toPhysicsPoint()).toList(),
        SourceTerrainPoint(5, 5).toPhysicsPoint(),
      ),
      isTrue,
    );
    for (final point in const <(int, int)>[(0, 0), (5, 0), (10, 5)]) {
      expect(
        TerrainPolygonOverlap.physicsLoopContainsPointStrictly(
          loop.map((point) => point.toPhysicsPoint()).toList(),
          SourceTerrainPoint(point.$1, point.$2).toPhysicsPoint(),
        ),
        isFalse,
      );
    }
    expect(
      TerrainPolygonOverlap.physicsLoopContainsPointStrictly(
        loop.map((point) => point.toPhysicsPoint()).toList(),
        SourceTerrainPoint(12, 5).toPhysicsPoint(),
      ),
      isFalse,
    );
  });

  test('permits a shared full boundary and point-only contact', () {
    final left = _points(const <(int, int)>[
      (0, 0),
      (10, 0),
      (10, 10),
      (0, 10),
    ]);
    final edgeAdjacent = _points(const <(int, int)>[
      (10, 0),
      (20, 0),
      (20, 10),
      (10, 10),
    ]);
    final pointAdjacent = _points(const <(int, int)>[
      (10, 10),
      (20, 10),
      (10, 20),
    ]);

    expect(TerrainPolygonOverlap.sourceLoops(left, edgeAdjacent), isFalse);
    expect(TerrainPolygonOverlap.sourceLoops(left, pointAdjacent), isFalse);
  });

  test('detects proper crossing and strict containment', () {
    final horizontal = _points(const <(int, int)>[
      (-10, -2),
      (10, -2),
      (10, 2),
      (-10, 2),
    ]);
    final vertical = _points(const <(int, int)>[
      (-2, -10),
      (2, -10),
      (2, 10),
      (-2, 10),
    ]);
    final contained = _points(const <(int, int)>[(-3, -1), (3, -1), (0, 1)]);

    expect(TerrainPolygonOverlap.sourceLoops(horizontal, vertical), isTrue);
    expect(TerrainPolygonOverlap.sourceLoops(horizontal, contained), isTrue);
  });

  test('detects identical occupied area independent of winding', () {
    final clockwise = _points(const <(int, int)>[
      (-1, -1),
      (9, -1),
      (9, 9),
      (-1, 9),
    ]);
    final counterclockwise = clockwise.reversed.toList(growable: false);

    expect(
      TerrainPolygonOverlap.sourceLoops(clockwise, counterclockwise),
      isTrue,
    );
  });

  test('handles concave empty space separately from occupied arms', () {
    final concave = _points(const <(int, int)>[
      (0, 0),
      (12, 0),
      (12, 4),
      (4, 4),
      (4, 12),
      (0, 12),
    ]);
    final inNotch = _points(const <(int, int)>[
      (6, 6),
      (10, 6),
      (10, 10),
      (6, 10),
    ]);
    final inArm = _points(const <(int, int)>[(1, 5), (3, 5), (3, 9), (1, 9)]);

    expect(TerrainPolygonOverlap.sourceLoops(concave, inNotch), isFalse);
    expect(TerrainPolygonOverlap.sourceLoops(concave, inArm), isTrue);
  });

  test('keeps accepted near-limit integer containment exact', () {
    const limit = terrainMaxAbsSourceTicks;
    final outer = _points(const <(int, int)>[
      (-limit, -limit),
      (limit, -limit),
      (limit, limit),
      (-limit, limit),
    ]);
    final inner = _points(const <(int, int)>[(-1, -1), (1, -1), (0, 1)]);

    expect(TerrainPolygonOverlap.sourceLoops(outer, inner), isTrue);
  });

  test('physics-grid entry point uses the same boundary policy', () {
    final upper = _physicsPoints(const <(int, int)>[
      (0, 0),
      (10, 0),
      (10, 10),
      (0, 10),
    ]);
    final lower = _physicsPoints(const <(int, int)>[
      (0, 10),
      (10, 10),
      (10, 20),
      (0, 20),
    ]);

    expect(TerrainPolygonOverlap.physicsLoops(upper, lower), isFalse);
    expect(TerrainPolygonOverlap.physicsLoops(upper, upper), isTrue);
  });
}

List<SourceTerrainPoint> _points(List<(int, int)> values) => values
    .map((value) => SourceTerrainPoint(value.$1, value.$2))
    .toList(growable: false);

List<TerrainPoint> _physicsPoints(List<(int, int)> values) => values
    .map((value) => TerrainPoint(value.$1, value.$2))
    .toList(growable: false);
