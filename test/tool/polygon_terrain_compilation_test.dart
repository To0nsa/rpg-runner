import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/polygon_terrain_compilation.dart';
import '../../tool/polygon_terrain_source.dart';

const String _fixtureDirectory = 'test/fixtures/polygon_terrain_generator';
const String _chunkSourcePath = 'chunks/forest/fixture_chunk.json';

void main() {
  test('strict current-schema fixture compiles through Core exactly', () {
    final compiled = _compileFixture();
    final golden = _golden();

    expect(
      compiled.geometry.polygons,
      hasLength(golden['polygonCount']! as int),
    );
    expect(compiled.geometry.edges, hasLength(golden['edgeCount']! as int));
    expect(compiled.triangles, hasLength(golden['triangleCount']! as int));
    expect(compiled.geometry.sourceSignature(), golden['sourceSignature']);
    expect(compiled.geometry.edgeSignature(), golden['edgeSignature']);
    expect(
      compiled.authoringPolygonSignature(),
      golden['authoringPolygonSignature'],
    );
    expect(compiled.placementSignature(), golden['placementSignature']);
    expect(compiled.triangleSignature(), golden['triangleSignature']);

    final lineage = compiled.placementLineage.single;
    expect(lineage.placementKey, 'prefab_ramp|60|20|0');
    expect(lineage.prefabKey, 'prefab_ramp');
    expect(lineage.prefabRevision, 3);
    expect(lineage.scaleTenths, 5);
    expect(lineage.flipX, isTrue);
  });

  test('fresh parses reproduce records and signatures', () {
    final first = _compileFixture();
    final second = _compileFixture();

    expect(
      second.geometry.canonicalSourceRecords(),
      first.geometry.canonicalSourceRecords(),
    );
    expect(
      second.geometry.canonicalEdgeRecords(),
      first.geometry.canonicalEdgeRecords(),
    );
    expect(second.placementRecords(), first.placementRecords());
    expect(second.triangleRecords(), first.triangleRecords());
    expect(second.authoringPolygonRecords(), first.authoringPolygonRecords());
  });

  test('compiled product signatures ignore caller collection order', () {
    final compiled = _compileFixture();
    final permuted = PolygonTerrainCompiledChunk(
      chunk: compiled.chunk,
      geometry: compiled.geometry,
      authoringPolygons: compiled.authoringPolygons.reversed,
      placementLineage: compiled.placementLineage.reversed,
      triangles: compiled.triangles.reversed,
    );

    expect(
      permuted.authoringPolygonRecords(),
      compiled.authoringPolygonRecords(),
    );
    expect(permuted.placementRecords(), compiled.placementRecords());
    expect(permuted.triangleRecords(), compiled.triangleRecords());
    expect(
      permuted.authoringPolygonSignature(),
      compiled.authoringPolygonSignature(),
    );
    expect(permuted.placementSignature(), compiled.placementSignature());
    expect(permuted.triangleSignature(), compiled.triangleSignature());
  });

  test('compiled product rejects duplicate derived identities', () {
    final compiled = _compileFixture();
    expect(
      () => PolygonTerrainCompiledChunk(
        chunk: compiled.chunk,
        geometry: compiled.geometry,
        authoringPolygons: compiled.authoringPolygons,
        placementLineage: <PolygonTerrainPlacementLineage>[
          compiled.placementLineage.single,
          compiled.placementLineage.single,
        ],
        triangles: compiled.triangles,
      ),
      throwsArgumentError,
    );
    expect(
      () => PolygonTerrainCompiledChunk(
        chunk: compiled.chunk,
        geometry: compiled.geometry,
        authoringPolygons: compiled.authoringPolygons,
        placementLineage: compiled.placementLineage,
        triangles: <PolygonTerrainTriangle>[
          compiled.triangles.first,
          compiled.triangles.first,
        ],
      ),
      throwsArgumentError,
    );
  });

  test('source identity is host-separator invariant and traversal-safe', () {
    final forward = _compileFixture();
    final windows = _compileFixture(
      sourcePath: r'chunks\forest\fixture_chunk.json',
    );

    expect(
      windows.geometry.canonicalSourceRecords(),
      forward.geometry.canonicalSourceRecords(),
    );
    expect(
      windows.geometry.canonicalEdgeRecords(),
      forward.geometry.canonicalEdgeRecords(),
    );
    expect(
      windows.geometry.sourceSignature(),
      forward.geometry.sourceSignature(),
    );
    expect(windows.geometry.edgeSignature(), forward.geometry.edgeSignature());

    for (final invalid in const <String>[
      '',
      '/chunks/forest/chunk.json',
      'chunks//forest/chunk.json',
      'chunks/../forest/chunk.json',
      r'C:\chunks\forest\chunk.json',
    ]) {
      expect(
        () => compilePolygonTerrainChunk(
          chunk: forward.chunk,
          prefabSources: PolygonTerrainPrefabSourceSet(
            const <PolygonTerrainPrefabSource>[],
          ),
          sourcePath: invalid,
        ),
        throwsArgumentError,
        reason: invalid,
      );
    }
  });

  test('every placement-lineage field participates in its signature', () {
    final compiled = _compileFixture();
    final baselineRecord = compiled.placementLineage.single;
    final baseline = compiled.placementSignature();
    final mutations = <PolygonTerrainPlacementLineage>[
      _lineage(baselineRecord, chunkKey: 'other_chunk'),
      _lineage(baselineRecord, placementKey: 'other|0|0|0'),
      _lineage(baselineRecord, prefabKey: 'prefab_other'),
      _lineage(baselineRecord, prefabId: 'other'),
      _lineage(baselineRecord, prefabRevision: 4),
      _lineage(baselineRecord, shapeId: 'other_shape'),
      _lineage(baselineRecord, placementX: 61),
      _lineage(baselineRecord, placementY: 21),
      _lineage(baselineRecord, scaleTenths: 6),
      _lineage(baselineRecord, flipX: !baselineRecord.flipX),
      _lineage(baselineRecord, flipY: !baselineRecord.flipY),
    ];

    for (final mutation in mutations) {
      expect(_placementSignatureWith(compiled, mutation), isNot(baseline));
    }
  });

  test('every triangle identity/index field participates in its signature', () {
    final compiled = _compileFixture();
    final baselineRecord = compiled.triangles.first;
    final baseline = _triangleSignatureWith(compiled, baselineRecord);
    final mutations = <PolygonTerrainTriangle>[
      _triangle(baselineRecord, chunkKey: 'other_chunk'),
      _triangle(
        baselineRecord,
        placementKey: baselineRecord.placementKey == null ? 'placed' : null,
        replacePlacementKey: true,
      ),
      _triangle(baselineRecord, shapeId: 'other_shape'),
      _triangle(baselineRecord, first: baselineRecord.first + 1),
      _triangle(baselineRecord, second: baselineRecord.second + 1),
      _triangle(baselineRecord, third: baselineRecord.third + 1),
    ];

    for (final mutation in mutations) {
      expect(_triangleSignatureWith(compiled, mutation), isNot(baseline));
    }
  });

  test('strict parsers reject legacy, unknown, and off-grid source', () {
    final prefab = _json('prefab_defs.json');
    final chunk = _json('chunk.json');

    expect(
      () => decodePolygonTerrainPrefabs(
        _mutated(prefab, (root) => root['schemaVersion'] = 2),
      ),
      throwsA(_formatMessage(contains('must be exactly 3'))),
    );
    expect(
      () => decodePolygonTerrainChunk(
        _mutated(chunk, (root) => root['groundProfile'] = <String, Object?>{}),
      ),
      throwsA(_formatMessage(contains('unknown field groundProfile'))),
    );
    expect(
      () => decodePolygonTerrainChunk(
        _mutated(chunk, (root) {
          final placement =
              (root['prefabs']! as List<Object?>).first!
                  as Map<String, Object?>;
          placement['scale'] = 0.35;
        }),
      ),
      throwsA(_formatMessage(contains('0.3-3.0 scale in 0.1 steps'))),
    );
    expect(
      () => decodePolygonTerrainChunk(
        _mutated(chunk, (root) {
          final shape =
              (root['collisionShapes']! as List<Object?>).first!
                  as Map<String, Object?>;
          final vertex =
              (shape['vertices']! as List<Object?>).first!
                  as Map<String, Object?>;
          vertex['x'] = 0.25;
        }),
      ),
      throwsA(_formatMessage(contains('divisible exactly by 0.5'))),
    );
  });

  test('unresolved placement fails without fabricated geometry', () {
    final chunk = decodePolygonTerrainChunk(
      _fixture('chunk.json'),
      sourcePath: _chunkSourcePath,
    );
    final result = compilePolygonTerrainChunk(
      chunk: chunk,
      prefabSources: PolygonTerrainPrefabSourceSet(
        const <PolygonTerrainPrefabSource>[],
      ),
      sourcePath: _chunkSourcePath,
    );

    expect(result.compiled, isNull);
    expect(result.issues, hasLength(1));
    expect(result.issues.single.code, 'unknown_prefab_reference');
    expect(result.issues.single.placementKey, 'prefab_ramp|60|20|0');
  });

  test('Core source-range rejection is a stable generation issue', () {
    final chunkJson = _json('chunk.json');
    final oversized = decodePolygonTerrainChunk(
      _mutated(chunkJson, (root) {
        final shape =
            (root['collisionShapes']! as List<Object?>).first!
                as Map<String, Object?>;
        final vertex =
            (shape['vertices']! as List<Object?>).first!
                as Map<String, Object?>;
        vertex['x'] = 1 << 40;
      }),
      sourcePath: _chunkSourcePath,
    );
    final prefabs = decodePolygonTerrainPrefabs(_fixture('prefab_defs.json'));

    final result = compilePolygonTerrainChunk(
      chunk: oversized,
      prefabSources: prefabs,
      sourcePath: _chunkSourcePath,
    );

    expect(result.compiled, isNull);
    final issue = result.issues.singleWhere(
      (candidate) => candidate.code == 'chunk_collision_source_value_invalid',
    );
    expect(issue.shapeId, 'ground');
    expect(issue.sourcePath, '$_chunkSourcePath#direct=ground');
  });

  test('noncanonical source is rejected instead of normalized silently', () {
    final chunkJson = _json('chunk.json');
    final noncanonical = decodePolygonTerrainChunk(
      _mutated(chunkJson, (root) {
        final shape =
            (root['collisionShapes']! as List<Object?>).first!
                as Map<String, Object?>;
        final vertices = shape['vertices']! as List<Object?>;
        shape['vertices'] = vertices.reversed.toList(growable: false);
      }),
      sourcePath: _chunkSourcePath,
    );
    final prefabs = decodePolygonTerrainPrefabs(_fixture('prefab_defs.json'));

    final result = compilePolygonTerrainChunk(
      chunk: noncanonical,
      prefabSources: prefabs,
      sourcePath: _chunkSourcePath,
    );

    expect(result.compiled, isNull);
    expect(
      result.issues.map((issue) => issue.code),
      contains('noncanonical_winding'),
    );
  });
}

