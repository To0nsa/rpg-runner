enum AccountDeletionStatus {
  deleted,
  requiresRecentLogin,
  unauthorized,
  unsupported,
  failed,
}

class AccountDeletionResult {
  const AccountDeletionResult({
    required this.status,
    this.errorCode,
    this.errorMessage,
  });

  final AccountDeletionStatus status;
  final String? errorCode;
  final String? errorMessage;

  bool get succeeded => status == AccountDeletionStatus.deleted;
}

abstract class AccountDeletionApi {
  Future<AccountDeletionResult> deleteAccountAndData({
    required String userId,
    required String sessionId,
    required String profileId,
  });
}

class NoopAccountDeletionApi implements AccountDeletionApi {
  const NoopAccountDeletionApi();

  @override
  Future<AccountDeletionResult> deleteAccountAndData({
    required String userId,
    required String sessionId,
    required String profileId,
  }) async {
    return const AccountDeletionResult(
      status: AccountDeletionStatus.unsupported,
      errorCode: 'account-deletion-unsupported',
      errorMessage: 'Account deletion is not configured for this environment.',
    );
  }
}
