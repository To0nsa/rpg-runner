import 'package:replay_validator/src/replay_benchmark_input.dart';
import 'package:replay_validator/src/replay_benchmark_fixture.dart';
import 'package:replay_validator/src/replay_benchmark_progress.dart';
import 'package:replay_validator/src/replay_simulation.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:test/test.dart';

void main() {
  test('old Forest jump window is rejected as a stalled recording', () {
    final core = buildReplayBenchmarkCore(
      levelId: LevelId.forest,
      seed: 4401,
      tickHz: 60,
    );
    final progress = ReplayBenchmarkProgress(
      initialX: core.playerPosX,
      tickHz: 60,
    );
    for (var tick = 1; tick <= 1200; tick++) {
      final x = core.playerPosX % 600;
      _step(
        core,
        ReplayCommandFrameV1(
          tick: tick,
          moveAxis: 1,
          pressedMask: core.playerGrounded && x >= 320 && x <= 380
              ? ReplayCommandFrameV1.pressedJumpBit
              : 0,
        ),
      );
      progress.observe(tick: tick, playerX: core.playerPosX);
    }
    expect(core.gameOver, isFalse);
    expect(progress.passed, isFalse);
    expect(core.distance, lessThan(400));
  });

  test(
    'Forest traverses 36000 ticks including slow late-loop pit takeoffs',
    () {
      final core = buildReplayBenchmarkCore(
        levelId: LevelId.forest,
        seed: 4401,
        tickHz: 60,
      );
      final input = ReplayBenchmarkInput(LevelId.forest);
      final progress = ReplayBenchmarkProgress(
        initialX: core.playerPosX,
        tickHz: 60,
      );
      for (var tick = 1; tick <= 36000; tick++) {
        _step(core, input.nextFrame(core, tick: tick));
        progress.observe(tick: tick, playerX: core.playerPosX);
        expect(core.gameOver, isFalse, reason: 'tick $tick');
        expect(progress.passed, isTrue, reason: 'tick $tick');
      }
      expect(core.distance, greaterThan(96000));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  for (final tickHz in [30, 60, 120]) {
    test('Field jumps across the seed-4401 opening pit at $tickHz Hz', () {
      final core = _fieldCore(tickHz: tickHz);
      final input = ReplayBenchmarkInput(LevelId.field);
      var jumpedBeforePit = false;
      var landedAcrossPit = false;
      for (var tick = 1; tick <= tickHz * 5; tick++) {
        final frame = input.nextFrame(core, tick: tick);
        if (_jumpPressed(frame) && core.playerPosX < 823) {
          jumpedBeforePit = true;
        }
        _step(core, frame);
        expect(core.gameOver, isFalse, reason: 'tick $tick');
        landedAcrossPit |= core.playerGrounded && core.playerPosX > 917;
      }
      expect(jumpedBeforePit, isTrue);
      expect(landedAcrossPit, isTrue);
    });
  }

  test('Field replays pits, water and stepping stones without stalling', () {
    final direct = _fieldCore();
    final input = ReplayBenchmarkInput(LevelId.field);
    final frames = <ReplayCommandFrameV1>[];
    // Include the later easy_008 -> easy_009 approach: waiting for coyote time
    // here puts the player below the stepping stone's top face.
    const ticks = 9000;
    for (var tick = 1; tick <= ticks; tick++) {
      final frame = input.nextFrame(direct, tick: tick);
      frames.add(frame);
      _step(direct, frame);
      expect(direct.gameOver, isFalse, reason: 'tick $tick');
    }
    expect(direct.distance, greaterThan(24000));

    final replayed = _fieldCore();
    final result = runReplaySimulation(
      core: replayed,
      totalTicks: ticks,
      commandStream: frames,
    );
    expect(result.ticksExecuted, ticks);
    expect(result.runEnded, isNull);
    expect(replayed.gameOver, isFalse);
    expect(replayed.playerPosX, direct.playerPosX);
    expect(replayed.playerPosY, direct.playerPosY);
    expect(replayed.distance, direct.distance);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

bool _jumpPressed(ReplayCommandFrameV1 frame) =>
    frame.pressedMask & ReplayCommandFrameV1.pressedJumpBit != 0;

void _step(GameCore core, ReplayCommandFrameV1 frame) {
  core.applyCommands([
    MoveAxisCommand(tick: frame.tick, axis: frame.moveAxis!),
    if (_jumpPressed(frame)) JumpPressedCommand(tick: frame.tick),
  ]);
  core.stepOneTick();
  core.drainEvents();
}

GameCore _fieldCore({int tickHz = 60}) => buildReplayBenchmarkCore(
  levelId: LevelId.field,
  seed: 4401,
  tickHz: tickHz,
);
