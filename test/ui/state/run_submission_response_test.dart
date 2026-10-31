import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/state/run/run_submission_response.dart';
import 'package:run_protocol/submission_status.dart';

void main() {
  Map<String, dynamic> fixture() => jsonDecode(
    File('functions/test/fixtures/run_completion_receipt_v1.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;

  RunSubmissionResponse decode(Object? value) =>
      RunSubmissionResponse.fromReceipt(
        value,
        userId: 'uid_projection_owner',
        runSessionId: 'run_completion_fixture',
      );

  test(
    'decodes the receipt emitted by the real TypeScript settlement transaction',
    () {
      final receipt = fixture();
      final completion = decode(receipt);
      expect(completion.status.state, RunSessionState.validated);
      expect(completion.status.reward!.spendableGoldDelta, 75);
      expect(completion.canonical!.progression.gold, 75);
      expect(completion.canonical!.revision, 1);
      final response = RunSubmissionResponse.fromJson(
        {
          'submissionStatus': receipt['submissionStatus'],
          'completion': receipt,
        },
        userId: 'uid_projection_owner',
        runSessionId: 'run_completion_fixture',
      );
      expect(response.canonical!.toJson(), completion.canonical!.toJson());
    },
  );

  for (final mutation in <String, void Function(Map<String, dynamic>)>{
    'wrong owner': (r) => r['uid'] = 'another',
    'wrong run': (r) => r['runSessionId'] = 'another',
    'unknown schema': (r) => r['schemaVersion'] = 2,
    'unconfirmed': (r) => r['submissionStatus']['state'] = 'settlement_pending',
    'provisional': (r) =>
        r['submissionStatus']['reward']['status'] = 'provisional',
    'missing canonical': (r) => r.remove('canonicalState'),
    'fractional revision': (r) => r['canonicalState']['revision'] = 1.5,
    'missing gold': (r) => r['canonicalState']['progression'].remove('gold'),
    'unapplied grant': (r) =>
        r['canonicalState']['progression']['appliedRewardGrantIds'] = [],
  }.entries) {
    test(
      'rejects ${mutation.key} completion before applying account state',
      () {
        final receipt = fixture();
        mutation.value(receipt);
        expect(() => decode(receipt), throwsFormatException);
      },
    );
  }

  test('legacy terminal responses retain the canonical-refresh fallback', () {
    final receipt = fixture();
    final response = RunSubmissionResponse.fromJson(
      {'submissionStatus': receipt['submissionStatus']},
      userId: 'uid_projection_owner',
      runSessionId: 'run_completion_fixture',
    );
    expect(response.canonical, isNull);
    expect(response.status.isTerminal, isTrue);
  });
}
