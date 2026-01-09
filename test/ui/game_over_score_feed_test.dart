import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkscape_runner/core/events/game_event.dart';
import 'package:walkscape_runner/core/levels/level_id.dart';
import 'package:walkscape_runner/core/tuning/score_tuning.dart';
import 'package:walkscape_runner/ui/hud/gameover/game_over_overlay.dart';
import 'package:walkscape_runner/ui/hud/gameover/leaderboard_panel.dart';
import 'package:walkscape_runner/ui/leaderboard/leaderboard_store.dart';
import 'package:walkscape_runner/ui/leaderboard/run_result.dart';

// Test constants matching _buildEvent().
const _distanceUnits = 500.0;
const _tick = 120;
const _tickHz = 60;
const _tuning = ScoreTuning(
  timeScorePerSecond: 10,
  distanceScorePerMeter: 5,
  groundEnemyKillScore: 100,
  flyingEnemyKillScore: 150,
);

// Derived expected values.
final _expectedMeters = (_distanceUnits / kWorldUnitsPerMeter).floor();
final _expectedDistancePoints = _expectedMeters * _tuning.distanceScorePerMeter;
const _expectedTimeSeconds = _tick ~/ _tickHz;
const _expectedTimePoints = _expectedTimeSeconds * 10;
const _expectedCollectiblePoints = 100;
const _expectedKillPoints = 150;
final _expectedTotal = _expectedDistancePoints +
    _expectedTimePoints +
    _expectedCollectiblePoints +
    _expectedKillPoints;

RunEndedEvent _buildEvent() {
  return const RunEndedEvent(
    tick: _tick,
    distance: _distanceUnits,
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
          levelId: LevelId.defaultLevel,
          runEndedEvent: _buildEvent(),
          scoreTuning: _tuning,
          tickHz: _tickHz,
          leaderboardStore: store,
        ),
      ),
    );
    await tester.pump();

    final panel = find.byType(LeaderboardPanel);
    expect(panel, findsOneWidget);

    expect(
      find.descendant(of: panel, matching: find.text('$_expectedTotal')),
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
      find.descendant(of: panel, matching: find.text('$_expectedTotal')),
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
          levelId: LevelId.defaultLevel,
          runEndedEvent: _buildEvent(),
          scoreTuning: _tuning,
          tickHz: _tickHz,
        ),
      ),
    );

    expect(find.textContaining('Score:'), findsNothing);
    expect(
      find.text('Distance: ${_expectedMeters}m -> $_expectedDistancePoints'),
      findsOneWidget,
    );
    expect(find.text('Time: 00:02 -> $_expectedTimePoints'), findsOneWidget);
    expect(
      find.text('Collectibles: 2 -> $_expectedCollectiblePoints'),
      findsOneWidget,
    );
    expect(find.text('Flying enemy x1 -> $_expectedKillPoints'), findsOneWidget);
    expect(find.text('Collect score'), findsOneWidget);

    await tester.tap(find.text('Collect score'));
    await tester.pump();
    expect(find.text('Skip'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Score: $_expectedTotal'), findsOneWidget);
    expect(find.text('Distance: ${_expectedMeters}m -> 0'), findsOneWidget);
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
          levelId: LevelId.defaultLevel,
          runEndedEvent: _buildEvent(),
          scoreTuning: _tuning,
          tickHz: _tickHz,
        ),
      ),
    );

    await tester.tap(find.text('Collect score'));
    await tester.pump();
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(find.text('Score: $_expectedTotal'), findsOneWidget);
    expect(find.text('Distance: ${_expectedMeters}m -> 0'), findsOneWidget);
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
    score: _expectedTotal,
    distanceMeters: _expectedMeters,
    durationSeconds: _expectedTimeSeconds,
    tick: _tick,
  );

  @override
  Future<LeaderboardSnapshot> addResult({
    required LevelId levelId,
    required RunResult result,
  }) async {
    return LeaderboardSnapshot(entries: [_current], current: _current);
  }

  @override
  Future<List<RunResult>> loadTop10({required LevelId levelId}) async =>
      <RunResult>[];
}
