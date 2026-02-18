import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:rpg_runner/core/commands/command.dart';
import 'package:rpg_runner/core/game_core.dart';
import '../../support/test_level.dart';
import 'package:rpg_runner/core/tuning/camera_tuning.dart';
import 'package:rpg_runner/core/tuning/core_tuning.dart';
import 'package:rpg_runner/core/tuning/physics_tuning.dart';
import 'package:rpg_runner/core/tuning/track_tuning.dart';

/// Headless benchmark for comparing baseline vs fixed-point pilot Core tick cost.
///
/// Usage:
///   dart run test/integration_test/core-fixed-point/core_fixed_point_benchmark.dart
///   dart run test/integration_test/core-fixed-point/core_fixed_point_benchmark.dart --ticks=6000 --runs=6
///   dart run test/integration_test/core-fixed-point/core_fixed_point_benchmark.dart --strict --max-overhead-pct=10
///   dart run test/integration_test/core-fixed-point/core_fixed_point_benchmark.dart --json-out=test/integration_test/core-fixed-point/perf/latest.json
void main(List<String> args) {
  final config = _BenchmarkConfig.fromArgs(args);

  final passA = _runBenchmarkPair(config: config, firstFixedPoint: false);
  final passB = _runBenchmarkPair(config: config, firstFixedPoint: true);

  final baseline = _mergeStats('baseline', <_BenchmarkStats>[
    passA.baseline,
    passB.baseline,
  ]);
  final pilot = _mergeStats('fixed-point', <_BenchmarkStats>[
    passA.pilot,
    passB.pilot,
  ]);

  _printSummary(config, baseline, pilot);

  final overheadPct = _overheadPercent(baseline.meanUs, pilot.meanUs);
  final passed = overheadPct <= config.maxOverheadPct;
  _writeJsonReport(
    config: config,
    baseline: baseline,
    pilot: pilot,
    overheadPct: overheadPct,
    passed: passed,
  );
  if (config.strict && overheadPct > config.maxOverheadPct) {
    stderr.writeln(
      'FAIL: fixed-point pilot overhead '
      '${overheadPct.toStringAsFixed(2)}% > '
      '${config.maxOverheadPct.toStringAsFixed(2)}%',
    );
    exitCode = 1;
  }
}

class _BenchmarkConfig {
  const _BenchmarkConfig({
    required this.runs,
    required this.warmupTicksPerRun,
    required this.measuredTicksPerRun,
    required this.seedBase,
    required this.subpixelScale,
    required this.trackEnabled,
    required this.autoscrollEnabled,
    required this.strict,
    required this.maxOverheadPct,
    required this.jsonOutPath,
  });

  factory _BenchmarkConfig.fromArgs(List<String> args) {
    int intArg(String key, int fallback) {
      final prefix = '--$key=';
      for (final a in args) {
        if (a.startsWith(prefix)) {
          return int.parse(a.substring(prefix.length));
        }
      }
      return fallback;
    }

    double doubleArg(String key, double fallback) {
      final prefix = '--$key=';
      for (final a in args) {
        if (a.startsWith(prefix)) {
          return double.parse(a.substring(prefix.length));
        }
      }
      return fallback;
    }

    bool boolFlag(String key) => args.contains('--$key');
    String? stringArg(String key) {
      final prefix = '--$key=';
      for (final a in args) {
        if (a.startsWith(prefix)) {
          return a.substring(prefix.length);
        }
      }
      return null;
    }

    return _BenchmarkConfig(
      runs: intArg('runs', 5),
      warmupTicksPerRun: intArg('warmup-ticks', 400),
      measuredTicksPerRun: intArg('ticks', 4000),
      seedBase: intArg('seed-base', 1000),
      subpixelScale: intArg('subpixel-scale', 1024),
      trackEnabled: boolFlag('track'),
      autoscrollEnabled: boolFlag('autoscroll'),
      strict: boolFlag('strict'),
      maxOverheadPct: doubleArg('max-overhead-pct', 10.0),
      jsonOutPath: stringArg('json-out'),
    );
  }

  final int runs;
  final int warmupTicksPerRun;
  final int measuredTicksPerRun;
  final int seedBase;
  final int subpixelScale;
  final bool trackEnabled;
  final bool autoscrollEnabled;
  final bool strict;
  final double maxOverheadPct;
  final String? jsonOutPath;
}

