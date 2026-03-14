import 'package:flutter_test/flutter_test.dart';
import 'package:run_protocol/board_key.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';

import 'package:rpg_runner/game/replay/ghost_playback_runner.dart';

void main() {
  test('ghost playback is deterministic for the same promoted replay blob', () {
    final replayBlob = _buildReplayBlob(runSessionId: 'run_ghost_1');
    final runnerA = GhostPlaybackRunner.fromReplayBlob(replayBlob);
    final runnerB = GhostPlaybackRunner.fromReplayBlob(replayBlob);

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
}

ReplayBlobV1 _buildReplayBlob({required String runSessionId}) {
  final loadout = const EquippedLoadoutDef();
  return ReplayBlobV1.withComputedDigest(
    runSessionId: runSessionId,
    boardId: 'board_competitive_2026_03_field',
    boardKey: const BoardKey(
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
    totalTicks: 180,
    commandStream: const <ReplayCommandFrameV1>[
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
    ],
  );
}
