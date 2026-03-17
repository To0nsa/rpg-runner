import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/tuning/score_tuning.dart';
import 'package:rpg_runner/ui/hud/gameover/game_over_overlay.dart';
import 'package:rpg_runner/ui/hud/gameover/leaderboard_panel.dart';
import 'package:rpg_runner/ui/leaderboard/leaderboard_store.dart';
import 'package:rpg_runner/ui/leaderboard/run_result.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';
import 'package:run_protocol/submission_status.dart' as protocol;
import 'package:rpg_runner/ui/state/run_submission_status.dart';

// Test constants matching _buildEvent().
const _distanceUnits = 500.0;
const _tick = 120;
const _tickHz = 60;
const _tuning = ScoreTuning(
  timeScorePerSecond: 10,
  distanceScorePerMeter: 5,
  groundEnemyKillScore: 100,
  unocoDemonKillScore: 150,
);

// Derived expected values.
final _expectedMeters = (_distanceUnits / kWorldUnitsPerMeter).floor();
final _expectedDistancePoints = _expectedMeters * _tuning.distanceScorePerMeter;
const _expectedTimeSeconds = _tick ~/ _tickHz;
const _expectedTimePoints = _expectedTimeSeconds * 10;
const _expectedCollectiblePoints = 100;
const _expectedKillPoints = 150;
final _expectedTotal =
    _expectedDistancePoints +
    _expectedTimePoints +
    _expectedCollectiblePoints +
    _expectedKillPoints;

