import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:test/test.dart';

void main() {
  test('identity boundaries reject empty keys and negative edge indices', () {
    expect(
      () =>
          TerrainSourceIdentity(chunkIndex: 0, chunkKey: '', shapeId: 'shape'),
      throwsArgumentError,
    );
    expect(
      () => TerrainEdgeId(
        chunkIndex: 0,
        chunkKey: 'chunk',
        shapeId: 'shape',
        localEdgeIndex: -1,
      ),
      throwsArgumentError,
    );
  });

  test('edge identity has one total order across source lineage', () {
    final values = <TerrainEdgeId>[
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

  test(
    'canonical edge keys are injective when source keys contain separators',
    () {
      final direct = TerrainEdgeId(
        chunkIndex: 0,
        chunkKey: 'a/b',
        shapeId: 'c',
        localEdgeIndex: 0,
      );
      final placed = TerrainEdgeId(
        chunkIndex: 0,
        chunkKey: 'a',
        placementKey: 'b',
        shapeId: '-/c',
        localEdgeIndex: 0,
      );

      expect(direct, isNot(placed));
      expect(direct.canonicalKey, isNot(placed.canonicalKey));
    },
  );

  test('compiled polygon, edge, and diagnostic collections are immutable', () {
    const compiler = TerrainCompiler();
    final geometry = compiler.compile(<TerrainPolygonInput>[
      TerrainPolygonInput.fromWorld(
        sourcePath: 'shape',
        identity: TerrainSourceIdentity(
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

  test('geometry boundary canonicalizes order and rejects invalid bundles', () {
    const compiler = TerrainCompiler();
    final compiled = compiler.compile(<TerrainPolygonInput>[
      TerrainPolygonInput.fromWorld(
        sourcePath: 'b',
        identity: TerrainSourceIdentity(
          chunkIndex: 1,
          chunkKey: 'chunk_b',
          shapeId: 'b',
        ),
        vertices: const [(20, 0), (30, 0), (30, 10), (20, 10)],
      ),
      TerrainPolygonInput.fromWorld(
        sourcePath: 'a',
        identity: TerrainSourceIdentity(
          chunkIndex: 0,
          chunkKey: 'chunk_a',
          shapeId: 'a',
        ),
        vertices: const [(0, 0), (10, 0), (10, 10), (0, 10)],
      ),
    ], geometryVersion: 1);
    final rebuilt = TerrainGeometry(
      version: 2,
      polygons: compiled.polygons.reversed,
      edges: compiled.edges.reversed,
    );

    expect(rebuilt.polygons, compiled.polygons);
    expect(rebuilt.edges, compiled.edges);
    expect(
      () => TerrainGeometry(version: -1, polygons: const [], edges: const []),
      throwsArgumentError,
    );
    expect(
      () => TerrainGeometry(
        version: 2,
        polygons: compiled.polygons,
        edges: [...compiled.edges, compiled.edges.first],
      ),
      throwsArgumentError,
    );
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
          identity: TerrainSourceIdentity(
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

  test(
    'shape and compiled-edge hard limits accept boundary and reject one over',
    () {
      const compiler = TerrainCompiler();

      final chunkBoundary = <TerrainPolygonInput>[
        for (
          var index = 0;
          index < TerrainGeometryLimits.maxShapesPerChunk;
          index++
        )
          _triangle(index),
      ];
      expect(
        compiler.compile(chunkBoundary, geometryVersion: 1).polygons,
        hasLength(TerrainGeometryLimits.maxShapesPerChunk),
      );
      _expectValidationCode(
        () => compiler.compile(<TerrainPolygonInput>[
          ...chunkBoundary,
          _triangle(512),
        ], geometryVersion: 1),
        'chunk_shape_limit',
      );

      final prefabBoundary = <TerrainPolygonInput>[
        for (
          var index = 0;
          index < TerrainGeometryLimits.maxShapesPerPrefab;
          index++
        )
          _triangle(index, placementKey: 'prefab'),
      ];
      expect(
        compiler.compile(prefabBoundary, geometryVersion: 1).polygons,
        hasLength(TerrainGeometryLimits.maxShapesPerPrefab),
      );
      _expectValidationCode(
        () => compiler.compile(<TerrainPolygonInput>[
          ...prefabBoundary,
          _triangle(64, placementKey: 'prefab'),
        ], geometryVersion: 1),
        'prefab_shape_limit',
      );

      final edgeBoundary = <TerrainPolygonInput>[
        for (var index = 0; index < 64; index++) _strip64(index),
      ];
      expect(
        compiler.compile(edgeBoundary, geometryVersion: 1).edges,
        hasLength(TerrainGeometryLimits.maxExposedEdgesPerChunk),
      );
      _expectValidationCode(
        () => compiler.compile(<TerrainPolygonInput>[
          ...edgeBoundary,
          _strip64(64),
        ], geometryVersion: 1),
        'edge_limit',
      );
    },
  );
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

TerrainPolygonInput _triangle(int index, {String? placementKey}) {
  final x = index * 4.0;
  return TerrainPolygonInput.fromWorld(
    sourcePath: 'limits/triangle_$index',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'limits',
      placementKey: placementKey,
      shapeId: 'triangle_$index',
    ),
    vertices: <(double, double)>[(x, 0), (x + 2, 0), (x, 2)],
  );
}

TerrainPolygonInput _strip64(int index) {
  final originX = index * 40.0;
  return TerrainPolygonInput.fromWorld(
    sourcePath: 'limits/strip_$index',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'limits',
      shapeId: 'strip_$index',
    ),
    vertices: <(double, double)>[
      for (var x = 0; x < 32; x++) (originX + x, x.isEven ? 0 : 1),
      for (var x = 31; x >= 0; x--) (originX + x, x.isEven ? 10 : 11),
    ],
  );
}

void _expectValidationCode(void Function() operation, String code) {
  try {
    operation();
    fail('Expected terrain validation code $code.');
  } on TerrainValidationException catch (error) {
    expect(
      error.diagnostics.map((diagnostic) => diagnostic.code),
      contains(code),
    );
  }
}
