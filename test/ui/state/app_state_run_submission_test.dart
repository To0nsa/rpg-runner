import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/state/ownership/codex_progress.dart';
import 'package:rpg_runner/ui/state/ownership/enemy_defeats.dart';
import 'package:rpg_runner/ui/state/ownership/player_progress.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:run_protocol/run_ticket.dart';
import 'package:run_protocol/submission_status.dart';

import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/auth/auth_api.dart';
import 'package:rpg_runner/ui/state/ownership/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/run/pending_run_submission.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';
import 'package:rpg_runner/ui/state/run/run_session_api.dart';
import 'package:rpg_runner/ui/state/run/run_submission_coordinator.dart';
import 'package:rpg_runner/ui/state/run/run_submission_spool_store.dart';
import 'package:rpg_runner/ui/state/run/run_submission_status.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';
import 'package:rpg_runner/ui/run/run_reward_diagnostics.dart';

void main() {
  test(
    'local rewards display once while canonical gold and gifts stay unchanged',
    () async {
      final api = _MutableRunSessionApi(
        finalizeStatus: SubmissionStatus(
          runSessionId: 'local',
          state: RunSessionState.pendingValidation,
          updatedAtMs: 1,
        ),
      );
      final ownership = _StaticOwnershipApi();
      final spool = _InMemorySpoolStore();
      final app = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownership,
        runSessionApi: api,
        runSubmissionCoordinator: RunSubmissionCoordinator(
          runSessionApi: api,
          spoolStore: spool,
          replayUploader: _NoopReplayUploader(),
        ),
      );
      addTearDown(app.dispose);
      await app.bootstrap();
      await app.journalRunReplay(
        runSessionId: 'local',
        runMode: RunMode.practice,
        replayArtifactId: 'replay',
        canonicalSha256: 'a' * 64,
        contentLengthBytes: 256,
        provisionalSummary: {'goldEarned': 9, 'score': 20199},
      );
      expect(app.displayedGold, 9);
      expect(app.displayedPlayerProgress.totalXp, 100);
      expect(app.displayedPlayerProgress.level, 2);
      expect(app.progression.gold, 0);
      expect(app.progression.playerProgress.level, 1);
      expect(app.displayedPlayerProgress.acceptedRuns, 0);
      expect(app.inboxMessages, isEmpty);
      expect(app.rewardDisplayRevision, isNull);
      expect(app.goldNeedsVerification(9), isTrue);
      expect(app.goldNeedsVerification(10), isFalse);
      await app.processJournaledRunReplay(runSessionId: 'local');
      await app.refreshRunSubmissionStatus(runSessionId: 'local');
      expect(app.displayedGold, 9);
      expect(app.displayedPlayerProgress.totalXp, 100);

      api.setLoadStatus(
        SubmissionStatus(
          runSessionId: 'local',
          state: RunSessionState.rejected,
          updatedAtMs: 2,
        ),
      );
      await app.refreshRunSubmissionStatus(runSessionId: 'local');
      expect(app.displayedGold, 0);
      expect(app.displayedPlayerProgress.totalXp, 0);
      expect(app.latestRewardCorrection?.runSessionId, 'local');
      expect(await spool.loadAll(), isEmpty);
    },
  );

  test(
    'independent previews reconcile with an account refresh before receipts',
    () async {
      final ownership = _StaticOwnershipApi();
      final app = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownership,
        runSubmissionSpoolStore: _InMemorySpoolStore(),
      );
      addTearDown(app.dispose);
      await app.bootstrap();
      for (final (id, gold, score) in [
        ('first', 9, 1735),
        ('second', 5, 1090),
      ]) {
        await app.journalRunReplay(
          runSessionId: id,
          runMode: RunMode.practice,
          replayArtifactId: id,
          canonicalSha256: 'a' * 64,
          contentLengthBytes: 256,
          provisionalSummary: {'goldEarned': gold, 'score': score},
        );
      }
      expect(app.displayedGold, 14);
      expect(app.displayedPlayerProgress.totalXp, 13);
      final confirmed = _canonicalWithGold(
        gold: 9,
        revision: 2,
        playerProgress: const PlayerProgress(
          totalXp: 8,
          acceptedRuns: 1,
          damageDealt100: 0,
          damageTaken100: 0,
        ),
        appliedRewardGrantIds: ['first'],
      );
      ownership.setCanonicalState(confirmed);
      await app.bootstrap(force: true);
      expect(app.progression.gold, 9);
      expect(app.displayedGold, 14);
      expect(app.displayedPlayerProgress.totalXp, 13);
      expect(app.goldNeedsVerification(9), isFalse);
      expect(app.goldNeedsVerification(14), isTrue);

      ownership.setCanonicalState(_canonicalWithGold(gold: 0, revision: 1));
      await app.bootstrap(force: true);
      expect(app.progression.gold, 9);
      expect(app.displayedGold, 14);
    },
  );

  test(
    'final response keeps the display steady through failed canonical recovery',
    () async {
      final api = _FakeRunSessionApi(
        finalizeStatus: SubmissionStatus(
          runSessionId: 'steady',
          state: RunSessionState.validated,
          updatedAtMs: 2,
          reward: SubmissionReward(
            status: SubmissionRewardStatus.finalReward,
            provisionalGold: 9,
            effectiveGoldDelta: 9,
            spendableGoldDelta: 9,
            updatedAtMs: 2,
          ),
        ),
      );
      final ownership = _StaticOwnershipApi();
      final app = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownership,
        runSubmissionCoordinator: RunSubmissionCoordinator(
          runSessionApi: api,
          spoolStore: _InMemorySpoolStore(),
          replayUploader: _NoopReplayUploader(),
        ),
      );
      addTearDown(app.dispose);
      await app.bootstrap();
      await app.journalRunReplay(
        runSessionId: 'steady',
        runMode: RunMode.practice,
        replayArtifactId: 'replay',
        canonicalSha256: 'a' * 64,
        contentLengthBytes: 256,
        provisionalSummary: {'goldEarned': 9, 'score': 1735},
      );
      final frames = <(int, int)>[];
      app.addListener(
        () => frames.add((
          app.displayedGold,
          app.displayedPlayerProgress.totalXp,
        )),
      );
      ownership.failNextLoad = true;
      await app.processJournaledRunReplay(runSessionId: 'steady');
      expect(app.displayedGold, 9);
      expect(app.progression.gold, 0);
      ownership.setCanonicalState(
        _canonicalWithGold(
          gold: 9,
          revision: 2,
          playerProgress: const PlayerProgress(
            totalXp: 8,
            acceptedRuns: 1,
            damageDealt100: 0,
            damageTaken100: 0,
          ),
          appliedRewardGrantIds: ['steady'],
        ),
      );
      await app.refreshRunSubmissionStatus(runSessionId: 'steady');
      expect(frames, isNotEmpty);
      expect(frames.every((value) => value == (9, 8)), isTrue);
      expect(app.progression.gold, 9);
      expect(app.rewardDisplayRevision, 2);
    },
  );

  for (final scenario in [
    'unpaid',
    'paid',
    'history pruned',
    'retained anchor',
  ]) {
    test(
      'restart restores $scenario journal without counting settled rewards twice',
      () async {
        final spool = _InMemorySpoolStore();
        final api = _FakeRunSessionApi(
          finalizeStatus: SubmissionStatus(
            runSessionId: 'restart',
            state: RunSessionState.pendingValidation,
            updatedAtMs: 1,
          ),
        );
        final ownership = _StaticOwnershipApi();
        AppState create() => AppState(
          authApi: _StaticAuthApi.authenticated(),
          loadoutOwnershipApi: ownership,
          runSessionApi: api,
          runSubmissionCoordinator: RunSubmissionCoordinator(
            runSessionApi: api,
            spoolStore: spool,
            replayUploader: _NoopReplayUploader(),
          ),
        );
        if (scenario == 'retained anchor') {
          ownership.setCanonicalState(
            _canonicalWithGold(
              gold: 0,
              revision: 10,
              appliedRewardGrantIds: List.generate(512, (i) => 'base_$i'),
            ),
          );
        }
        final first = create();
        await first.bootstrap();
        await first.journalRunReplay(
          runSessionId: 'restart',
          runMode: RunMode.practice,
          replayArtifactId: 'replay',
          canonicalSha256: 'a' * 64,
          contentLengthBytes: 256,
          provisionalSummary: {'goldEarned': 9, 'score': 1735},
        );
        first.dispose();
        if (scenario == 'retained anchor') {
          ownership.setCanonicalState(
            _canonicalWithGold(
              gold: 0,
              revision: 11,
              appliedRewardGrantIds: [
                ...List.generate(511, (i) => 'base_${i + 1}'),
                'later',
              ],
            ),
          );
        } else if (scenario != 'unpaid') {
          ownership.setCanonicalState(
            _canonicalWithGold(
              gold: 9,
              revision: 600,
              playerProgress: const PlayerProgress(
                totalXp: 8,
                acceptedRuns: 1,
                damageDealt100: 0,
                damageTaken100: 0,
              ),
              appliedRewardGrantIds: scenario == 'paid'
                  ? ['restart']
                  : List.generate(512, (i) => 'later_$i'),
            ),
          );
        }
        final restored = create();
        addTearDown(restored.dispose);
        await restored.bootstrap();
        await restored.processPendingRunSubmissions();
        expect(restored.displayedGold, 9);
        expect(restored.displayedPlayerProgress.totalXp, 8);
        expect(
          restored.progression.gold,
          scenario == 'unpaid' || scenario == 'retained anchor' ? 0 : 9,
        );
      },
    );
  }

  test('account replacement clears local reward presentation before loading the new account', () async {
    final auth = _StaticAuthApi.authenticated();
    final ownership = _StaticOwnershipApi();
    final app = AppState(
      authApi: auth,
      loadoutOwnershipApi: ownership,
      runSubmissionSpoolStore: _InMemorySpoolStore(),
    );
    addTearDown(app.dispose);
    await app.bootstrap();
    await app.journalRunReplay(
      runSessionId: 'old_preview',
      runMode: RunMode.practice,
      replayArtifactId: 'replay',
      canonicalSha256: 'a' * 64,
      contentLengthBytes: 256,
      provisionalSummary: {'goldEarned': 9, 'score': 1735},
    );
    auth._session = const AuthSession(
      userId: 'u2',
      sessionId: 's2',
      isAnonymous: true,
      expiresAtMs: 0,
    );
    ownership.setCanonicalState(_canonicalWithGold(gold: 3, revision: 0));
    await app.bootstrap(force: true);
    expect(app.progression.gold, 3);
    expect(app.displayedGold, 3);
    expect(app.displayedPlayerProgress.totalXp, 0);
    expect(app.latestRewardCorrection, isNull);
  });

  for (final scenario in ['confirmed', 'older revision', 'pause and resume', 'during finalize', 'account replacement']) {
    test('completion receipt $scenario applies without a canonical fetch', () async {
      final gate = Completer<void>();
      final pending = SubmissionStatus(runSessionId: 'push',
        state: RunSessionState.pendingValidation, updatedAtMs: 1000);
      final blocksFinalize = scenario == 'during finalize' || scenario == 'account replacement';
      final api = blocksFinalize
          ? _BlockingFinalizeRunSessionApi(finalizeStatus: pending, finalizeGate: gate.future)
          : _FakeRunSessionApi(finalizeStatus: pending);
      final source = _TestCompletionSource();
      final spool = _InMemorySpoolStore();
      final ownership = _StaticOwnershipApi();
      final auth = _StaticAuthApi.authenticated();
      if (scenario == 'older revision') {
        ownership.setCanonicalState(_canonicalWithGold(gold: 20, revision: 5));
      }
      final app = AppState(authApi: auth,
        loadoutOwnershipApi: ownership, runSessionApi: api, runCompletionSource: source,
        runSubmissionCoordinator: RunSubmissionCoordinator(runSessionApi: api,
          spoolStore: spool, replayUploader: _NoopReplayUploader()));
      addTearDown(() async { app.dispose(); await source.controller.close(); });
      await app.bootstrap();
      app.setRunSubmissionForeground(true);
      final submission = app.submitRunReplay(runSessionId: 'push', runMode: RunMode.practice,
        replayArtifactId: 'replay', canonicalSha256: 'a' * 64, contentLengthBytes: 256);
      if (!blocksFinalize) await submission;
      for (var i = 0; i < 20 && source.listens == 0; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(source.listens, 1);
      final reads = ownership.loadCanonicalStateCallCount;
      final receipt = RunSubmissionResponse(SubmissionStatus(runSessionId: 'push',
        state: RunSessionState.validated, updatedAtMs: 2000,
        reward: SubmissionReward(status: SubmissionRewardStatus.finalReward,
          provisionalGold: 12, effectiveGoldDelta: 12, spendableGoldDelta: 12,
          updatedAtMs: 2000, grantId: 'push')),
        canonical: _canonicalWithGold(gold: 12, revision: 2));
      if (scenario == 'pause and resume') {
        app.setRunSubmissionForeground(false);
        source.controller.add(receipt);
        await Future<void>.delayed(Duration.zero);
        expect(app.progression.gold, 0);
        app.setRunSubmissionForeground(true);
        for (var i = 0; i < 20 && source.listens < 2; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(source.listens, 2);
      }
      final completed = Completer<void>();
      app.addListener(() {
        if (!completed.isCompleted && app.latestVerifiedReward?.runSessionId == 'push') {
          completed.complete();
        }
      });
      source.controller.add(receipt);
      if (scenario == 'account replacement') {
        await Future<void>.delayed(Duration.zero);
        auth._session = const AuthSession(userId: 'u2', sessionId: 's2',
          isAnonymous: true, expiresAtMs: 0);
        ownership.setCanonicalState(_canonicalWithGold(gold: 3, revision: 1));
        await app.bootstrap(force: true);
        gate.complete();
        await submission;
        expect(app.progression.gold, 3);
        expect(app.runSubmissionStatusFor('push'), isNull);
        expect(source.controller.hasListener, isFalse);
        return;
      }
      if (!gate.isCompleted) gate.complete();
      await completed.future.timeout(const Duration(seconds: 5));
      await submission;
      expect(app.progression.gold, scenario == 'older revision' ? 20 : 12);
      expect(ownership.loadCanonicalStateCallCount, reads);
      expect(await spool.load(runSessionId: 'push'), isNull);
      source.controller.add(receipt);
      await Future<void>.delayed(Duration.zero);
      expect(ownership.loadCanonicalStateCallCount, reads);
      expect(source.controller.hasListener, isFalse);
    });
  }

  test('a bundled recovery receipt skips a second ownership request', () async {
    final status = SubmissionStatus(runSessionId: 'bundled', state: RunSessionState.validated,
      updatedAtMs: 2000, reward: SubmissionReward(status: SubmissionRewardStatus.finalReward,
        provisionalGold: 9, effectiveGoldDelta: 9, spendableGoldDelta: 9, updatedAtMs: 2000));
    final api = _FakeRunSessionApi(finalizeStatus: status,
      canonical: _canonicalWithGold(gold: 9, revision: 2));
    final ownership = _StaticOwnershipApi();
    final spool = _InMemorySpoolStore();
    final app = AppState(authApi: _StaticAuthApi.authenticated(), loadoutOwnershipApi: ownership,
      runSessionApi: api, runSubmissionCoordinator: RunSubmissionCoordinator(runSessionApi: api,
        spoolStore: spool, replayUploader: _NoopReplayUploader()));
    addTearDown(app.dispose);
    await app.bootstrap();
    final reads = ownership.loadCanonicalStateCallCount;
    await app.submitRunReplay(runSessionId: 'bundled', runMode: RunMode.practice,
      replayArtifactId: 'replay', canonicalSha256: 'a' * 64, contentLengthBytes: 256);
    expect(app.progression.gold, 9);
    expect(ownership.loadCanonicalStateCallCount, reads);
    expect(await spool.loadAll(), isEmpty);
  });

  test(
    'disposing app services cannot attribute a new account paint to an old run',
    () {
      final previous = RunRewardDiagnostics.instance;
      final output = <String>[];
      final diagnostics = RunRewardDiagnostics(enabled: true, sink: output.add);
      RunRewardDiagnostics.instance = diagnostics;
      addTearDown(() => RunRewardDiagnostics.instance = previous);
      final app = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: _StaticOwnershipApi(),
      );
      diagnostics.canonical('old-account-run', revision: 2, gold: 9, xp: 10);
      app.dispose();
      output.clear();
      diagnostics.painted(
        revision: 2,
        metric: 'gold',
        value: 9,
        target: 9,
        surface: 'hub',
      );
      expect(output, isEmpty);
    },
  );

  test(
    'final receipts survive a failed wallet refresh and are acknowledged once',
    () async {
      final api = _FakeRunSessionApi(
        finalizeStatus: SubmissionStatus(
          runSessionId: 'receipt',
          state: RunSessionState.validated,
          updatedAtMs: 2000,
          reward: SubmissionReward(
            status: SubmissionRewardStatus.finalReward,
            provisionalGold: 9,
            effectiveGoldDelta: 9,
            spendableGoldDelta: 9,
            updatedAtMs: 2000,
          ),
        ),
      );
      final ownership = _StaticOwnershipApi();
      final spool = _InMemorySpoolStore();
      final app = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownership,
        runSessionApi: api,
        runSubmissionCoordinator: RunSubmissionCoordinator(
          runSessionApi: api,
          spoolStore: spool,
          replayUploader: _NoopReplayUploader(),
        ),
      );
      addTearDown(app.dispose);
      await app.bootstrap();
      ownership.setCanonicalState(_canonicalWithGold(gold: 9, revision: 2));
      ownership.failNextLoad = true;
      await app.submitRunReplay(
        runSessionId: 'receipt',
        runMode: RunMode.practice,
        replayArtifactId: '/tmp/receipt.json',
        canonicalSha256: 'a' * 64,
        contentLengthBytes: 256,
      );
      expect(app.progression.gold, 0);
      expect(await spool.load(runSessionId: 'receipt'), isNotNull);
      await app.refreshRunSubmissionStatus(runSessionId: 'receipt');
      expect(app.progression.gold, 9);
      expect(await spool.load(runSessionId: 'receipt'), isNull);
    },
  );

  test(
    'wallet result from an old account cannot overwrite the current player',
    () async {
      final api = _MutableRunSessionApi(
        finalizeStatus: SubmissionStatus(
          runSessionId: 'old',
          state: RunSessionState.pendingValidation,
          updatedAtMs: 1000,
        ),
      );
      final auth = _StaticAuthApi.authenticated();
      final ownership = _StaticOwnershipApi();
      final app = AppState(
        authApi: auth,
        loadoutOwnershipApi: ownership,
        runSessionApi: api,
        runSubmissionCoordinator: RunSubmissionCoordinator(
          runSessionApi: api,
          spoolStore: _InMemorySpoolStore(),
          replayUploader: _NoopReplayUploader(),
        ),
      );
      addTearDown(app.dispose);
      await app.bootstrap();
      await app.submitRunReplay(
        runSessionId: 'old',
        runMode: RunMode.practice,
        replayArtifactId: '/tmp/old.json',
        canonicalSha256: 'a' * 64,
        contentLengthBytes: 256,
      );
      api.setLoadStatus(
        SubmissionStatus(
          runSessionId: 'old',
          state: RunSessionState.validated,
          updatedAtMs: 2000,
          reward: SubmissionReward(
            status: SubmissionRewardStatus.finalReward,
            provisionalGold: 99,
            effectiveGoldDelta: 99,
            spendableGoldDelta: 99,
            updatedAtMs: 2000,
          ),
        ),
      );
      ownership.setCanonicalState(_canonicalWithGold(gold: 99, revision: 2));
      final gate = Completer<void>();
      ownership.nextLoadGate = gate.future;
      final refresh = app.refreshRunSubmissionStatus(runSessionId: 'old');
      await Future<void>.delayed(Duration.zero);
      auth._session = const AuthSession(
        userId: 'u2',
        sessionId: 's2',
        isAnonymous: true,
        expiresAtMs: 0,
      );
      ownership.setCanonicalState(_canonicalWithGold(gold: 3, revision: 1));
      await app.bootstrap(force: true);
      gate.complete();
      await refresh;
      expect(app.authSession.userId, 'u2');
      expect(app.progression.gold, 3);
      expect(app.runSubmissionStatusFor('old'), isNull);
    },
  );

  test(
    'foreground rewards complete without a run widget and resume after inactivity',
    () async {
      final api = _MutableRunSessionApi(
        finalizeStatus: SubmissionStatus(
          runSessionId: 'background',
          state: RunSessionState.pendingValidation,
          updatedAtMs: 1000,
        ),
      );
      final spool = _InMemorySpoolStore();
      final ownership = _StaticOwnershipApi();
      final app = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownership,
        runSessionApi: api,
        runSubmissionCoordinator: RunSubmissionCoordinator(
          runSessionApi: api,
          spoolStore: spool,
          replayUploader: _NoopReplayUploader(),
        ),
      );
      addTearDown(app.dispose);
      await app.bootstrap();
      final submitted = Completer<void>();
      final rewardCompleted = Completer<void>();
      app.addListener(() {
        if (!submitted.isCompleted &&
            app.runSubmissionStatusFor('background')?.phase ==
                RunSubmissionPhase.pendingValidation) {
          submitted.complete();
        }
        if (!rewardCompleted.isCompleted && app.progression.gold == 12) {
          rewardCompleted.complete();
        }
      });
      await app.journalRunReplay(
        runSessionId: 'background',
        runMode: RunMode.practice,
        replayArtifactId: '/tmp/background.json',
        canonicalSha256: 'a' * 64,
        contentLengthBytes: 256,
      );
      app.setRunSubmissionForeground(true);
      await submitted.future.timeout(const Duration(seconds: 5));
      expect(api.createUploadGrantCallCount, 1);
      app.setRunSubmissionForeground(false);
      ownership.setCanonicalState(_canonicalWithGold(gold: 12, revision: 2));
      api.setLoadStatus(
        SubmissionStatus(
          runSessionId: 'background',
          state: RunSessionState.validated,
          updatedAtMs: 2000,
          reward: SubmissionReward(
            status: SubmissionRewardStatus.finalReward,
            provisionalGold: 12,
            effectiveGoldDelta: 12,
            spendableGoldDelta: 12,
            updatedAtMs: 2000,
          ),
        ),
      );
      // The app scheduler uses wall time; widget pumping advances only timers.
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(app.progression.gold, 0);
      app.setRunSubmissionForeground(true);
      await rewardCompleted.future.timeout(const Duration(seconds: 5));
      expect(app.progression.gold, 12);
      expect(await spool.load(runSessionId: 'background'), isNull);
      final reads = ownership.loadCanonicalStateCallCount;
      await app.refreshRunSubmissionStatus(runSessionId: 'background');
      expect(ownership.loadCanonicalStateCallCount, reads);
    },
  );

  test(
    'journalRunReplay persists the replay before any remote submission',
    () async {
      final runSessionApi = _FakeRunSessionApi(
        finalizeStatus: SubmissionStatus(
          runSessionId: 'run_journaled',
          state: RunSessionState.pendingValidation,
          updatedAtMs: 1000,
        ),
      );
      final spoolStore = _InMemorySpoolStore();
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: _StaticOwnershipApi(),
        runSessionApi: runSessionApi,
        runSubmissionCoordinator: RunSubmissionCoordinator(
          runSessionApi: runSessionApi,
          spoolStore: spoolStore,
          replayUploader: _NoopReplayUploader(),
          clock: () => 1000,
        ),
      );
      await appState.bootstrap(force: true);

      final journaled = await appState.journalRunReplay(
        runSessionId: 'run_journaled',
        runMode: RunMode.practice,
        replayArtifactId: '/tmp/replay_journaled.json',
        canonicalSha256:
            'abababababababababababababababababababababababababababababababab',
        contentLengthBytes: 256,
        provisionalSummary: const <String, Object?>{'goldEarned': 27},
      );

      expect(journaled.phase, RunSubmissionPhase.queued);
      expect(journaled.resultContextGold, 27);
      expect(runSessionApi.createUploadGrantCallCount, 0);
      expect(await spoolStore.load(runSessionId: 'run_journaled'), isNotNull);

      await appState.processJournaledRunReplay(runSessionId: 'run_journaled');

      expect(runSessionApi.createUploadGrantCallCount, 1);
    },
  );

  test('submitRunReplay preserves reward payload from server status', () async {
    final runSessionApi = _FakeRunSessionApi(
      finalizeStatus: SubmissionStatus(
        runSessionId: 'run_reward',
        state: RunSessionState.pendingValidation,
        updatedAtMs: 3000,
        reward: SubmissionReward(
          status: SubmissionRewardStatus.provisional,
          provisionalGold: 17,
          effectiveGoldDelta: 0,
          spendableGoldDelta: 0,
          updatedAtMs: 3000,
          grantId: 'run_reward',
        ),
      ),
    );
    final coordinator = RunSubmissionCoordinator(
      runSessionApi: runSessionApi,
      spoolStore: _InMemorySpoolStore(),
      replayUploader: _NoopReplayUploader(),
      clock: () => 3000,
    );
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _StaticOwnershipApi(),
      runSessionApi: runSessionApi,
      runSubmissionCoordinator: coordinator,
    );
    await appState.bootstrap(force: true);

    final status = await appState.submitRunReplay(
      runSessionId: 'run_reward',
      runMode: RunMode.practice,
      replayArtifactId: '/tmp/replay_reward.json',
      canonicalSha256:
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      contentLengthBytes: 1024,
    );

    expect(status.hasProvisionalReward, isTrue);
    expect(status.provisionalGold, 17);
    expect(status.spendableGoldDelta, 0);
    expect(
      appState.runSubmissionStatusFor('run_reward')?.hasProvisionalReward,
      isTrue,
    );
    expect(appState.runSubmissionStatusFor('run_reward')?.provisionalGold, 17);
    expect(appState.progression.gold, 0);
  });

  test(
    'submitRunReplay retains provisionalSummary outside canonical gold',
    () async {
      final runSessionApi = _FakeRunSessionApi(
        finalizeStatus: SubmissionStatus(
          runSessionId: 'run_pending_reward',
          state: RunSessionState.pendingValidation,
          updatedAtMs: 4000,
        ),
      );
      final coordinator = RunSubmissionCoordinator(
        runSessionApi: runSessionApi,
        spoolStore: _InMemorySpoolStore(),
        replayUploader: _NoopReplayUploader(),
        clock: () => 4000,
      );
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: _StaticOwnershipApi(),
        runSessionApi: runSessionApi,
        runSubmissionCoordinator: coordinator,
      );
      await appState.bootstrap(force: true);

      final status = await appState.submitRunReplay(
        runSessionId: 'run_pending_reward',
        runMode: RunMode.practice,
        replayArtifactId: '/tmp/replay_pending_reward.json',
        canonicalSha256:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        contentLengthBytes: 1024,
        provisionalSummary: const <String, Object?>{'goldEarned': 23},
      );

      expect(status.hasProvisionalReward, isFalse);
      expect(status.resultContextGold, 23);
      expect(appState.progression.gold, 0);
    },
  );

  test('submitRunReplay stores latest status in AppState', () async {
    final runSessionApi = _FakeRunSessionApi(
      finalizeStatus: SubmissionStatus(
        runSessionId: 'run_submit',
        state: RunSessionState.pendingValidation,
        updatedAtMs: 1000,
      ),
    );
    final coordinator = RunSubmissionCoordinator(
      runSessionApi: runSessionApi,
      spoolStore: _InMemorySpoolStore(),
      replayUploader: _NoopReplayUploader(),
      clock: () => 1000,
    );
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _StaticOwnershipApi(),
      runSessionApi: runSessionApi,
      runSubmissionCoordinator: coordinator,
    );
    await appState.bootstrap(force: true);

    final status = await appState.submitRunReplay(
      runSessionId: 'run_submit',
      runMode: RunMode.practice,
      replayArtifactId: '/tmp/replay.json',
      canonicalSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      contentLengthBytes: 1024,
    );

    expect(status.phase, RunSubmissionPhase.pendingValidation);
    expect(
      appState.runSubmissionStatusFor('run_submit')?.phase,
      RunSubmissionPhase.pendingValidation,
    );
  });

  test('submitRunReplay does not update canonical gold while submission is in flight', () async {
    final finalizeGate = Completer<void>();
    final runSessionApi = _BlockingFinalizeRunSessionApi(
      finalizeStatus: SubmissionStatus(
        runSessionId: 'run_immediate_gold',
        state: RunSessionState.pendingValidation,
        updatedAtMs: 5000,
      ),
      finalizeGate: finalizeGate.future,
    );
    final coordinator = RunSubmissionCoordinator(
      runSessionApi: runSessionApi,
      spoolStore: _InMemorySpoolStore(),
      replayUploader: _NoopReplayUploader(),
      clock: () => 5000,
    );
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _StaticOwnershipApi(),
      runSessionApi: runSessionApi,
      runSubmissionCoordinator: coordinator,
    );
    await appState.bootstrap(force: true);

    final submitFuture = appState.submitRunReplay(
      runSessionId: 'run_immediate_gold',
      runMode: RunMode.practice,
      replayArtifactId: '/tmp/replay_immediate_gold.json',
      canonicalSha256:
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
      contentLengthBytes: 1024,
      provisionalSummary: const <String, Object?>{'goldEarned': 31},
    );

    await Future<void>.delayed(Duration.zero);
    expect(appState.progression.gold, 0);

    finalizeGate.complete();
    await submitFuture;
    expect(appState.progression.gold, 0);
  });

  test(
    'submitRunReplay syncs canonical gold when submission reward is final',
    () async {
      final runSessionApi = _FakeRunSessionApi(
        finalizeStatus: SubmissionStatus(
          runSessionId: 'run_final_reward',
          state: RunSessionState.validated,
          updatedAtMs: 6000,
          reward: SubmissionReward(
            status: SubmissionRewardStatus.finalReward,
            provisionalGold: 11,
            effectiveGoldDelta: 11,
            spendableGoldDelta: 11,
            updatedAtMs: 6000,
            grantId: 'run_final_reward',
          ),
        ),
      );
      final ownershipApi = _StaticOwnershipApi();
      final coordinator = RunSubmissionCoordinator(
        runSessionApi: runSessionApi,
        spoolStore: _InMemorySpoolStore(),
        replayUploader: _NoopReplayUploader(),
        clock: () => 6000,
      );
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownershipApi,
        runSessionApi: runSessionApi,
        runSubmissionCoordinator: coordinator,
      );
      await appState.bootstrap(force: true);
      ownershipApi.setCanonicalState(_canonicalWithGold(gold: 11, revision: 2));

      final status = await appState.submitRunReplay(
        runSessionId: 'run_final_reward',
        runMode: RunMode.practice,
        replayArtifactId: '/tmp/replay_final_reward.json',
        canonicalSha256:
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        contentLengthBytes: 1024,
      );

      expect(status.isRewardFinal, isTrue);
      expect(appState.progression.gold, 11);
      expect(ownershipApi.loadCanonicalStateCallCount, 2);
    },
  );

  test(
    'refreshRunSubmissionStatus syncs canonical gold and Codex when reward settles',
    () async {
      final runSessionApi = _MutableRunSessionApi(
        finalizeStatus: SubmissionStatus(
          runSessionId: 'run_refresh_final',
          state: RunSessionState.pendingValidation,
          updatedAtMs: 7000,
        ),
      );
      final ownershipApi = _StaticOwnershipApi();
      final coordinator = RunSubmissionCoordinator(
        runSessionApi: runSessionApi,
        spoolStore: _InMemorySpoolStore(),
        replayUploader: _NoopReplayUploader(),
        clock: () => 7000,
      );
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: ownershipApi,
        runSessionApi: runSessionApi,
        runSubmissionCoordinator: coordinator,
      );
      await appState.bootstrap(force: true);

      await appState.submitRunReplay(
        runSessionId: 'run_refresh_final',
        runMode: RunMode.practice,
        replayArtifactId: '/tmp/replay_refresh_final.json',
        canonicalSha256:
            '9999999999999999999999999999999999999999999999999999999999999999',
        contentLengthBytes: 1024,
        provisionalSummary: const <String, Object?>{'goldEarned': 23},
      );
      expect(appState.progression.gold, 0);

      ownershipApi.setCanonicalState(_canonicalWithGold(
        gold: 23,
        revision: 2,
        codex: CodexProgress(
          competitiveBestScores: {'forest': 10000},
        ),
        enemyDefeats: EnemyDefeats(byEnemy: {'grojib': 10}),
        playerProgress: const PlayerProgress(
          totalXp: 100,
          acceptedRuns: 1,
          damageDealt100: 500,
          damageTaken100: 100,
        ),
      ));
      runSessionApi.setLoadStatus(
        SubmissionStatus(
          runSessionId: 'run_refresh_final',
          state: RunSessionState.validated,
          updatedAtMs: 7100,
          reward: SubmissionReward(
            status: SubmissionRewardStatus.finalReward,
            provisionalGold: 23,
            effectiveGoldDelta: 23,
            spendableGoldDelta: 23,
            updatedAtMs: 7100,
            grantId: 'run_refresh_final',
          ),
        ),
      );

      final status = await appState.refreshRunSubmissionStatus(
        runSessionId: 'run_refresh_final',
      );

      expect(status.isRewardFinal, isTrue);
      expect(appState.progression.gold, 23);
      expect(appState.progression.enemyDefeats.byEnemy, {'grojib': 10});
      expect(appState.progression.codex.competitiveBestScores, {'forest': 10000});
      expect(appState.progression.playerProgress.totalXp, 100);
      expect(appState.progression.playerProgress.damageDealt100, 500);
      expect(ownershipApi.loadCanonicalStateCallCount, 2);
    },
  );

  test('processPendingRunSubmissions drains queued spool entries', () async {
    final runSessionApi = _FakeRunSessionApi(
      finalizeStatus: SubmissionStatus(
        runSessionId: 'run_pending',
        state: RunSessionState.validated,
        updatedAtMs: 2000,
      ),
    );
    final spoolStore = _InMemorySpoolStore();
    final coordinator = RunSubmissionCoordinator(
      runSessionApi: runSessionApi,
      spoolStore: spoolStore,
      replayUploader: _NoopReplayUploader(),
      clock: () => 2000,
    );
    await spoolStore.upsert(
      submission: PendingRunSubmission(
        ownerUserId: 'u1',
        runSessionId: 'run_pending',
        runMode: RunMode.practice,
        replayArtifactId: '/tmp/replay_pending.json',
        canonicalSha256:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        contentLengthBytes: 512,
        createdAtMs: 1500,
        updatedAtMs: 1500,
      ),
    );
    final appState = AppState(
      authApi: _StaticAuthApi.authenticated(),
      loadoutOwnershipApi: _StaticOwnershipApi(),
      runSessionApi: runSessionApi,
      runSubmissionCoordinator: coordinator,
    );
    await appState.bootstrap(force: true);

    final statuses = await appState.processPendingRunSubmissions();

    expect(statuses, hasLength(1));
    expect(statuses.single.phase, RunSubmissionPhase.validated);
    expect(
      appState.runSubmissionStatusFor('run_pending')?.phase,
      RunSubmissionPhase.validated,
    );
    expect(await spoolStore.load(runSessionId: 'run_pending'), isNull);
  });
}

