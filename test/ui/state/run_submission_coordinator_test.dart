import 'package:flutter_test/flutter_test.dart';

import 'dart:async';

import 'package:rpg_runner/ui/state/run/local_replay_artifact_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:run_protocol/run_ticket.dart';
import 'package:run_protocol/submission_status.dart';

import 'package:rpg_runner/ui/state/run/pending_run_submission.dart';
import 'package:rpg_runner/ui/state/run/run_session_api.dart';
import 'package:rpg_runner/ui/state/run/run_submission_coordinator.dart';
import 'package:rpg_runner/ui/state/run/run_submission_spool_store.dart';
import 'package:rpg_runner/ui/state/run/run_submission_status.dart';
import 'package:rpg_runner/ui/state/run/run_start_remote_exception.dart';

void main() {
  test(
    'an upload finishing after discard cannot recreate retry metadata',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final spool = _InMemorySpoolStore();
      final uploader = _FakeReplayUploader()
        ..onUpload = (() {
          started.complete();
        })
        ..uploadGate = release.future
        ..uploadFailure = const RunReplayUploadException(
          code: 'network',
          message: 'upload interrupted',
        );
      final coordinator = RunSubmissionCoordinator(
        runSessionApi: _FakeRunSessionApi(),
        spoolStore: spool,
        replayUploader: uploader,
        localReplayArtifactStore: _NoopLocalReplayArtifactStore(),
      );
      await coordinator.enqueueSubmission(
        userId: 'u1',
        runSessionId: 'run_late_upload',
        runMode: RunMode.practice,
        replayArtifactId: 'replay.json',
        canonicalSha256: 'a' * 64,
        contentLengthBytes: 10,
        contentType: 'application/json',
      );
      final upload = coordinator.processRunSession(
        userId: 'u1',
        sessionId: 's1',
        runSessionId: 'run_late_upload',
      );
      await started.future;
      await coordinator.discardAllLocalSubmissions();
      release.complete();
      await upload;
      expect(await spool.loadAll(), isEmpty);
    },
  );

  test('discard waits for started spool writes and prevents late upload metadata from returning', () async {
    final writeStarted = Completer<void>();
    final finishWrite = Completer<void>();
    final spool = _BlockingSpoolStore(writeStarted, finishWrite);
    final coordinator = RunSubmissionCoordinator(
      runSessionApi: _FakeRunSessionApi(),
      spoolStore: spool,
      localReplayArtifactStore: _NoopLocalReplayArtifactStore(),
    );
    final enqueue = coordinator.enqueueSubmission(
      userId: 'u1',
      runSessionId: 'run_discard',
      runMode: RunMode.practice,
      replayArtifactId: 'replay.json',
      canonicalSha256: 'a' * 64,
      contentLengthBytes: 10,
      contentType: 'application/json',
    );
    await writeStarted.future;
    final cleanup = coordinator.discardAllLocalSubmissions();
    finishWrite.complete();
    await enqueue;
    await cleanup;
    expect(await spool.loadAll(), isEmpty);
    expect(
      await coordinator.processReadySubmissions(userId: 'u1', sessionId: 's1'),
      isEmpty,
    );
    await expectLater(
      coordinator.enqueueSubmission(
        userId: 'u1',
        runSessionId: 'run_again',
        runMode: RunMode.practice,
        replayArtifactId: 'replay.json',
        canonicalSha256: 'a' * 64,
        contentLengthBytes: 10,
        contentType: 'application/json',
      ),
      throwsStateError,
    );
  });

  group('RunSubmissionCoordinator', () {
    late _InMemorySpoolStore spoolStore;
    late _FakeRunSessionApi runSessionApi;
    late _FakeReplayUploader replayUploader;
    late _FakeClock clock;
    late RunSubmissionCoordinator coordinator;

    setUp(() {
      spoolStore = _InMemorySpoolStore();
      runSessionApi = _FakeRunSessionApi();
      replayUploader = _FakeReplayUploader();
      clock = _FakeClock(startMs: 1_700_000_000_000);
      coordinator = RunSubmissionCoordinator(
        runSessionApi: runSessionApi,
        spoolStore: spoolStore,
        replayUploader: replayUploader,
        clock: clock.now,
      );
    });

    Future<void> queueRecoveryRun() => coordinator.enqueueSubmission(
      userId: 'uid_recovery',
      runSessionId: 'run_recovery',
      runMode: RunMode.practice,
      replayArtifactId: '/tmp/recovery.replay.json',
      canonicalSha256: 'a' * 64,
      contentLengthBytes: 2048,
    );

    Future<RunSubmissionStatus> recover() => coordinator.processRunSession(
      userId: 'uid_recovery',
      sessionId: 'session_recovery',
      runSessionId: 'run_recovery',
    );

    Future<void> prepare() => coordinator.prepareUpload(
      userId: 'uid_recovery',
      sessionId: 'session_recovery',
      runSessionId: 'run_recovery',
    );

    test('run preparation reuses a valid grant exactly once', () async {
      await prepare();
      await prepare();
      await queueRecoveryRun();
      await recover();
      expect(runSessionApi.grantRunSessionIds, ['run_recovery']);
      expect(replayUploader.uploadedRunSessionIds, ['run_recovery']);
    });

    test('expired prepared permission is renewed before uploading', () async {
      runSessionApi.grantExpiresAtMs = clock.now() + 60000;
      await prepare();
      clock.advance(const Duration(seconds: 31));
      runSessionApi.grantExpiresAtMs = clock.now() + 60000;
      await queueRecoveryRun();
      await recover();
      expect(runSessionApi.grantRunSessionIds.length, 2);
      expect(replayUploader.uploadedRunSessionIds.length, 1);
    });

    test('failed preparation does not prevent normal submission', () async {
      runSessionApi.grantFailure = const RunStartRemoteException(
        code: 'unavailable',
        message: 'offline',
      );
      await prepare();
      runSessionApi.grantFailure = null;
      await queueRecoveryRun();
      await recover();
      expect(replayUploader.uploadedRunSessionIds.length, 1);
    });

    test('account reset discards prepared credentials', () async {
      await prepare();
      coordinator.clearPreparedUploads();
      await queueRecoveryRun();
      await recover();
      expect(runSessionApi.grantRunSessionIds.length, 2);
    });

    for (final state in [
      RunSessionState.uploaded,
      RunSessionState.validating,
      RunSessionState.settlementPending,
      RunSessionState.validated,
    ]) {
      test(
        'lost finalize response recovers $state without another upload',
        () async {
          await queueRecoveryRun();
          runSessionApi.finalizeFailure = const RunStartRemoteException(
            code: 'unavailable',
            message: 'Response lost after server commit',
          );
          expect((await recover()).phase, RunSubmissionPhase.retryScheduled);
          final before = await spoolStore.load(runSessionId: 'run_recovery');
          expect(before!.uploadCompletedAtMs, isNotNull);
          clock.advance(const Duration(seconds: 2));
          runSessionApi.loadStatus = SubmissionStatus(
            runSessionId: 'run_recovery',
            state: state,
            updatedAtMs: clock.now(),
            reward: state == RunSessionState.validated
                ? SubmissionReward(
                    status: SubmissionRewardStatus.finalReward,
                    provisionalGold: 11,
                    effectiveGoldDelta: 11,
                    spendableGoldDelta: 11,
                    updatedAtMs: clock.now(),
                    grantId: 'run_recovery',
                  )
                : null,
          );
          final recovered = await recover();
          expect(recovered.serverStatus!.state, state);
          expect(runSessionApi.grantRunSessionIds, ['run_recovery']);
          expect(replayUploader.uploadedRunSessionIds, ['run_recovery']);
          expect(runSessionApi.finalizeRunSessionIds, ['run_recovery']);
          expect(
            (await spoolStore.load(runSessionId: 'run_recovery'))!.step,
            PendingRunSubmissionStep.awaitingServerStatus,
          );
          if (state == RunSessionState.validated) {
            expect(recovered.isRewardFinal, isTrue);
            await coordinator.acknowledgeFinalReward(
              runSessionId: 'run_recovery',
            );
            expect(await spoolStore.loadAll(), isEmpty);
          }
        },
      );
    }

    test(
      'restart after upload resumes finalization using the saved object',
      () async {
        await queueRecoveryRun();
        final queued = (await spoolStore.load(runSessionId: 'run_recovery'))!;
        await spoolStore.upsert(
          submission: queued.copyWith(
            step: PendingRunSubmissionStep.finalizing,
            uploadCompletedAtMs: clock.now(),
            objectPath: 'saved/object/path',
          ),
        );
        runSessionApi.loadStatus = SubmissionStatus(
          runSessionId: 'run_recovery',
          state: RunSessionState.uploading,
          updatedAtMs: clock.now(),
        );
        final status = await recover();
        expect(status.phase, RunSubmissionPhase.pendingValidation);
        expect(runSessionApi.grantRunSessionIds, isEmpty);
        expect(replayUploader.uploadedRunSessionIds, isEmpty);
        expect(runSessionApi.finalizeObjectPaths, ['saved/object/path']);
      },
    );

    test(
      'malformed finalize response preserves ambiguous outcome for recovery',
      () async {
        await queueRecoveryRun();
        runSessionApi.finalizeFailure = const FormatException(
          'Truncated response',
        );
        expect((await recover()).phase, RunSubmissionPhase.retryScheduled);
        expect(await spoolStore.load(runSessionId: 'run_recovery'), isNotNull);
      },
    );

    test('failed recovery lookup preserves the upload and does not reissue a grant', () async {
      await queueRecoveryRun();
      runSessionApi.finalizeFailure = const RunStartRemoteException(
        code: 'unavailable',
      );
      await recover();
      clock.advance(const Duration(seconds: 2));
      runSessionApi.loadStatusFailure = const RunStartRemoteException(
        code: 'unavailable',
      );
      expect((await recover()).phase, RunSubmissionPhase.retryScheduled);
      expect(runSessionApi.grantRunSessionIds, ['run_recovery']);
      expect(replayUploader.uploadedRunSessionIds, ['run_recovery']);
      expect(
        (await spoolStore.load(runSessionId: 'run_recovery'))!
            .uploadCompletedAtMs,
        isNotNull,
      );
    });

    test('processRunSession uploads + finalizes and keeps non-terminal pending', () async {
      await coordinator.enqueueSubmission(
        userId: 'uid_1',
        runSessionId: 'run_1',
        runMode: RunMode.practice,
        replayArtifactId: '/tmp/run_1.replay.json',
        canonicalSha256:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        contentLengthBytes: 2048,
      );

      runSessionApi.finalizeStatus = SubmissionStatus(
        runSessionId: 'run_1',
        state: RunSessionState.pendingValidation,
        updatedAtMs: clock.now(),
      );

      final status = await coordinator.processRunSession(
        userId: 'uid_1',
        sessionId: 'session_1',
        runSessionId: 'run_1',
      );

      expect(status.phase, RunSubmissionPhase.pendingValidation);
      expect(replayUploader.uploadedRunSessionIds, <String>['run_1']);
      expect(runSessionApi.finalizeRunSessionIds, <String>['run_1']);
      expect(
        runSessionApi.finalizeObjectPaths.single,
        'replay-submissions/pending/uid_1/run_1/replay.bin.gz',
      );

      final pending = await spoolStore.load(runSessionId: 'run_1');
      expect(pending, isNotNull);
      expect(pending!.step, PendingRunSubmissionStep.awaitingServerStatus);
    });

    test('a forced close after journaling resumes submission on the next bootstrap', () async {
      await coordinator.enqueueSubmission(
        userId: 'uid_restart',
        runSessionId: 'run_forced_close',
        runMode: RunMode.practice,
        replayArtifactId: '/tmp/run_forced_close.replay.json',
        canonicalSha256:
            'abababababababababababababababababababababababababababababababab',
        contentLengthBytes: 1024,
      );

      // Simulate process death: no upload/finalize future survives this point.
      final afterRestart = RunSubmissionCoordinator(
        runSessionApi: runSessionApi,
        spoolStore: spoolStore,
        replayUploader: replayUploader,
        clock: clock.now,
      );
      runSessionApi.finalizeStatus = SubmissionStatus(
        runSessionId: 'run_forced_close',
        state: RunSessionState.pendingValidation,
        updatedAtMs: clock.now(),
      );

      final statuses = await afterRestart.processReadySubmissions(
        userId: 'uid_restart',
        sessionId: 'session_restart',
      );

      expect(statuses.single.phase, RunSubmissionPhase.pendingValidation);
      expect(replayUploader.uploadedRunSessionIds, <String>[
        'run_forced_close',
      ]);
      expect(runSessionApi.finalizeRunSessionIds, <String>['run_forced_close']);
      expect(
        await spoolStore.load(runSessionId: 'run_forced_close'),
        isNotNull,
      );
    });

    test('does not process a replay journaled by another account', () async {
      await coordinator.enqueueSubmission(
        userId: 'uid_a',
        runSessionId: 'run_owned_by_a',
        runMode: RunMode.practice,
        replayArtifactId: '/tmp/run_owned_by_a.replay.json',
        canonicalSha256:
            'abababababababababababababababababababababababababababababababab',
        contentLengthBytes: 1024,
      );

      final statuses = await coordinator.processReadySubmissions(
        userId: 'uid_b',
        sessionId: 'session_b',
      );

      expect(statuses, isEmpty);
      expect(await spoolStore.load(runSessionId: 'run_owned_by_a'), isNotNull);
      expect(replayUploader.uploadedRunSessionIds, isEmpty);
      expect(runSessionApi.finalizeRunSessionIds, isEmpty);
    });

    test('processRunSession removes local spool row for terminal status', () async {
      await coordinator.enqueueSubmission(
        userId: 'uid_2',
        runSessionId: 'run_2',
        runMode: RunMode.practice,
        replayArtifactId: '/tmp/run_2.replay.json',
        canonicalSha256:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        contentLengthBytes: 1024,
      );
      runSessionApi.finalizeStatus = SubmissionStatus(
        runSessionId: 'run_2',
        state: RunSessionState.validated,
        updatedAtMs: clock.now(),
      );

      final status = await coordinator.processRunSession(
        userId: 'uid_2',
        sessionId: 'session_2',
        runSessionId: 'run_2',
      );

      expect(status.phase, RunSubmissionPhase.validated);
      final pending = await spoolStore.load(runSessionId: 'run_2');
      expect(pending, isNull);
    });

    test('processRunSession schedules retry when grant fails', () async {
      await coordinator.enqueueSubmission(
        userId: 'uid_3',
        runSessionId: 'run_3',
        runMode: RunMode.practice,
        replayArtifactId: '/tmp/run_3.replay.json',
        canonicalSha256:
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        contentLengthBytes: 1024,
      );
      runSessionApi.grantFailure = const RunStartRemoteException(
        code: 'unavailable',
        message: 'simulated',
      );

      final status = await coordinator.processRunSession(
        userId: 'uid_3',
        sessionId: 'session_3',
        runSessionId: 'run_3',
      );

      expect(status.phase, RunSubmissionPhase.retryScheduled);
      expect(
        status.nextRetryAtMs,
        clock.now() + const Duration(seconds: 2).inMilliseconds,
      );

      final pending = await spoolStore.load(runSessionId: 'run_3');
      expect(pending, isNotNull);
      expect(pending!.step, PendingRunSubmissionStep.retryScheduled);
      expect(pending.attemptCount, 1);
      expect(pending.lastErrorCode, 'unavailable');
    });

    test(
      'quota throttling retains a slower retry than a network failure',
      () async {
        await queueRecoveryRun();
        runSessionApi.grantFailure = const RunStartRemoteException(
          code: 'resource-exhausted',
        );
        final result = await recover();
        expect(result.nextRetryAtMs, clock.now() + 30000);
      },
    );

    test(
      'expired authentication preserves the pending replay for renewed auth',
      () async {
        await queueRecoveryRun();
        runSessionApi.grantFailure = const RunStartRemoteException(
          code: 'unauthenticated',
        );
        expect((await recover()).phase, RunSubmissionPhase.retryScheduled);
        expect(await spoolStore.load(runSessionId: 'run_recovery'), isNotNull);
      },
    );

    test('processRunSession marks non-retryable upload failures terminal', () async {
      await coordinator.enqueueSubmission(
        userId: 'uid_403',
        runSessionId: 'run_403',
        runMode: RunMode.practice,
        replayArtifactId: '/tmp/run_403.replay.json',
        canonicalSha256:
            'abababababababababababababababababababababababababababababababab',
        contentLengthBytes: 1024,
      );
      replayUploader.uploadFailure = const RunReplayUploadException(
        code: 'upload-access-denied',
        message:
            'Replay upload denied (HTTP 403): replay upload service account '
            'is missing storage.objects.create permission.',
        statusCode: 403,
      );

      final status = await coordinator.processRunSession(
        userId: 'uid_403',
        sessionId: 'session_403',
        runSessionId: 'run_403',
      );

      expect(status.phase, RunSubmissionPhase.internalError);
      expect(status.message, contains('storage.objects.create'));
      expect(await spoolStore.load(runSessionId: 'run_403'), isNull);
    });

    test('processRunSession awaiting server status does not re-upload replay', () async {
      await coordinator.enqueueSubmission(
        userId: 'uid_await',
        runSessionId: 'run_await',
        runMode: RunMode.practice,
        replayArtifactId: '/tmp/run_await.replay.json',
        canonicalSha256:
            '1212121212121212121212121212121212121212121212121212121212121212',
        contentLengthBytes: 1024,
      );
      final pending = (await spoolStore.load(runSessionId: 'run_await'))!
          .copyWith(step: PendingRunSubmissionStep.awaitingServerStatus);
      await spoolStore.upsert(submission: pending);
      runSessionApi.loadStatus = SubmissionStatus(
        runSessionId: 'run_await',
        state: RunSessionState.pendingValidation,
        updatedAtMs: clock.now(),
      );

      final status = await coordinator.processRunSession(
        userId: 'uid_await',
        sessionId: 'session_await',
        runSessionId: 'run_await',
      );

      expect(status.phase, RunSubmissionPhase.pendingValidation);
      expect(replayUploader.uploadedRunSessionIds, isEmpty);
      expect(runSessionApi.finalizeRunSessionIds, isEmpty);
      expect(runSessionApi.loadStatusRunSessionIds, <String>['run_await']);
    });

    test('refreshRunSessionStatus keeps deferred retry state instead of server uploading', () async {
      await coordinator.enqueueSubmission(
        userId: 'uid_retry',
        runSessionId: 'run_retry',
        runMode: RunMode.practice,
        replayArtifactId: '/tmp/run_retry.replay.json',
        canonicalSha256:
            '3434343434343434343434343434343434343434343434343434343434343434',
        contentLengthBytes: 1024,
      );
      final deferred = (await spoolStore.load(runSessionId: 'run_retry'))!
          .copyWith(
            step: PendingRunSubmissionStep.retryScheduled,
            attemptCount: 1,
            nextAttemptAtMs:
                clock.now() + const Duration(seconds: 30).inMilliseconds,
            lastErrorCode: 'upload-access-denied',
            lastErrorMessage: 'Replay upload denied',
          );
      await spoolStore.upsert(submission: deferred);
      runSessionApi.loadStatus = SubmissionStatus(
        runSessionId: 'run_retry',
        state: RunSessionState.uploading,
        updatedAtMs: clock.now(),
      );

      final status = await coordinator.refreshRunSessionStatus(
        userId: 'uid_retry',
        sessionId: 'session_retry',
        runSessionId: 'run_retry',
      );

      expect(status.phase, RunSubmissionPhase.retryScheduled);
      expect(status.message, 'Replay upload denied');
      expect(runSessionApi.loadStatusRunSessionIds, isEmpty);
    });

    test('refreshRunSessionStatus removes local spool row when server terminal', () async {
      await coordinator.enqueueSubmission(
        userId: 'uid_4',
        runSessionId: 'run_4',
        runMode: RunMode.practice,
        replayArtifactId: '/tmp/run_4.replay.json',
        canonicalSha256:
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        contentLengthBytes: 1024,
      );
      final pending = (await spoolStore.load(runSessionId: 'run_4'))!
          .copyWith(step: PendingRunSubmissionStep.awaitingServerStatus);
      await spoolStore.upsert(submission: pending);
      runSessionApi.loadStatus = SubmissionStatus(
        runSessionId: 'run_4',
        state: RunSessionState.rejected,
        updatedAtMs: clock.now(),
      );

      final status = await coordinator.refreshRunSessionStatus(
        userId: 'uid_4',
        sessionId: 'session_4',
        runSessionId: 'run_4',
      );

      expect(status.phase, RunSubmissionPhase.rejected);
      final loaded = await spoolStore.load(runSessionId: 'run_4');
      expect(loaded, isNull);
    });
  });
}

