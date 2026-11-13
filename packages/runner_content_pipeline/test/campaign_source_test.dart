import 'dart:convert';
import 'dart:io';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_core/interactions/world_interaction_catalog.dart';
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
        // This fixture replaces the entire route; production marker coordinates
        // belong to that authored route, not these synthetic chunk instances.
        ..remove('placements')
        ..remove('tutorialSequences')
        ..remove('requiresFirstCoin')
        ..remove('blessingObjectiveShrineId')
        ..['route'] = [
          for (final id in ['first', 'second'])
            {
              'id': id,
              'levelId': 'training_field',
              'chunkKey': 'training_field_1',
            },
        ]
        ..['start'] = {'missionChunkId': 'first', 'x': 60, 'y': 224}
        ..['exit'] = {
          'origin': {'missionChunkId': 'second', 'x': 500, 'y': 0},
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

  test('coin objective is optional, strict and requires an authored coin', () {
    expect(compile(mission()).definition.requiresFirstCoin, isFalse);
    final data = mission()..['requiresFirstCoin'] = true;
    expect(
      CampaignMissionSource.decode(data).toJson()['requiresFirstCoin'],
      true,
    );
    expect(() => compile(data), throwsFormatException);
    data['collectibles'] = [
      {'missionChunkId': 'first', 'x': 100, 'y': 205},
    ];
    expect(compile(data).definition.requiresFirstCoin, isTrue);
    data['requiresFirstCoin'] = null;
    expect(() => CampaignMissionSource.decode(data), throwsFormatException);
  });

  test('blessing objective and guidance follow one strict shrine marker', () {
    final data = mission();
    final shrine = CampaignShrineSource(
      'basin',
      CampaignPoint(missionChunkId: 'second', x: 240, y: 224),
      prefabKey: null,
      placementKey: null,
      shapeId: 'ground_001',
      appearance: WorldInteractionAppearanceId.emberFlame,
      activationWidth: 24,
      scale: 1,
    ).toJson();
    data['placements'] = [shrine];
    data['blessingObjectiveShrineId'] = 'basin';
    data['tutorialSequences'] = [
      CampaignBlessingTutorial.introduction(shrineId: 'basin').toJson(),
    ];
    final captured = compile(data);
    expect(captured.definition.requiredBlessingShrine, (
      missionChunkId: 'second',
      bindingKey: 'basin',
    ));
    final lesson =
        captured.source.tutorialSequences.single as CampaignBlessingTutorial;
    final before = lesson.resolveShrine(captured.definition);
    shrine['position'] = {'missionChunkId': 'first', 'x': 300, 'y': 224};
    final moved = lesson.resolveShrine(compile(data).definition);
    expect(moved.missionChunkId, 'first');
    expect(moved.left, before.left + 60);
    expect(
      lesson.resolveShrine(captured.definition).left,
      before.left,
      reason: 'Previously captured Play is immutable.',
    );
    (data['tutorialSequences'] as List).first['enabled'] = false;
    data['blessingObjectiveShrineId'] = 'missing';
    expect(() => compile(data), throwsFormatException);
    data['blessingObjectiveShrineId'] = 'basin';
    shrine['shapeId'] = 'missing';
    expect(() => compile(data), throwsFormatException);
    shrine['shapeId'] = 'ground_001';
    data.remove('blessingObjectiveShrineId');
    expect(() => CampaignMissionSource.decode(data), throwsFormatException);
    data['tutorialSequences'] = [];
    expect(compile(data).definition.requiredBlessingShrine, isNull);
    data['blessingObjectiveShrineId'] = null;
    expect(() => CampaignMissionSource.decode(data), throwsFormatException);
  });

  test('water references validate against captured chunks, including disabled lessons', () {
    final data = mission()
      ..['tutorialSequences'] = [
        CampaignWaterTutorial.introduction(
          missionChunkId: 'second',
          waterRegionId: 'pool',
        ).toJson(),
      ];
    final wet = jsonDecode(chunks['training_field_1']!) as Map<String, dynamic>;
    wet['waterRegions'] = [
      {
        'id': 'pool',
        'x': 300,
        'y': 224,
        'width': 80,
        'height': 46,
        'materialKey': 'biome_water',
      },
    ];
    CompiledCampaignMission compileWet() =>
        compile(data, sources: {'training_field_1': jsonEncode(wet)});
    final compiled = compileWet();
    final lesson =
        compiled.source.tutorialSequences.single as CampaignWaterTutorial;
    expect(lesson.resolveWater(compiled.definition).x, 300);
    wet['waterRegions'][0]['x'] = 330;
    expect(
      lesson.resolveWater(compileWet().definition).x,
      330,
      reason: 'Spotlight and trigger follow current captured geometry.',
    );
    (data['tutorialSequences'] as List).first['enabled'] = false;
    wet['waterRegions'] = [];
    expect(compileWet, throwsFormatException);
    (data['tutorialSequences'] as List).first['missionChunkId'] = 'missing';
    expect(() => CampaignMissionSource.decode(data), throwsFormatException);
  });

  test('decoration attachment follows captured prefab geometry and rejects stale references', () {
    final lesson = CampaignDecorationTutorial.introduction(
      missionChunkId: 'second',
      waterRegionId: 'pool',
      decorationPrefabKey: 'pixel_fantasy_caves_tree_02',
    );
    final data = mission()..['tutorialSequences'] = [lesson.toJson()];
    final wet = jsonDecode(chunks['training_field_1']!) as Map<String, dynamic>;
    wet['waterRegions'] = [
      {
        'id': 'pool',
        'x': 300,
        'y': 224,
        'width': 80,
        'height': 46,
        'materialKey': 'biome_water',
      },
    ];
    final tree = <String, Object?>{
      'prefabId': lesson.decorationPrefabKey,
      'prefabKey': lesson.decorationPrefabKey,
      'x': 484,
      'y': 162,
      'zIndex': -1,
      'snapToGrid': false,
    };
    wet['prefabs'] = [tree];
    CompiledCampaignMission compileWet() =>
        compile(data, sources: {'training_field_1': jsonEncode(wet)});
    final before = lesson.resolveDecoration(compileWet().definition);
    tree['x'] = 500;
    tree['rotationDegrees'] = 90;
    final after = lesson.resolveDecoration(compileWet().definition);
    expect(after.prefabKey, lesson.decorationPrefabKey);
    expect(after.x, before.x + 16);
    expect(after.rotationDegrees, 90);
    (data['tutorialSequences'] as List).first['enabled'] = false;
    wet['prefabs'] = [
      tree,
      {...tree, 'x': 400},
    ];
    expect(compileWet, throwsFormatException);
    wet['prefabs'] = [];
    expect(compileWet, throwsFormatException);
    wet['prefabs'] = [tree];
    wet['waterRegions'] = [];
    expect(compileWet, throwsFormatException);
    (data['tutorialSequences'] as List).first['missionChunkId'] = 'missing';
    expect(() => CampaignMissionSource.decode(data), throwsFormatException);
  });

  test('gap references follow captured ground and reject removed banks even disabled', () {
    final data = mission();
    final lesson = CampaignGapTutorial.introduction(
      missionChunkId: 'second',
      nearGroundShapeId: 'ground_001',
      farGroundShapeId: 'solid_002',
    );
    data['tutorialSequences'] = [lesson.toJson()];
    final chunk =
        jsonDecode(chunks['training_field_1']!) as Map<String, dynamic>;
    final gapSource = jsonDecode(
      File(
        '$root/assets/authoring/level/chunks/forest/forest_default_early_cmp_004.json',
      ).readAsStringSync(),
    );
    chunk['collisionShapes'] = gapSource['collisionShapes'];
    chunk['prefabs'] = [];
    CompiledCampaignMission compileGap() =>
        compile(data, sources: {'training_field_1': jsonEncode(chunk)});
    expect(lesson.resolveGap(compileGap().definition).width, 69);
    for (final v in chunk['collisionShapes'][0]['vertices'] as List) {
      if (v['x'] == 221) v['x'] = 201;
    }
    expect(lesson.resolveGap(compileGap().definition).width, 89);
    (data['tutorialSequences'] as List).first['enabled'] = false;
    chunk['collisionShapes'][2]['shapeId'] = 'renamed_bank';
    expect(compileGap, throwsFormatException);
    (data['tutorialSequences'] as List).first['missionChunkId'] = 'missing';
    expect(() => CampaignMissionSource.decode(data), throwsFormatException);
  });

  test('platform attachment follows captured geometry and rejects stale disabled references', () {
    const key = 'tiny_swords_ground_platform_04_64x32_platform';
    final lesson = CampaignPlatformTutorial.introduction(
      missionChunkId: 'second',
      platformPrefabKey: key,
    );
    final data = mission()..['tutorialSequences'] = [lesson.toJson()];
    final chunk =
        jsonDecode(chunks['training_field_1']!) as Map<String, dynamic>;
    final placement = <String, Object?>{
      'prefabId': key,
      'prefabKey': key,
      'x': 192,
      'y': 176,
      'zIndex': 0,
      'snapToGrid': false,
    };
    chunk['prefabs'] = [placement];
    CompiledCampaignMission compilePlatform() =>
        compile(data, sources: {'training_field_1': jsonEncode(chunk)});
    expect(lesson.resolvePlatform(compilePlatform().definition).bounds.x, 160);
    placement['x'] = 210;
    expect(lesson.resolvePlatform(compilePlatform().definition).bounds.x, 178);
    (data['tutorialSequences'] as List).first['enabled'] = false;
    chunk['prefabs'] = [
      placement,
      {...placement, 'x': 400},
    ];
    expect(compilePlatform, throwsFormatException);
    chunk['prefabs'] = [];
    expect(compilePlatform, throwsFormatException);
    (data['tutorialSequences'] as List).first['missionChunkId'] = 'missing';
    expect(() => CampaignMissionSource.decode(data), throwsFormatException);
  });

  test('four editable drafts, arrival rules and 224 XP round-trip', () {
    final drafts = jsonDecode(text) as Map<String, dynamic>;
    for (final chapter in drafts['chapters'] as List) {
      for (final mission in chapter['missions'] as List) {
        mission['includeInBuild'] = false;
        mission['route'] = [];
        mission.remove('tutorialSequences');
        mission['start'] = null;
        mission['exit'] = null;
      }
    }
    final catalog = CampaignCatalogSource.decode(jsonEncode(drafts));
    expect(jsonDecode(catalog.encode()), drafts);
    expect(catalog.missions, hasLength(4));
    expect(catalog.missions.every((m) => !m.includeInBuild), isTrue);
    expect(catalog.missions.fold<int>(0, (n, m) => n + m.firstClearXp), 224);
    expect(
      catalog.missions.first.firstClearItems.single.item.itemId,
      'eloise.double_jump',
    );
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
    'mission first-clear rewards validate the same catalog and amount bounds',
    () {
      const gear = {
        'kind': 'gear',
        'slot': 'mainWeapon',
        'itemId': 'cinderedge',
      };
      const ability = {
        'kind': 'ability',
        'slot': 'jump',
        'itemId': 'eloise.double_jump',
        'characterId': 'eloise',
      };
      final data = mission()
        ..addAll({
          'firstClearXp': 100000,
          'firstClearGold': 1000000,
          'firstClearItems': [gear, ability],
        });
      final parsed = CampaignMissionSource.decode(data);
      expect(parsed.toJson(), data);
      expect(parsed.firstClearItems.map((item) => item.toJson()), [
        gear,
        ability,
      ]);
      for (final invalid in <Map<String, Object?>>[
        {'firstClearXp': -1},
        {'firstClearXp': 100001},
        {'firstClearGold': 1000001},
        {'firstClearGold': null},
        {'firstClearGold': 1.5},
        {'firstClearItems': null},
        {
          'firstClearItems': [gear, gear],
        },
        {'firstClearItems': List.filled(9, gear)},
        {
          'firstClearItems': [
            {...gear, 'itemId': 'invented'},
          ],
        },
        {
          'firstClearItems': [
            {...ability, 'characterId': 'bountyHunter'},
          ],
        },
        {
          'firstClearItems': [
            {...ability}..remove('characterId'),
          ],
        },
        {'combatAllowed': true},
        {'rewardAbilityId': 'eloise.double_jump'},
      ]) {
        expect(
          () => CampaignMissionSource.decode({...data, ...invalid}),
          throwsFormatException,
          reason: '$invalid',
        );
      }
    },
  );
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
  test('missing source, wrong owner, duplicate mission chunk and unsupported start reject', () {
    for (final mutate in <void Function(Map<String, Object?>)>[
      (m) => (m['route'] as List)[1]['chunkKey'] = 'missing',
      (m) => (m['route'] as List)[1]['levelId'] = 'forest',
      (m) => (m['route'] as List)[1]['id'] = 'first',
      (m) => m['start'] = {'missionChunkId': 'first', 'x': 60, 'y': 180},
      (m) => m['start'] = {'missionChunkId': 'gone', 'x': 60, 'y': 224},
      (m) => m['requiredEnemies'] = [
        {'missionChunkId': 'first', 'markerSalt': 42},
      ],
      (m) => m['includeInBuild'] = null,
      (m) => m['randomize'] = true,
    ]) {
      final data = mission();
      mutate(data);
      expect(() => compile(data), throwsFormatException);
    }
  });
  test('48 chunks compile through Core and 49 are rejected', () {
    final data = mission()
      ..['route'] = [
        for (var i = 0; i < 48; i++)
          {
            'id': 'step_$i',
            'levelId': 'training_field',
            'chunkKey': 'training_field_1',
          },
      ]
      ..['start'] = {'missionChunkId': 'step_0', 'x': 60, 'y': 224}
      ..['exit'] = {
        'origin': {'missionChunkId': 'step_47', 'x': 500, 'y': 0},
        'width': 100,
        'height': 270,
      };
    final compiled = compile(data);
    expect(compiled.definition.route.length, 48);
    expect(compiled.definition.worldWidth, 28800);
    (data['route'] as List).add({
      'id': 'step_48',
      'levelId': 'training_field',
      'chunkKey': 'training_field_1',
    });
    expect(() => compile(data), throwsFormatException);
  });

  test(
    'retired mission identities round-trip and cannot be active or duplicated',
    () {
      final raw = jsonDecode(text) as Map<String, dynamic>;
      raw['retiredMissionIds'] = ['old_mission'];
      final source = CampaignCatalogSource.decode(jsonEncode(raw));
      expect(CampaignCatalogSource.decode(source.encode()).retiredMissionIds, {
        'old_mission',
      });
      for (final value in [
        null,
        ['old_mission', 'old_mission'],
        [source.missions.first.id],
      ]) {
        raw['retiredMissionIds'] = value;
        expect(
          () => CampaignCatalogSource.decode(jsonEncode(raw)),
          throwsFormatException,
        );
      }
    },
  );

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
    final combatMission = mission();
    expect(
      compile(
        combatMission,
        sources: withEnemy,
      ).definition.route.missionChunks.first.pattern.spawnMarkers.single.salt,
      42,
    );
  });
}
