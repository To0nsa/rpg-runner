// Run explicitly: flutter test --no-pub tools/benchmark_ghost_playback.dart
// Add --dart-define=GHOST_BENCHMARK_OUTPUT=<path> to retain the JSON evidence.
// Benchmark instrumentation intentionally reads playback diagnostics.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/replay/buffered_ghost_playback.dart';
import 'package:rpg_runner/game/replay/ghost_playback_runner.dart';

import '../test/game/replay/support/ghost_replay_fixture.dart';

void main() {
  test('record local ghost simulation and UI consumption costs', () async {
    final results = <Map<String, Object?>>[];
    for (final level in ['field', 'forest']) {
      for (var round = 0; round < 4; round++) {
        final blob = ghostReplayFixture(levelId: level);
        final reference = GhostPlaybackRunner.fromReplayBlob(blob);
        await reference.prepareTerrainAhead();
        final buffered = BufferedGhostPlayback(replayBlob: blob);
        final preparation = Stopwatch()..start();
        await buffered.prepare();
        preparation.stop();
        expect(buffered.error, isNull);
        final synchronousUs = <int>[];
        final bufferedUs = <int>[];
        final watch = Stopwatch();
        var waits = 0;
        for (var tick = 1; tick <= blob.totalTicks; tick++) {
          // Measure consumption when ready; report waits separately instead of
          // interpreting this maximum-speed loop as a device FPS workload.
          while (buffered.debugBufferedThroughTick < tick &&
              buffered.debugRefilling) {
            waits++;
            await Future<void>.delayed(const Duration(milliseconds: 1));
          }
          watch
            ..reset()
            ..start();
          reference.advanceToTick(tick);
          watch.stop();
          synchronousUs.add(watch.elapsedMicroseconds);
          watch
            ..reset()
            ..start();
          buffered.advanceToTick(tick);
          watch.stop();
          bufferedUs.add(watch.elapsedMicroseconds);
          expect(buffered.error, isNull);
          expect(buffered.frame!.current.tick, reference.tick);
          if (reference.isComplete) break;
        }
        if (round > 0) {
          results.add({
            'level': level,
            'round': round,
            'ticks': synchronousUs.length,
            'nativeStartupAndPrefillMs': preparation.elapsedMicroseconds / 1000,
            'synchronousUiStepUs': _stats(synchronousUs),
            'bufferedUiConsumptionUs': _stats(bufferedUs),
            'producerWaitIterationsAtMaximumConsumptionSpeed': waits,
          });
        }
        reference.dispose();
        buffered.dispose();
      }
    }
    final report = {
      'runtime': Platform.version,
      'operatingSystem': Platform.operatingSystem,
      'mode': 'Flutter test / debug, headless native VM',
      'fixture':
          'seed 1337, Eloise, 900-tick command stream, actual terminal tick',
      'terrainPreparation': 'Both synchronous and buffered runners prepare terrain before measurement.',
      'warmupRoundsPerLevel': 1,
      'measuredRoundsPerLevel': 3,
      'limitations': [
        'Measures ghost stepping versus ready-frame consumption on the UI isolate.',
        'Includes request dispatch in consumption; worker CPU and transfer run concurrently.',
        'Maximum-speed consumer waits are not real-time underruns.',
        'No live game, raster/GPU workload, mobile device, or end-to-end FPS measurement.',
      ],
      'results': results,
    };
    final json = const JsonEncoder.withIndent('  ').convert(report);
    stdout.writeln(json);
    const output = String.fromEnvironment('GHOST_BENCHMARK_OUTPUT');
    if (output.isNotEmpty) await File(output).writeAsString('$json\n');
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Map<String, num> _stats(List<int> values) {
  final sorted = [...values]..sort();
  return {
    'mean': values.reduce((a, b) => a + b) / values.length,
    'p50': sorted[sorted.length ~/ 2],
    'p95': sorted[((sorted.length - 1) * 0.95).floor()],
    'max': sorted.last,
  };
}
