/// On-device Core simulation benchmark for the fixed-point pilot path.
///
/// This integration test is designed to run under `flutter drive --profile`
/// and compare per-tick Core CPU cost between:
/// - baseline floating-point path
/// - fixed-point pilot path
///
/// Output contract:
/// - `BENCHMARK_SUMMARY::...` one line per scenario for quick log scanning
/// - `BENCHMARK_JSON::...` full machine-readable payload for artifact capture
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rpg_runner/core/commands/command.dart';
import 'package:rpg_runner/core/game_core.dart';
import '../../support/test_level.dart';
import 'package:rpg_runner/core/tuning/camera_tuning.dart';
import 'package:rpg_runner/core/tuning/core_tuning.dart';
import 'package:rpg_runner/core/tuning/physics_tuning.dart';
import 'package:rpg_runner/core/tuning/track_tuning.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('core fixed-point benchmark on device (profile-ready)', (
    tester,
  ) async {
    const noTrackConfig = _BenchmarkConfig(
      runs: 2,
      warmupTicksPerRun: 150,
      measuredTicksPerRun: 2000,
      seedBase: 7000,
      subpixelScale: 1024,
      trackEnabled: false,
      autoscrollEnabled: false,
      maxOverheadPct: 10.0,
    );
    const trackConfig = _BenchmarkConfig(
      runs: 2,
      warmupTicksPerRun: 150,
      measuredTicksPerRun: 2000,
      seedBase: 9000,
      subpixelScale: 1024,
      trackEnabled: true,
      autoscrollEnabled: true,
      maxOverheadPct: 10.0,
    );

    final noTrackResult = _runBenchmarkSuite(noTrackConfig);
    final trackResult = _runBenchmarkSuite(trackConfig);

    final report = <String, Object?>{
      'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'scenarioNoTrack': noTrackResult.toJson(),
      'scenarioTrackAutoscroll': trackResult.toJson(),
    };

    binding.reportData = report;
    // Printed as a single line for easy extraction from `flutter drive` logs.
    // ignore: avoid_print
    print('BENCHMARK_JSON::${jsonEncode(report)}');

    expect(
      noTrackResult.overheadPct,
      lessThanOrEqualTo(noTrackConfig.maxOverheadPct),
      reason:
          'No-track benchmark overhead must stay under '
          '${noTrackConfig.maxOverheadPct.toStringAsFixed(2)}%',
    );
  }, tags: <String>['integration']);
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
    required this.maxOverheadPct,
  });

  /// Number of independent runs per mode.
  final int runs;

  /// Warmup ticks per run (excluded from metrics).
  final int warmupTicksPerRun;

  /// Measured ticks per run (included in metrics).
  final int measuredTicksPerRun;

  /// Base seed for deterministic run generation.
  final int seedBase;

  /// Quantization scale used by fixed-point pilot mode.
  final int subpixelScale;

  /// Whether procedural track streaming/culling is enabled.
  final bool trackEnabled;

  /// Whether camera baseline autoscroll behavior is enabled.
  final bool autoscrollEnabled;

  /// Maximum allowed pilot overhead percent for strict-gated scenarios.
  final double maxOverheadPct;
}

/// Aggregated per-tick timing stats for one benchmark mode.
class _BenchmarkStats {
  const _BenchmarkStats({
    required this.name,
    required this.samplesUs,
    required this.resets,
  });

  final String name;

  /// Tick durations in microseconds.
  final List<int> samplesUs;

  /// Number of run resets due to `gameOver` while collecting samples.
  final int resets;

  int get count => samplesUs.length;

  double get meanUs {
    if (samplesUs.isEmpty) return 0.0;
    var sum = 0.0;
    for (final v in samplesUs) {
      sum += v;
    }
    return sum / samplesUs.length;
  }

  /// Returns percentile value from sorted sample timings.
  ///
  /// [p] must be in `[0.0, 1.0]` (e.g. `0.95`, `0.99`).
  double percentile(double p) {
    if (samplesUs.isEmpty) return 0.0;
    final sorted = List<int>.of(samplesUs)..sort();
    final index = ((sorted.length - 1) * p).round();
    return sorted[index].toDouble();
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'name': name,
      'n': count,
      'meanUs': meanUs,
      'p95Us': percentile(0.95),
      'p99Us': percentile(0.99),
      'resets': resets,
    };
  }
}

