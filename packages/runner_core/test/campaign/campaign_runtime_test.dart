import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/interactions/world_interaction_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/finite_chunk_pattern_source.dart';
import 'package:runner_core/training/authored_training_field.dart';
import 'package:test/test.dart';

void main() {
  for (final player in PlayerCharacterRegistry.playable) {
    test(
      '${player.id.name}: continuous outward and return travel keeps state',
      () {
        final core = GameCore.campaignPlaytest(
          mission: _mission(),
          playerCharacter: player,
          seed: 42,
        );
        final initial = core.buildSnapshot();
        expect(
          initial.stagedTerrainRenderSnapshot!.polygons
              .map((p) => p.sourceId.chunkIndex)
              .toSet(),
          {0, 1, 2},
        );
        expect(
          initial.entities.where((e) => e.kind == EntityKind.pickup),
          hasLength(2),
        );
        final commands = <List<Command>>[];
        final events = <RunEndedEvent>[];
        void travel(double destination) {
          for (var budget = 0; budget < 1200; budget++) {
            final before = core.buildSnapshot();
            final x = before.playerEntity!.pos.x;
            if ((x - destination).abs() < 6 || core.gameOver) break;
            final frame = <Command>[
              MoveAxisCommand(
                tick: core.tick + 1,
                axis: destination > x ? 1 : -1,
              ),
              if (core.tick % 24 == 0)
                StrikePressedCommand(tick: core.tick + 1),
              if (core.tick % 45 == 0)
                ProjectilePressedCommand(tick: core.tick + 1),
            ];
            commands.add(frame);
            core.applyCommands(frame);
            core.stepOneTick();
            events.addAll(core.drainEvents().whereType<RunEndedEvent>());
            expect(
              (core.buildSnapshot().playerEntity!.pos.x - x).abs(),
              lessThan(15),
              reason: 'Continuous motion, no route skipping.',
            );
          }
        }

        travel(1400);
        expect(
          core.gameOver,
          isFalse,
          reason: events.map((e) => e.reason).join(','),
        );
        expect(core.buildSnapshot().playerEntity!.pos.x, greaterThan(1390));
        final rightCamera = core.buildSnapshot().camera.centerX;
        expect(core.collectibles, 1);
        travel(80);
        expect(core.gameOver, isFalse);
        expect(core.buildSnapshot().camera.centerX, lessThan(rightCamera));
        expect(core.collectibles, 2);
        expect(core.buildSnapshot().campaign!.exitReady, isTrue);
        travel(1750);
        expect(events.single.reason, RunEndReason.missionCompleted);
        expect(
          core.buildSnapshot().playerEntity!.pos.x,
          greaterThanOrEqualTo(1700),
        );
        expect(events.single.stats.collectibles, 2);
        expect(events.single.stats.enemyKillCounts[EnemyId.grojib.index], 1);
        expect(events.single.stats.excludedScoreTicks, events.single.tick);
        expect(
          core.buildSnapshot().entities.where(
            (e) => e.kind == EntityKind.enemy,
          ),
          isEmpty,
        );
        final finalTick = core.tick;
        core.stepOneTick();
        core.giveUp();
        expect(core.tick, finalTick);
        expect(core.drainEvents(), isEmpty);

        final replay = GameCore.campaignPlaytest(
          mission: _mission(),
          playerCharacter: player,
          seed: 42,
        );
        for (final frame in commands) {
          replay.applyCommands(frame);
          replay.stepOneTick();
        }
        final replayResult = replay
            .drainEvents()
            .whereType<RunEndedEvent>()
            .single;
        expect(
          (
            replayResult.tick,
            replayResult.reason,
            replayResult.distance,
            replayResult.goldEarned,
          ),
          (
            events.single.tick,
            events.single.reason,
            events.single.distance,
            events.single.goldEarned,
          ),
        );
        expect(
          replayResult.stats.enemyKillCounts,
          events.single.stats.enemyKillCounts,
        );
      },
    );
  }

  test('exit overlap cannot bypass required return region', () {
    final core = GameCore.campaignPlaytest(
      mission: _mission(combat: false),
      playerCharacter: PlayerCharacterRegistry.eloise,
    );
    for (var i = 0; i < 750; i++) {
      core.applyCommands([
        MoveAxisCommand(tick: core.tick + 1, axis: 1),
        if (i % 90 == 0) DashPressedCommand(tick: core.tick + 1),
      ]);
      core.stepOneTick();
    }
    expect(core.gameOver, isFalse);
    final debug = core.buildTerrainPlayerDebugSnapshot()!;
    expect(
      debug.capsuleCenterXTicks + debug.capsuleRadiusTicks,
      lessThanOrEqualTo(1800 * 1024),
    );
    expect(core.buildSnapshot().campaign!.exitReady, isFalse);
    for (var i = 0; i < 750; i++) {
      core.applyCommands([
        MoveAxisCommand(tick: core.tick + 1, axis: -1),
        if (i % 90 == 0) DashPressedCommand(tick: core.tick + 1),
      ]);
      core.stepOneTick();
    }
    expect(core.gameOver, isFalse);
    final left = core.buildTerrainPlayerDebugSnapshot()!;
    expect(
      left.capsuleCenterXTicks - left.capsuleRadiusTicks,
      greaterThanOrEqualTo(0),
    );
    core.giveUp();
    expect(
      core.drainEvents().whereType<RunEndedEvent>().single.reason,
      RunEndReason.gaveUp,
    );
  });

  test('coin objective gates exit and completes identically on replay', () {
    final mission = _coinMission();
    final core = GameCore.campaignPlaytest(
      mission: mission,
      playerCharacter: PlayerCharacterRegistry.eloise,
      seed: 42,
    );
    final frames = <List<Command>>[];
    void travel(double destination) {
      for (var budget = 0; budget < 1200 && !core.gameOver; budget++) {
        final x = core.buildSnapshot().playerEntity!.pos.x;
        if ((destination - x).abs() < 6) return;
        final frame = <Command>[
          MoveAxisCommand(tick: core.tick + 1, axis: destination > x ? 1 : -1),
        ];
        frames.add(frame);
        core.applyCommands(frame);
        core.stepOneTick();
        expect(
          (core.buildSnapshot().playerEntity!.pos.x - x).abs(),
          lessThan(15),
        );
      }
    }

    travel(520);
    expect(core.buildSnapshot().playerEntity!.pos.x, greaterThan(500));
    expect(
      core.gameOver,
      isFalse,
      reason: 'Exit overlap before pickup must fail.',
    );
    expect(core.buildSnapshot().campaign!.required, 1);
    expect(core.buildSnapshot().campaign!.completed, 0);
    expect(core.buildSnapshot().campaign!.exitReady, isFalse);
    travel(80);
    expect(core.collectibles, 1);
    expect(core.buildSnapshot().campaign!.firstCoinCollected, isTrue);
    expect(core.buildSnapshot().campaign!.completed, 1);
    expect(core.buildSnapshot().campaign!.exitReady, isTrue);
    travel(520);
    final outcome = core.drainEvents().whereType<RunEndedEvent>().single;
    expect(outcome.reason, RunEndReason.missionCompleted);
    final replay = GameCore.campaignPlaytest(
      mission: mission,
      playerCharacter: PlayerCharacterRegistry.eloise,
      seed: 42,
    );
    for (final frame in frames) {
      replay.applyCommands(frame);
      replay.stepOneTick();
    }
    final replayOutcome = replay
        .drainEvents()
        .whereType<RunEndedEvent>()
        .single;
    expect(
      (replayOutcome.tick, replayOutcome.reason, replayOutcome.goldEarned),
      (outcome.tick, outcome.reason, outcome.goldEarned),
    );
    expect(() => _coinMission(coins: false), throwsArgumentError);
  });

  test('selected blessing shrine gates exit and replays exactly', () {
    final base = _coinMission();
    CampaignMissionDefinition mission({
      String target = 'required',
      CampaignRegion? exit,
    }) => CampaignMissionDefinition(
      id: 'blessing_objective_fixture',
      route: base.route,
      terrainChunks: trainingFieldDefinition.terrain.chunks,
      start: base.start,
      exit: exit ?? base.exit,
      visualThemeId: base.visualThemeId,
      requiredBlessingShrine: (missionChunkId: 'first', bindingKey: target),
      interactions: [
        for (final (id, x) in [('required', 80.0), ('other', 400.0)])
          WorldInteractionBinding(
            key: id,
            chunkKey: base.route.missionChunks.first.pattern.chunkKey!,
            prefabKey: null,
            shapeId: 'ground_001',
            missionChunkId: 'first',
            surfaceX: x,
            activationWidth: 24,
            interactionId: WorldInteractionId.regenerationShrine,
            appearanceId: WorldInteractionAppearanceId.emberFlame,
          ),
      ],
    );
    expect(() => mission(target: 'missing'), throwsArgumentError);
    final definition = mission();
    GameCore create() => GameCore.campaignPlaytest(
      mission: definition,
      playerCharacter: PlayerCharacterRegistry.eloise,
      seed: 42,
    );
    final core = create();
    final frames = <List<Command>>[];
    void travel(double destination) {
      for (var i = 0; i < 1200 && !core.gameOver; i++) {
        final x = core.buildSnapshot().playerEntity!.pos.x;
        if ((destination - x).abs() < 6) return;
        final commands = <Command>[
          MoveAxisCommand(tick: core.tick + 1, axis: destination > x ? 1 : -1),
        ];
        frames.add(commands);
        core.applyCommands(commands);
        core.stepOneTick();
      }
    }

    travel(520);
    expect(core.gameOver, isFalse);
    expect(core.buildSnapshot().hud.blessings, hasLength(1));
    expect(
      core.buildSnapshot().campaign!.blessingReceived,
      isFalse,
      reason: 'An unrelated shrine cannot satisfy the selected objective.',
    );
    expect(core.buildSnapshot().campaign!.exitReady, isFalse);
    travel(80);
    expect(core.buildSnapshot().campaign!.blessingReceived, isTrue);
    expect(core.buildSnapshot().campaign!.completed, 1);
    expect(core.buildSnapshot().hud.blessings, hasLength(1));
    travel(520);
    final ended = core.drainEvents().whereType<RunEndedEvent>().single;
    expect(ended.reason, RunEndReason.missionCompleted);
    final replay = create();
    for (final commands in frames) {
      replay.applyCommands(commands);
      replay.stepOneTick();
    }
    final replayed = replay.drainEvents().whereType<RunEndedEvent>().single;
    expect((replayed.tick, replayed.reason), (ended.tick, ended.reason));
    expect(create().buildSnapshot().campaign!.blessingReceived, isFalse);
    final simultaneous = GameCore.campaignPlaytest(
      mission: mission(
        target: 'other',
        exit: CampaignRegion(
          origin: CampaignPoint(missionChunkId: 'first', x: 350, y: 0),
          width: 100,
          height: 270,
        ),
      ),
      playerCharacter: PlayerCharacterRegistry.eloise,
      seed: 42,
    );
    for (var i = 0; i < 200 && !simultaneous.gameOver; i++) {
      simultaneous.applyCommands([
        MoveAxisCommand(tick: simultaneous.tick + 1, axis: 1),
      ]);
      simultaneous.stepOneTick();
    }
    expect(
      simultaneous.drainEvents().whereType<RunEndedEvent>().single.reason,
      RunEndReason.missionCompleted,
    );
    expect(simultaneous.buildSnapshot().campaign!.blessingReceived, isTrue);
    expect(
      simultaneous
          .buildSnapshot()
          .interactions
          .where((s) => s.active)
          .single
          .elapsedTicks,
      0,
      reason:
          'Overlapping exit and shrine complete on the actual activation tick.',
    );
  });

  test('combat is determined by authored markers', () {
    expect(
      _mission().route.missionChunks[1].pattern.spawnMarkers,
      hasLength(1),
    );
    expect(
      _mission(combat: false).route.missionChunks
          .every((o) => o.pattern.spawnMarkers.isEmpty),
      isTrue,
    );
  });
}