class _NoopReplayUploader implements RunReplayUploader {
  @override
  Future<void> uploadReplay({
    required RunUploadGrant uploadGrant,
    required String replayArtifactId,
    required int contentLengthBytes,
    required String contentType,
  }) async {}
}

class _InMemorySpoolStore implements RunSubmissionSpoolStore {
  final Map<String, PendingRunSubmission> _entries =
      <String, PendingRunSubmission>{};

  @override
  Future<void> clear() async {
    _entries.clear();
  }

  @override
  Future<PendingRunSubmission?> load({required String runSessionId}) async {
    return _entries[runSessionId];
  }

  @override
  Future<List<PendingRunSubmission>> loadAll() async {
    return _entries.values.toList(growable: false);
  }

  @override
  Future<void> remove({required String runSessionId}) async {
    _entries.remove(runSessionId);
  }

  @override
  Future<void> upsert({required PendingRunSubmission submission}) async {
    _entries[submission.runSessionId] = submission;
  }
}

class _TestCompletionSource implements RunCompletionSource {
  _TestCompletionSource() {
    controller = StreamController<RunSubmissionResponse>.broadcast(onListen: () => listens++);
  }
  late final StreamController<RunSubmissionResponse> controller;
  int listens = 0;
  @override
  Stream<RunSubmissionResponse> watch({required String userId, required String runSessionId}) => controller.stream;
}

