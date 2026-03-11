import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';

import 'account_deletion_api.dart';

/// Firebase-backed [AccountDeletionApi] for user account and data deletion.
class FirebaseAccountDeletionApi implements AccountDeletionApi {
  FirebaseAccountDeletionApi({FirebaseAccountDeletionSource? source})
    : _source = source ?? PluginFirebaseAccountDeletionSource();

  final FirebaseAccountDeletionSource _source;

  @override
  Future<AccountDeletionResult> deleteAccountAndData({
    required String userId,
    required String sessionId,
  }) async {
    try {
      final response = await _source.deleteAccountAndData(
        userId: userId,
        sessionId: sessionId,
      );
      return _decodeResult(response);
    } on FirebaseFunctionsException catch (error) {
      return _mapFirebaseFunctionsError(error);
    } on PlatformException catch (error) {
      return _mapPlatformError(error);
    } catch (error) {
      return AccountDeletionResult(
        status: AccountDeletionStatus.failed,
        errorCode: 'account-delete-failed',
        errorMessage: '$error',
      );
    }
  }

  AccountDeletionResult _decodeResult(Map<String, dynamic> response) {
    final wrapped = response['result'];
    final payload = wrapped is Map<String, dynamic>
        ? wrapped
        : (wrapped is Map ? Map<String, dynamic>.from(wrapped) : response);

    final status = _statusFromRaw(payload['status']);
    final errorCode = payload['errorCode'];
    final errorMessage = payload['errorMessage'];
    if (status != null) {
      return AccountDeletionResult(
        status: status,
        errorCode: errorCode is String ? errorCode : null,
        errorMessage: errorMessage is String ? errorMessage : null,
      );
    }

    final deletedRaw = payload['deleted'];
    if (deletedRaw is bool && deletedRaw) {
      return const AccountDeletionResult(status: AccountDeletionStatus.deleted);
    }

    final okRaw = payload['ok'];
    if (okRaw is bool) {
      return AccountDeletionResult(
        status: okRaw
            ? AccountDeletionStatus.deleted
            : AccountDeletionStatus.failed,
        errorCode: errorCode is String ? errorCode : null,
        errorMessage: errorMessage is String ? errorMessage : null,
      );
    }

    return const AccountDeletionResult(status: AccountDeletionStatus.deleted);
  }

  AccountDeletionResult _mapFirebaseFunctionsError(
    FirebaseFunctionsException error,
  ) {
    final code = error.code;
    final message = error.message;
    if (_isRequiresRecentLogin(code: code, message: message)) {
      return AccountDeletionResult(
        status: AccountDeletionStatus.requiresRecentLogin,
        errorCode: code,
        errorMessage: message,
      );
    }
    if (_isUnauthorized(code)) {
      return AccountDeletionResult(
        status: AccountDeletionStatus.unauthorized,
        errorCode: code,
        errorMessage: message,
      );
    }
    if (_isUnsupported(code)) {
      return AccountDeletionResult(
        status: AccountDeletionStatus.unsupported,
        errorCode: code,
        errorMessage: message,
      );
    }
    return AccountDeletionResult(
      status: AccountDeletionStatus.failed,
      errorCode: code,
      errorMessage: message,
    );
  }

  AccountDeletionResult _mapPlatformError(PlatformException error) {
    final code = error.code;
    final message = error.message;
    if (_isRequiresRecentLogin(code: code, message: message)) {
      return AccountDeletionResult(
        status: AccountDeletionStatus.requiresRecentLogin,
        errorCode: code,
        errorMessage: message,
      );
    }
    if (_isUnauthorized(code)) {
      return AccountDeletionResult(
        status: AccountDeletionStatus.unauthorized,
        errorCode: code,
        errorMessage: message,
      );
    }
    if (_isUnsupported(code)) {
      return AccountDeletionResult(
        status: AccountDeletionStatus.unsupported,
        errorCode: code,
        errorMessage: message,
      );
    }
    return AccountDeletionResult(
      status: AccountDeletionStatus.failed,
      errorCode: code,
      errorMessage: message,
    );
  }

  AccountDeletionStatus? _statusFromRaw(Object? raw) {
    if (raw is! String) {
      return null;
    }
    return switch (raw) {
      'deleted' || 'success' => AccountDeletionStatus.deleted,
      'requiresRecentLogin' ||
      'requires-recent-login' => AccountDeletionStatus.requiresRecentLogin,
      'unauthorized' => AccountDeletionStatus.unauthorized,
      'unsupported' => AccountDeletionStatus.unsupported,
      'failed' => AccountDeletionStatus.failed,
      _ => null,
    };
  }

  bool _isRequiresRecentLogin({
    required String code,
    required String? message,
  }) {
    if (code == 'requires-recent-login' || code == 'failed-precondition') {
      return true;
    }
    final normalizedMessage = message?.toLowerCase() ?? '';
    return normalizedMessage.contains('recent login') ||
        normalizedMessage.contains('reauthenticate');
  }

  bool _isUnauthorized(String code) {
    return code == 'unauthenticated' || code == 'permission-denied';
  }

  bool _isUnsupported(String code) {
    return code == 'unimplemented' || code == 'not-found';
  }
}

/// Transport abstraction for account deletion backend calls.
abstract class FirebaseAccountDeletionSource {
  Future<Map<String, dynamic>> deleteAccountAndData({
    required String userId,
    required String sessionId,
  });
}

/// Production callable source backed by `package:cloud_functions`.
class PluginFirebaseAccountDeletionSource
    implements FirebaseAccountDeletionSource {
  PluginFirebaseAccountDeletionSource({
    FirebaseFunctions? functions,
    this.deleteCallableName = 'accountDelete',
  }) : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  final String deleteCallableName;

  @override
  Future<Map<String, dynamic>> deleteAccountAndData({
    required String userId,
    required String sessionId,
  }) async {
    final callable = _functions.httpsCallable(deleteCallableName);
    final result = await callable.call(<String, Object?>{
      'userId': userId,
      'sessionId': sessionId,
    });
    return _decodeMap(result.data);
  }

  Map<String, dynamic> _decodeMap(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    throw FormatException(
      'Firebase account deletion callable returned non-map payload: '
      '${raw.runtimeType}',
    );
  }
}
