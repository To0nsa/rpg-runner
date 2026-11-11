import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_core/commands/command.dart';
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

  test('combat-free admission rejects retained encounter markers', () {
    expect(() => _mission(combatAllowed: false), throwsArgumentError);
  });
}

CampaignMissionDefinition _mission({
  bool combat = true,
  bool combatAllowed = true,
}) {
  final field = trainingFieldDefinition;
  final flat = field.chunks.first;
  return CampaignMissionDefinition(
    id: 'return_trip_fixture',
    route: FiniteChunkPatternSource([
      for (final id in ['first', 'middle', 'last'])
        FiniteChunkOccurrence(
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
    start: CampaignPoint(occurrenceId: 'first', x: 300, y: 224),
    exit: CampaignRegion(
      origin: CampaignPoint(occurrenceId: 'last', x: 500, y: 0),
      width: 100,
      height: 270,
    ),
    visualThemeId: field.visualThemeId,
    combatAllowed: combatAllowed,
    collectibles: [
      CampaignPoint(occurrenceId: 'first', x: 80, y: 205),
      CampaignPoint(occurrenceId: 'last', x: 150, y: 205),
    ],
    requiredRegions: [
      CampaignRegion(
        origin: CampaignPoint(occurrenceId: 'first', x: 20, y: 0),
        width: 100,
        height: 270,
      ),
      CampaignRegion(
        origin: CampaignPoint(occurrenceId: 'last', x: 100, y: 0),
        width: 100,
        height: 270,
      ),
    ],
    requiredEnemies: combat
        ? [(occurrenceId: 'middle', markerSalt: 42)]
        : const [],
  );
}
