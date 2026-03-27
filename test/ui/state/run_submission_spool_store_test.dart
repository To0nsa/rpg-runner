import 'package:flutter_test/flutter_test.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rpg_runner/ui/state/run/pending_run_submission.dart';
import 'package:rpg_runner/ui/state/run/run_submission_spool_store.dart';

void main() {
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
    runSessionId: runSessionId,
    runMode: RunMode.practice,
    replayFilePath: '/tmp/$runSessionId.replay.json',
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