class _FakeRunSessionApi implements RunSessionApi {
  _FakeRunSessionApi({required this.finalizeStatus, this.canonical});

  final SubmissionStatus finalizeStatus;
  final OwnershipCanonicalState? canonical;
  int createUploadGrantCallCount = 0;

  @override
  Future<RunUploadGrant> createUploadGrant({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    createUploadGrantCallCount += 1;
    return RunUploadGrant(
      runSessionId: runSessionId,
      objectPath:
          'replay-submissions/pending/$userId/$runSessionId/replay.bin.gz',
      uploadUrl: 'https://upload.invalid/$runSessionId',
      uploadMethod: 'POST',
      uploadFields: const <String, String>{
        'Content-Type': 'application/octet-stream',
        'key': 'replay-submissions/pending/test/replay.bin.gz',
      },
      contentType: 'application/octet-stream',
      maxBytes: 8_388_608,
      expiresAtMs: 9_999_999,
    );
  }

  @override
  Future<RunTicket> createRunSession({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<RunSubmissionResponse> finalizeUpload({
    required String userId,
    required String sessionId,
    required String runSessionId,
    required String canonicalSha256,
    required int contentLengthBytes,
    String? contentType,
    String? objectPath,
    Map<String, Object?>? provisionalSummary,
  }) async {
    return RunSubmissionResponse(SubmissionStatus(
      runSessionId: runSessionId,
      state: finalizeStatus.state,
      updatedAtMs: finalizeStatus.updatedAtMs,
      message: finalizeStatus.message,
      validatedRun: finalizeStatus.validatedRun,
      reward: finalizeStatus.reward,
    ), canonical: canonical);
  }

  @override
  Future<RunSubmissionResponse> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    return RunSubmissionResponse(SubmissionStatus(
      runSessionId: runSessionId,
      state: finalizeStatus.state,
      updatedAtMs: finalizeStatus.updatedAtMs,
      message: finalizeStatus.message,
      validatedRun: finalizeStatus.validatedRun,
      reward: finalizeStatus.reward,
    ), canonical: canonical);
  }
}

class _BlockingFinalizeRunSessionApi extends _FakeRunSessionApi {
  _BlockingFinalizeRunSessionApi({
    required super.finalizeStatus,
    required Future<void> finalizeGate,
  }) : _finalizeGate = finalizeGate;

  final Future<void> _finalizeGate;

  @override
  Future<RunSubmissionResponse> finalizeUpload({
    required String userId,
    required String sessionId,
    required String runSessionId,
    required String canonicalSha256,
    required int contentLengthBytes,
    String? contentType,
    String? objectPath,
    Map<String, Object?>? provisionalSummary,
  }) async {
    await _finalizeGate;
    return super.finalizeUpload(
      userId: userId,
      sessionId: sessionId,
      runSessionId: runSessionId,
      canonicalSha256: canonicalSha256,
      contentLengthBytes: contentLengthBytes,
      contentType: contentType,
      objectPath: objectPath,
      provisionalSummary: provisionalSummary,
    );
  }
}

class _MutableRunSessionApi extends _FakeRunSessionApi {
  _MutableRunSessionApi({required super.finalizeStatus})
    : _loadStatus = finalizeStatus;

  SubmissionStatus _loadStatus;

  void setLoadStatus(SubmissionStatus status) {
    _loadStatus = status;
  }

  @override
  Future<RunSubmissionResponse> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    return RunSubmissionResponse(SubmissionStatus(
      runSessionId: runSessionId,
      state: _loadStatus.state,
      updatedAtMs: _loadStatus.updatedAtMs,
      message: _loadStatus.message,
      validatedRun: _loadStatus.validatedRun,
      reward: _loadStatus.reward,
    ));
  }
}

class _StaticAuthApi implements AuthApi {
  _StaticAuthApi._(this._session);