class _FakeClock {
  _FakeClock({required int startMs}) : _nowMs = startMs;

  int _nowMs;

  int now() => _nowMs;
  void advance(Duration duration) => _nowMs += duration.inMilliseconds;
}

class _FakeReplayUploader implements RunReplayUploader {
  final List<String> uploadedRunSessionIds = <String>[];
  Object? uploadFailure;
  void Function()? onUpload;
  Future<void>? uploadGate;

  @override
  Future<void> uploadReplay({
    required RunUploadGrant uploadGrant,
    required String replayArtifactId,
    required int contentLengthBytes,
    required String contentType,
  }) async {
    onUpload?.call();
    if (uploadGate != null) await uploadGate;
    if (uploadFailure != null) {
      throw uploadFailure!;
    }
    uploadedRunSessionIds.add(uploadGrant.runSessionId);
  }
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
    final values = _entries.values.toList(growable: false)
      ..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    return values;
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

class _BlockingSpoolStore extends _InMemorySpoolStore {
  _BlockingSpoolStore(this.started, this.release);
  final Completer<void> started;
  final Completer<void> release;
  @override
  Future<void> upsert({required PendingRunSubmission submission}) async {
    started.complete();
    await release.future;
    await super.upsert(submission: submission);
  }
}

class _NoopLocalReplayArtifactStore implements LocalReplayArtifactStore {
  @override
  Future<void> clear() async {}
}

class _FakeRunSessionApi implements RunSessionApi {
  int grantExpiresAtMs = 1_800_000_000_000;
  SubmissionStatus finalizeStatus = SubmissionStatus(
    runSessionId: 'run_default',
    state: RunSessionState.pendingValidation,
    updatedAtMs: 0,
  );
  SubmissionStatus loadStatus = SubmissionStatus(
    runSessionId: 'run_default',
    state: RunSessionState.pendingValidation,
    updatedAtMs: 0,
  );
  Object? grantFailure;
  Object? finalizeFailure;
  Object? loadStatusFailure;
  final List<String> grantRunSessionIds = <String>[];
  final List<String> loadStatusRunSessionIds = <String>[];
  final List<String> finalizeRunSessionIds = <String>[];
  final List<String?> finalizeObjectPaths = <String?>[];

  @override
  Future<RunUploadGrant> createUploadGrant({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    grantRunSessionIds.add(runSessionId);
    if (grantFailure != null) {
      throw grantFailure!;
    }
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
      expiresAtMs: grantExpiresAtMs,
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
    finalizeRunSessionIds.add(runSessionId);
    finalizeObjectPaths.add(objectPath);
    if (finalizeFailure != null) throw finalizeFailure!;
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
    loadStatusRunSessionIds.add(runSessionId);
    if (loadStatusFailure != null) throw loadStatusFailure!;
    return SubmissionStatus(
      runSessionId: runSessionId,
      state: loadStatus.state,
      updatedAtMs: loadStatus.updatedAtMs,
      message: loadStatus.message,
      validatedRun: loadStatus.validatedRun,
      reward: loadStatus.reward,
    );
  }
}
