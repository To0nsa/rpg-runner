import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:test/test.dart';

void main() {
  test('edge identity has one total order across source lineage', () {
    const values = <TerrainEdgeId>[
      TerrainEdgeId(
        chunkIndex: 1,
        chunkKey: 'chunk',
        shapeId: 'shape',
        localEdgeIndex: 0,
      ),
      TerrainEdgeId(
        chunkIndex: -1,
        chunkKey: 'base',
        shapeId: 'shape',
        localEdgeIndex: 0,
      ),
      TerrainEdgeId(
        chunkIndex: 0,
        chunkKey: 'chunk',
        placementKey: 'placed',
        shapeId: 'shape',
        localEdgeIndex: 0,
      ),
      TerrainEdgeId(
        chunkIndex: 0,
        chunkKey: 'chunk',
        shapeId: 'shape',
        localEdgeIndex: 0,
      ),
      TerrainEdgeId(
        chunkIndex: 0,
        chunkKey: 'chunk',
        shapeId: 'shape',
        localEdgeIndex: 0,
        subEdgeIndex: 1,
      ),
    ];

    final sorted = values.toList()..sort();
    expect(sorted.map((value) => value.chunkIndex), <int>[-1, 0, 0, 0, 1]);
    expect(sorted[1].placementKey, isNull);
    expect(sorted[1].subEdgeIndex, 0);
    expect(sorted[2].subEdgeIndex, 1);
    expect(sorted[3].placementKey, 'placed');
    expect(sorted.toSet(), hasLength(values.length));
  });

  test('compiled polygon, edge, and diagnostic collections are immutable', () {
    const compiler = TerrainCompiler();
    final geometry = compiler.compile(<TerrainPolygonInput>[
      TerrainPolygonInput.fromWorld(
        sourcePath: 'shape',
        identity: const TerrainSourceIdentity(
          chunkIndex: 0,
          chunkKey: 'chunk',
          shapeId: 'shape',
        ),
        vertices: const [(0, 0), (10, 0), (10, 10), (0, 10)],
      ),
    ], geometryVersion: 1);

    expect(
      () => geometry.polygons.add(geometry.polygons.single),
      throwsUnsupportedError,
    );
    expect(
      () => geometry.edges.add(geometry.edges.first),
      throwsUnsupportedError,
    );
    expect(
      () => geometry.polygons.single.vertices.clear(),
      throwsUnsupportedError,
    );
    expect(() => geometry.edgeById.clear(), throwsUnsupportedError);
  });

  test('diagnostic order is independent of input construction order', () {
    const compiler = TerrainCompiler();
    final a = _invalid('a');
    final b = _invalid('b');

    List<String> codes(Iterable<TerrainPolygonInput> inputs) {
      try {
        compiler.compile(inputs, geometryVersion: 1);
      } on TerrainValidationException catch (error) {
        return error.diagnostics.map((value) => value.toString()).toList();
      }
      fail('Expected invalid geometry.');
    }

    expect(
      codes(<TerrainPolygonInput>[a, b]),
      codes(<TerrainPolygonInput>[b, a]),
    );
  });

  test('one-over vertex hard limit fails with a stable code', () {
    const compiler = TerrainCompiler();
    final vertices = <(double, double)>[
      for (var i = 0; i < 63; i += 1) (i.toDouble(), 0),
      (62, 10),
      (0, 10),
    ];
    try {
      compiler.compile(<TerrainPolygonInput>[
        TerrainPolygonInput.fromWorld(
          sourcePath: 'too_many',
          identity: const TerrainSourceIdentity(
            chunkIndex: 0,
            chunkKey: 'chunk',
            shapeId: 'too_many',
          ),
          vertices: vertices,
        ),
      ], geometryVersion: 1);
      fail('Expected vertex limit failure.');
    } on TerrainValidationException catch (error) {
      expect(
        error.diagnostics.map((diagnostic) => diagnostic.code),
        contains('vertex_limit'),
      );
    }
  });
}

TerrainPolygonInput _invalid(String shapeId) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$shapeId',
  identity: TerrainSourceIdentity(
    chunkIndex: 0,
    chunkKey: 'chunk',
    shapeId: shapeId,
  ),
  vertices: const [(0, 0), (10, 0), (0, 0)],
);
