import 'dart:convert';
import 'dart:io';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:test/test.dart';

Map<String, Object> _source() => {
  'id': 'forest_bringer',
  'enemyId': 'bringerOfDeath',
  'spawnX': 440,
  'minX': 24,
  'maxX': 576,
};
void main() {
  test(
    'compiled arena preserves metadata and rejects unsupported body placement',
    () {
      var root = Directory.current;
      while (!File('${root.path}/docs/examples/rescue_encounter_chunk.json')
          .existsSync()) {
        if (root.parent.path == root.path) {
          throw StateError('Repository root missing.');
        }
        root = root.parent;
      }
      Map<String, dynamic> source() =>
          (jsonDecode(
              File('${root.path}/docs/examples/rescue_encounter_chunk.json')
                  .readAsStringSync(),
            ) as Map<String, dynamic>)
            ..remove('encounters')
            ..['bossArena'] = _source();
      PolygonTerrainRuntimeChunkResult compile(
        Map<String, dynamic> chunk, {
        double? ground = 224,
      }) => compilePolygonTerrainRuntimeChunkSource(
        prefabSourcePath: 'prefabs.json',
        prefabContents: '{"schemaVersion":3,"slices":[],"prefabs":[]}',
        tileSourcePath: 'tiles.json',
        tileContents:
            '{"schemaVersion":2,"tileSlices":[],"platformModules":[]}',
        chunkSourcePath: 'arena.json',
        chunkContents: jsonEncode(chunk),
        groundTopY: ground,
      );
      final valid = compile(source());
      expect(valid.issues, isEmpty);
      expect(bossArenaToJson(valid.chunk!.pattern.bossArena!), _source());
      for (final id in bossEnemyIds) {
        final newBoss = source()
          ..['bossArena'] = {..._source(), 'enemyId': id.name};
        final result = compile(newBoss);
        expect(result.issues, isEmpty, reason: id.name);
        expect(result.chunk!.pattern.bossArena!.enemyId, id);
      }
      final nearWall = source()..['bossArena'] = {..._source(), 'spawnX': 25};
      final unsupported = source()..['collisionShapes'] = [];
      for (final result in [
        compile(nearWall),
        compile(unsupported),
        compile(source(), ground: null),
      ]) {
        expect(result.chunk, isNull);
        expect(result.issues.single.code, 'boss_arena_placement_rejected');
      }
      final conflict = source()
        ..['encounters'] = (jsonDecode(
          File('${root.path}/docs/examples/rescue_encounter_chunk.json')
              .readAsStringSync(),
        ) as Map)['encounters'];
      expect(
        () => decodePolygonTerrainChunk(jsonEncode(conflict)),
        throwsFormatException,
      );
    },
  );
  test('strict arena source round trips its stable identity and bounds', () {
    final arena = decodeBossArena(
      _source(),
      sourcePath: 'chunk.bossArena',
      chunkWidth: 600,
      chunkHeight: 270,
    )!;
    expect(arena.enemyId, EnemyId.bringerOfDeath);
    expect(bossArenaToJson(arena), _source());
  });
  for (final id in EnemyId.values.where((id) => id.isBossSummon)) {
    test('reject summoned ${id.name} as the required boss', () {
      expect(
        () => decodeBossArena(
          {..._source(), 'enemyId': id.name},
          sourcePath: 'chunk.bossArena',
          chunkWidth: 600,
          chunkHeight: 270,
        ),
        throwsFormatException,
      );
    });
  }
  for (final value in [
    null,
    {},
    {..._source(), 'enemyId': 'grojib'},
    {..._source(), 'spawnX': 12},
    {..._source(), 'minX': 576},
    {..._source(), 'spawnX': 440.5},
    {..._source(), 'extra': true},
  ]) {
    test(
      'reject malformed arena $value',
      () => expect(
        () => decodeBossArena(
          value,
          sourcePath: 'chunk.bossArena',
          chunkWidth: 600,
          chunkHeight: 270,
        ),
        throwsFormatException,
      ),
    );
  }
  test(
    'arena must match the full viewport',
    () => expect(
      () => decodeBossArena(
        _source(),
        sourcePath: 'chunk.bossArena',
        chunkWidth: 1200,
        chunkHeight: 270,
      ),
      throwsFormatException,
    ),
  );
}