class _BenchmarkStats {
  const _BenchmarkStats({
    required this.name,
    required this.samplesUs,
    required this.resets,
  });

  final String name;
  final List<int> samplesUs;
  final int resets;

  int get count => samplesUs.length;

  double get meanUs {
    if (samplesUs.isEmpty) return 0;
    var sum = 0.0;
    for (final s in samplesUs) {
      sum += s;
    }
    return sum / samplesUs.length;
  }

  double percentile(double p) {
    if (samplesUs.isEmpty) return 0;
    final sorted = List<int>.of(samplesUs)..sort();
    final index = ((sorted.length - 1) * p).round();
    return sorted[index].toDouble();
  }

  double get minUs {
    if (samplesUs.isEmpty) return 0;
    var best = samplesUs.first;
    for (final s in samplesUs.skip(1)) {
      if (s < best) best = s;
    }
    return best.toDouble();
  }

  double get maxUs {
    if (samplesUs.isEmpty) return 0;
    var best = samplesUs.first;
    for (final s in samplesUs.skip(1)) {
      if (s > best) best = s;
    }
    return best.toDouble();
  }

  Map<String, Object> toSummaryJson() {
    return <String, Object>{
      'name': name,
      'n': count,
      'meanUs': meanUs,
      'p95Us': percentile(0.95),
      'p99Us': percentile(0.99),
      'minUs': minUs,
      'maxUs': maxUs,
      'resets': resets,
    };
  }
}

class _BenchmarkPair {
  const _BenchmarkPair({required this.baseline, required this.pilot});

  final _BenchmarkStats baseline;
  final _BenchmarkStats pilot;
}

_BenchmarkPair _runBenchmarkPair({
  required _BenchmarkConfig config,
  required bool firstFixedPoint,
}) {
  if (firstFixedPoint) {
    final pilot = _runBenchmark(config: config, fixedPointEnabled: true);
    final baseline = _runBenchmark(config: config, fixedPointEnabled: false);
    return _BenchmarkPair(baseline: baseline, pilot: pilot);
  }
  final baseline = _runBenchmark(config: config, fixedPointEnabled: false);
  final pilot = _runBenchmark(config: config, fixedPointEnabled: true);
  return _BenchmarkPair(baseline: baseline, pilot: pilot);
}

_BenchmarkStats _runBenchmark({
  required _BenchmarkConfig config,
  required bool fixedPointEnabled,
}) {
  final samples = <int>[];
  var resets = 0;
  final sw = Stopwatch();

  for (var run = 0; run < config.runs; run += 1) {
    var seedOffset = 0;
    GameCore newCore() => GameCore(
      levelDefinition: testFieldLevel(
        tuning: _buildTuning(
          fixedPointEnabled: fixedPointEnabled,
          subpixelScale: config.subpixelScale,
          trackEnabled: config.trackEnabled,
          autoscrollEnabled: config.autoscrollEnabled,
        ),
      ),
      playerCharacter: testPlayerCharacter,
      seed: config.seedBase + run * 1000 + seedOffset,
    );
    var core = newCore();

    var warmupTicks = 0;
    while (warmupTicks < config.warmupTicksPerRun) {
      if (core.gameOver) {
        seedOffset += 1;
        resets += 1;
        core = newCore();
        continue;
      }
      core.applyCommands(_commandsForTick(core.tick + 1));
      core.stepOneTick();
      warmupTicks += 1;
    }

    var measured = 0;
    while (measured < config.measuredTicksPerRun) {
      if (core.gameOver) {
        seedOffset += 1;
        resets += 1;
        core = newCore();
        continue;
      }
      core.applyCommands(_commandsForTick(core.tick + 1));
      sw.start();
      core.stepOneTick();
      sw.stop();
      samples.add(sw.elapsedMicroseconds);
      sw.reset();
      measured += 1;
    }
  }

  return _BenchmarkStats(
    name: fixedPointEnabled ? 'fixed-point' : 'baseline',
    samplesUs: List<int>.unmodifiable(samples),
    resets: resets,
  );
}