CampaignMissionDefinition _mission({bool combat = true}) {
  final field = trainingFieldDefinition;
  final flat = field.chunks.first;
  return CampaignMissionDefinition(
    id: 'return_trip_fixture',
    route: FiniteChunkPatternSource([
      for (final id in ['first', 'middle', 'last'])
        FiniteMissionChunk(
          id: id,
          sourceLevelId: 'training_field',
          tier: ChunkPatternTier.easy,
          pattern: ChunkPattern(
            name: flat.name,
            chunkKey: flat.chunkKey,
            spawnMarkers: id == 'middle' && combat
                ? const [
                    SpawnMarker(
                      enemyId: EnemyId.grojib,
                      x: 300,
                      chancePercent: 100,
                      salt: 42,
                    ),
                  ]
                : const [],
          ),
        ),
    ]),
    terrainChunks: field.terrain.chunks,
    start: CampaignPoint(missionChunkId: 'first', x: 300, y: 224),
    exit: CampaignRegion(
      origin: CampaignPoint(missionChunkId: 'last', x: 500, y: 0),
      width: 100,
      height: 270,
    ),
    visualThemeId: field.visualThemeId,
    collectibles: [
      CampaignPoint(missionChunkId: 'first', x: 80, y: 205),
      CampaignPoint(missionChunkId: 'last', x: 150, y: 205),
    ],
    requiredRegions: [
      CampaignRegion(
        origin: CampaignPoint(missionChunkId: 'first', x: 20, y: 0),
        width: 100,
        height: 270,
      ),
      CampaignRegion(
        origin: CampaignPoint(missionChunkId: 'last', x: 100, y: 0),
        width: 100,
        height: 270,
      ),
    ],
    requiredEnemies: combat
        ? [(missionChunkId: 'middle', markerSalt: 42)]
        : const [],
  );
}

CampaignMissionDefinition _coinMission({bool coins = true}) {
  final base = _mission(combat: false);
  return CampaignMissionDefinition(
    id: 'coin_objective_fixture',
    route: base.route,
    terrainChunks: trainingFieldDefinition.terrain.chunks,
    start: base.start,
    exit: CampaignRegion(
      origin: CampaignPoint(missionChunkId: 'first', x: 480, y: 0),
      width: 100,
      height: 270,
    ),
    visualThemeId: base.visualThemeId,
    requiresFirstCoin: true,
    collectibles: coins ? [base.collectibles.first] : [],
  );
}
