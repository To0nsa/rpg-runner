import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/scoring/run_score_breakdown.dart';
import 'package:runner_core/snapshots/game_state_snapshot.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/game/replay/replay_command_codec.dart';
import 'package:rpg_runner/game/replay/run_recorder.dart';
import 'package:run_protocol/replay_blob.dart';

class _RecordedScenario {
  const _RecordedScenario({
    required this.finalizeResult,
    required this.liveSnapshotDigest,
    required this.liveRunEnded,
    required this.liveScoreBreakdown,
  });

  final RunRecorderFinalizeResult finalizeResult;
  final String liveSnapshotDigest;
  final RunEndedEvent liveRunEnded;
  final RunScoreBreakdown liveScoreBreakdown;
}

Future<_RecordedScenario> _recordDeterministicScenario({
  required Directory dir,
  required String fileStem,
  required String runSessionId,
  required int seed,
  required LevelId levelId,
  required PlayerCharacterId playerCharacterId,
  required Map<String, Object?> loadoutSnapshot,
}) async {
  final level = LevelRegistry.byId(levelId);
  final character = PlayerCharacterRegistry.resolve(playerCharacterId);
  final controller = GameController(
    core: GameCore(
      seed: seed,
      runId: 777,
      levelDefinition: level,
      playerCharacter: character,
    ),
  );

  final recorder = await RunRecorder.create(
    header: RunRecorderHeader(
      runSessionId: runSessionId,
      tickHz: controller.tickHz,
      seed: seed,
      levelId: levelId.name,
      playerCharacterId: playerCharacterId.name,
      loadoutSnapshot: loadoutSnapshot,
    ),
    spoolDirectory: dir,
    fileStem: fileStem,
  );

  controller.addAppliedCommandFrameListener(recorder.appendFrame);

  const totalTicks = 360;
  final dt = 1.0 / controller.tickHz;
  for (var tick = 1; tick <= totalTicks; tick += 1) {
    controller.enqueue(
      MoveAxisCommand(tick: tick, axis: tick <= 180 ? 1.0 : -1.0),
    );
    if (tick == 8) {
      controller.enqueue(const JumpPressedCommand(tick: 8));
    }
    if (tick == 50) {
      controller.enqueue(const DashPressedCommand(tick: 50));
    }
    if (tick == 120) {
      controller.enqueue(const StrikePressedCommand(tick: 120));
    }
    if (tick == 240) {
      controller.enqueue(const ProjectilePressedCommand(tick: 240));
    }
    if (tick == 200) {
      controller.enqueue(const AimDirCommand(tick: 200, x: 0.2, y: -0.7));
    }
    if (tick == 260) {
      controller.enqueue(const ClearAimDirCommand(tick: 260));
    }
    if (tick == 150) {
      controller.enqueue(
        const AbilitySlotHeldCommand(
          tick: 150,
          slot: AbilitySlot.secondary,
          held: true,
        ),
      );
    }
    if (tick == 165) {
      controller.enqueue(
        const AbilitySlotHeldCommand(
          tick: 165,
          slot: AbilitySlot.secondary,
          held: false,
        ),
      );
    }
    controller.advanceFrame(dt);
  }

  controller.giveUp();
  final liveRunEnded = controller.lastRunEndedEvent!;
  final liveScoreBreakdown = buildRunScoreBreakdown(
    tick: liveRunEnded.tick,
    distanceUnits: liveRunEnded.distance,
    collectibles: liveRunEnded.stats.collectibles,
    collectibleScore: liveRunEnded.stats.collectibleScore,
    enemyKillCounts: liveRunEnded.stats.enemyKillCounts,
    tuning: controller.scoreTuning,
    tickHz: controller.tickHz,
  );

  final finalizeResult = await recorder.finalize();
  final liveSnapshotDigest = _snapshotDigest(controller.snapshot);

  await recorder.close();
  controller.shutdown();
  controller.dispose();

  return _RecordedScenario(
    finalizeResult: finalizeResult,
    liveSnapshotDigest: liveSnapshotDigest,
    liveRunEnded: liveRunEnded,
    liveScoreBreakdown: liveScoreBreakdown,
  );
}

String _snapshotDigest(GameStateSnapshot s) {
  final parts = <String>[
    't=${s.tick}',
    'dist=${s.distance.toStringAsFixed(6)}',
    'camx=${s.camera.centerX.toStringAsFixed(6)}',
    'camy=${s.camera.centerY.toStringAsFixed(6)}',
    'level=${s.levelId.name}',
    'theme=${s.themeId}',
    'hp=${s.hud.hp.toStringAsFixed(6)}',
    'mana=${s.hud.mana.toStringAsFixed(6)}',
    'stamina=${s.hud.stamina.toStringAsFixed(6)}',
    'collectibles=${s.hud.collectibles}',
    'collectibleScore=${s.hud.collectibleScore}',
    'solids=${s.staticSolids.length}',
    'groundSurfaces=${s.groundSurfaces.length}',
    'ents=${s.entities.length}',
    'paused=${s.paused}',
    'gameOver=${s.gameOver}',
  ];

  for (final e in s.entities) {
    parts.addAll([
      'id=${e.id}',
      'k=${e.kind.name}',
      'px=${e.pos.x.toStringAsFixed(6)}',
      'py=${e.pos.y.toStringAsFixed(6)}',
      if (e.vel != null) 'vx=${e.vel!.x.toStringAsFixed(6)}',
      if (e.vel != null) 'vy=${e.vel!.y.toStringAsFixed(6)}',
      if (e.size != null) 'sx=${e.size!.x.toStringAsFixed(6)}',
      if (e.size != null) 'sy=${e.size!.y.toStringAsFixed(6)}',
      if (e.projectileId != null) 'pid=${e.projectileId!.name}',
      'rot=${e.rotationRad.toStringAsFixed(6)}',
      'f=${e.facing.name}',
      'a=${e.anim.name}',
      'g=${e.grounded}',
    ]);
  }

  return parts.join('|');
}

