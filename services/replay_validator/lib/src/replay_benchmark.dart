import 'dart:convert';
import 'dart:io';

import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:run_protocol/replay_blob.dart';

import 'replay_simulation.dart';

/// Runs the deployment-shaped local replay throughput benchmark.
///
/// Returns the process exit code so `bin/server.dart benchmark` can share the
/// exact executable compiled for the validator container.
int runReplayBenchmark(List<String> args) {
  final config = _ReplayBenchmarkConfig.fromArgs(args);
  final measurements = <_ReplayBenchmarkMeasurement>[
    for (final levelId in <LevelId>[LevelId.field, LevelId.forest])
      _measureLevel(levelId: levelId, config: config),
  ];
  final gates = <String, bool>{
    for (final measurement in measurements)
      '${measurement.levelId.name}_at_least_2x_real_time':
          measurement.realTimeMultiple >= 2,
    for (final measurement in measurements)
      '${measurement.levelId.name}_36000_ticks_under_300_seconds':
          config.ticks != 36000 || measurement.elapsedSeconds < 300,
    for (final measurement in measurements)
      '${measurement.levelId.name}_deterministic_outcome':
          measurement.deterministicOutcome,
  };
  final passed = gates.values.every((value) => value);
  final gitStatus = _gitOutput(<String>['status', '--porcelain']);
  final report = <String, Object?>{
    'benchmark': 'replay-validator-terrain-stream-v1',
    'revision':
        _gitOutput(<String>['rev-parse', '--short', 'HEAD']) ?? 'unavailable',
    'dirty': gitStatus?.isNotEmpty,
    'os': Platform.operatingSystem,
    'osVersion': Platform.operatingSystemVersion,
    'dartVersion': Platform.version,
    'fixture': 'normal-field-forest-no-enemy-stream',
    'tickHz': config.tickHz,
    'ticksPerLevel': config.ticks,
    'measurements': <String, Object?>{
      for (final measurement in measurements)
        measurement.levelId.name: measurement.toJson(),
    },
    'gates': gates,
    'passed': passed,
    'phase7ContainerVerificationRequired': true,
  };
  final json = const JsonEncoder.withIndent('  ').convert(report);
  stdout.writeln(json);
  return config.strict && !passed ? 1 : 0;
}

_ReplayBenchmarkMeasurement _measureLevel({
  required LevelId levelId,
  required _ReplayBenchmarkConfig config,
}) {
  final recorded = _recordFrames(levelId: levelId, config: config);
  final stopwatch = Stopwatch()..start();
  final core = _buildCore(levelId: levelId, config: config);
  final simulation = runReplaySimulation(
    core: core,
    totalTicks: config.ticks,
    commandStream: recorded.frames,
  );
  stopwatch.stop();

  final elapsedSeconds = stopwatch.elapsedMicroseconds / 1000000;
  final simulatedSeconds = config.ticks / config.tickHz;
  final deterministicOutcome =
      simulation.ticksExecuted == config.ticks &&
      simulation.runEnded == null &&
      !core.gameOver &&
      core.playerPosX == recorded.playerPosX &&
      core.playerPosY == recorded.playerPosY &&
      core.distance == recorded.distance;
  return _ReplayBenchmarkMeasurement(
    levelId: levelId,
    elapsedMicros: stopwatch.elapsedMicroseconds,
    simulatedSeconds: simulatedSeconds,
    realTimeMultiple: elapsedSeconds == 0
        ? double.infinity
        : simulatedSeconds / elapsedSeconds,
    commandFrames: recorded.frames.length,
    finalDistance: core.distance,
    finalGeometryVersion: core
        .buildSnapshot()
        .stagedTerrainRenderSnapshot
        ?.geometryVersion,
    deterministicOutcome: deterministicOutcome,
  );
}