/// Pair of baseline/pilot stats for one balanced pass.
class _BenchmarkPair {
  const _BenchmarkPair({required this.baseline, required this.pilot});

  final _BenchmarkStats baseline;
  final _BenchmarkStats pilot;
}

/// Final result payload for one scenario configuration.
class _BenchmarkSuiteResult {
  const _BenchmarkSuiteResult({
    required this.config,
    required this.baseline,
    required this.pilot,
    required this.overheadPct,
  });

  final _BenchmarkConfig config;
  final _BenchmarkStats baseline;
  final _BenchmarkStats pilot;
  final double overheadPct;

  Map<String, Object> toJson() {
    return <String, Object>{
      'config': <String, Object>{
        'runs': config.runs,
        'warmupTicksPerRun': config.warmupTicksPerRun,
        'measuredTicksPerRun': config.measuredTicksPerRun,
        'seedBase': config.seedBase,
        'subpixelScale': config.subpixelScale,
        'trackEnabled': config.trackEnabled,
        'autoscrollEnabled': config.autoscrollEnabled,
        'maxOverheadPct': config.maxOverheadPct,
      },
      'baseline': baseline.toJson(),
      'pilot': pilot.toJson(),
      'overheadPct': overheadPct,
    };
  }
}

/// Executes a full scenario with balanced mode ordering.
///
/// Two passes are run:
/// - baseline then pilot
/// - pilot then baseline
///
/// This reduces warmup/order bias in the final aggregate.
_BenchmarkSuiteResult _runBenchmarkSuite(_BenchmarkConfig config) {
  final passA = _runBenchmarkPair(config: config, firstFixedPoint: false);
  final passB = _runBenchmarkPair(config: config, firstFixedPoint: true);
  final baseline = _mergeStats(<_BenchmarkStats>[
    passA.baseline,
    passB.baseline,
  ]);
  final pilot = _mergeStats(<_BenchmarkStats>[passA.pilot, passB.pilot]);
  final overheadPct = _overheadPercent(baseline.meanUs, pilot.meanUs);

  // Human-readable per-scenario line in drive logs.
  // ignore: avoid_print
  print(
    'BENCHMARK_SUMMARY::track=${config.trackEnabled} '
    'autoscroll=${config.autoscrollEnabled} '
    'baselineMeanUs=${baseline.meanUs.toStringAsFixed(2)} '
    'pilotMeanUs=${pilot.meanUs.toStringAsFixed(2)} '
    'overheadPct=${overheadPct.toStringAsFixed(2)}',
  );

  return _BenchmarkSuiteResult(
    config: config,
    baseline: baseline,
    pilot: pilot,
    overheadPct: overheadPct,
  );
}

/// Runs one pass of baseline/pilot in a specific order.
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

/// Collects per-tick timings for one mode (baseline or pilot).
///
/// Determinism notes:
/// - same command script is used each tick
/// - each run gets a deterministic seed series
/// - when a run ends (`gameOver`), the seed is incremented and run continues
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

/// Merges multiple stat blocks into one aggregate sample set.
_BenchmarkStats _mergeStats(List<_BenchmarkStats> parts) {
  final merged = <int>[];
  var resets = 0;
  for (final p in parts) {
    merged.addAll(p.samplesUs);
    resets += p.resets;
  }
  return _BenchmarkStats(
    name: parts.isNotEmpty ? parts.first.name : 'unknown',
    samplesUs: List<int>.unmodifiable(merged),
    resets: resets,
  );
}

/// Builds scenario tuning with explicit pilot/track/autoscroll switches.
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

/// Deterministic synthetic input stream used for benchmark load generation.
///
/// This approximates continuous movement with periodic jump/dash events.
List<Command> _commandsForTick(int tick) {
  const axis = 1.0;
  return <Command>[
    MoveAxisCommand(tick: tick, axis: axis),
    if (tick % 90 == 0) JumpPressedCommand(tick: tick),
    if (tick % 180 == 0) DashPressedCommand(tick: tick),
  ];
}

/// Computes pilot overhead percentage relative to baseline mean.
///
/// Positive means pilot is slower; negative means pilot is faster.
double _overheadPercent(double baseline, double pilot) {
  if (baseline <= 0.0) return 0.0;
  return ((pilot - baseline) / math.max(1e-9, baseline)) * 100.0;
}
