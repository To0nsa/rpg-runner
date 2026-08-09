import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../fixtures/polygon_terrain_generator/staged_authored_terrain.g.dart'
    as golden;
import '../../tool/generated_artifact_plan.dart';
import '../../tool/polygon_terrain_compilation.dart';
import '../../tool/polygon_terrain_render.dart';
import '../../tool/polygon_terrain_source.dart';

const String _fixtureDirectory = 'test/fixtures/polygon_terrain_generator';
const String _goldenPath = '$_fixtureDirectory/staged_authored_terrain.g.dart';
const String _chunkSourcePath = 'chunks/forest/fixture_chunk.json';

void main() {
  test(
    'staged Dart render is exact, local, and drift-plan compatible',
    () async {
      final first = buildStagedPolygonTerrainArtifact(
        chunks: <PolygonTerrainCompiledChunk>[_compileFixture()],
        outputPath: _goldenPath,
      );
      final second = buildStagedPolygonTerrainArtifact(
        chunks: <PolygonTerrainCompiledChunk>[_compileFixture()],
        outputPath: _goldenPath,
      );

      if (Platform.environment['UPDATE_POLYGON_TERRAIN_GOLDEN'] == '1') {
        await GeneratedArtifactPlan(<GeneratedArtifact>[first]).writeAll();
      }

      expect(second.content, first.content);
      expect(first.content, File(_goldenPath).readAsStringSync());
      expect(
        await GeneratedArtifactPlan(<GeneratedArtifact>[first]).inspectDrift(),
        isEmpty,
      );
      expect(first.content, isNot(contains('chunkIndex')));
      expect(first.content, contains('formatVersion: 2'));
      expect(first.content, contains('compilerGeometryVersion: 1'));
      expect(
        first.content,
        contains('authoringPolygonSignatureFormat: "authoring-polygons-v1"'),
      );
      expect(first.content, contains('sourceSignatureFormat: "source-v1"'));
      expect(first.content, contains('edgeSignatureFormat: "edges-v1"'));
      expect(
        first.content,
        contains('placementSignatureFormat: "authoring-placement-v1"'),
      );
      expect(
        first.content,
        contains('triangleSignatureFormat: "authoring-triangles-v1"'),
      );
      expect(golden.stagedAuthoredTerrain.chunks, hasLength(1));
      expect(golden.stagedAuthoredTerrain.chunks.single.polygons, hasLength(3));
      expect(golden.stagedAuthoredTerrain.chunks.single.edges, hasLength(13));
      expect(
        golden.stagedAuthoredTerrain.chunks.single.triangles,
        hasLength(10),
      );
    },
  );

  test('staged Dart render sorts chunk input explicitly', () {
    final earlier = _compileFixture(chunkKey: 'a_fixture');
    final later = _compileFixture(chunkKey: 'z_fixture');

    expect(
      renderStagedPolygonTerrainDart(<PolygonTerrainCompiledChunk>[
        later,
        earlier,
      ]),
      renderStagedPolygonTerrainDart(<PolygonTerrainCompiledChunk>[
        earlier,
        later,
      ]),
    );
  });

  test('staged renderer rejects empty and duplicate chunk sets', () {
    final compiled = _compileFixture();

    expect(
      () =>
          renderStagedPolygonTerrainDart(const <PolygonTerrainCompiledChunk>[]),
      throwsArgumentError,
    );
    expect(
      () => renderStagedPolygonTerrainDart(<PolygonTerrainCompiledChunk>[
        compiled,
        compiled,
      ]),
      throwsArgumentError,
    );
  });

  test('staged records remain unreachable from production construction', () {
    const productionRoots = <String>[
      'packages/runner_core/lib',
      'lib',
      'services/replay_validator/lib',
    ];
    final imports = <String>[];
    for (final rootPath in productionRoots) {
      for (final entity in Directory(rootPath).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path
            .replaceAll('\\', '/')
            .endsWith('/track/staged_terrain_data.dart')) {
          continue;
        }
        final source = entity.readAsStringSync();
        if (source.contains('staged_terrain_data.dart') ||
            source.contains('staged_authored_terrain.dart')) {
          imports.add(entity.path.replaceAll('\\', '/'));
        }
      }
    }

    expect(imports, isEmpty);
    final liveGenerator = File(
      'tool/generate_chunk_runtime_data.dart',
    ).readAsStringSync();
    expect(liveGenerator, isNot(contains('polygon_terrain_render.dart')));
    expect(liveGenerator, isNot(contains('staged_authored_terrain.dart')));
  });
}

PolygonTerrainCompiledChunk _compileFixture({String? chunkKey}) {
  final prefabs = decodePolygonTerrainPrefabs(
    File('$_fixtureDirectory/prefab_defs.json').readAsStringSync(),
    sourcePath: 'prefab_defs.json',
  );
  final rawChunk = File('$_fixtureDirectory/chunk.json').readAsStringSync();
  final resolvedChunkKey = chunkKey ?? 'fixture_chunk';
  final chunkJson = jsonDecode(rawChunk) as Map<String, Object?>;
  chunkJson['chunkKey'] = resolvedChunkKey;
  chunkJson['id'] = resolvedChunkKey;
  final sourcePath = chunkKey == null
      ? _chunkSourcePath
      : 'chunks/forest/$resolvedChunkKey.json';
  final chunk = decodePolygonTerrainChunk(
    jsonEncode(chunkJson),
    sourcePath: sourcePath,
  );
  final result = compilePolygonTerrainChunk(
    chunk: chunk,
    prefabSources: prefabs,
    sourcePath: sourcePath,
  );
  expect(result.issues, isEmpty);
  return result.compiled!;
}
