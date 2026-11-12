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
    final drafts = jsonDecode(text) as Map<String, dynamic>;
    for (final chapter in drafts['chapters'] as List) {
      for (final mission in chapter['missions'] as List) {
        mission['includeInBuild'] = false;
        mission['route'] = [];
        mission['start'] = null;
        mission['exit'] = null;
      }
    }
    final catalog = CampaignCatalogSource.decode(jsonEncode(drafts));
    expect(jsonDecode(catalog.encode()), drafts);
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
  test('chapter rewards validate catalog identities, recipients, bounds and round-trip', () {
    final raw = jsonDecode(text) as Map<String, dynamic>;
    final chapter = (raw['chapters'] as List).first as Map<String, dynamic>;
    const gear = {'kind': 'gear', 'slot': 'mainWeapon', 'itemId': 'plainsteel'};
    const skill = {
      'kind': 'ability',
      'slot': 'jump',
      'itemId': 'eloise.double_jump',
      'characterId': 'eloise',
    };
    chapter.addAll({
      'rewardXp': 120,
      'rewardGold': 300,
      'rewardItems': [gear, skill],
    });
    final parsed = CampaignCatalogSource.decode(jsonEncode(raw));
    expect(parsed.chapters.first.rewardItems.map((r) => r.toJson()), [
      gear,
      skill,
    ]);
    expect(jsonDecode(parsed.encode()), raw);
    for (final invalid in <Map<String, Object?>>[
      {'rewardXp': -1},
      {'rewardXp': 100001},
      {'rewardXp': 1.5},
      {'rewardGold': 1000001},
      {'rewardGold': null},
      {'rewardItems': null},
      {
        'rewardItems': [gear, gear],
      },
      {'rewardItems': List.filled(9, gear)},
      {
        'rewardItems': [
          {...gear, 'itemId': 'invented'},
        ],
      },
      {
        'rewardItems': [
          {...gear, 'characterId': 'eloise'},
        ],
      },
      {
        'rewardItems': [
          {...skill}..remove('characterId'),
        ],
      },
      {
        'rewardItems': [
          {...skill, 'characterId': 'bountyHunter'},
        ],
      },
      {
        'rewardItems': [
          {...skill, 'quantity': 2},
        ],
      },
    ]) {
      final copy = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
      (copy['chapters'] as List).first.addAll(invalid);
      expect(
        () => CampaignCatalogSource.decode(jsonEncode(copy)),
        throwsFormatException,
        reason: '$invalid',
      );
    }
    chapter.remove('rewardXp');
    chapter.remove('rewardGold');
    chapter.remove('rewardItems');
    final legacy = CampaignCatalogSource.decode(jsonEncode(raw)).chapters.first;
    expect(legacy.rewardXp, 0);
    expect(legacy.rewardGold, 0);
    expect(legacy.rewardItems, isEmpty);
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
