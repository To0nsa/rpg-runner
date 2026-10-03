import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:rpg_runner/game/replay/replay_command_codec.dart';
import 'package:run_protocol/board_key.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';

import 'package:rpg_runner/game/replay/ghost_playback_runner.dart';

void main() {
  test('empty replay finalizes once and freezes its initial pose', () {
    final runner = GhostPlaybackRunner.fromReplayBlob(
      _buildReplayBlob(runSessionId: 'empty', totalTicks: 0),
    );
    runner.advanceToTick(0);
    runner.advanceToEnd();
    expect(runner.tick, 0);
    expect(runner.isComplete, isTrue);
    expect(runner.snapshot.gameOver, isTrue);
    expect(identical(runner.previousSnapshot, runner.snapshot), isTrue);
    expect(runner.drainedEvents.whereType<RunEndedEvent>(), hasLength(1));
  });

  test('disposed replay cannot advance or finalize', () {
    final runner = GhostPlaybackRunner.fromReplayBlob(
      _buildReplayBlob(runSessionId: 'disposed', totalTicks: 0),
    );
    runner.dispose();
    runner.advanceToEnd();
    expect(runner.drainedEvents, isEmpty);
    expect(runner.isComplete, isFalse);
  });

  test('early terminal catch-up freezes the actual ending tick', () {
    final runner = GhostPlaybackRunner.fromReplayBlob(
      _buildReplayBlob(runSessionId: 'early-terminal', totalTicks: 10000),
    );
    addTearDown(runner.dispose);
    runner.advanceToEnd();
    expect(runner.tick, lessThan(10000));
    expect(runner.isComplete, isTrue);
    expect(runner.snapshot.tick, runner.runEndedEvent!.tick);
    expect(runner.snapshot.gameOver, isTrue);
    expect(identical(runner.previousSnapshot, runner.snapshot), isTrue);
    expect(runner.debugSnapshotBuildCount, 2);
    expect(runner.drainedEvents.whereType<RunEndedEvent>(), hasLength(1));
  });

  test(
    'catch-up skips unused projections and matches full-Core replay events',
    () {
      final blob = _buildReplayBlob(runSessionId: 'batched');
      final runner = GhostPlaybackRunner.fromReplayBlob(blob);
      addTearDown(runner.dispose);
      final reference = GameCore(
        seed: blob.seed,
        runId: 1,
        tickHz: blob.tickHz,
        levelDefinition: LevelRegistry.byId(LevelId.field),
        playerCharacter: PlayerCharacterRegistry.eloise,
        equippedLoadoutOverride: const EquippedLoadoutDef(),
      );
      final frames = {
        for (final frame in blob.commandStream) frame.tick: frame,
      };
      final referenceEvents = <GameEvent>[];
      for (var target = 6; target <= blob.totalTicks; target += 6) {
        while (reference.tick < target && !reference.gameOver) {
          final frame = frames[reference.tick + 1];
          reference.applyCommands(
            frame == null ? [] : ReplayCommandCodec.commandsFromFrame(frame),
          );
          reference.stepOneTick();
          reference.buildSnapshot();
          referenceEvents.addAll(reference.drainEvents());
        }
        if (target == blob.totalTicks && !reference.gameOver) {
          reference.giveUp();
          referenceEvents.addAll(reference.drainEvents());
        }
        final before = runner.debugSnapshotBuildCount;
        runner.advanceToTick(target);
        expect(runner.debugSnapshotBuildCount - before, lessThanOrEqualTo(2));
        final full = reference.buildSnapshot();
        expect(runner.snapshot.tick, full.tick);
        expect(runner.snapshot.distance, full.distance);
        expect(runner.snapshot.gameOver, full.gameOver);
        expect(
          runner.drainedEvents.map((e) => e.runtimeType),
          referenceEvents.map((e) => e.runtimeType),
        );
        if (runner.isComplete) break;
        expect(runner.previousSnapshot.tick, runner.snapshot.tick - 1);
      }
      final expected = referenceEvents.whereType<RunEndedEvent>().single;
      final ended = runner.runEndedEvent!;
      expect(ended.tick, expected.tick);
      expect(ended.reason, expected.reason);
      expect(ended.distance, expected.distance);
      expect(ended.goldEarned, expected.goldEarned);
      expect(ended.stats.enemyKillCounts, expected.stats.enemyKillCounts);
      expect(ended.stats.collectibles, expected.stats.collectibles);
      expect(ended.stats.collectibleScore, expected.stats.collectibleScore);
      expect(identical(runner.previousSnapshot, runner.snapshot), isTrue);
      final frozen = runner.snapshot;
      runner.advanceToTick(blob.totalTicks + 60);
      expect(identical(runner.snapshot, frozen), isTrue);
    },
  );

  test('prepared ghost playback matches synchronous replay results', () async {
    final replayBlob = _buildReplayBlob(runSessionId: 'run_ghost_1');
    final runnerA = GhostPlaybackRunner.fromReplayBlob(replayBlob);
    final runnerB = GhostPlaybackRunner.fromReplayBlob(replayBlob);
    addTearDown(runnerB.dispose);
    await runnerB.prepareTerrainAhead();

    for (var tick = 1; tick <= replayBlob.totalTicks; tick += 1) {
      runnerA.advanceToTick(tick);
      runnerB.advanceToTick(tick);
      expect(runnerA.tick, runnerB.tick);
      expect(runnerA.distance, closeTo(runnerB.distance, 0.000001));
    }
    runnerA.advanceToEnd();
    runnerB.advanceToEnd();

    final endedA = runnerA.runEndedEvent;
    final endedB = runnerB.runEndedEvent;
    expect(endedA, isNotNull);
    expect(endedB, isNotNull);
    expect(endedA!.tick, endedB!.tick);
    expect(endedA.distance, closeTo(endedB.distance, 0.000001));
    expect(endedA.goldEarned, endedB.goldEarned);
    expect(endedA.reason, endedB.reason);
    expect(endedA.stats.collectibles, endedB.stats.collectibles);
    expect(endedA.stats.collectibleScore, endedB.stats.collectibleScore);
    expect(endedA.stats.enemyKillCounts, endedB.stats.enemyKillCounts);
  });

  test(
    'ghost playback exposes current snapshot for render-only consumption',
    () {
      final replayBlob = _buildReplayBlob(runSessionId: 'run_ghost_snapshot');
      final runner = GhostPlaybackRunner.fromReplayBlob(replayBlob);

      expect(runner.snapshot.tick, runner.tick);
      runner.advanceToTick(20);
      expect(runner.snapshot.tick, runner.tick);
      expect(runner.snapshot.distance, closeTo(runner.distance, 0.000001));
    },
  );

  test('catch-up retains the immediately preceding tick for interpolation', () {
    final runner = GhostPlaybackRunner.fromReplayBlob(
      _buildReplayBlob(runSessionId: 'run_ghost_catchup'),
    );
    addTearDown(runner.dispose);
    runner.advanceToTick(1);
    expect(runner.previousSnapshot.tick, 0);
    runner.advanceToTick(20);
    expect(runner.previousSnapshot.tick, 19);
    expect(runner.snapshot.tick, 20);
  });

  test('ghost playback exposes drained events read-only and clearable', () {
    final replayBlob = _buildReplayBlob(runSessionId: 'run_ghost_events');
    final runner = GhostPlaybackRunner.fromReplayBlob(replayBlob);

    runner.advanceToEnd();
    final events = runner.drainedEvents;
    expect(events.whereType<RunEndedEvent>(), isNotEmpty);
    final firstEvent = events.first;
    expect(() => events.add(firstEvent), throwsUnsupportedError);

    runner.clearDrainedEvents();
    expect(runner.drainedEvents, isEmpty);
  });
}

