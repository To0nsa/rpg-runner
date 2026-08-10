import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_triangulator.dart';
import 'package:test/test.dart';

void main() {
  const triangulator = TerrainTriangulator();

  test('first-ear order is exact for convex and concave canonical loops', () {
    final rectangle = _compile(const <(double, double)>[
      (0, 0),
      (4, 0),
      (4, 2),
      (0, 2),
    ]);
    final concave = _compile(const <(double, double)>[
      (0, 20),
      (40, 20),
      (40, 40),
      (24, 40),
      (24, 30),
      (16, 30),
      (16, 40),
      (0, 40),
    ]);

    expect(triangulator.triangulate(rectangle), const <TerrainTriangleIndices>[
      TerrainTriangleIndices(3, 0, 1),
      TerrainTriangleIndices(1, 2, 3),
    ]);
    final triangles = triangulator.triangulate(concave);
    expect(triangles, const <TerrainTriangleIndices>[
      TerrainTriangleIndices(1, 2, 3),
      TerrainTriangleIndices(1, 3, 4),
      TerrainTriangleIndices(0, 1, 4),
      TerrainTriangleIndices(0, 4, 5),
      TerrainTriangleIndices(7, 0, 5),
      TerrainTriangleIndices(5, 6, 7),
    ]);
    expect(
      () => triangles.add(const TerrainTriangleIndices(0, 1, 2)),
      throwsUnsupportedError,
    );
  });

  test(
    'compiler normalization makes every loop spelling triangulate equally',
    () {
      const canonical = <(double, double)>[
        (0, 20),
        (40, 20),
        (40, 40),
        (24, 40),
        (24, 30),
        (16, 30),
        (16, 40),
        (0, 40),
      ];
      final expected = triangulator.triangulate(_compile(canonical));

      for (var rotation = 0; rotation < canonical.length; rotation += 1) {
        final rotated = <(double, double)>[
          ...canonical.skip(rotation),
          ...canonical.take(rotation),
        ];
        for (final spelling in <List<(double, double)>>[
          rotated,
          rotated.reversed.toList(growable: false),
        ]) {
          expect(triangulator.triangulate(_compile(spelling)), expected);
        }
      }
    },
  );

  test('malformed compiled loop fails instead of fabricating triangles', () {
    final malformed = TerrainPolygon(
      sourcePath: 'fixture/malformed',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'chunk',
        shapeId: 'malformed',
      ),
      sourceVertices: <SourceTerrainPoint>[
        SourceTerrainPoint(0, 0),
        SourceTerrainPoint(2, 0),
      ],
      vertices: <TerrainPoint>[TerrainPoint(0, 0), TerrainPoint(1024, 0)],
      collisionMode: TerrainCollisionMode.solid,
      surfaceKind: null,
      materialKey: null,
    );

    expect(() => triangulator.triangulate(malformed), throwsStateError);
  });
}

TerrainPolygon _compile(List<(double, double)> vertices) =>
    const TerrainCompiler()
        .compile(<TerrainPolygonInput>[
          TerrainPolygonInput.fromWorld(
            sourcePath: 'fixture/polygon',
            identity: TerrainSourceIdentity(
              chunkIndex: 0,
              chunkKey: 'chunk',
              shapeId: 'shape',
            ),
            vertices: vertices,
          ),
        ], geometryVersion: 1)
        .polygons
        .single;
