import 'package:runner_core/collision/terrain/terrain_boundary_signature.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:test/test.dart';

void main() {
  test(
    'matching slope endpoints and explicit open boundaries are compatible',
    () {
      final left = _signature(
        chunkKey: 'left',
        side: TerrainBoundarySide.right,
        geometry: _geometry(
          chunkKey: 'left',
          vertices: const <(double, double)>[
            (0, 50),
            (100, 40),
            (100, 100),
            (0, 100),
          ],
        ),
      );
      final right = _signature(
        chunkKey: 'right',
        side: TerrainBoundarySide.left,
        geometry: _geometry(
          chunkKey: 'right',
          vertices: const <(double, double)>[
            (0, 40),
            (100, 60),
            (100, 100),
            (0, 100),
          ],
        ),
      );

      expect(
        compareTerrainBoundaries(left: left, right: right).isCompatible,
        isTrue,
      );
      expect(
        left.coverageIntervals.single.canonicalRecord,
        'solid:40960..102400',
      );
      expect(left.continuationVertices.map((item) => item.yTicks), <int>[
        40960,
        102400,
      ]);

      final openLeft = _signature(
        chunkKey: 'open_left',
        side: TerrainBoundarySide.right,
        geometry: _emptyGeometry(),
      );
      final openRight = _signature(
        chunkKey: 'open_right',
        side: TerrainBoundarySide.left,
        geometry: _emptyGeometry(),
      );
      expect(openLeft.isEmpty, isTrue);
      expect(openLeft.canonicalRecord, contains('empty'));
      expect(
        compareTerrainBoundaries(left: openLeft, right: openRight).isCompatible,
        isTrue,
      );
    },
  );

  test('reports exact physical mismatches while material stays advisory', () {
    final left = _signature(
      chunkKey: 'left',
      side: TerrainBoundarySide.right,
      geometry: _flatGeometry(
        chunkKey: 'left',
        topY: 40,
        surfaceKind: 'earth',
        materialKey: 'grass_a',
      ),
    );
    final high = _signature(
      chunkKey: 'high',
      side: TerrainBoundarySide.left,
      geometry: _flatGeometry(
        chunkKey: 'high',
        topY: 48,
        surfaceKind: 'earth',
        materialKey: 'grass_a',
      ),
    );
    final material = _signature(
      chunkKey: 'material',
      side: TerrainBoundarySide.left,
      geometry: _flatGeometry(
        chunkKey: 'material',
        topY: 40,
        surfaceKind: 'earth',
        materialKey: 'grass_b',
      ),
    );

    final mismatch = compareTerrainBoundaries(left: left, right: high);
    expect(mismatch.isCompatible, isFalse);
    expect(mismatch.mismatchYTicks, <int>[40960, 49152, 102400]);
    final advisory = compareTerrainBoundaries(left: left, right: material);
    expect(advisory.isCompatible, isTrue);
    expect(advisory.materialMismatchVertices, hasLength(2));
  });

  test('canonical evidence is invariant under compiled input order', () {
    final first = const TerrainCompiler().compile(<TerrainPolygonInput>[
      _input('a', const <(double, double)>[
        (0, 20),
        (20, 20),
        (20, 40),
        (0, 40),
      ]),
      _input('b', const <(double, double)>[
        (0, 60),
        (20, 60),
        (20, 80),
        (0, 80),
      ]),
    ], geometryVersion: 1);
    final second = const TerrainCompiler().compile(<TerrainPolygonInput>[
      _input('b', const <(double, double)>[
        (0, 60),
        (20, 60),
        (20, 80),
        (0, 80),
      ]),
      _input('a', const <(double, double)>[
        (0, 20),
        (20, 20),
        (20, 40),
        (0, 40),
      ]),
    ], geometryVersion: 1);

    final a = buildTerrainBoundarySignature(
      chunkKey: 'chunk',
      chunkWidth: 20,
      geometry: first,
      side: TerrainBoundarySide.left,
    );
    final b = buildTerrainBoundarySignature(
      chunkKey: 'chunk',
      chunkWidth: 20,
      geometry: second,
      side: TerrainBoundarySide.left,
    );
    expect(a.canonicalRecord, b.canonicalRecord);
    expect(a.digest, b.digest);
  });
}

TerrainBoundarySignature _signature({
  required String chunkKey,
  required TerrainBoundarySide side,
  required TerrainGeometry geometry,
}) => buildTerrainBoundarySignature(
  chunkKey: chunkKey,
  chunkWidth: 100,
  geometry: geometry,
  side: side,
);

TerrainGeometry _emptyGeometry() =>
    TerrainGeometry(version: 1, polygons: const [], edges: const []);

TerrainGeometry _flatGeometry({
  required String chunkKey,
  required double topY,
  String? surfaceKind,
  String? materialKey,
}) => _geometry(
  chunkKey: chunkKey,
  vertices: <(double, double)>[(0, topY), (100, topY), (100, 100), (0, 100)],
  surfaceKind: surfaceKind,
  materialKey: materialKey,
);

TerrainGeometry _geometry({
  required String chunkKey,
  required List<(double, double)> vertices,
  String? surfaceKind,
  String? materialKey,
}) => const TerrainCompiler().compile(<TerrainPolygonInput>[
  TerrainPolygonInput.fromWorld(
    sourcePath: 'chunks/$chunkKey.json',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: chunkKey,
      shapeId: 'ground',
    ),
    vertices: vertices,
    surfaceKind: surfaceKind,
    materialKey: materialKey,
  ),
], geometryVersion: 1);

TerrainPolygonInput _input(String shapeId, List<(double, double)> vertices) =>
    TerrainPolygonInput.fromWorld(
      sourcePath: 'chunks/chunk.json#$shapeId',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'chunk',
        shapeId: shapeId,
      ),
      vertices: vertices,
    );
