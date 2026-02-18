import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/commands/command.dart';
import 'package:rpg_runner/core/events/game_event.dart';
import 'package:rpg_runner/core/game_core.dart';
import '../support/test_level.dart';
import 'package:rpg_runner/core/tuning/core_tuning.dart';
import 'package:rpg_runner/core/tuning/physics_tuning.dart';
import 'package:rpg_runner/core/tuning/track_tuning.dart';

import '../test_tunings.dart';

String _digest(GameCore core) {
  final s = core.buildSnapshot();
  final player = s.playerEntity;
  return <String>[
    't=${s.tick}',
    'dist=${s.distance.toStringAsFixed(6)}',
    'camx=${s.camera.centerX.toStringAsFixed(6)}',
    'camy=${s.camera.centerY.toStringAsFixed(6)}',
    'px=${player?.pos.x.toStringAsFixed(6)}',
    'py=${player?.pos.y.toStringAsFixed(6)}',
    'vx=${player?.vel?.x.toStringAsFixed(6)}',
    'vy=${player?.vel?.y.toStringAsFixed(6)}',
    'grounded=${player?.grounded}',
    'gameOver=${s.gameOver}',
  ].join('|');
}

CoreTuning _pilotTuning({required bool enabled, int subpixelScale = 1024}) {
  return CoreTuning(
    camera: noAutoscrollCameraTuning,
    track: const TrackTuning(enabled: false),
    physics: PhysicsTuning(
      fixedPointPilot: FixedPointPilotTuning(
        enabled: enabled,
        subpixelScale: subpixelScale,
      ),
    ),
  );
}

List<Command> _commandsForTick(int tick) {
  final axis = tick <= 90 ? 1.0 : -1.0;
  return <Command>[
    MoveAxisCommand(tick: tick, axis: axis),
    if (tick == 10 || tick == 100) JumpPressedCommand(tick: tick),
    if (tick == 45 || tick == 130) DashPressedCommand(tick: tick),
  ];
}

CoreTuning _fullRunPilotTuning({
  required bool enabled,
  int subpixelScale = 1024,
}) {
  return CoreTuning(
    physics: PhysicsTuning(
      fixedPointPilot: FixedPointPilotTuning(
        enabled: enabled,
        subpixelScale: subpixelScale,
      ),
    ),
  );
}

class _RunOutcome {
  const _RunOutcome({
    required this.gameOver,
    required this.reason,
    required this.tick,
    required this.distance,
  });

  final bool gameOver;
  final RunEndReason? reason;
  final int tick;
  final double distance;
}

_RunOutcome _runScenario(GameCore core, {required int maxTicks}) {
  RunEndReason? reason;
  for (var t = 1; t <= maxTicks; t += 1) {
    core.applyCommands(<Command>[
      MoveAxisCommand(tick: t, axis: 1.0),
      if (t % 75 == 0) JumpPressedCommand(tick: t),
      if (t % 140 == 0) DashPressedCommand(tick: t),
    ]);
    core.stepOneTick();
    for (final e in core.drainEvents()) {
      if (e is RunEndedEvent && reason == null) {
        reason = e.reason;
      }
    }
    if (core.gameOver) break;
  }

  return _RunOutcome(
    gameOver: core.gameOver,
    reason: reason,
    tick: core.tick,
    distance: core.distance,
  );
}

void main() {
  test('fixed-point pilot is deterministic for same seed + commands', () {
    for (final seed in <int>[7, 42, 1337]) {
      final a = GameCore(
        levelDefinition: testFieldLevel(tuning: _pilotTuning(enabled: true)),
        playerCharacter: testPlayerCharacter,
        seed: seed,
      );
      final b = GameCore(
        levelDefinition: testFieldLevel(tuning: _pilotTuning(enabled: true)),
        playerCharacter: testPlayerCharacter,
        seed: seed,
      );

      const ticks = 180;
      for (var t = 1; t <= ticks; t += 1) {
        final cmds = _commandsForTick(t);
        a.applyCommands(cmds);
        b.applyCommands(cmds);
        a.stepOneTick();
        b.stepOneTick();
        expect(_digest(a), _digest(b));
      }
    }
  });

  test('fixed-point pilot trajectory stays close to floating baseline', () {
    final baseline = GameCore(
      levelDefinition: testFieldLevel(tuning: _pilotTuning(enabled: false)),
      playerCharacter: testPlayerCharacter,
      seed: 7,
    );
    final pilot = GameCore(
      levelDefinition: testFieldLevel(
        tuning: _pilotTuning(enabled: true, subpixelScale: 2048),
      ),
      playerCharacter: testPlayerCharacter,
      seed: 7,
    );

    const ticks = 180;
    for (var t = 1; t <= ticks; t += 1) {
      final cmds = _commandsForTick(t);
      baseline.applyCommands(cmds);
      pilot.applyCommands(cmds);
      baseline.stepOneTick();
      pilot.stepOneTick();
    }

    expect((pilot.playerPosX - baseline.playerPosX).abs(), lessThan(8.0));
    expect((pilot.playerPosY - baseline.playerPosY).abs(), lessThan(8.0));
    expect((pilot.playerVelX - baseline.playerVelX).abs(), lessThan(16.0));
    expect((pilot.playerVelY - baseline.playerVelY).abs(), lessThan(16.0));
    expect((pilot.distance - baseline.distance).abs(), lessThan(8.0));
    expect(pilot.gameOver, baseline.gameOver);
  });

  test('fixed-point pilot preserves run-end parity across seeds', () {
    const maxTicks = 600;
    for (final seed in <int>[3, 17, 42, 99]) {
      final baseline = GameCore(
        levelDefinition: testFieldLevel(
          tuning: _fullRunPilotTuning(enabled: false),
        ),
        playerCharacter: testPlayerCharacter,
        seed: seed,
      );
      final pilot = GameCore(
        levelDefinition: testFieldLevel(
          tuning: _fullRunPilotTuning(enabled: true, subpixelScale: 2048),
        ),
        playerCharacter: testPlayerCharacter,
        seed: seed,
      );

      final baselineOutcome = _runScenario(baseline, maxTicks: maxTicks);
      final pilotOutcome = _runScenario(pilot, maxTicks: maxTicks);

      expect(pilotOutcome.gameOver, baselineOutcome.gameOver);
      expect(pilotOutcome.reason, baselineOutcome.reason);
      if (baselineOutcome.gameOver) {
        expect(
          (pilotOutcome.tick - baselineOutcome.tick).abs(),
          lessThanOrEqualTo(30),
        );
      } else {
        expect(
          (pilotOutcome.distance - baselineOutcome.distance).abs(),
          lessThan(40.0),
        );
      }
    }
  });
}
