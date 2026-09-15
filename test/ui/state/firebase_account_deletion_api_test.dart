import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/state/profile/account_deletion_api.dart';
import 'package:rpg_runner/ui/state/profile/firebase_account_deletion_api.dart';

void main() {
  test('decodes wrapped deletion result status payload', () async {
    final source = _FakeFirebaseAccountDeletionSource()
      ..response = <String, dynamic>{
        'result': <String, dynamic>{
          'status': 'requiresRecentLogin',
          'errorCode': 'failed-precondition',
          'errorMessage': 'recent login required',
        },
      };
    final api = FirebaseAccountDeletionApi(source: source);

    final result = await api.deleteAccountAndData(
      userId: 'u1',
      sessionId: 's1',
    );

    expect(result.status, AccountDeletionStatus.requiresRecentLogin);
    expect(result.errorCode, 'failed-precondition');
  });

  test(
    'requires an explicit deletion status for the requested account',
    () async {
      final source = _FakeFirebaseAccountDeletionSource()
        ..response = <String, dynamic>{
          'result': {'status': 'deleted', 'requestId': 'u1'},
        };
      final api = FirebaseAccountDeletionApi(source: source);

      final result = await api.deleteAccountAndData(
        userId: 'u1',
        sessionId: 's1',
      );

      expect(result.status, AccountDeletionStatus.deleted);
      expect(result.succeeded, isTrue);
      expect(result.requestId, 'u1');
    },
  );

  for (final response in <Map<String, dynamic>>[
    {},
    {'ok': true},
    {'deleted': true},
    {'status': 'future_status', 'requestId': 'u1'},
    {
      'result': {'status': 'requested'},
    },
    {
      'result': {'status': 'deleted', 'requestId': 'other'},
    },
    {
      'result': {'status': 'success', 'requestId': 'u1'},
    },
  ]) {
    test('rejects unconfirmed deletion response $response', () async {
      final source = _FakeFirebaseAccountDeletionSource()..response = response;
      final result = await FirebaseAccountDeletionApi(source: source)
          .deleteAccountAndData(userId: 'u1', sessionId: 's1');
      expect(result.succeeded, isFalse);
      expect(result.errorCode, 'invalid-response');
    });
  }

  for (final status in <String>[
    'requested',
    'in_progress',
    'retryable',
    'deleted',
  ]) {
    test('accepts the server-owned $status response', () async {
      final source = _FakeFirebaseAccountDeletionSource()
        ..response = {
          'result': {'status': status, 'requestId': 'u1'},
        };
      final result = await FirebaseAccountDeletionApi(source: source)
          .deleteAccountAndData(userId: 'u1', sessionId: 's1');
      expect(result.succeeded, isTrue);
    });
  }

  test(
    'maps unauthenticated Firebase callable failures to unauthorized',
    () async {
      final source = _FakeFirebaseAccountDeletionSource()
        ..error = _TestFirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'auth required',
        );
      final api = FirebaseAccountDeletionApi(source: source);

      final result = await api.deleteAccountAndData(
        userId: 'u1',
        sessionId: 's1',
      );

      expect(result.status, AccountDeletionStatus.unauthorized);
      expect(result.errorCode, 'unauthenticated');
    },
  );

  test('maps unimplemented callable errors to unsupported', () async {
    final source = _FakeFirebaseAccountDeletionSource()
      ..error = _TestFirebaseFunctionsException(
        code: 'unimplemented',
        message: 'function missing',
      );
    final api = FirebaseAccountDeletionApi(source: source);

    final result = await api.deleteAccountAndData(
      userId: 'u1',
      sessionId: 's1',
    );

    expect(result.status, AccountDeletionStatus.unsupported);
    expect(result.errorCode, 'unimplemented');
  });

  test(
    'does not mistake unrelated failed preconditions for reauthentication',
    () async {
      final source = _FakeFirebaseAccountDeletionSource()
        ..error = _TestFirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Deletion is already in progress.',
        );
      final api = FirebaseAccountDeletionApi(source: source);

      final result = await api.deleteAccountAndData(
        userId: 'u1',
        sessionId: 's1',
      );

      expect(result.status, AccountDeletionStatus.failed);
    },
  );
}

class _FakeFirebaseAccountDeletionSource
    implements FirebaseAccountDeletionSource {
  Map<String, dynamic> response = <String, dynamic>{};
  Object? error;

  @override
  Future<Map<String, dynamic>> deleteAccountAndData({
    required String userId,
    required String sessionId,
  }) async {
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }
    return response;
  }
}

class _TestFirebaseFunctionsException extends FirebaseFunctionsException {
  _TestFirebaseFunctionsException({
    required super.code,
    required super.message,
  });
}
