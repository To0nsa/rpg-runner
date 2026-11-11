import 'dart:convert';
import 'dart:io';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:test/test.dart';

void main() {
  final root = Directory.current.parent.parent.path;
  final text = File('$root/$campaignSourcePath').readAsStringSync();
  final prefabs = File('$root/assets/authoring/level/prefab_defs.json')
      .readAsStringSync();
  final tiles = File('$root/assets/authoring/level/tile_defs.json')
      .readAsStringSync();
  final flat =
      (jsonDecode(
                File('$root/$trainingFieldSourcePath').readAsStringSync(),
              )['chunks']
              as List)
          .first;
  final chunks = {
    'training_field_1': jsonEncode({
      ...flat as Map<String, dynamic>,
      'usage': 'campaign',
    }),
  };
  Map<String, Object?> mission() =>
      CampaignCatalogSource.decode(text).missions.first.toJson()
        ..['route'] = [
          for (final id in ['first', 'second'])
            {
              'id': id,
              'levelId': 'training_field',
              'chunkKey': 'training_field_1',
            },
        ]
        ..['start'] = {'occurrenceId': 'first', 'x': 60, 'y': 224}
        ..['exit'] = {
          'origin': {'occurrenceId': 'second', 'x': 500, 'y': 0},
          'width': 100,
          'height': 270,
        };
  CompiledCampaignMission compile(
    Map<String, Object?> data, {
    Map<String, String>? sources,
  }) => compileCampaignMission(
    source: CampaignMissionSource.decode(data),
    chunkContentsByKey: sources ?? chunks,
    prefabContents: prefabs,
    tileContents: tiles,
  );

  test('four editable drafts, arrival rules and 224 XP round-trip', () {
    final catalog = CampaignCatalogSource.decode(text);
    expect(jsonDecode(catalog.encode()), jsonDecode(text));
    expect(catalog.missions, hasLength(4));
    expect(catalog.missions.every((m) => !m.includeInBuild), isTrue);
    expect(catalog.missions.fold<int>(0, (n, m) => n + m.firstClearXp), 224);
    expect(catalog.missions.first.combatAllowed, isFalse);
    expect(catalog.missions.first.rewardAbilityId, 'eloise.double_jump');
    expect(catalog.chapters.single.rewardCharacterId, 'bountyHunter');
    expect(
      () => compileCampaignMission(
        source: catalog.missions.first,
        chunkContentsByKey: chunks,
        prefabContents: prefabs,
        tileContents: tiles,
      ),
      throwsFormatException,
    );
  });
  test(
    'campaign-only repeated sources compile, cross the real seam and finish',
    () {
      final compiled = compile(mission());
      expect(compiled.chunks, hasLength(1));
      final core = GameCore.campaignPlaytest(
        mission: compiled.definition,
        playerCharacter: PlayerCharacterRegistry.eloise,
      );
      for (var i = 0; i < 1200 && !core.gameOver; i++) {
        core.applyCommands([MoveAxisCommand(tick: core.tick + 1, axis: 1)]);
        core.stepOneTick();
      }
      expect(core.playerPosX, greaterThanOrEqualTo(1100));
      expect(
        core.drainEvents().whereType<RunEndedEvent>().single.reason,
        RunEndReason.missionCompleted,
      );
    },
  );
  test('missing source, wrong owner, duplicate occurrence and unsupported start reject', () {
    for (final mutate in <void Function(Map<String, Object?>)>[
      (m) => (m['route'] as List)[1]['chunkKey'] = 'missing',
      (m) => (m['route'] as List)[1]['levelId'] = 'forest',
      (m) => (m['route'] as List)[1]['id'] = 'first',
      (m) => m['start'] = {'occurrenceId': 'first', 'x': 60, 'y': 180},
      (m) => m['start'] = {'occurrenceId': 'gone', 'x': 60, 'y': 224},
      (m) => m['requiredEnemies'] = [
        {'occurrenceId': 'first', 'markerSalt': 42},
      ],
      (m) => m['includeInBuild'] = null,
      (m) => m['randomize'] = true,
    ]) {
      final data = mission();
      mutate(data);
      expect(() => compile(data), throwsFormatException);
    }
  });
  test('usage is explicit and strict; source combat is never removed', () {
    final raw = jsonDecode(chunks.values.single) as Map<String, dynamic>;
    expect(decodePolygonTerrainChunk(jsonEncode(raw)).usage, 'campaign');
    expect(
      decodePolygonTerrainChunk(jsonEncode({...raw}..remove('usage'))).usage,
      'runner',
    );
    expect(
      () => decodePolygonTerrainChunk(jsonEncode({...raw, 'usage': null})),
      throwsFormatException,
    );
    raw['markers'] = [
      {
        'markerId': 'grojib',
        'x': 300,
        'y': 224,
        'chancePercent': 100,
        'salt': 42,
        'placement': 'ground',
      },
    ];
    final withEnemy = {'training_field_1': jsonEncode(raw)};
    expect(() => compile(mission(), sources: withEnemy), throwsFormatException);
    final combatMission = mission()..['combatAllowed'] = true;
    expect(
      compile(
        combatMission,
        sources: withEnemy,
      ).definition.route.occurrences.first.pattern.spawnMarkers.single.salt,
      42,
    );
  });
}