PolygonTerrainCompiledChunk _compileFixture({
  String sourcePath = _chunkSourcePath,
}) {
  final prefabs = decodePolygonTerrainPrefabs(
    _fixture('prefab_defs.json'),
    sourcePath: 'prefab_defs.json',
  );
  final chunk = decodePolygonTerrainChunk(
    _fixture('chunk.json'),
    sourcePath: _chunkSourcePath,
  );
  final result = compilePolygonTerrainChunk(
    chunk: chunk,
    prefabSources: prefabs,
    sourcePath: sourcePath,
  );
  expect(result.issues, isEmpty);
  expect(result.compiled, isNotNull);
  return result.compiled!;
}

Map<String, Object?> _golden() =>
    jsonDecode(_fixture('golden.json')) as Map<String, Object?>;

String _fixture(String name) =>
    File('$_fixtureDirectory/$name').readAsStringSync();

Map<String, Object?> _json(String name) =>
    jsonDecode(_fixture(name)) as Map<String, Object?>;

String _mutated(
  Map<String, Object?> source,
  void Function(Map<String, Object?> root) mutate,
) {
  final copied = jsonDecode(jsonEncode(source)) as Map<String, Object?>;
  mutate(copied);
  return jsonEncode(copied);
}

Matcher _formatMessage(Matcher message) =>
    isA<FormatException>().having((error) => error.message, 'message', message);

