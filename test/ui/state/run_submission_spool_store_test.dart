import 'package:flutter_test/flutter_test.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rpg_runner/ui/state/run/pending_run_submission.dart';
import 'package:rpg_runner/ui/state/run/run_submission_spool_store.dart';

void main() {
  test('existing native artifact paths retain their durable JSON key', () {
    final json = <String, Object?>{
      'ownerUserId': 'uid_test',
      'runSessionId': 'existing',
      'runMode': 'practice',
      'replayFilePath': '/tmp/existing.replay.json',
      'canonicalSha256': 'a' * 64,
      'contentLengthBytes': 1234,
      'contentType': 'application/octet-stream',
      'step': 'queued',
      'attemptCount': 0,
      'nextAttemptAtMs': 0,
      'createdAtMs': 1,
      'updatedAtMs': 1,
    };
    final pending = PendingRunSubmission.fromJson(json);
    expect(pending.replayArtifactId, '/tmp/existing.replay.json');
    expect(pending.toJson(), json);
  });

  group('SharedPrefsRunSubmissionSpoolStore', () {
    late SharedPrefsRunSubmissionSpoolStore store;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      store = SharedPrefsRunSubmissionSpoolStore();
    });

    test('upsert + loadAll persists entries by runSessionId', () async {
      final first = _pending(runSessionId: 'run_a', createdAtMs: 1);
      final second = _pending(runSessionId: 'run_b', createdAtMs: 2);
      await store.upsert(submission: first);
      await store.upsert(submission: second);

      final entries = await store.loadAll();
      expect(entries, hasLength(2));
      expect(entries[0].runSessionId, 'run_a');
      expect(entries[1].runSessionId, 'run_b');
    });

    test('concurrent journal mutations preserve independent runs', () async {
      await Future.wait([
        store.upsert(submission: _pending(runSessionId: 'run_a')),
        store.upsert(submission: _pending(runSessionId: 'run_b')),
        store.upsert(submission: _pending(runSessionId: 'run_c')),
        store.remove(runSessionId: 'run_b'),
      ]);
      expect((await store.loadAll()).map((entry) => entry.runSessionId), [
        'run_a',
        'run_c',
      ]);
    });

    test(
      'reward presentation evidence survives retry and process restart',
      () async {
        final pending = PendingRunSubmission(
          ownerUserId: 'uid_test',
          runSessionId: 'preview',
          runMode: RunMode.practice,
          replayArtifactId: 'replay',
          canonicalSha256: 'a' * 64,
          contentLengthBytes: 1234,
          createdAtMs: 1,
          updatedAtMs: 1,
          provisionalSummary: {'goldEarned': 9, 'score': 1735},
          presentationBaseRevision: 18,
          presentationBaseGrantId: 'previous',
        );
        await store.upsert(
          submission: pending.copyWith(
            step: PendingRunSubmissionStep.retryScheduled,
            attemptCount: 2,
            nextAttemptAtMs: 3000,
          ),
        );
        final restarted = SharedPrefsRunSubmissionSpoolStore();
        final restored = (await restarted.load(runSessionId: 'preview'))!;
        expect(restored.provisionalSummary, {'goldEarned': 9, 'score': 1735});
        expect(restored.presentationBaseRevision, 18);
        expect(restored.presentationBaseGrantId, 'previous');
        expect(restored.attemptCount, 2);
      },
    );

    test('upsert replaces existing entry with same runSessionId', () async {
      await store.upsert(
        submission: _pending(
          runSessionId: 'run_x',
          attemptCount: 0,
          updatedAtMs: 10,
        ),
      );
      await store.upsert(
        submission: _pending(
          runSessionId: 'run_x',
          attemptCount: 2,
          updatedAtMs: 20,
          step: PendingRunSubmissionStep.retryScheduled,
          nextAttemptAtMs: 50,
          lastErrorCode: 'unavailable',
        ),
      );

      final loaded = await store.load(runSessionId: 'run_x');
      expect(loaded, isNotNull);
      expect(loaded!.attemptCount, 2);
      expect(loaded.step, PendingRunSubmissionStep.retryScheduled);
      expect(loaded.nextAttemptAtMs, 50);
      expect(loaded.lastErrorCode, 'unavailable');
    });

    test('remove deletes one entry and clear removes all entries', () async {
      await store.upsert(submission: _pending(runSessionId: 'run_a'));
      await store.upsert(submission: _pending(runSessionId: 'run_b'));

      await store.remove(runSessionId: 'run_a');
      final afterRemove = await store.loadAll();
      expect(afterRemove, hasLength(1));
      expect(afterRemove.single.runSessionId, 'run_b');

      await store.clear();
      final afterClear = await store.loadAll();
      expect(afterClear, isEmpty);
    });
  });
}

PendingRunSubmission _pending({
  required String runSessionId,
  int createdAtMs = 1000,
  int updatedAtMs = 1000,
  int attemptCount = 0,
  int nextAttemptAtMs = 0,
  PendingRunSubmissionStep step = PendingRunSubmissionStep.queued,
  String? lastErrorCode,
}) {
  return PendingRunSubmission(
    ownerUserId: 'uid_test',
    runSessionId: runSessionId,
    runMode: RunMode.practice,
    replayArtifactId: '/tmp/$runSessionId.replay.json',
    canonicalSha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    contentLengthBytes: 1234,
    contentType: 'application/octet-stream',
    step: step,
    createdAtMs: createdAtMs,
    updatedAtMs: updatedAtMs,
    attemptCount: attemptCount,
    nextAttemptAtMs: nextAttemptAtMs,
    lastErrorCode: lastErrorCode,
  );
}