RunEndedEvent _runEndedAfterGiveUp(GameCore core) {
  core.giveUp();
  final runEnded = core.drainEvents().whereType<RunEndedEvent>().toList();
  expect(runEnded, isNotEmpty);
  return runEnded.last;
}

void main() {
  test('replay bytes are reproduced from same command stream', () async {
    final dir = await Directory.systemTemp.createTemp('replay-recorder-bytes-');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    final a = await _recordDeterministicScenario(
      dir: dir,
      fileStem: 'a',
      runSessionId: 'session-fixed',
      seed: 42,
      levelId: LevelId.field,
      playerCharacterId: PlayerCharacterId.eloise,
      loadoutSnapshot: const <String, Object?>{
        'mainWeapon': 'plainsteel',
        'projectile': 'eloise.snap_shot',
      },
    );
    final b = await _recordDeterministicScenario(
      dir: dir,
      fileStem: 'b',
      runSessionId: 'session-fixed',
      seed: 42,
      levelId: LevelId.field,
      playerCharacterId: PlayerCharacterId.eloise,
      loadoutSnapshot: const <String, Object?>{
        'mainWeapon': 'plainsteel',
        'projectile': 'eloise.snap_shot',
      },
    );

    final bytesA = await a.finalizeResult.replayBlobFile.readAsBytes();
    final bytesB = await b.finalizeResult.replayBlobFile.readAsBytes();
    expect(bytesA, bytesB);

    expect(
      a.finalizeResult.replayBlob.canonicalSha256,
      b.finalizeResult.replayBlob.canonicalSha256,
    );
    expect(a.finalizeResult.streamDigestSha256, b.finalizeResult.streamDigestSha256);
    expect(
      a.finalizeResult.replayBlob.commandStream.length,
      b.finalizeResult.replayBlob.commandStream.length,
    );
  });

  test('replayed result equals live canonical result', () async {
    final dir = await Directory.systemTemp.createTemp('replay-recorder-replay-');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    final recorded = await _recordDeterministicScenario(
      dir: dir,
      fileStem: 'single',
      runSessionId: 'session-live-vs-replay',
      seed: 99,
      levelId: LevelId.forest,
      playerCharacterId: PlayerCharacterId.eloise,
      loadoutSnapshot: const <String, Object?>{
        'mainWeapon': 'plainsteel',
        'projectile': 'eloise.snap_shot',
      },
    );

    final blob = recorded.finalizeResult.replayBlob;
    final replayCore = GameCore(
      seed: blob.seed,
      levelDefinition: LevelRegistry.byId(
        LevelId.values.firstWhere((id) => id.name == blob.levelId),
      ),
      playerCharacter: PlayerCharacterRegistry.resolve(
        PlayerCharacterId.values.firstWhere(
          (id) => id.name == blob.playerCharacterId,
        ),
      ),
    );

    final frameByTick = <int, ReplayCommandFrameV1>{
      for (final frame in blob.commandStream) frame.tick: frame,
    };
    for (var tick = 1; tick <= blob.totalTicks; tick += 1) {
      final frame = frameByTick[tick];
      final commands = frame == null
          ? const <Command>[]
          : ReplayCommandCodec.commandsFromFrame(frame);
      replayCore.applyCommands(commands);
      replayCore.stepOneTick();
    }

    final replayRunEnded = _runEndedAfterGiveUp(replayCore);
    final replayScoreBreakdown = buildRunScoreBreakdown(
      tick: replayRunEnded.tick,
      distanceUnits: replayRunEnded.distance,
      collectibles: replayRunEnded.stats.collectibles,
      collectibleScore: replayRunEnded.stats.collectibleScore,
      enemyKillCounts: replayRunEnded.stats.enemyKillCounts,
      tuning: replayCore.scoreTuning,
      tickHz: replayCore.tickHz,
    );

    expect(_snapshotDigest(replayCore.buildSnapshot()), recorded.liveSnapshotDigest);
    expect(replayRunEnded.tick, recorded.liveRunEnded.tick);
    expect(
      replayRunEnded.distance,
      closeTo(recorded.liveRunEnded.distance, 1e-9),
    );
    expect(
      replayRunEnded.stats.collectibles,
      recorded.liveRunEnded.stats.collectibles,
    );
    expect(
      replayRunEnded.stats.collectibleScore,
      recorded.liveRunEnded.stats.collectibleScore,
    );
    expect(
      replayRunEnded.stats.enemyKillCounts,
      recorded.liveRunEnded.stats.enemyKillCounts,
    );
    expect(
      replayScoreBreakdown.totalPoints,
      recorded.liveScoreBreakdown.totalPoints,
    );
  });
}
