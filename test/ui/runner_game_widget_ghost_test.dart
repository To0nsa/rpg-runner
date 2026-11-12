import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:run_protocol/board_key.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:rpg_runner/game/replay/run_recorder_io.dart';
import 'package:rpg_runner/game/runner_flame_game.dart';
import 'package:rpg_runner/ui/run/runner_run_session.dart';
import 'package:rpg_runner/ui/runner_game_widget.dart';
import 'package:rpg_runner/ui/state/boards/ghost_api.dart';
import 'package:rpg_runner/ui/state/boards/ghost_replay_cache.dart';
import 'package:rpg_runner/ui/theme/ui_tokens.dart';

import '../game/replay/support/ghost_replay_fixture.dart';

void main() {
  for (final leaveWhileLoading in [true, false]) {
    testWidgets(
      'ghost route readiness and cleanup (leave while loading: $leaveWhileLoading)',
      (tester) async {
        // Account-cleanup tests can clear the app's shared spool concurrently.
        final spoolDirectory = Directory.systemTemp.createTempSync(
          'ghost_route_test_',
        );
        RunnerRunSession? session;
        final boardKey = BoardKey(
          mode: RunMode.competitive,
          levelId: 'field',
          windowId: '2026-10',
          rulesetVersion: 'rules-v1',
          scoreVersion: 'score-v1',
        );
        final replay = ghostReplayFixture(boardKey: boardKey, totalTicks: 180);
        final runId =
            'ghost_route_test_${DateTime.now().microsecondsSinceEpoch}';
        final bootstrap = GhostReplayBootstrap(
          replayBlob: replay,
          cacheKey: 'unused-test-ghost.json',
          cachedAtMs: 1,
          manifest: GhostManifest(
            boardId: replay.boardId!,
            entryId: 'entry',
            runSessionId: replay.runSessionId,
            uid: 'fixture-user',
            replayStorageRef: 'ghosts/ghost_board/entry/ghost.bin.gz',
            sourceReplayStorageRef:
                'replay-submissions/pending/fixture-user/run/replay.bin.gz',
            sourceReplayStorageGeneration: '1',
            promotedReplayStorageGeneration: '2',
            replayDigest: replay.canonicalSha256,
            downloadUrl: 'https://example.invalid/unused',
            downloadUrlExpiresAtMs: 999999,
            score: 0,
            distanceMeters: 0,
            durationSeconds: 3,
            sortKey: 'fixture',
            rank: 1,
            updatedAtMs: 1,
          ),
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          var stopped = false;
          final stopping = (session?.stop() ?? Future<void>.value())
              .whenComplete(() => stopped = true);
          // Closing spans real file IO and the test's fake microtask queue.
          for (var attempt = 0; attempt < 600 && !stopped; attempt++) {
            await tester.pump();
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
          }
          expect(
            stopped,
            isTrue,
            reason: 'Recorder must close before cleanup.',
          );
          await stopping;
          await tester.runAsync(() async {
            await spoolDirectory.delete(recursive: true);
          });
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              extensions: [UiTokens.standard],
            ),
            home: Scaffold(
              body: RunnerGameWidget(
                sessionFactory: (descriptor) => session = RunnerRunSession(
                  descriptor: descriptor,
                  createRecorder: (header) => FileRunRecorder.create(
                    header: header,
                    spoolDirectory: spoolDirectory,
                  ),
                ),
                runSessionId: runId,
                runId: 1,
                seed: replay.seed,
                levelId: LevelId.field,
                runMode: RunMode.competitive,
                boardId: replay.boardId,
                boardKey: boardKey,
                ghostReplayBootstrap: bootstrap,
              ),
            ),
          ),
        );
        final gameWidget = tester.widget<GameWidget<RunnerFlameGame>>(
          find.byWidgetPredicate(
            (widget) => widget is GameWidget<RunnerFlameGame>,
          ),
        );
        final game = gameWidget.game!;
        expect(find.text('Tap to start'), findsNothing);
        if (leaveWhileLoading) {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 300)),
          );
          // Advance the fake event queue so already-queued, cancelled terrain
          // work can observe disposal without retaining a test timer.
          await tester.pump(Duration.zero);
          expect(tester.takeException(), isNull);
          return;
        }
        for (
          var attempt = 0;
          attempt < 600 && find.text('Tap to start').evaluate().isEmpty;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          expect(tester.takeException(), isNull);
        }
        expect(
          find.text('Tap to start'),
          findsOneWidget,
          reason:
              'phase: ${game.loadState.value.phase.name}, '
              'ghost: ${game.ghostRenderListenable?.value?.current.tick}, '
              'disabled: ${game.debugGhostLayerDisabled}',
        );
        expect(game.loadState.value.phase, RunLoadPhase.worldReady);
        expect(game.ghostRenderListenable!.value, isNotNull);
        expect(game.ghostRenderListenable!.value!.current.tick, 0);
        expect(game.controller.tick, 0);
        expect(game.debugGhostLayerDisabled, isFalse);
        await tester.tap(find.text('Tap to start'));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.text('Tap to start'), findsNothing);
        expect(game.controller.tick, greaterThan(0));
        expect(
          game.ghostRenderListenable!.value!.current.tick,
          game.controller.tick,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
