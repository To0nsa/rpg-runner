import 'dart:convert';
import 'dart:io';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/combat/ai_target_policy.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:test/test.dart';

Map<String, dynamic> _source() {
  var root = Directory.current;
  while (!File('${root.path}/docs/examples/rescue_encounter_chunk.json')
      .existsSync()) {
    if (root.parent.path == root.path) {
      throw StateError('Repository root missing.');
    }
    root = root.parent;
  }
  return jsonDecode(
    File('${root.path}/docs/examples/rescue_encounter_chunk.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
}

Map<String, dynamic> _encounter(Map<String, dynamic> source) =>
    (source['encounters'] as List).single as Map<String, dynamic>;
PolygonTerrainRuntimeChunkResult _compile(
  Map<String, dynamic> source, {
  double? groundTopY = 224,
}) => compilePolygonTerrainRuntimeChunkSource(
  prefabSourcePath: 'prefabs.json',
  prefabContents: '{"schemaVersion":3,"slices":[],"prefabs":[]}',
  tileSourcePath: 'tiles.json',
  tileContents: '{"schemaVersion":2,"tileSlices":[],"platformModules":[]}',
  chunkSourcePath: 'example.json',
  chunkContents: jsonEncode(source),
  groundTopY: groundTopY,
);

void main() {
  test(
    'absent and empty collections preserve encounter-free terrain products',
    () {
      final source = _source()..remove('encounters');
      final absent = _compile(source).chunk!;
      source['encounters'] = [];
      final empty = _compile(source).chunk!;
      expect(absent.pattern.encounters, isEmpty);
      expect(empty.pattern.encounters, isEmpty);
      expect(
        empty.stagedTerrain.sourceSignature,
        absent.stagedTerrain.sourceSignature,
      );
      expect(
        _compile(_source()).chunk!.stagedTerrain.sourceSignature,
        absent.stagedTerrain.sourceSignature,
      );
    },
  );
  test('source materializes immutable identities, policies and exact override presence', () {
    for (final points in [null, 0, 250, 700]) {
      final source = _source();
      final e = _encounter(source);
      if (points != null) e['pointsPerNpc'] = points;
      (e['enemies'] as List).single['targetPolicy'] = 'playerOnly';
      final result = _compile(source);
      expect(
        result.issues,
        isEmpty,
        reason: result.issues.map((i) => '${i.code}: ${i.message}').join('\n'),
      );
      final runtime = result.chunk!.pattern.encounters.single;
      expect(runtime.id, 'roadside_rescue');
      expect(runtime.npcs.single.npcId, NpcId.warrior);
      expect(runtime.enemies.single.targetPolicy, AiTargetPolicy.playerOnly);
      expect(runtime.pointsPerNpc, points);
      expect(encounterDefinitionsToJson([runtime]).single, e);
      expect(() => runtime.npcs.clear(), throwsUnsupportedError);
      expect(
        () => result.chunk!.pattern.encounters.clear(),
        throwsUnsupportedError,
      );
    }
  });
  final invalid =
      <String, void Function(Map<String, dynamic>, Map<String, dynamic>)>{
        'explicit null': (s, e) => s['encounters'] = null,
        'unknown key': (s, e) => e['markerId'] = 'ambient',
        'null points': (s, e) => e['pointsPerNpc'] = null,
        'fractional points': (s, e) => e['pointsPerNpc'] = 2.5,
        'negative points': (s, e) => e['pointsPerNpc'] = -1,
        'overflow points': (s, e) => e['pointsPerNpc'] = 100001,
        'unknown policy': (s, e) => e['targetPolicy'] = 'default',
        'duplicate member': (s, e) =>
            e['enemies'][0]['id'] = e['npcs'][0]['id'],
        'unknown npc': (s, e) => e['npcs'][0]['npcId'] = 'enemy',
        'fractional x': (s, e) => e['npcs'][0]['x'] = 128.5,
        'out of bounds member': (s, e) => e['npcs'][0]['x'] = 640,
        'out of bounds trigger': (s, e) => e['trigger']['height'] = 301,
        'unknown facing': (s, e) => e['enemies'][0]['facing'] = 'up',
        'unknown placement': (s, e) => e['enemies'][0]['placement'] = 'random',
        'unknown member key': (s, e) =>
            e['npcs'][0]['targetPolicy'] = 'playerOnly',
        'noncanonical IDs': (s, e) => s['encounters'] = [
          {...e, 'id': 'z'},
          {...e, 'id': 'a'},
        ],
        'too many groups': (s, e) => s['encounters'] = [
          for (var i = 0; i < 5; i++) {...e, 'id': 'group_$i'},
        ],
      };
  for (final entry in invalid.entries) {
    test('strict decoder rejects ${entry.key}', () {
      final source = _source();
      entry.value(source, _encounter(source));
      expect(
        () => decodePolygonTerrainChunk(jsonEncode(source)),
        throwsFormatException,
      );
      expect(_compile(source).chunk, isNull);
    });
  }
  test('incomplete roles save structurally but cannot materialize', () {
    final source = _source();
    _encounter(source)['enemies'] = [];
    expect(
      decodePolygonTerrainChunk(jsonEncode(source)).encounters.single.enemies,
      isEmpty,
    );
    final result = _compile(source);
    expect(result.chunk, isNull);
    expect(result.issues.single.code, 'encounter_incomplete');
    expect(result.issues.single.elementId, 'roadside_rescue');
  });
  test('required support and full-body bounds fail the complete group', () {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (e) => e['npcs'][0]['x'] = 1,
      (e) => e['enemies'][0]['enemyId'] = 'derf',
      (e) => e['enemies'][0]['placement'] = 'obstacleTop',
    ]) {
      final source = _source();
      mutate(_encounter(source));
      final result = _compile(source);
      expect(result.chunk, isNull);
      expect(result.issues.single.code, 'encounter_placement_rejected');
      expect(result.issues.single.fieldKey, startsWith('members.'));
    }
    expect(
      _compile(_source(), groundTopY: null).issues.single.code,
      'encounter_level_ground_context_missing',
    );
  });
  test(
    'canonical export sorts copies without changing immutable authored order',
    () {
      final e = decodePolygonTerrainChunk(jsonEncode(_source()))
          .encounters
          .single;
      final a = EncounterDefinition(
        id: 'a',
        name: e.name,
        trigger: e.trigger,
        npcs: e.npcs,
        enemies: e.enemies,
      );
      final z = EncounterDefinition(
        id: 'z',
        name: e.name,
        trigger: e.trigger,
        npcs: e.npcs,
        enemies: e.enemies,
      );
      final input = [z, a];
      expect(encounterDefinitionsToJson(input).map((e) => e['id']), ['z', 'a']);
      expect(
        encounterDefinitionsToJson(input, canonical: true).map((e) => e['id']),
        ['a', 'z'],
      );
      expect(input, [z, a]);
    },
  );
}
