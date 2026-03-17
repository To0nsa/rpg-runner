import 'package:run_protocol/submission_status.dart';
import 'package:test/test.dart';

void main() {
  group('SubmissionRewardStatus wire values', () {
    test('provisional wire value is provisional', () {
      expect(SubmissionRewardStatus.provisional.wireValue, 'provisional');
    });

    test('finalReward wire value is final', () {
      expect(SubmissionRewardStatus.finalReward.wireValue, 'final');
    });

    test('revoked wire value is revoked', () {
      expect(SubmissionRewardStatus.revoked.wireValue, 'revoked');
    });

    test('none wire value is none', () {
      expect(SubmissionRewardStatus.none.wireValue, 'none');
    });
  });

  group('SubmissionRewardStatus.parse', () {
    test('parses provisional', () {
      expect(SubmissionRewardStatus.parse('provisional'),
          SubmissionRewardStatus.provisional);
    });

    test('parses final', () {
      expect(SubmissionRewardStatus.parse('final'),
          SubmissionRewardStatus.finalReward);
    });

    test('parses revoked', () {
      expect(SubmissionRewardStatus.parse('revoked'),
          SubmissionRewardStatus.revoked);
    });

    test('parses none', () {
      expect(
          SubmissionRewardStatus.parse('none'), SubmissionRewardStatus.none);
    });

    test('throws on unknown string', () {
      expect(() => SubmissionRewardStatus.parse('unknown'),
          throwsA(isA<FormatException>()));
    });

    test('throws on non-string', () {
      expect(() => SubmissionRewardStatus.parse(42),
          throwsA(isA<FormatException>()));
    });

    test('throws on null', () {
      expect(() => SubmissionRewardStatus.parse(null),
          throwsA(isA<FormatException>()));
    });
  });

  group('SubmissionReward round-trip serialization', () {
    test('provisional reward round-trips through JSON', () {
      final reward = SubmissionReward(
        status: SubmissionRewardStatus.provisional,
        provisionalGold: 42,
        effectiveGoldDelta: 0,
        spendableGoldDelta: 0,
        updatedAtMs: 1700000000000,
        grantId: 'grant_abc',
        message: null,
      );

      final json = reward.toJson();
      final parsed = SubmissionReward.fromJson(json);

      expect(parsed.status, SubmissionRewardStatus.provisional);
      expect(parsed.provisionalGold, 42);
      expect(parsed.effectiveGoldDelta, 0);
      expect(parsed.spendableGoldDelta, 0);
      expect(parsed.updatedAtMs, 1700000000000);
      expect(parsed.grantId, 'grant_abc');
      expect(parsed.message, isNull);
    });

    test('final reward round-trips through JSON', () {
      final reward = SubmissionReward(
        status: SubmissionRewardStatus.finalReward,
        provisionalGold: 75,
        effectiveGoldDelta: 75,
        spendableGoldDelta: 75,
        updatedAtMs: 1700000001000,
        grantId: 'grant_def',
        message: 'ok',
      );

      final json = reward.toJson();
      expect(json['status'], 'final');

      final parsed = SubmissionReward.fromJson(json);
      expect(parsed.status, SubmissionRewardStatus.finalReward);
      expect(parsed.provisionalGold, 75);
      expect(parsed.effectiveGoldDelta, 75);
      expect(parsed.spendableGoldDelta, 75);
      expect(parsed.message, 'ok');
    });

    test('revoked reward round-trips through JSON', () {
      final reward = SubmissionReward(
        status: SubmissionRewardStatus.revoked,
        provisionalGold: 30,
        effectiveGoldDelta: 0,
        spendableGoldDelta: 0,
        updatedAtMs: 1700000002000,
        grantId: 'grant_ghi',
        message: 'replay_invalid',
      );

      final json = reward.toJson();
      expect(json['status'], 'revoked');

      final parsed = SubmissionReward.fromJson(json);
      expect(parsed.status, SubmissionRewardStatus.revoked);
      expect(parsed.provisionalGold, 30);
      expect(parsed.effectiveGoldDelta, 0);
      expect(parsed.spendableGoldDelta, 0);
      expect(parsed.message, 'replay_invalid');
    });

    test('optional fields absent when null', () {
      final reward = SubmissionReward(
        status: SubmissionRewardStatus.provisional,
        provisionalGold: 5,
        effectiveGoldDelta: 0,
        spendableGoldDelta: 0,
        updatedAtMs: 0,
      );

      final json = reward.toJson();
      expect(json.containsKey('grantId'), isFalse);
      expect(json.containsKey('message'), isFalse);

      final parsed = SubmissionReward.fromJson(json);
      expect(parsed.grantId, isNull);
      expect(parsed.message, isNull);
    });
  });

  group('SubmissionStatus reward field round-trip', () {
    test('SubmissionStatus with provisional reward round-trips', () {
      final status = SubmissionStatus(
        runSessionId: 'run_1',
        state: RunSessionState.pendingValidation,
        updatedAtMs: 1700000000000,
        reward: SubmissionReward(
          status: SubmissionRewardStatus.provisional,
          provisionalGold: 10,
          effectiveGoldDelta: 0,
          spendableGoldDelta: 0,
          updatedAtMs: 1700000000000,
        ),
      );

      final json = status.toJson();
      final parsed = SubmissionStatus.fromJson(json);

      expect(parsed.runSessionId, 'run_1');
      expect(parsed.reward, isNotNull);
      expect(parsed.reward!.status, SubmissionRewardStatus.provisional);
      expect(parsed.reward!.provisionalGold, 10);
    });

    test('SubmissionStatus without reward parses reward as null', () {
      final status = SubmissionStatus(
        runSessionId: 'run_2',
        state: RunSessionState.pendingValidation,
        updatedAtMs: 0,
      );

      final json = status.toJson();
      expect(json.containsKey('reward'), isFalse);

      final parsed = SubmissionStatus.fromJson(json);
      expect(parsed.reward, isNull);
    });

    test('SubmissionStatus.fromJson tolerates missing reward field', () {
      final json = <String, Object?>{
        'runSessionId': 'run_3',
        'state': 'pending_validation',
        'updatedAtMs': 0,
      };

      final parsed = SubmissionStatus.fromJson(json);
      expect(parsed.reward, isNull);
    });

    test('SubmissionStatus.fromJson tolerates null reward field', () {
      final json = <String, Object?>{
        'runSessionId': 'run_4',
        'state': 'pending_validation',
        'updatedAtMs': 0,
        'reward': null,
      };

      final parsed = SubmissionStatus.fromJson(json);
      expect(parsed.reward, isNull);
    });
  });
}
