import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkscape_runner/core/events/game_event.dart';
import 'package:walkscape_runner/core/tuning/v0_score_tuning.dart';
import 'package:walkscape_runner/ui/hud/gameover/game_over_overlay.dart';
import 'package:walkscape_runner/ui/hud/gameover/leaderboard_panel.dart';
import 'package:walkscape_runner/ui/leaderboard/leaderboard_store.dart';
import 'package:walkscape_runner/ui/leaderboard/run_result.dart';

RunEndedEvent _buildEvent() {
  return const RunEndedEvent(
    tick: 120,
    distance: 500,
    reason: RunEndReason.gaveUp,
    stats: RunEndStats(
      collectibles: 2,
      collectibleScore: 100,
      enemyKillCounts: [1, 0],
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'Scoreboard hides current run score until feed complete', (tester) async {
    final store = _FakeLeaderboardStore();

    await tester.pumpWidget(
      MaterialApp(
        home: GameOverOverlay(
          visible: true,
          onRestart: () {},
          onExit: null,
          showExitButton: false,
          runEndedEvent: _buildEvent(),
          scoreTuning: const V0ScoreTuning(
            timeScorePerSecond: 10,
            distanceScorePerMeter: 5,
            groundEnemyKillScore: 100,
            flyingEnemyKillScore: 150,
          ),
          tickHz: 60,
          leaderboardStore: store,
        ),
      ),
    );
    await tester.pump();

    final panel = find.byType(LeaderboardPanel);
    expect(panel, findsOneWidget);

    expect(
      find.descendant(of: panel, matching: find.text('295')),
      findsNothing,
    );
    expect(
      find.descendant(of: panel, matching: find.text('—')),
      findsWidgets,
    );

    await tester.tap(find.text('Collect score'));
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(
      find.descendant(of: panel, matching: find.text('295')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.text('—')),
      findsNothing,
    );
  });

  testWidgets('GameOverOverlay feeds all rows into score', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameOverOverlay(
          visible: true,
          onRestart: () {},
          onExit: null,
          showExitButton: false,
          runEndedEvent: _buildEvent(),
          scoreTuning: const V0ScoreTuning(
            timeScorePerSecond: 10,
            distanceScorePerMeter: 5,
            groundEnemyKillScore: 100,
            flyingEnemyKillScore: 150,
          ),
          tickHz: 60,
        ),
      ),
    );

    expect(find.textContaining('Score:'), findsNothing);
    expect(find.text('Distance: 5m -> 25'), findsOneWidget);
    expect(find.text('Time: 00:02 -> 20'), findsOneWidget);
    expect(find.text('Collectibles: 2 -> 100'), findsOneWidget);
    expect(find.text('Flying enemy x1 -> 150'), findsOneWidget);
    expect(find.text('Collect score'), findsOneWidget);

    await tester.tap(find.text('Collect score'));
    await tester.pump();
    expect(find.text('Skip'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Score: 295'), findsOneWidget);
    expect(find.text('Distance: 5m -> 0'), findsOneWidget);
    expect(find.text('Time: 00:02 -> 0'), findsOneWidget);
    expect(find.text('Collectibles: 2 -> 0'), findsOneWidget);
    expect(find.text('Flying enemy x1 -> 0'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('GameOverOverlay skip completes feed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameOverOverlay(
          visible: true,
          onRestart: () {},
          onExit: null,
          showExitButton: false,
          runEndedEvent: _buildEvent(),
          scoreTuning: const V0ScoreTuning(
            timeScorePerSecond: 10,
            distanceScorePerMeter: 5,
            groundEnemyKillScore: 100,
            flyingEnemyKillScore: 150,
          ),
          tickHz: 60,
        ),
      ),
    );

    await tester.tap(find.text('Collect score'));
    await tester.pump();
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(find.text('Score: 295'), findsOneWidget);
    expect(find.text('Distance: 5m -> 0'), findsOneWidget);
    expect(find.text('Time: 00:02 -> 0'), findsOneWidget);
    expect(find.text('Collectibles: 2 -> 0'), findsOneWidget);
    expect(find.text('Flying enemy x1 -> 0'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
  });
}

class _FakeLeaderboardStore implements LeaderboardStore {
  _FakeLeaderboardStore();

  late final RunResult _current = RunResult(
    runId: 42,
    endedAtMs: 0,
    endedReason: RunEndReason.gaveUp,
    score: 295,
    distanceMeters: 5,
    durationSeconds: 2,
    tick: 120,
  );

  @override
  Future<LeaderboardSnapshot> addResult(RunResult result) async {
    return LeaderboardSnapshot(entries: [_current], current: _current);
  }

  @override
  Future<List<RunResult>> loadTop10() async => <RunResult>[];
}