_BenchmarkStats _mergeStats(String name, List<_BenchmarkStats> parts) {
  final merged = <int>[];
  var resets = 0;
  for (final p in parts) {
    merged.addAll(p.samplesUs);
    resets += p.resets;
  }
  return _BenchmarkStats(
    name: name,
    samplesUs: List<int>.unmodifiable(merged),
    resets: resets,
  );
}

CoreTuning _buildTuning({
  required bool fixedPointEnabled,
  required int subpixelScale,
  required bool trackEnabled,
  required bool autoscrollEnabled,
}) {
  final camera = autoscrollEnabled
      ? const CameraTuning()
      : const CameraTuning(speedLagMulX: 0.0);
  return CoreTuning(
    camera: camera,
    track: TrackTuning(enabled: trackEnabled),
    physics: PhysicsTuning(
      fixedPointPilot: FixedPointPilotTuning(
        enabled: fixedPointEnabled,
        subpixelScale: subpixelScale,
      ),
    ),
  );
}

List<Command> _commandsForTick(int tick) {
  // Keep the actor active and exercise jump/dash/collision branches regularly.
  const axis = 1.0;
  return <Command>[
    MoveAxisCommand(tick: tick, axis: axis),
    if (tick % 90 == 0) JumpPressedCommand(tick: tick),
    if (tick % 180 == 0) DashPressedCommand(tick: tick),
  ];
}

void _printSummary(
  _BenchmarkConfig config,
  _BenchmarkStats baseline,
  _BenchmarkStats pilot,
) {
  final baselineMean = baseline.meanUs;
  final pilotMean = pilot.meanUs;
  final overheadPct = _overheadPercent(baselineMean, pilotMean);

  stdout.writeln('Core Fixed-Point Pilot Benchmark');
  stdout.writeln(
    'runs=${config.runs} warmupTicks=${config.warmupTicksPerRun} '
    'ticks=${config.measuredTicksPerRun} subpixelScale=${config.subpixelScale}',
  );
  stdout.writeln('order=balanced (baseline->pilot and pilot->baseline)');
  stdout.writeln(
    'trackEnabled=${config.trackEnabled} autoscrollEnabled=${config.autoscrollEnabled}',
  );
  stdout.writeln('');

  void printLine(_BenchmarkStats s) {
    stdout.writeln(
      '${s.name.padRight(12)} '
      'n=${s.count.toString().padLeft(6)} '
      'mean=${s.meanUs.toStringAsFixed(2).padLeft(8)}us '
      'p95=${s.percentile(0.95).toStringAsFixed(2).padLeft(8)}us '
      'p99=${s.percentile(0.99).toStringAsFixed(2).padLeft(8)}us '
      'resets=${s.resets}',
    );
  }

  printLine(baseline);
  printLine(pilot);
  stdout.writeln('');
  stdout.writeln(
    'overhead=${overheadPct.toStringAsFixed(2)}% '
    '(threshold ${config.maxOverheadPct.toStringAsFixed(2)}%)',
  );
}

double _overheadPercent(double baseline, double candidate) {
  if (baseline <= 0) return 0;
  return ((candidate - baseline) / math.max(1e-9, baseline)) * 100.0;
}

void _writeJsonReport({
  required _BenchmarkConfig config,
  required _BenchmarkStats baseline,
  required _BenchmarkStats pilot,
  required double overheadPct,
  required bool passed,
}) {
  final out = config.jsonOutPath;
  if (out == null || out.isEmpty) return;

  final file = File(out);
  file.parent.createSync(recursive: true);
  final report = <String, Object?>{
    'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'host': <String, Object>{
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'dartVersion': Platform.version,
    },
    'config': <String, Object>{
      'runs': config.runs,
      'warmupTicksPerRun': config.warmupTicksPerRun,
      'measuredTicksPerRun': config.measuredTicksPerRun,
      'seedBase': config.seedBase,
      'subpixelScale': config.subpixelScale,
      'trackEnabled': config.trackEnabled,
      'autoscrollEnabled': config.autoscrollEnabled,
      'strict': config.strict,
      'maxOverheadPct': config.maxOverheadPct,
    },
    'baseline': baseline.toSummaryJson(),
    'pilot': pilot.toSummaryJson(),
    'overheadPct': overheadPct,
    'passedThreshold': passed,
  };
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(report)}\n');
  stdout.writeln('jsonReport=$out');
}
