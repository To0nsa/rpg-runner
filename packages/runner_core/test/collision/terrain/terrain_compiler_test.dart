import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:test/test.dart';

void main() {
  const compiler = TerrainCompiler();

  group('canonicalization and validation', () {
    test(
      'every cyclic rotation and reversed winding canonicalizes equally',
      () {
        const vertices = <(double, double)>[(0, 0), (20, 0), (20, 10), (0, 10)];
        final canonical = compiler.compile(<TerrainPolygonInput>[
          _input('base', vertices),
        ], geometryVersion: 1);

        for (var start = 0; start < vertices.length; start += 1) {
          final rotated = <(double, double)>[
            ...vertices.skip(start),
            ...vertices.take(start),
          ];
          for (final candidate in <List<(double, double)>>[
            rotated,
            rotated.reversed.toList(),
          ]) {
            final geometry = compiler.compile(<TerrainPolygonInput>[
              _input('base', candidate),
            ], geometryVersion: 1);
            expect(geometry.polygons.single, canonical.polygons.single);
            expect(
              geometry.canonicalEdgeRecords(),
              canonical.canonicalEdgeRecords(),
            );
          }
        }
      },
    );

    test(
      'concavity is retained and explicit collinear normalization reports',
      () {
        final input = _input('concave', const <(double, double)>[
          (0, 0),
          (10, 0),
          (20, 0),
          (20, 20),
          (10, 10),
          (0, 20),
        ]);

        expect(
          () => compiler.compile(<TerrainPolygonInput>[
            input,
          ], geometryVersion: 1),
          throwsA(isA<TerrainValidationException>()),
        );

        final normalized = compiler.compile(
          <TerrainPolygonInput>[input],
          geometryVersion: 1,
          normalizeCollinear: true,
        );
        expect(normalized.polygons.single.vertices, hasLength(5));
        expect(
          normalized.diagnostics.single.code,
          'normalized_collinear_vertex',
        );
      },
    );

    test(
      'rejects duplicate, closing, short, zero-area, and crossing shapes',
      () {
        final invalid = <TerrainPolygonInput>[
          _input('closing', const [(0, 0), (10, 0), (0, 10), (0, 0)]),
          _input('duplicate', const [(0, 0), (10, 0), (10, 0), (0, 10)]),
          _input('short', const [(0, 0), (0.5, 0), (0, 10)]),
          _input('zero', const [(0, 0), (10, 0), (20, 0)]),
          _input('crossing', const [(0, 0), (20, 20), (0, 20), (20, 0)]),
        ];

        for (final input in invalid) {
          expect(
            () => compiler.compile(<TerrainPolygonInput>[
              input,
            ], geometryVersion: 1),
            throwsA(isA<TerrainValidationException>()),
            reason: input.identity.shapeId,
          );
        }
      },
    );

    test('rejects edges made too short by an exact placement scale', () {
      final input = TerrainPolygonInput.fromWorld(
        sourcePath: 'test/transformed_short',
        identity: TerrainSourceIdentity(
          chunkIndex: 0,
          chunkKey: 'chunk',
          shapeId: 'transformed_short',
        ),
        vertices: const <(double, double)>[(0, 0), (1, 0), (1, 1), (0, 1)],
        transform: const TerrainSourceTransform(
          scaleNumerator: 3,
          scaleDenominator: 10,
        ),
      );

      expect(
        () =>
            compiler.compile(<TerrainPolygonInput>[input], geometryVersion: 1),
        throwsA(
          isA<TerrainValidationException>().having(
            (error) =>
                error.diagnostics.map((diagnostic) => diagnostic.code).toSet(),
            'diagnostic codes',
            <String>{'transform_minimum_edge_length'},
          ),
        ),
      );
    });

    test(
      'accepts exact shared boundaries and rejects occupied-area overlap',
      () {
        final left = _input('left', const [(0, 0), (10, 0), (10, 10), (0, 10)]);
        final adjacent = _input('adjacent', const [
          (10, 0),
          (20, 0),
          (20, 10),
          (10, 10),
        ]);
        final overlap = _input('overlap', const [
          (5, 0),
          (15, 0),
          (15, 10),
          (5, 10),
        ]);

        final geometry = compiler.compile(<TerrainPolygonInput>[
          adjacent,
          left,
        ], geometryVersion: 1);
        expect(geometry.edges, hasLength(6));
        expect(
          () => compiler.compile(<TerrainPolygonInput>[
            left,
            overlap,
          ], geometryVersion: 1),
          throwsA(isA<TerrainValidationException>()),
        );
      },
    );

    test('partially shared solid edges split before internal removal', () {
      final upper = _input('upper', const [(0, 0), (20, 0), (20, 10), (0, 10)]);
      final lowerLeft = _input('lower_left', const [
        (0, 10),
        (10, 10),
        (10, 20),
        (0, 20),
      ]);
      final lowerRight = _input('lower_right', const [
        (10, 10),
        (20, 10),
        (20, 20),
        (10, 20),
      ]);

      final geometry = compiler.compile(<TerrainPolygonInput>[
        upper,
        lowerLeft,
        lowerRight,
      ], geometryVersion: 1);
      expect(
        geometry.edges.where(
          (edge) =>
              edge.start.yTicks == 10 * terrainPhysicsTicksPerWorldUnit &&
              edge.end.yTicks == 10 * terrainPhysicsTicksPerWorldUnit,
        ),
        isEmpty,
      );
    });

    test('one-way loop emits only its upward authored top edge', () {
      final input = TerrainPolygonInput.fromWorld(
        sourcePath: 'one_way',
        identity: TerrainSourceIdentity(
          chunkIndex: 0,
          chunkKey: 'chunk',
          shapeId: 'one_way',
        ),
        vertices: const [(0, 10), (20, 0), (20, 2), (0, 12)],
        collisionMode: TerrainCollisionMode.oneWay,
      );

      final geometry = compiler.compile(<TerrainPolygonInput>[
        input,
      ], geometryVersion: 1);
      expect(geometry.edges, hasLength(1));
      expect(geometry.edges.single.outwardNormal.yTicks, lessThan(0));
      expect(geometry.edges.single.previousId, isNull);
      expect(geometry.edges.single.nextId, isNull);
    });

    test('compiled horizontal, vertical, and slope fields are exact', () {
      final geometry = compiler.compile(<TerrainPolygonInput>[
        _input('fields', const [(0, 0), (20, 0), (20, 20), (10, 10), (0, 20)]),
      ], geometryVersion: 1);

      expect(geometry.edges.any((edge) => edge.dyTicks == 0), isTrue);
      expect(geometry.edges.any((edge) => edge.dxTicks == 0), isTrue);
      expect(
        geometry.edges.any((edge) => edge.dxTicks != 0 && edge.dyTicks != 0),
        isTrue,
      );
      for (final edge in geometry.edges) {
        expect(
          edge.tangent,
          TerrainDirection.fromDelta(edge.dxTicks, edge.dyTicks),
        );
        expect(
          edge.outwardNormal,
          TerrainDirection.fromDelta(edge.dyTicks, -edge.dxTicks),
        );
        expect(
          <int>[
            edge.bounds.minX,
            edge.bounds.minY,
            edge.bounds.maxX,
            edge.bounds.maxY,
          ],
          <int>[
            edge.start.xTicks < edge.end.xTicks
                ? edge.start.xTicks
                : edge.end.xTicks,
            edge.start.yTicks < edge.end.yTicks
                ? edge.start.yTicks
                : edge.end.yTicks,
            edge.start.xTicks > edge.end.xTicks
                ? edge.start.xTicks
                : edge.end.xTicks,
            edge.start.yTicks > edge.end.yTicks
                ? edge.start.yTicks
                : edge.end.yTicks,
          ],
        );
      }
    });
  });
}

TerrainPolygonInput _input(String shapeId, List<(double, double)> vertices) =>
    TerrainPolygonInput.fromWorld(
      sourcePath: 'test/$shapeId',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'chunk',
        shapeId: shapeId,
      ),
      vertices: vertices,
      surfaceKind: 'terrain',
    );
