import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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

void main() {
  test('submitRunReplay preserves reward payload from server status', () async {
    final runSessionApi = _FakeRunSessionApi(
      finalizeStatus: const SubmissionStatus(
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
      replayFilePath: '/tmp/replay_reward.json',
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
    expect(appState.unverifiedGold, 17);
    expect(appState.displayGold, 17);
  });

  test(
    'submitRunReplay surfaces provisionalSummary gold in displayGold before verification',
    () async {
      final runSessionApi = _FakeRunSessionApi(
        finalizeStatus: const SubmissionStatus(
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
        replayFilePath: '/tmp/replay_pending_reward.json',
        canonicalSha256:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        contentLengthBytes: 1024,
        provisionalSummary: const <String, Object?>{'goldEarned': 23},
      );

      expect(status.hasProvisionalReward, isFalse);
      expect(status.displayProvisionalGold, 23);
      expect(appState.unverifiedGold, 23);
      expect(appState.displayGold, 23);
    },
  );

  test('submitRunReplay stores latest status in AppState', () async {
    final runSessionApi = _FakeRunSessionApi(
      finalizeStatus: const SubmissionStatus(
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
      replayFilePath: '/tmp/replay.json',
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

  test(
    'submitRunReplay updates displayGold immediately while submission is in flight',
    () async {
      final finalizeGate = Completer<void>();
      final runSessionApi = _BlockingFinalizeRunSessionApi(
        finalizeStatus: const SubmissionStatus(
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
        replayFilePath: '/tmp/replay_immediate_gold.json',
        canonicalSha256:
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        contentLengthBytes: 1024,
        provisionalSummary: const <String, Object?>{'goldEarned': 31},
      );

      await Future<void>.delayed(Duration.zero);
      expect(appState.unverifiedGold, 31);
      expect(appState.displayGold, 31);

      finalizeGate.complete();
      await submitFuture;
      expect(appState.unverifiedGold, 31);
      expect(appState.displayGold, 31);
    },
  );

  test(
    'submitRunReplay syncs canonical gold when submission reward is final',
    () async {
      final runSessionApi = _FakeRunSessionApi(
        finalizeStatus: const SubmissionStatus(
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
        replayFilePath: '/tmp/replay_final_reward.json',
        canonicalSha256:
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        contentLengthBytes: 1024,
      );

      expect(status.isRewardFinal, isTrue);
      expect(appState.unverifiedGold, 0);
      expect(appState.displayGold, 11);
      expect(ownershipApi.loadCanonicalStateCallCount, 2);
    },
  );

  test(
    'refreshRunSubmissionStatus syncs canonical gold when reward settles',
    () async {
      final runSessionApi = _MutableRunSessionApi(
        finalizeStatus: const SubmissionStatus(
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
        replayFilePath: '/tmp/replay_refresh_final.json',
        canonicalSha256:
            '9999999999999999999999999999999999999999999999999999999999999999',
        contentLengthBytes: 1024,
        provisionalSummary: const <String, Object?>{'goldEarned': 23},
      );
      expect(appState.unverifiedGold, 23);
      expect(appState.displayGold, 23);

      ownershipApi.setCanonicalState(_canonicalWithGold(gold: 23, revision: 2));
      runSessionApi.setLoadStatus(
        const SubmissionStatus(
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
      expect(appState.unverifiedGold, 0);
      expect(appState.displayGold, 23);
      expect(ownershipApi.loadCanonicalStateCallCount, 2);
    },
  );

  test('processPendingRunSubmissions drains queued spool entries', () async {
    final runSessionApi = _FakeRunSessionApi(
      finalizeStatus: const SubmissionStatus(
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
        runSessionId: 'run_pending',
        runMode: RunMode.practice,
        replayFilePath: '/tmp/replay_pending.json',
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
    required String replayFilePath,
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

class _FakeRunSessionApi implements RunSessionApi {
  _FakeRunSessionApi({required this.finalizeStatus});

  final SubmissionStatus finalizeStatus;

  @override
  Future<RunUploadGrant> createUploadGrant({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    return RunUploadGrant(
      runSessionId: runSessionId,
      objectPath:
          'replay-submissions/pending/$userId/$runSessionId/replay.bin.gz',
      uploadUrl: 'https://upload.invalid/$runSessionId',
      uploadMethod: 'PUT',
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
  Future<SubmissionStatus> finalizeUpload({
    required String userId,
    required String sessionId,
    required String runSessionId,
    required String canonicalSha256,
    required int contentLengthBytes,
    String? contentType,
    String? objectPath,
    Map<String, Object?>? provisionalSummary,
  }) async {
    return SubmissionStatus(
      runSessionId: runSessionId,
      state: finalizeStatus.state,
      updatedAtMs: finalizeStatus.updatedAtMs,
      message: finalizeStatus.message,
      validatedRun: finalizeStatus.validatedRun,
      reward: finalizeStatus.reward,
    );
  }

  @override
  Future<SubmissionStatus> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    return SubmissionStatus(
      runSessionId: runSessionId,
      state: finalizeStatus.state,
      updatedAtMs: finalizeStatus.updatedAtMs,
      message: finalizeStatus.message,
      validatedRun: finalizeStatus.validatedRun,
      reward: finalizeStatus.reward,
    );
  }
}

class _BlockingFinalizeRunSessionApi extends _FakeRunSessionApi {
  _BlockingFinalizeRunSessionApi({
    required super.finalizeStatus,
    required Future<void> finalizeGate,
  }) : _finalizeGate = finalizeGate;

  final Future<void> _finalizeGate;

  @override
  Future<SubmissionStatus> finalizeUpload({
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
  Future<SubmissionStatus> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    return SubmissionStatus(
      runSessionId: runSessionId,
      state: _loadStatus.state,
      updatedAtMs: _loadStatus.updatedAtMs,
      message: _loadStatus.message,
      validatedRun: _loadStatus.validatedRun,
      reward: _loadStatus.reward,
    );
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

  final AuthSession _session;

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
}

class _StaticOwnershipApi implements LoadoutOwnershipApi {
  _StaticOwnershipApi() : _canonical = _canonicalWithGold(gold: 0, revision: 1);

  OwnershipCanonicalState _canonical;
  int loadCanonicalStateCallCount = 0;

  void setCanonicalState(OwnershipCanonicalState canonical) {
    _canonical = canonical;
  }

  @override
  Future<OwnershipCommandResult> awardRunGold(
    AwardRunGoldCommand command,
  ) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> learnProjectileSpell(
    LearnProjectileSpellCommand command,
  ) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCommandResult> learnSpellAbility(
    LearnSpellAbilityCommand command,
  ) async {
    return _acceptedNoop();
  }

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async {
    loadCanonicalStateCallCount += 1;
    return _canonical;
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
  Future<OwnershipCommandResult> resetOwnership(
    ResetOwnershipCommand command,
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

  @override
  Future<OwnershipCommandResult> unlockGear(UnlockGearCommand command) async {
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
}) {
  return OwnershipCanonicalState(
    profileId: 'profile_static',
    revision: revision,
    selection: SelectionState.defaults,
    meta: const MetaService().createNew(),
    progression: ProgressionState.initial.copyWith(gold: gold),
  );
}