PolygonTerrainPlacementLineage _lineage(
  PolygonTerrainPlacementLineage source, {
  String? chunkKey,
  String? placementKey,
  String? prefabKey,
  String? prefabId,
  int? prefabRevision,
  String? shapeId,
  int? placementX,
  int? placementY,
  int? scaleTenths,
  bool? flipX,
  bool? flipY,
}) => PolygonTerrainPlacementLineage(
  chunkKey: chunkKey ?? source.chunkKey,
  placementKey: placementKey ?? source.placementKey,
  prefabKey: prefabKey ?? source.prefabKey,
  prefabId: prefabId ?? source.prefabId,
  prefabRevision: prefabRevision ?? source.prefabRevision,
  shapeId: shapeId ?? source.shapeId,
  placementX: placementX ?? source.placementX,
  placementY: placementY ?? source.placementY,
  scaleTenths: scaleTenths ?? source.scaleTenths,
  flipX: flipX ?? source.flipX,
  flipY: flipY ?? source.flipY,
);

PolygonTerrainTriangle _triangle(
  PolygonTerrainTriangle source, {
  String? chunkKey,
  String? placementKey,
  bool replacePlacementKey = false,
  String? shapeId,
  int? first,
  int? second,
  int? third,
}) => PolygonTerrainTriangle(
  chunkKey: chunkKey ?? source.chunkKey,
  placementKey: replacePlacementKey ? placementKey : source.placementKey,
  shapeId: shapeId ?? source.shapeId,
  first: first ?? source.first,
  second: second ?? source.second,
  third: third ?? source.third,
);

String _placementSignatureWith(
  PolygonTerrainCompiledChunk source,
  PolygonTerrainPlacementLineage lineage,
) => PolygonTerrainCompiledChunk(
  chunk: source.chunk,
  geometry: source.geometry,
  authoringPolygons: source.authoringPolygons,
  placementLineage: <PolygonTerrainPlacementLineage>[lineage],
  triangles: source.triangles,
).placementSignature();

String _triangleSignatureWith(
  PolygonTerrainCompiledChunk source,
  PolygonTerrainTriangle triangle,
) => PolygonTerrainCompiledChunk(
  chunk: source.chunk,
  geometry: source.geometry,
  authoringPolygons: source.authoringPolygons,
  placementLineage: source.placementLineage,
  triangles: <PolygonTerrainTriangle>[triangle],
).triangleSignature();
