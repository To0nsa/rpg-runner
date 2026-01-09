import '../../core/levels/level_id.dart';

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
  Future<LeaderboardSnapshot> addResult({
    required LevelId levelId,
    required RunResult result,
  });

  Future<List<RunResult>> loadTop10({required LevelId levelId});
}
