import 'package:flutter_test/flutter_test.dart';
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

    test(
      'processRunSession uploads + finalizes and keeps non-terminal pending',
      () async {
        await coordinator.enqueueSubmission(
          runSessionId: 'run_1',
          runMode: RunMode.practice,
          replayFilePath: '/tmp/run_1.replay.json',
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
      },
    );

    test(
      'processRunSession removes local spool row for terminal status',
      () async {
        await coordinator.enqueueSubmission(
          runSessionId: 'run_2',
          runMode: RunMode.practice,
          replayFilePath: '/tmp/run_2.replay.json',
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
      },
    );

    test('processRunSession schedules retry when grant fails', () async {
      await coordinator.enqueueSubmission(
        runSessionId: 'run_3',
        runMode: RunMode.practice,
        replayFilePath: '/tmp/run_3.replay.json',
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
        clock.now() + const Duration(seconds: 30).inMilliseconds,
      );

      final pending = await spoolStore.load(runSessionId: 'run_3');
      expect(pending, isNotNull);
      expect(pending!.step, PendingRunSubmissionStep.retryScheduled);
      expect(pending.attemptCount, 1);
      expect(pending.lastErrorCode, 'unavailable');
    });

    test(
      'processRunSession marks non-retryable upload failures terminal',
      () async {
        await coordinator.enqueueSubmission(
          runSessionId: 'run_403',
          runMode: RunMode.practice,
          replayFilePath: '/tmp/run_403.replay.json',
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
      },
    );

    test(
      'processRunSession awaiting server status does not re-upload replay',
      () async {
        await coordinator.enqueueSubmission(
          runSessionId: 'run_await',
          runMode: RunMode.practice,
          replayFilePath: '/tmp/run_await.replay.json',
          canonicalSha256:
              '1212121212121212121212121212121212121212121212121212121212121212',
          contentLengthBytes: 1024,
        );
        final pending = (await spoolStore.load(
          runSessionId: 'run_await',
        ))!.copyWith(step: PendingRunSubmissionStep.awaitingServerStatus);
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
      },
    );

    test(
      'refreshRunSessionStatus keeps deferred retry state instead of server uploading',
      () async {
        await coordinator.enqueueSubmission(
          runSessionId: 'run_retry',
          runMode: RunMode.practice,
          replayFilePath: '/tmp/run_retry.replay.json',
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
      },
    );

    test(
      'refreshRunSessionStatus removes local spool row when server terminal',
      () async {
        await coordinator.enqueueSubmission(
          runSessionId: 'run_4',
          runMode: RunMode.practice,
          replayFilePath: '/tmp/run_4.replay.json',
          canonicalSha256:
              'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          contentLengthBytes: 1024,
        );
        final pending = (await spoolStore.load(
          runSessionId: 'run_4',
        ))!.copyWith(step: PendingRunSubmissionStep.awaitingServerStatus);
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
      },
    );
  });
}

class _FakeClock {
  _FakeClock({required int startMs}) : _nowMs = startMs;

  final int _nowMs;

  int now() => _nowMs;
}

class _FakeReplayUploader implements RunReplayUploader {
  final List<String> uploadedRunSessionIds = <String>[];
  Object? uploadFailure;

  @override
  Future<void> uploadReplay({
    required RunUploadGrant uploadGrant,
    required String replayFilePath,
    required int contentLengthBytes,
    required String contentType,
  }) async {
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

class _FakeRunSessionApi implements RunSessionApi {
  SubmissionStatus finalizeStatus = const SubmissionStatus(
    runSessionId: 'run_default',
    state: RunSessionState.pendingValidation,
    updatedAtMs: 0,
  );
  SubmissionStatus loadStatus = const SubmissionStatus(
    runSessionId: 'run_default',
    state: RunSessionState.pendingValidation,
    updatedAtMs: 0,
  );
  Object? grantFailure;
  final List<String> loadStatusRunSessionIds = <String>[];
  final List<String> finalizeRunSessionIds = <String>[];
  final List<String?> finalizeObjectPaths = <String?>[];

  @override
  Future<RunUploadGrant> createUploadGrant({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    if (grantFailure != null) {
      throw grantFailure!;
    }
    return RunUploadGrant(
      runSessionId: runSessionId,
      objectPath:
          'replay-submissions/pending/$userId/$runSessionId/replay.bin.gz',
      uploadUrl: 'https://upload.invalid/$runSessionId',
      uploadMethod: 'PUT',
      contentType: 'application/octet-stream',
      maxBytes: 8_388_608,
      expiresAtMs: 1_800_000_000_000,
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
    return SubmissionStatus(
      runSessionId: runSessionId,
      state: finalizeStatus.state,
      updatedAtMs: finalizeStatus.updatedAtMs,
      message: finalizeStatus.message,
      validatedRun: finalizeStatus.validatedRun,
    );
  }

  @override
  Future<SubmissionStatus> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    loadStatusRunSessionIds.add(runSessionId);
    return SubmissionStatus(
      runSessionId: runSessionId,
      state: loadStatus.state,
      updatedAtMs: loadStatus.updatedAtMs,
      message: loadStatus.message,
      validatedRun: loadStatus.validatedRun,
    );
  }
}
