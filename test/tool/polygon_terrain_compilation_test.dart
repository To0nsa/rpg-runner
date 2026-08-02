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

PolygonTerrainCompiledChunk _compileFixture() {
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
    sourcePath: _chunkSourcePath,
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
