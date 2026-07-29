import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_source_canonicalizer.dart';
import 'package:test/test.dart';

void main() {
  const canonicalizer = TerrainSourceCanonicalizer();
  const compiler = TerrainCompiler();

  test('reports noncanonical start and returns the canonical cyclic loop', () {
    final input = _input('rotated', const <(int, int)>[
      (20, 10),
      (0, 10),
      (0, 0),
      (20, 0),
    ]);

    final result = canonicalizer.review(input, requireCanonical: true);

    expect(result.signedDoubledArea, 400);
    expect(result.diagnostics.map((diagnostic) => diagnostic.code), <String>[
      'noncanonical_start',
    ]);
    expect(result.hasBlockingDiagnostics, isTrue);
    expect(
      result.canonicalVertices,
      _points(const <(int, int)>[(0, 0), (20, 0), (20, 10), (0, 10)]),
    );
  });

  test('reports counterclockwise winding without mutating source order', () {
    final input = _input('reversed', const <(int, int)>[
      (0, 10),
      (20, 10),
      (20, 0),
      (0, 0),
    ]);

    final result = canonicalizer.review(input, requireCanonical: true);

    expect(result.signedDoubledArea, -400);
    expect(result.validatedVertices, input.vertices);
    expect(result.diagnostics.map((diagnostic) => diagnostic.code), <String>[
      'noncanonical_winding',
    ]);
    expect(
      result.canonicalVertices,
      _points(const <(int, int)>[(0, 0), (20, 0), (20, 10), (0, 10)]),
    );
  });

  test('signed area remains exact for negative half-unit coordinates', () {
    final result = canonicalizer.review(
      _input('half_grid', const <(int, int)>[
        (-1, -1),
        (3, -1),
        (3, 3),
        (-1, 3),
      ]),
      requireCanonical: true,
    );

    expect(result.signedDoubledArea, 32);
    expect(result.isCanonical, isTrue);
    expect(result.diagnostics, isEmpty);
  });

  test('collinear removal occurs only in explicit normalization mode', () {
    final input = _input('collinear', const <(int, int)>[
      (0, 0),
      (10, 0),
      (20, 0),
      (20, 20),
      (0, 20),
    ]);

    final preserved = canonicalizer.review(input);
    final normalized = canonicalizer.review(
      input,
      normalizeCollinear: true,
      requireCanonical: true,
    );

    expect(preserved.hasBlockingDiagnostics, isTrue);
    expect(preserved.validatedVertices, hasLength(5));
    expect(preserved.diagnostics.single.code, 'collinear_middle_vertex');
    expect(normalized.hasBlockingDiagnostics, isFalse);
    expect(normalized.validatedVertices, hasLength(4));
    expect(normalized.diagnostics.single.code, 'normalized_collinear_vertex');
    expect(normalized.isCanonical, isTrue);
  });

  test('compiler and source review retain identical blocking diagnostics', () {
    final invalid = <TerrainPolygonInput>[
      _input('closing', const [(0, 0), (10, 0), (0, 10), (0, 0)]),
      _input('duplicate', const [(0, 0), (10, 0), (10, 0), (0, 10)]),
      _input('short', const [(0, 0), (1, 0), (0, 10)]),
      _input('zero', const [(0, 0), (10, 0), (20, 0)]),
      _input('crossing', const [(0, 0), (20, 20), (0, 20), (20, 0)]),
    ];

    for (final input in invalid) {
      final reviewCodes = canonicalizer
          .review(input)
          .diagnostics
          .map((diagnostic) => diagnostic.code)
          .toList(growable: false);

      expect(
        () =>
            compiler.compile(<TerrainPolygonInput>[input], geometryVersion: 1),
        throwsA(
          isA<TerrainValidationException>().having(
            (error) => error.diagnostics
                .map((diagnostic) => diagnostic.code)
                .toList(growable: false),
            'diagnostic codes',
            reviewCodes,
          ),
        ),
        reason: input.identity.shapeId,
      );
    }
  });

  test('compiler still accepts rotations without source-authoring policy', () {
    final rotated = _input('runtime', const <(int, int)>[
      (20, 10),
      (0, 10),
      (0, 0),
      (20, 0),
    ]);

    final review = canonicalizer.review(rotated);
    final geometry = compiler.compile(<TerrainPolygonInput>[
      rotated,
    ], geometryVersion: 1);

    expect(review.hasBlockingDiagnostics, isFalse);
    expect(review.diagnostics, isEmpty);
    expect(geometry.polygons.single.sourceVertices, review.canonicalVertices);
  });
}

TerrainPolygonInput _input(String shapeId, List<(int, int)> vertices) =>
    TerrainPolygonInput(
      sourcePath: 'test/$shapeId',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'chunk',
        shapeId: shapeId,
      ),
      vertices: _points(vertices),
    );

List<SourceTerrainPoint> _points(List<(int, int)> vertices) => vertices
    .map((point) => SourceTerrainPoint(point.$1, point.$2))
    .toList(growable: false);
