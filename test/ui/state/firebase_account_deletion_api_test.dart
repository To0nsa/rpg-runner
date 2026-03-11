import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/state/account_deletion_api.dart';
import 'package:rpg_runner/ui/state/firebase_account_deletion_api.dart';

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

  test('treats successful callable response as deleted', () async {
    final source = _FakeFirebaseAccountDeletionSource()
      ..response = <String, dynamic>{'ok': true};
    final api = FirebaseAccountDeletionApi(source: source);

    final result = await api.deleteAccountAndData(
      userId: 'u1',
      sessionId: 's1',
    );

    expect(result.status, AccountDeletionStatus.deleted);
    expect(result.succeeded, isTrue);
  });

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