ReplayBlobV1 _buildReplayBlob({
  required String runSessionId,
  int totalTicks = 180,
}) {
  final loadout = const EquippedLoadoutDef();
  return ReplayBlobV1.withComputedDigest(
    runSessionId: runSessionId,
    boardId: 'board_competitive_2026_03_field',
    boardKey: BoardKey(
      mode: RunMode.competitive,
      levelId: 'field',
      windowId: '2026-03',
      rulesetVersion: 'rules-v1',
      scoreVersion: 'score-v1',
    ),
    tickHz: 60,
    seed: 1337,
    levelId: 'field',
    playerCharacterId: 'eloise',
    loadoutSnapshot: <String, Object?>{
      'mask': loadout.mask,
      'mainWeaponId': loadout.mainWeaponId.name,
      'offhandWeaponId': loadout.offhandWeaponId.name,
      'spellBookId': loadout.spellBookId.name,
      'projectileSlotSpellId': loadout.projectileSlotSpellId.name,
      'accessoryId': loadout.accessoryId.name,
      'abilityPrimaryId': loadout.abilityPrimaryId,
      'abilitySecondaryId': loadout.abilitySecondaryId,
      'abilityProjectileId': loadout.abilityProjectileId,
      'abilitySpellId': loadout.abilitySpellId,
      'abilityMobilityId': loadout.abilityMobilityId,
      'abilityJumpId': loadout.abilityJumpId,
    },
    totalTicks: totalTicks,
    commandStream: <ReplayCommandFrameV1>[
      ReplayCommandFrameV1(tick: 1, moveAxis: 1),
      ReplayCommandFrameV1(tick: 2, moveAxis: 1),
      ReplayCommandFrameV1(tick: 10, moveAxis: 1),
      ReplayCommandFrameV1(tick: 20, moveAxis: 1),
      ReplayCommandFrameV1(tick: 30, moveAxis: 1),
      ReplayCommandFrameV1(tick: 60, moveAxis: 1, pressedMask: 1 << 0),
      ReplayCommandFrameV1(tick: 90, moveAxis: 1, pressedMask: 1 << 1),
      ReplayCommandFrameV1(tick: 120, moveAxis: 1),
      ReplayCommandFrameV1(tick: 150, moveAxis: 1),
      ReplayCommandFrameV1(tick: 180, moveAxis: 0),
    ].where((frame) => frame.tick <= totalTicks).toList(),
  );
}
