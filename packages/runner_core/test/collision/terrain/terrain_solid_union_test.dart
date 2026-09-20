import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:test/test.dart';

void main() {
  test(
    'partial overlap exposes only the combined outline with source lineage',
    () {
      final inputs = [_rect('a', 0, 0, 20, 20), _rect('b', 10, -10, 30, 10)];
      final geometry = _compile(inputs);
      expect(geometry.polygons, hasLength(2));
      expect(_segments(geometry), {
        (0.0, 0.0, 10.0, 0.0),
        (10.0, 0.0, 10.0, -10.0),
        (10.0, -10.0, 30.0, -10.0),
        (30.0, -10.0, 30.0, 10.0),
        (30.0, 10.0, 20.0, 10.0),
        (20.0, 10.0, 20.0, 20.0),
        (20.0, 20.0, 0.0, 20.0),
        (0.0, 20.0, 0.0, 0.0),
      });
      _expectClosed(geometry);
      expect(
        _compile(inputs.reversed).canonicalEdgeRecords(),
        geometry.canonicalEdgeRecords(),
      );
      expect(geometry.edges.map((edge) => edge.id.placementKey).toSet(), {
        'a',
        'b',
      });
    },
  );

  test('contained and identical solids add no interior collision faces', () {
    final outer = _rect('a', 0, 0, 40, 40);
    final geometry = _compile([
      _rect('c', 0, 0, 40, 40),
      _rect('b', 10, 10, 30, 30),
      outer,
    ]);
    expect(geometry.polygons, hasLength(3));
    expect(_segments(geometry), _segments(_compile([outer])));
    expect(geometry.edges.every((edge) => edge.id.placementKey == 'a'), isTrue);
    _expectClosed(geometry);
  });

  test('triple coverage removes buried opposing and coincident segments', () {
    final geometry = _compile([
      _rect('a', 0, 0, 20, 20),
      _rect('b', 10, 0, 30, 20),
      _rect('c', 10, 20, 30, 40),
      _rect('d', 10, 0, 30, 20),
    ]);
    expect(
      geometry.edges.where(
        (edge) =>
            edge.start.y == 20 &&
            edge.end.y == 20 &&
            edge.start.x >= 10 &&
            edge.end.x >= 10,
      ),
      isEmpty,
    );
    expect(
      geometry.edges.map((edge) => (edge.start, edge.end)).toSet(),
      hasLength(geometry.edges.length),
    );
    _expectClosed(geometry);
  });

  test('sloped crossings share one exactly rounded physics endpoint', () {
    final geometry = _compile([
      _placed('a', const [(0, 0), (30, 20), (0, 20)]),
      _rect('b', 10, -10, 20, 30),
    ]);
    expect(
      geometry.edges.any(
        (edge) =>
            edge.start == TerrainPoint(10 * 1024, 6827) ||
            edge.end == TerrainPoint(10 * 1024, 6827),
      ),
      isTrue,
    );
    expect(
      geometry.edges.any(
        (edge) =>
            edge.start == TerrainPoint(20 * 1024, 13653) ||
            edge.end == TerrainPoint(20 * 1024, 13653),
      ),
      isTrue,
    );
    _expectClosed(geometry);
  });

  test('union preserves an enclosed empty hole', () {
    final geometry = _compile([
      _rect('a', 0, 0, 40, 12),
      _rect('b', 28, 0, 40, 40),
      _rect('c', 0, 28, 40, 40),
      _rect('d', 0, 0, 12, 40),
    ]);
    expect(
      _segments(geometry),
      containsAll({
        (28.0, 12.0, 12.0, 12.0),
        (12.0, 12.0, 12.0, 28.0),
        (12.0, 28.0, 28.0, 28.0),
        (28.0, 28.0, 28.0, 12.0),
      }),
    );
    _expectClosed(geometry);
  });

  test(
    'point-touching components retain separate reciprocal boundary loops',
    () {
      final geometry = _compile([
        _rect('a', 0, 0, 10, 10),
        _rect('b', 5, 0, 15, 10),
        _rect('c', 15, 10, 25, 20),
      ]);
      _expectClosed(geometry);
      for (final edge in geometry.edges.where(
        (edge) => edge.id.placementKey == 'c',
      )) {
        expect(edge.previousId!.placementKey, 'c');
        expect(edge.nextId!.placementKey, 'c');
      }
    },
  );

  test('large negative coordinates retain exact intersections', () {
    const offset = -1000000000.0;
    final geometry = _compile([
      _rect('a', offset, offset, offset + 20, offset + 20),
      _rect('b', offset + 10, offset - 10, offset + 30, offset + 10),
    ]);
    expect(geometry.edges, hasLength(8));
    _expectClosed(geometry);
  });

  test(
    'reflected scaled placements retain order-independent joined semantics',
    () {
      final inputs = <TerrainPolygonInput>[
        for (final (placement, offset, kind) in [
          ('a', 40, 'stone'),
          ('b', 50, 'wood'),
        ])
          TerrainPolygonInput.fromWorld(
            sourcePath: 'test/$placement',
            identity: TerrainSourceIdentity(
              chunkIndex: 0,
              chunkKey: 'chunk',
              placementKey: placement,
              shapeId: 'shape',
            ),
            vertices: const [(0, 0), (20, 0), (20, 20), (0, 20)],
            transform: TerrainSourceTransform(
              reflectX: true,
              scaleNumerator: 13,
              scaleDenominator: 10,
              translateXSourceTicks: offset * terrainSourceTicksPerWorldUnit,
            ),
            surfaceKind: kind,
            materialKey: kind,
          ),
      ];
      final geometry = _compile(inputs);
      _expectClosed(geometry);
      expect(geometry.edges.map((edge) => edge.surfaceKind).toSet(), {
        'stone',
        'wood',
      });
      expect(
        geometry.edges.every((edge) => edge.surfaceKind == edge.materialKey),
        isTrue,
      );
      expect(
        _compile(inputs.reversed).canonicalEdgeRecords(),
        geometry.canonicalEdgeRecords(),
      );
    },
  );

  test('obstacle embedded in terrain exposes a joined outline across surface kinds', () {
    final terrain = _placed(null, const [
      (0, 10),
      (40, 10),
      (40, 40),
      (0, 40),
    ], kind: 'ground');
    final obstacle = _rect('rock', 10, 0, 30, 20);
    final geometry = _compile([terrain, obstacle]);
    expect(geometry.polygons, hasLength(2));
    expect(_segments(geometry), {
      (0.0, 10.0, 10.0, 10.0),
      (10.0, 10.0, 10.0, 0.0),
      (10.0, 0.0, 30.0, 0.0),
      (30.0, 0.0, 30.0, 10.0),
      (30.0, 10.0, 40.0, 10.0),
      (40.0, 10.0, 40.0, 40.0),
      (40.0, 40.0, 0.0, 40.0),
      (0.0, 40.0, 0.0, 10.0),
    });
    _expectClosed(geometry);
    expect(
      _compile([obstacle, terrain]).canonicalEdgeRecords(),
      geometry.canonicalEdgeRecords(),
    );
  });

  test('fully buried obstacles leave only the terrain outline', () {
    final terrain = _placed(null, const [
      (0, 0),
      (40, 0),
      (40, 40),
      (0, 40),
    ], kind: 'ground');
    final geometry = _compile([terrain, _rect('rock', 10, 10, 30, 30)]);
    expect(_segments(geometry), _segments(_compile([terrain])));
    expect(
      geometry.edges.every((edge) => edge.id.placementKey == null),
      isTrue,
    );
    _expectClosed(geometry);
  });

  test(
    'sloped terrain clips obstacle sides at a shared physics-grid crossing',
    () {
      final terrain = _placed(null, const [
        (0, 0),
        (30, 20),
        (30, 40),
        (0, 40),
      ], kind: 'ground');
      final geometry = _compile([terrain, _rect('rock', 10, 0, 20, 30)]);
      expect(geometry.edges, hasLength(8));
      expect(
        geometry.edges.where((edge) => edge.id.placementKey == 'rock'),
        hasLength(3),
      );
      expect(
        geometry.edges.any((edge) => edge.end == TerrainPoint(10 * 1024, 6827)),
        isTrue,
      );
      expect(
        geometry.edges.any(
          (edge) => edge.start == TerrainPoint(20 * 1024, 13653),
        ),
        isTrue,
      );
      _expectClosed(geometry);
    },
  );

  test('platforms and same-placement overlap still reject', () {
    for (final other in [
      _placed('b', const [
        (5, 0),
        (15, 0),
        (15, 10),
        (5, 10),
      ], mode: TerrainCollisionMode.oneWay),
      _placed(null, const [
        (5, 0),
        (15, 0),
        (15, 10),
        (5, 10),
      ], mode: TerrainCollisionMode.oneWay),
      _placed('a', const [(5, 0), (15, 0), (15, 10), (5, 10)], shape: 'second'),
    ]) {
      expect(
        () => _compile([_rect('a', 0, 0, 10, 10), other]),
        throwsA(isA<TerrainValidationException>()),
      );
    }
  });

  test('overlap between direct terrain shapes remains invalid', () {
    expect(
      () => _compile([
        _placed(null, const [
          (0, 0),
          (10, 0),
          (10, 10),
          (0, 10),
        ], shape: 'ground'),
        _placed(null, const [
          (5, 0),
          (15, 0),
          (15, 10),
          (5, 10),
        ], shape: 'other'),
      ]),
      throwsA(isA<TerrainValidationException>()),
    );
  });
}