RunEndedEvent _buildEvent() {
  return const RunEndedEvent(
    runId: 1,
    tick: _tick,
    distance: _distanceUnits,
    reason: RunEndReason.gaveUp,
    stats: RunEndStats(
      collectibles: 2,
      collectibleScore: 100,
      enemyKillCounts: [1, 0],
    ),
    goldEarned: 2,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Scoreboard hides current run score until feed complete', (
    tester,
  ) async {
    final store = _FakeLeaderboardStore();

    await tester.pumpWidget(
      MaterialApp(
        home: GameOverOverlay(
          visible: true,
          onRestart: () {},
          onExit: null,
          showExitButton: false,
          levelId: LevelId.field,
          runMode: RunMode.practice,
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
    expect(find.descendant(of: panel, matching: find.text('—')), findsWidgets);

    await tester.tap(find.text('Collect Score'));
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(
      find.descendant(of: panel, matching: find.text('$_expectedTotal')),
      findsOneWidget,
    );
    expect(find.descendant(of: panel, matching: find.text('—')), findsNothing);
  });

  testWidgets('GameOverOverlay feeds all rows into score', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameOverOverlay(
          visible: true,
          onRestart: () {},
          onExit: null,
          showExitButton: false,
          levelId: LevelId.field,
          runMode: RunMode.practice,
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
    expect(find.text('Unoco Demon x1 -> $_expectedKillPoints'), findsOneWidget);
    expect(find.text('Collect Score'), findsOneWidget);

    await tester.tap(find.text('Collect Score'));
    await tester.pump();
    expect(find.text('Skip'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Score: $_expectedTotal'), findsOneWidget);
    expect(find.text('Distance: ${_expectedMeters}m -> 0'), findsOneWidget);
    expect(find.text('Time: 00:02 -> 0'), findsOneWidget);
    expect(find.text('Collectibles: 2 -> 0'), findsOneWidget);
    expect(find.text('Unoco Demon x1 -> 0'), findsOneWidget);
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
          levelId: LevelId.field,
          runMode: RunMode.practice,
          runEndedEvent: _buildEvent(),
          scoreTuning: _tuning,
          tickHz: _tickHz,
        ),
      ),
    );

    await tester.tap(find.text('Collect Score'));
    await tester.pump();
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(find.text('Score: $_expectedTotal'), findsOneWidget);
    expect(find.text('Distance: ${_expectedMeters}m -> 0'), findsOneWidget);
    expect(find.text('Time: 00:02 -> 0'), findsOneWidget);
    expect(find.text('Collectibles: 2 -> 0'), findsOneWidget);
    expect(find.text('Unoco Demon x1 -> 0'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('GameOverOverlay animates earned gold into actual gold', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameOverOverlay(
          visible: true,
          onRestart: () {},
          onExit: null,
          showExitButton: false,
          levelId: LevelId.field,
          runMode: RunMode.practice,
          runEndedEvent: _buildEvent(),
          scoreTuning: _tuning,
          tickHz: _tickHz,
          provisionalGoldEarned: 7,
          verifiedGold: 1234,
        ),
      ),
    );

    expect(find.text('Gold earned: 7 + '), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);

    await tester.tap(find.text('Collect Score'));
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(find.text('Gold earned: 0 + '), findsOneWidget);
    expect(find.text('1241'), findsOneWidget);
  });

  testWidgets('Competitive mode does not write local leaderboard entries', (
    tester,
  ) async {
    final store = _FakeLeaderboardStore();

    await tester.pumpWidget(
      MaterialApp(
        home: GameOverOverlay(
          visible: true,
          onRestart: () {},
          onExit: null,
          showExitButton: false,
          levelId: LevelId.field,
          runMode: RunMode.competitive,
          runEndedEvent: _buildEvent(),
          scoreTuning: _tuning,
          tickHz: _tickHz,
          leaderboardStore: store,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Online leaderboard updates after validation.'),
      findsOneWidget,
    );
    expect(store.addResultCalls, 0);
  });

  group('GameOverOverlay gold panel reward states', () {
    RunSubmissionStatus _provisionalStatus({
      required int provisionalGold,
      String runSessionId = 'run_test',
      protocol.RunSessionState state = protocol.RunSessionState.pendingValidation,
      RunSubmissionPhase phase = RunSubmissionPhase.pendingValidation,
    }) {
      return RunSubmissionStatus(
        runSessionId: runSessionId,
        phase: phase,
        updatedAtMs: 0,
        serverStatus: protocol.SubmissionStatus(
          runSessionId: runSessionId,
          state: state,
          updatedAtMs: 0,
          reward: protocol.SubmissionReward(
            status: protocol.SubmissionRewardStatus.provisional,
            provisionalGold: provisionalGold,
            effectiveGoldDelta: 0,
            spendableGoldDelta: 0,
            updatedAtMs: 0,
          ),
        ),
      );
    }

    RunSubmissionStatus _finalStatus({
      required int provisionalGold,
      required int effectiveGoldDelta,
      required int spendableGoldDelta,
      String runSessionId = 'run_test',
    }) {
      return RunSubmissionStatus(
        runSessionId: runSessionId,
        phase: RunSubmissionPhase.validated,
        updatedAtMs: 1,
        serverStatus: protocol.SubmissionStatus(
          runSessionId: runSessionId,
          state: protocol.RunSessionState.validated,
          updatedAtMs: 1,
          reward: protocol.SubmissionReward(
            status: protocol.SubmissionRewardStatus.finalReward,
            provisionalGold: provisionalGold,
            effectiveGoldDelta: effectiveGoldDelta,
            spendableGoldDelta: spendableGoldDelta,
            updatedAtMs: 1,
          ),
        ),
      );
    }

    RunSubmissionStatus _revokedStatus({
      required int provisionalGold,
      String runSessionId = 'run_test',
    }) {
      return RunSubmissionStatus(
        runSessionId: runSessionId,
        phase: RunSubmissionPhase.rejected,
        updatedAtMs: 1,
        serverStatus: protocol.SubmissionStatus(
          runSessionId: runSessionId,
          state: protocol.RunSessionState.rejected,
          updatedAtMs: 1,
          reward: protocol.SubmissionReward(
            status: protocol.SubmissionRewardStatus.revoked,
            provisionalGold: provisionalGold,
            effectiveGoldDelta: 0,
            spendableGoldDelta: 0,
            updatedAtMs: 1,
          ),
        ),
      );
    }

    testWidgets('gold panel absent when no gold fields are set', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameOverOverlay(
            visible: true,
            onRestart: () {},
            onExit: null,
            showExitButton: false,
            levelId: LevelId.field,
            runMode: RunMode.practice,
            runEndedEvent: _buildEvent(),
            scoreTuning: _tuning,
            tickHz: _tickHz,
          ),
        ),
      );

      expect(find.textContaining('Gold earned:'), findsNothing);
    });

    testWidgets('gold panel shows provisional reward from runSubmissionStatus', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameOverOverlay(
            visible: true,
            onRestart: () {},
            onExit: null,
            showExitButton: false,
            levelId: LevelId.field,
            runMode: RunMode.practice,
            runEndedEvent: _buildEvent(),
            scoreTuning: _tuning,
            tickHz: _tickHz,
            verifiedGold: 100,
            runSubmissionStatus: _provisionalStatus(provisionalGold: 50),
          ),
        ),
      );

      // Before collect: 50 earned remaining, 100 in wallet.
      expect(find.text('Gold earned: 50 + '), findsOneWidget);
      expect(find.text('100'), findsOneWidget);

      await tester.tap(find.text('Collect Score'));
      await tester.pump();
      await tester.tap(find.text('Skip'));
      await tester.pump();

      // After collect: 0 remaining, 150 in wallet.
      expect(find.text('Gold earned: 0 + '), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
    });

    testWidgets('gold panel shows final reward using provisionalGold field', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameOverOverlay(
            visible: true,
            onRestart: () {},
            onExit: null,
            showExitButton: false,
            levelId: LevelId.field,
            runMode: RunMode.practice,
            runEndedEvent: _buildEvent(),
            scoreTuning: _tuning,
            tickHz: _tickHz,
            verifiedGold: 200,
            runSubmissionStatus: _finalStatus(
              provisionalGold: 40,
              effectiveGoldDelta: 40,
              spendableGoldDelta: 40,
            ),
          ),
        ),
      );

      // Final reward: overlay uses provisionalGold for the earn row.
      expect(find.text('Gold earned: 40 + '), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
    });

    testWidgets(
      'gold panel absent when reward is revoked and verifiedGold is zero',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: GameOverOverlay(
              visible: true,
              onRestart: () {},
              onExit: null,
              showExitButton: false,
              levelId: LevelId.field,
              runMode: RunMode.practice,
              runEndedEvent: _buildEvent(),
              scoreTuning: _tuning,
              tickHz: _tickHz,
              // No verifiedGold — earnedTotal = 0 and actualGold = 0.
              runSubmissionStatus: _revokedStatus(provisionalGold: 50),
            ),
          ),
        );

        expect(find.textContaining('Gold earned:'), findsNothing);
      },
    );

    testWidgets(
      'gold panel shows zero earned and full verifiedGold when reward revoked',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: GameOverOverlay(
              visible: true,
              onRestart: () {},
              onExit: null,
              showExitButton: false,
              levelId: LevelId.field,
              runMode: RunMode.practice,
              runEndedEvent: _buildEvent(),
              scoreTuning: _tuning,
              tickHz: _tickHz,
              verifiedGold: 200,
              runSubmissionStatus: _revokedStatus(provisionalGold: 50),
            ),
          ),
        );

        // _resolvedEarnedGold() = 0 (revoked), actualGold = 200.
        expect(find.text('Gold earned: 0 + '), findsOneWidget);
        expect(find.text('200'), findsOneWidget);
      },
    );

    testWidgets(
      'verifiedGoldBaseline does not re-inflate after widget update with new verifiedGold',
      (tester) async {
        late StateSetter updateState;
        int verifiedGold = 100;
        RunSubmissionStatus? runSubmissionStatus =
            _provisionalStatus(provisionalGold: 50);

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                updateState = setState;
                return GameOverOverlay(
                  visible: true,
                  onRestart: () {},
                  onExit: null,
                  showExitButton: false,
                  levelId: LevelId.field,
                  runMode: RunMode.practice,
                  runEndedEvent: _buildEvent(),
                  scoreTuning: _tuning,
                  tickHz: _tickHz,
                  verifiedGold: verifiedGold,
                  runSubmissionStatus: runSubmissionStatus,
                );
              },
            ),
          ),
        );

        // Collect to drain all provisional gold into the wallet.
        await tester.tap(find.text('Collect Score'));
        await tester.pump();
        await tester.tap(find.text('Skip'));
        await tester.pump();

        // Baseline 100 + collected 50 = 150.
        expect(find.text('Gold earned: 0 + '), findsOneWidget);
        expect(find.text('150'), findsOneWidget);

        // Simulate a server poll that settles the grant: verifiedGold now 150.
        updateState(() {
          verifiedGold = 150;
          runSubmissionStatus = _finalStatus(
            provisionalGold: 50,
            effectiveGoldDelta: 50,
            spendableGoldDelta: 50,
          );
        });
        await tester.pump();

        // Baseline must NOT update — stays 100 — so actualGold stays 150,
        // not 200 (which would double-count the earned gold).
        expect(find.text('150'), findsOneWidget);
        expect(find.text('200'), findsNothing);
      },
    );
  });
}

class _FakeLeaderboardStore implements LeaderboardStore {
  _FakeLeaderboardStore();

  int addResultCalls = 0;
  int loadTop10Calls = 0;

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
    required RunMode runMode,
    required RunResult result,
  }) async {
    addResultCalls += 1;
    return LeaderboardSnapshot(entries: [_current], current: _current);
  }

  @override
  Future<List<RunResult>> loadTop10({
    required LevelId levelId,
    required RunMode runMode,
  }) async {
    loadTop10Calls += 1;
    return <RunResult>[];
  }
}