_RecordedReplay _recordFrames({
  required LevelId levelId,
  required _ReplayBenchmarkConfig config,
}) {
  final core = _buildCore(levelId: levelId, config: config);
  final frames = <ReplayCommandFrameV1>[];
  for (var tick = 1; tick <= config.ticks; tick += 1) {
    final xWithinChunk = core.playerPosX % 600;
    final jump =
        levelId == LevelId.forest &&
        core.playerGrounded &&
        xWithinChunk >= 320 &&
        xWithinChunk <= 380;
    frames.add(
      ReplayCommandFrameV1(
        tick: tick,
        moveAxis: 1,
        pressedMask: jump ? ReplayCommandFrameV1.pressedJumpBit : 0,
      ),
    );
    core.applyCommands(<Command>[
      MoveAxisCommand(tick: tick, axis: 1),
      if (jump) JumpPressedCommand(tick: tick),
    ]);
    core.stepOneTick();
    core.drainEvents();
    if (core.gameOver) {
      throw StateError(
        'Benchmark recording ended early for ${levelId.name} at tick $tick.',
      );
    }
  }
  return _RecordedReplay(
    frames: frames,
    playerPosX: core.playerPosX,
    playerPosY: core.playerPosY,
    distance: core.distance,
  );
}

GameCore _buildCore({
  required LevelId levelId,
  required _ReplayBenchmarkConfig config,
}) {
  final registered = LevelRegistry.byId(levelId);
  final baseTuning = registered.tuning;
  final benchmarkTuning = CoreTuning(
    physics: baseTuning.physics,
    unocoDemon: baseTuning.unocoDemon,
    groundEnemy: baseTuning.groundEnemy,
    navigation: baseTuning.navigation,
    spatialGrid: baseTuning.spatialGrid,
    camera: const CameraTuning(speedLagMulX: 0),
    track: baseTuning.track,
    collectible: baseTuning.collectible,
    restorationItem: baseTuning.restorationItem,
    score: baseTuning.score,
  );
  return GameCore(
    seed: config.seed,
    runId: 1,
    tickHz: config.tickHz,
    levelDefinition: registered.copyWith(
      tuning: benchmarkTuning,
      noEnemyChunks: 1 << 30,
    ),
    playerCharacter: PlayerCharacterRegistry.eloise,
  );
}

String? _gitOutput(List<String> arguments) {
  try {
    final result = Process.runSync('git', arguments);
    if (result.exitCode != 0) return null;
    return (result.stdout as String).trim();
  } on ProcessException {
    return null;
  }
}

final class _ReplayBenchmarkConfig {
  const _ReplayBenchmarkConfig({
    required this.ticks,
    required this.tickHz,
    required this.seed,
    required this.strict,
  });

  factory _ReplayBenchmarkConfig.fromArgs(List<String> args) {
    String value(String name, String fallback) {
      final prefix = '--$name=';
      for (final argument in args) {
        if (argument.startsWith(prefix)) {
          return argument.substring(prefix.length);
        }
      }
      return fallback;
    }

    final ticks = int.parse(value('ticks', '36000'));
    final tickHz = int.parse(value('tick-hz', '60'));
    if (ticks <= 0 || tickHz <= 0) {
      throw ArgumentError('ticks and tick-hz must be positive.');
    }
    return _ReplayBenchmarkConfig(
      ticks: ticks,
      tickHz: tickHz,
      seed: int.parse(value('seed', '4401')),
      strict: args.contains('--strict'),
    );
  }

  final int ticks;
  final int tickHz;
  final int seed;
  final bool strict;
}

final class _RecordedReplay {
  const _RecordedReplay({
    required this.frames,
    required this.playerPosX,
    required this.playerPosY,
    required this.distance,
  });

  final List<ReplayCommandFrameV1> frames;
  final double playerPosX;
  final double playerPosY;
  final double distance;
}

final class _ReplayBenchmarkMeasurement {
  const _ReplayBenchmarkMeasurement({
    required this.levelId,
    required this.elapsedMicros,
    required this.simulatedSeconds,
    required this.realTimeMultiple,
    required this.commandFrames,
    required this.finalDistance,
    required this.finalGeometryVersion,
    required this.deterministicOutcome,
  });

  final LevelId levelId;
  final int elapsedMicros;
  final double simulatedSeconds;
  final double realTimeMultiple;
  final int commandFrames;
  final double finalDistance;
  final int? finalGeometryVersion;
  final bool deterministicOutcome;

  double get elapsedSeconds => elapsedMicros / 1000000;

  Map<String, Object?> toJson() => <String, Object?>{
    'elapsedMicros': elapsedMicros,
    'elapsedSeconds': elapsedSeconds,
    'simulatedSeconds': simulatedSeconds,
    'realTimeMultiple': realTimeMultiple,
    'commandFrames': commandFrames,
    'finalDistance': finalDistance,
    'finalGeometryVersion': finalGeometryVersion,
    'deterministicOutcome': deterministicOutcome,
  };
}