TerrainGeometry _compile(Iterable<TerrainPolygonInput> inputs) =>
    const TerrainCompiler().compile(inputs, geometryVersion: 1);

TerrainPolygonInput _rect(
  String placement,
  double x1,
  double y1,
  double x2,
  double y2,
) => _placed(placement, [(x1, y1), (x2, y1), (x2, y2), (x1, y2)]);

TerrainPolygonInput _placed(
  String? placement,
  List<(double, double)> vertices, {
  TerrainCollisionMode mode = TerrainCollisionMode.solid,
  String shape = 'shape',
  String kind = 'obstacle',
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/${placement ?? 'direct'}/$shape',
  identity: TerrainSourceIdentity(
    chunkIndex: 0,
    chunkKey: 'chunk',
    placementKey: placement,
    shapeId: shape,
  ),
  vertices: vertices,
  collisionMode: mode,
  surfaceKind: kind,
);

Set<(double, double, double, double)> _segments(TerrainGeometry geometry) => {
  for (final edge in geometry.edges)
    (edge.start.x, edge.start.y, edge.end.x, edge.end.y),
};

void _expectClosed(TerrainGeometry geometry) {
  for (final edge in geometry.edges) {
    final previous = geometry.edgeById[edge.previousId];
    final next = geometry.edgeById[edge.nextId];
    expect(previous, isNotNull, reason: '${edge.id} has no predecessor');
    expect(next, isNotNull, reason: '${edge.id} has no successor');
    expect(previous!.end, edge.start);
    expect(next!.start, edge.end);
    expect(previous.nextId, edge.id);
    expect(next.previousId, edge.id);
  }
}
