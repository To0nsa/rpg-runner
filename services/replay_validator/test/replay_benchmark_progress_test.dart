import 'package:replay_validator/src/replay_benchmark_progress.dart';
import 'package:test/test.dart';

void main() {
  for (final tickHz in [30, 60, 120]) {
    test('stationary recording fails at ten seconds at $tickHz Hz', () {
      final progress = ReplayBenchmarkProgress(initialX: 300, tickHz: tickHz);
      progress.observe(tick: 10 * tickHz - 1, playerX: 300);
      expect(progress.passed, isTrue);
      progress.observe(tick: 10 * tickHz, playerX: 300);
      expect(progress.passed, isFalse);
      expect(progress.maxSecondsWithoutProgress, 10);
    });
  }

  test('backtracking and sub-threshold jitter cannot conceal a stall', () {
    final progress = ReplayBenchmarkProgress(initialX: 300, tickHz: 60);
    for (var tick = 1; tick <= 600; tick++) {
      progress.observe(tick: tick, playerX: tick.isEven ? 303.9 : 280);
    }
    expect(progress.passed, isFalse);
    progress.observe(tick: 601, playerX: 500);
    expect(
      progress.passed,
      isFalse,
      reason: 'later progress cannot erase a stall',
    );
  });

  test('four new units reset the budget, including on its last tick', () {
    final progress = ReplayBenchmarkProgress(initialX: 300, tickHz: 60);
    progress.observe(tick: 599, playerX: 303);
    progress.observe(tick: 600, playerX: 304);
    progress.observe(tick: 1199, playerX: 304);
    expect(progress.passed, isTrue);
    progress.observe(tick: 1200, playerX: 304);
    expect(progress.passed, isFalse);
  });
}
