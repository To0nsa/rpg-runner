import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/tuning/score_tuning.dart';
import 'package:rpg_runner/ui/hud/gameover/game_over_overlay.dart';
import 'package:rpg_runner/ui/hud/gameover/leaderboard_panel.dart';
import 'package:rpg_runner/ui/leaderboard/leaderboard_store.dart';
import 'package:rpg_runner/ui/leaderboard/run_result.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';
import 'package:run_protocol/submission_status.dart' as protocol;
import 'package:rpg_runner/ui/state/run/run_submission_status.dart';

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

RunEndedEvent _buildDerfSpellImpactDeathEvent() {
  return const RunEndedEvent(
    runId: 2,
    tick: _tick,
    distance: _distanceUnits,
    reason: RunEndReason.playerDied,
    stats: RunEndStats(
      collectibles: 0,
      collectibleScore: 0,
      enemyKillCounts: [0, 0],
    ),
    goldEarned: 0,
    deathInfo: DeathInfo(
      kind: DeathSourceKind.spellImpact,
      enemyId: EnemyId.derf,
    ),
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
        theme: ThemeData(useMaterial3: false),
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
        theme: ThemeData(useMaterial3: false),
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
        theme: ThemeData(useMaterial3: false),
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

  testWidgets(
    'GameOverOverlay presents provisional gold as a verifying result',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
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

      expect(find.text('Run reward: +'), findsOneWidget);
      expect(find.text('Verifying reward…'), findsOneWidget);
      expect(find.textContaining('Reward pending:'), findsNothing);
      expect(find.text('1234'), findsOneWidget);

      await tester.tap(find.text('Collect Score'));
      await tester.pump();
      await tester.tap(find.text('Skip'));
      await tester.pump();

      expect(find.text('Verifying reward…'), findsOneWidget);
      expect(find.text('1234'), findsOneWidget);
    },
  );

  testWidgets('GameOverOverlay blocks exit until the replay is journaled', (
    tester,
  ) async {
    var exitCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: GameOverOverlay(
          visible: true,
          onRestart: () {},
          onExit: () => exitCalls += 1,
          showExitButton: true,
          levelId: LevelId.field,
          runMode: RunMode.practice,
          runEndedEvent: _buildEvent(),
          scoreTuning: _tuning,
          tickHz: _tickHz,
          provisionalGoldEarned: 7,
          verifiedGold: 1234,
          replaySubmissionJournaled: false,
        ),
      ),
    );

    expect(find.text('Saving replay'), findsOneWidget);
    expect(find.text('Verifying reward…'), findsNothing);

    await tester.tap(find.text('Collect Score'));
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(find.text('Saving Replay'), findsOneWidget);
    await tester.tap(find.text('Saving Replay'), warnIfMissed: false);
    await tester.pump();
    expect(exitCalls, 0);
  });

  testWidgets(
    'GameOverOverlay permits an explicit discard after save failure',
    (tester) async {
      var exitCalls = 0;
      var retryCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: GameOverOverlay(
            visible: true,
            onRestart: () {},
            onExit: () => exitCalls += 1,
            showExitButton: true,
            levelId: LevelId.field,
            runMode: RunMode.practice,
            runEndedEvent: _buildEvent(),
            scoreTuning: _tuning,
            tickHz: _tickHz,
            replaySubmissionJournaled: false,
            replaySubmissionJournalError: 'disk unavailable',
            onRetryReplayJournal: () => retryCalls += 1,
          ),
        ),
      );

      expect(find.text('Replay save failed'), findsOneWidget);
      await tester.tap(find.text('Retry Saving'));
      await tester.pump();
      expect(retryCalls, 1);

      await tester.tap(find.text('Collect Score'));
      await tester.pump();
      await tester.tap(find.text('Skip'));
      await tester.pump();
      await tester.tap(find.text('Exit Without Reward'));
      await tester.pump();

      expect(exitCalls, 1);
    },
  );

  testWidgets('Competitive mode does not write local leaderboard entries', (
    tester,
  ) async {
    final store = _FakeLeaderboardStore();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
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
    await tester.pumpAndSettle();

    expect(find.text('Actual rank unavailable.'), findsOneWidget);
    expect(store.addResultCalls, 0);
    expect(store.loadTop10Calls, 0);
  });

  testWidgets('GameOverOverlay shows Derf spell-impact death subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: GameOverOverlay(
          visible: true,
          onRestart: () {},
          onExit: null,
          showExitButton: false,
          levelId: LevelId.field,
          runMode: RunMode.practice,
          runEndedEvent: _buildDerfSpellImpactDeathEvent(),
          scoreTuning: _tuning,
          tickHz: _tickHz,
        ),
      ),
    );

    expect(find.text('Incinerated by Derf\'s explosion.'), findsOneWidget);
  });

  group('GameOverOverlay gold panel reward states', () {
    RunSubmissionStatus provisionalStatus({
      required int provisionalGold,
      String runSessionId = 'run_test',
      protocol.RunSessionState state =
          protocol.RunSessionState.pendingValidation,
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

    RunSubmissionStatus finalStatus({
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

    RunSubmissionStatus revokedStatus({
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
          theme: ThemeData(useMaterial3: false),
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

      expect(find.textContaining('Gold:'), findsNothing);
    });

    testWidgets(
      'gold panel shows provisional reward from runSubmissionStatus',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: false),
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
              runSubmissionStatus: provisionalStatus(provisionalGold: 50),
            ),
          ),
        );

        expect(find.text('Wallet: '), findsOneWidget);
        expect(find.text('100'), findsOneWidget);
        expect(find.text('Run reward: +'), findsOneWidget);
        expect(find.text('Verifying reward…'), findsOneWidget);

        await tester.tap(find.text('Collect Score'));
        await tester.pump();
        await tester.tap(find.text('Skip'));
        await tester.pump();

        expect(find.text('100'), findsOneWidget);
        expect(find.text('Verifying reward…'), findsOneWidget);
      },
    );

    testWidgets('settlement processing uses the compact reward confirmation', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
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
            runSubmissionStatus: provisionalStatus(
              provisionalGold: 50,
              state: protocol.RunSessionState.settlementPending,
              phase: RunSubmissionPhase.settlementPending,
            ),
          ),
        ),
      );

      expect(find.text('Verifying reward…'), findsOneWidget);
      expect(find.text('Verification: '), findsNothing);
      expect(find.text('Settling Reward'), findsNothing);
    });

    testWidgets('gold panel only shows canonical gold after final settlement', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
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
            runSubmissionStatus: finalStatus(
              provisionalGold: 40,
              effectiveGoldDelta: 40,
              spendableGoldDelta: 40,
            ),
          ),
        ),
      );

      expect(find.text('Wallet: '), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('Reward verified'), findsOneWidget);
    });

    testWidgets(
      'gold panel absent when reward is revoked and verifiedGold is zero',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: false),
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
              runSubmissionStatus: revokedStatus(provisionalGold: 50),
            ),
          ),
        );

        expect(find.textContaining('Gold:'), findsNothing);
      },
    );

    testWidgets('gold panel shows only verifiedGold when reward is revoked', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
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
            runSubmissionStatus: revokedStatus(provisionalGold: 50),
          ),
        ),
      );

      expect(find.text('Wallet: '), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.textContaining('Run reward:'), findsNothing);
    });

    testWidgets(
      'verified gold refresh replaces the displayed wallet value without double count',
      (tester) async {
        late StateSetter updateState;
        int verifiedGold = 100;
        RunSubmissionStatus? runSubmissionStatus = provisionalStatus(
          provisionalGold: 50,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: false),
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

        expect(find.text('100'), findsOneWidget);
        expect(find.text('Verifying reward…'), findsOneWidget);

        updateState(() {
          verifiedGold = 150;
          runSubmissionStatus = finalStatus(
            provisionalGold: 50,
            effectiveGoldDelta: 50,
            spendableGoldDelta: 50,
          );
        });
        await tester.pump();

        expect(find.text('150'), findsOneWidget);
        expect(find.text('200'), findsNothing);
        expect(find.text('Reward verified'), findsOneWidget);
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
