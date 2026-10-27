/// Tracks new forward progress without letting backtracking reset a stall.
///
/// Observe every completed recording tick. The policy matches the level
/// traversal harness: four new world units within ten simulated seconds.
final class ReplayBenchmarkProgress {
  ReplayBenchmarkProgress({required double initialX, required this.tickHz})
    : _progressX = initialX;

  final int tickHz;
  double _progressX;
  int _progressTick = 0;
  int _maxTicksWithoutProgress = 0;

  /// Accepts the actual player position after [tick], in world units.
  void observe({required int tick, required double playerX}) {
    if (playerX >= _progressX + 4) {
      _progressX = playerX;
      _progressTick = tick;
    }
    final stalledTicks = tick - _progressTick;
    if (stalledTicks > _maxTicksWithoutProgress) {
      _maxTicksWithoutProgress = stalledTicks;
    }
  }

  double get maxSecondsWithoutProgress => _maxTicksWithoutProgress / tickHz;
  bool get passed => _maxTicksWithoutProgress < 10 * tickHz;
}
