import 'dart:convert';
import 'dart:io';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_core/interactions/world_interaction_catalog.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/traps/trap_catalog.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:runner_core/traps/trap_placement.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

void main() {
  final root = Directory.current.parent.parent.path;
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
  Map<String, Object?> mission(List<Map<String, Object?>> placements) => {
    'id': 'placement_test',
    'revision': 1,
    'includeInBuild': false,
    'title': {'en': 'Placement test', 'fr': 'Placement'},
    'description': {'en': 'Fixture', 'fr': 'Fixture'},
    'visualThemeId': 'forest',
    'levelId': 'training_field',
    'firstClearXp': 0,
    'firstClearGold': 0,
    'firstClearItems': [],
    'route': [
      for (final id in ['first', 'second'])
        {'id': id, 'levelId': 'training_field', 'chunkKey': 'training_field_1'},
    ],
    'start': {'missionChunkId': 'first', 'x': 60, 'y': 224},
    'exit': {
      'origin': {'missionChunkId': 'second', 'x': 570, 'y': 0},
      'width': 20,
      'height': 20,
    },
    'collectibles': [],
    'requiredRegions': [],
    'requiredEnemies': [],
    'requiredRescues': [],
    'placements': placements,
  };
  Map<String, Object?> pickup(
    String id,
    String missionChunk,
    int x, [
    String? resource,
  ]) => {
    'id': id,
    'kind': resource == null ? 'gold' : 'gem',
    'position': {'missionChunkId': missionChunk, 'x': x, 'y': 208},
    'resource': ?resource,
  };
  CompiledCampaignMission compile(Map<String, Object?> source) =>
      compileCampaignMission(
        source: CampaignMissionSource.decode(jsonDecode(jsonEncode(source))),
        chunkContentsByKey: chunks,
        prefabContents: prefabs,
        tileContents: tiles,
      );

  test(
    'enemy return/follow policy defaults, round-trips and compiles per marker',
    () {
      final marker = <String, Object?>{
        'id': 'local_guard',
        'kind': 'enemy',
        'position': {'missionChunkId': 'second', 'x': 300, 'y': 224},
        'enemyId': 'grojib',
        'placement': 'ground',
        'chancePercent': 100,
        'salt': 42,
        'required': true,
      };
      final defaultSource =
          decodeCampaignPlacements([marker]).single as CampaignEnemySource;
      expect(defaultSource.returnWhenPlayerRetreats, isTrue);
      expect(
        defaultSource.toJson().containsKey('returnWhenPlayerRetreats'),
        isFalse,
      );
      expect(
        compile(mission([marker])).definition.persistentPursuitEnemies,
        isEmpty,
      );
      final follows = {...marker, 'returnWhenPlayerRetreats': false};
      final source =
          decodeCampaignPlacements([follows]).single as CampaignEnemySource;
      expect(source.returnWhenPlayerRetreats, isFalse);
      expect(source.toJson(), follows);
      expect(compile(mission([follows])).definition.persistentPursuitEnemies, {
        (missionChunkId: 'second', markerSalt: 42),
      });
      for (final invalid in [null, 0, 'false']) {
        expect(
          () => decodeCampaignPlacements([
            {...marker, 'returnWhenPlayerRetreats': invalid},
          ]),
          throwsFormatException,
        );
      }
    },
  );

  for (final hz in [30, 120]) {
    for (final character in PlayerCharacterRegistry.playable) {
      test(
        '${character.id.name} $hz Hz: surface fire activates only on its mission chunk and resets',
        () {
          final terrain = compile(mission([])).chunks.single.stagedTerrain;
          final floor = terrain.polygons.firstWhere(
            (p) => p.id.placementKey == null,
          );
          Map<String, Object?> fire(String id, double x) =>
              CampaignShrineSource(
                id,
                CampaignPoint(missionChunkId: 'second', x: x, y: 224),
                prefabKey: null,
                placementKey: null,
                shapeId: floor.id.shapeId,
                appearance: WorldInteractionAppearanceId.blueFlame,
                activationWidth: 24,
                scale: 1,
              ).toJson();
          final compiled = compile(
            mission([fire('fire_a', 150), fire('fire_b', 350)]),
          );
          expect(compiled.chunks, hasLength(1));
          GameCore start() => GameCore.campaignPlaytest(
            mission: compiled.definition,
            playerCharacter: character,
            seed: 42,
            tickHz: hz,
          );
          final core = start();
          expect(core.buildSnapshot().interactions.map((f) => f.x), [750, 950]);
          int? grant;
          void travel(double goal) {
            for (
              var t = 0;
              t < hz * 20 && (core.playerPosX - goal).abs() >= 6;
              t++
            ) {
              final before = core.playerPosX;
              core.applyCommands([
                MoveAxisCommand(
                  tick: core.tick + 1,
                  axis: goal > before ? 1 : -1,
                ),
              ]);
              core.stepOneTick();
              expect(core.gameOver, isFalse);
              expect((core.playerPosX - before).abs(), lessThan(30));
              final snapshot = core.buildSnapshot();
              if (core.playerPosX < 600 && grant == null) {
                expect(snapshot.hud.blessings, isEmpty);
              }
              if (snapshot.hud.blessings.isNotEmpty) {
                grant ??= core.tick;
                expect(snapshot.hud.blessings.single.grantedAtTick, grant);
              }
            }
            expect((core.playerPosX - goal).abs(), lessThan(6));
          }

          travel(1100);
          expect(grant, isNotNull);
          expect(
            core.buildSnapshot().interactions.every((f) => f.active),
            isTrue,
          );
          travel(80);
          travel(1100);
          expect(
            core.buildSnapshot().hud.blessings.single.grantedAtTick,
            grant,
          );
          final restarted = start().buildSnapshot();
          expect(restarted.hud.blessings, isEmpty);
          expect(restarted.interactions.every((f) => !f.active), isTrue);
          for (final broken in [
            {...fire('broken', 150), 'shapeId': 'missing'},
            {...fire('broken', 150), 'activationWidth': 601},
            {...fire('broken', 2), 'activationWidth': 24},
            {
              ...fire('broken', 150),
              'position': {'missionChunkId': 'second', 'x': 150, 'y': 200},
            },
          ]) {
            expect(() => compile(mission([broken])), throwsFormatException);
          }
        },
      );
      test(
        '${character.id.name} $hz Hz: authored gold/gems survive travel and stay consumed',
        () {
          final data = mission([
            pickup('coin_a', 'first', 150),
            pickup('coin_b', 'second', 150),
            pickup('health', 'first', 250, 'health'),
            pickup('mana', 'second', 250, 'mana'),
            pickup('stamina', 'second', 350, 'stamina'),
          ]);
          final compiled = compile(data);
          expect(compiled.chunks, hasLength(1));
          expect(compiled.definition.restorations, hasLength(3));
          final core = GameCore.campaignPlaytest(
            mission: compiled.definition,
            playerCharacter: character,
            seed: 42,
            tickHz: hz,
          );
          expect(
            core.buildSnapshot().entities.where(
              (e) => e.kind == EntityKind.pickup,
            ),
            hasLength(5),
          );
          void travel(double goal) {
            for (var budget = 0; budget < hz * 20; budget++) {
              final before = core.playerPosX;
              if ((before - goal).abs() < 6) break;
              core.applyCommands([
                MoveAxisCommand(
                  tick: core.tick + 1,
                  axis: goal > before ? 1 : -1,
                ),
              ]);
              core.stepOneTick();
              expect(core.gameOver, isFalse);
              expect((core.playerPosX - before).abs(), lessThan(30));
            }
            expect((core.playerPosX - goal).abs(), lessThan(6));
          }

          travel(1100);
          expect(core.collectibles, 2);
          expect(
            core.buildSnapshot().entities.where(
              (e) => e.kind == EntityKind.pickup,
            ),
            isEmpty,
          );
          travel(80);
          travel(1100);
          expect(core.collectibles, 2);
          expect(
            core.buildSnapshot().entities.where(
              (e) => e.kind == EntityKind.pickup,
            ),
            isEmpty,
          );
          final restarted = GameCore.campaignPlaytest(
            mission: compiled.definition,
            playerCharacter: character,
            seed: 42,
            tickHz: hz,
          );
          expect(
            restarted.buildSnapshot().entities.where(
              (e) => e.kind == EntityKind.pickup,
            ),
            hasLength(5),
          );
        },
      );
    }
  }

  test(
    'local enemy changes one mission chunk without changing shared terrain',
    () {
      final before = chunks['training_field_1'];
      final source = mission([
        {
          'id': 'guard',
          'kind': 'enemy',
          'position': {'missionChunkId': 'second', 'x': 300, 'y': 224},
          'enemyId': 'grojib',
          'placement': 'ground',
          'chancePercent': 100,
          'salt': 42,
          'required': true,
        },
      ]);
      final compiled = compile(source);
      expect(
        compiled.definition.route.missionChunks.first.pattern.spawnMarkers,
        isEmpty,
      );
      expect(
        compiled.definition.route.missionChunks.last.pattern.spawnMarkers,
        hasLength(1),
      );
      expect(compiled.definition.requiredEnemies.single, (
        missionChunkId: 'second',
        markerSalt: 42,
      ));
      expect(chunks['training_field_1'], before);
      expect(compiled.chunks, hasLength(1));
    },
  );

  test('strict placement boundaries and unchanged absent-field encoding', () {
    final source = mission([])..remove('placements');
    expect(
      CampaignMissionSource.decode(jsonDecode(jsonEncode(source))).toJson(),
      source,
    );
    for (final invalid in [
      null,
      [pickup('same', 'first', 150), pickup('same', 'second', 150)],
      [pickup('bad', 'first', 600)],
      [pickup('bad', 'first', 150, 'invented')],
      [
        {...pickup('bad', 'first', 150), 'unknown': true},
      ],
    ]) {
      expect(
        () => compile({...source, 'placements': invalid}),
        throwsFormatException,
      );
    }
    expect(
      () => compile(mission([pickup('missing', 'gone', 150)])),
      throwsFormatException,
    );
  });

  test('local traps and rescue rosters reuse shared readiness and mission chunk identity', () {
    final trap = CampaignTrapSource(
      'spikes',
      'second',
      TrapPlacement(
        trapId: TrapId.spike,
        x: 500,
        y: 224,
        trigger: TrapCatalog.get(TrapId.spike).defaultTrigger,
      ),
    );
    CampaignRescueSource rescue({bool complete = true}) => CampaignRescueSource(
      'rescue',
      'second',
      EncounterDefinition(
        id: 'rescue',
        name: 'Rescue',
        trigger: EncounterTrigger(x: 200, y: 160, width: 200, height: 64),
        npcs: [EncounterNpcPlacement(id: 'npc', npcId: NpcId.warrior, x: 250)],
        enemies: [
          if (complete)
            EncounterEnemyPlacement(
              id: 'guard',
              enemyId: EnemyId.grojib,
              x: 350,
            ),
        ],
      ),
      required: true,
    );
    final draft = mission([rescue(complete: false).toJson()]);
    expect(CampaignMissionSource.decode(draft).placements, hasLength(1));
    expect(() => compile(draft), throwsFormatException);
    final compiled = compile(mission([trap.toJson(), rescue().toJson()]));
    final first = compiled.definition.route.missionChunks.first.pattern;
    final second = compiled.definition.route.missionChunks.last.pattern;
    expect(first.traps, isEmpty);
    expect(first.encounters, isEmpty);
    expect(second.traps.single.x, 500);
    expect(second.encounters.single.id, 'rescue');
    expect(compiled.definition.requiredRescues.single, (
      missionChunkId: 'second',
      encounterId: 'rescue',
    ));
    final core = GameCore.campaignPlaytest(
      mission: compiled.definition,
      playerCharacter: PlayerCharacterRegistry.eloise,
      seed: 42,
    );
    expect(core.buildSnapshot().traps, hasLength(1));
    for (var t = 0; t < 180; t++) {
      core.stepOneTick();
    }
    expect(core.buildSnapshot().traps, hasLength(1));
    final duplicateSalt = mission([
      {
        'id': 'enemy_a',
        'kind': 'enemy',
        'position': {'missionChunkId': 'second', 'x': 250, 'y': 224},
        'enemyId': 'grojib',
        'placement': 'ground',
        'chancePercent': 100,
        'salt': 8,
        'required': false,
      },
      {
        'id': 'enemy_b',
        'kind': 'enemy',
        'position': {'missionChunkId': 'second', 'x': 350, 'y': 224},
        'enemyId': 'grojib',
        'placement': 'ground',
        'chancePercent': 100,
        'salt': 8,
        'required': false,
      },
    ]);
    expect(() => compile(duplicateSalt), throwsFormatException);
  });
}