  factory _StaticAuthApi.authenticated() {
    return _StaticAuthApi._(
      const AuthSession(
        userId: 'u1',
        sessionId: 's1',
        isAnonymous: true,
        expiresAtMs: 0,
      ),
    );
  }

  AuthSession _session;

  @override
  Future<void> clearSession() async {}

  @override
  Future<AuthSession> ensureAuthenticatedSession() async => _session;

  @override
  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    return AuthLinkResult(
      provider: provider,
      status: AuthLinkStatus.alreadyLinked,
      session: _session,
    );
  }

  @override
  Future<AuthSession> loadSession() async => _session;

  @override
  Future<AuthSession> reauthenticateForSensitiveOperation() async => _session;
}

class _StaticOwnershipApi extends LoadoutOwnershipApi {
  _StaticOwnershipApi() : _canonical = _canonicalWithGold(gold: 0, revision: 1);

  OwnershipCanonicalState _canonical;
  int loadCanonicalStateCallCount = 0;
  bool failNextLoad = false;
  Future<void>? nextLoadGate;

  void setCanonicalState(OwnershipCanonicalState canonical) {
    _canonical = canonical;
  }

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async {
    loadCanonicalStateCallCount += 1;
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('offline');
    }
    final result = _canonical;
    final gate = nextLoadGate;
    nextLoadGate = null;
    if (gate != null) await gate;
    return result;
  }

  @override
  Future<OwnershipCommandResult> purchaseStoreOffer(
    PurchaseStoreOfferCommand command,
  ) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> refreshStore(
    RefreshStoreCommand command,
  ) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> setAbilitySlot(
    SetAbilitySlotCommand command,
  ) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  ) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> setSelection(
    SetSelectionCommand command,
  ) async {
    return _acceptedNoop();
  }

  OwnershipCommandResult _acceptedNoop() {
    return OwnershipCommandResult(
      canonicalState: _canonical,
      newRevision: _canonical.revision,
      replayedFromIdempotency: false,
    );
  }
}

OwnershipCanonicalState _canonicalWithGold({
  required int gold,
  required int revision,
  CodexProgress codex = CodexProgress.empty,
  EnemyDefeats enemyDefeats = EnemyDefeats.empty,
  PlayerProgress playerProgress = PlayerProgress.empty,
  List<String> appliedRewardGrantIds = const [],
}) {
  return OwnershipCanonicalState(
    profileId: 'profile_static',
    revision: revision,
    selection: SelectionState.defaults,
    meta: const MetaService().createNew(),
    progression: ProgressionState.initial.copyWith(
      gold: gold,
      codex: codex,
      enemyDefeats: enemyDefeats,
      playerProgress: playerProgress,
      appliedRewardGrantIds: appliedRewardGrantIds,
    ),
  );
}
