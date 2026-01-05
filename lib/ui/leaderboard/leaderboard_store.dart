import 'run_result.dart';

class LeaderboardSnapshot {
  const LeaderboardSnapshot({
    required this.entries,
    required this.current,
  });

  final List<RunResult> entries;
  final RunResult current;
}

abstract class LeaderboardStore {
  Future<LeaderboardSnapshot> addResult(RunResult result);
  Future<List<RunResult>> loadTop10();
}
