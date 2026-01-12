import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:rpg_runner/core/events/game_event.dart';
import 'package:rpg_runner/core/levels/level_id.dart';
import 'package:rpg_runner/ui/leaderboard/run_result.dart';
import 'package:rpg_runner/ui/leaderboard/shared_prefs_leaderboard_store.dart';

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

  test('SharedPrefsLeaderboardStore keeps separate top10 per level', () async {
    final store = SharedPrefsLeaderboardStore();

    await store.addResult(levelId: LevelId.forest, result: _result(score: 100));
    await store.addResult(levelId: LevelId.field, result: _result(score: 200));
    await store.addResult(levelId: LevelId.forest, result: _result(score: 300));

    final forest = await store.loadTop10(levelId: LevelId.forest);
    final field = await store.loadTop10(levelId: LevelId.field);

    expect(forest.map((e) => e.score).toList(), [300, 100]);
    expect(field.map((e) => e.score).toList(), [200]);
  });
}

