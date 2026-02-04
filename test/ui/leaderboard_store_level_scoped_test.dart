import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:rpg_runner/core/events/game_event.dart';
import 'package:rpg_runner/core/levels/level_id.dart';
import 'package:rpg_runner/ui/leaderboard/run_result.dart';
import 'package:rpg_runner/ui/leaderboard/shared_prefs_leaderboard_store.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';

RunResult _result({required int score}) {
  return RunResult(
    runId: 0,
    endedAtMs: 1,
    endedReason: RunEndReason.gaveUp,
    score: score,
    distanceMeters: 0,
    durationSeconds: 0,
    tick: 1,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'SharedPrefsLeaderboardStore keeps separate top10 per level and run type',
    () async {
      final store = SharedPrefsLeaderboardStore();

      await store.addResult(
        levelId: LevelId.forest,
        runType: RunType.practice,
        result: _result(score: 100),
      );
      await store.addResult(
        levelId: LevelId.field,
        runType: RunType.practice,
        result: _result(score: 200),
      );
      await store.addResult(
        levelId: LevelId.forest,
        runType: RunType.practice,
        result: _result(score: 300),
      );
      await store.addResult(
        levelId: LevelId.forest,
        runType: RunType.competitive,
        result: _result(score: 999),
      );

      final forest = await store.loadTop10(
        levelId: LevelId.forest,
        runType: RunType.practice,
      );
      final field = await store.loadTop10(
        levelId: LevelId.field,
        runType: RunType.practice,
      );
      final forestCompetitive = await store.loadTop10(
        levelId: LevelId.forest,
        runType: RunType.competitive,
      );

      expect(forest.map((e) => e.score).toList(), [300, 100]);
      expect(field.map((e) => e.score).toList(), [200]);
      expect(forestCompetitive.map((e) => e.score).toList(), [999]);
    },
  );
}
