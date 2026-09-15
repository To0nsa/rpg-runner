enum AccountDeletionStatus {
  requested,
  inProgress,
  retrying,
  deleted,
  requiresRecentLogin,
  unauthorized,
  unsupported,
  failed,
}

/// Device cleanup failures after the server has accepted account deletion.
enum AccountDeletionLocalCleanupIssue {
  ownershipOutbox,
  replaySubmissions,
  signOut,
}

class AccountDeletionResult {
  const AccountDeletionResult({
    required this.status,
    this.errorCode,
    this.errorMessage,
    this.requestId,
    this.localCleanupIssues = const <AccountDeletionLocalCleanupIssue>[],
  });

  final AccountDeletionStatus status;
  final String? errorCode;
  final String? errorMessage;
  final String? requestId;
  final List<AccountDeletionLocalCleanupIssue> localCleanupIssues;

  bool get localCleanupSucceeded => localCleanupIssues.isEmpty;

  /// Whether the server owns deletion, independently of device cleanup.
  bool get succeeded =>
      status == AccountDeletionStatus.requested ||
      status == AccountDeletionStatus.inProgress ||
      status == AccountDeletionStatus.retrying ||
      status == AccountDeletionStatus.deleted;
}

abstract class AccountDeletionApi {
  Future<AccountDeletionResult> deleteAccountAndData({
    required String userId,
    required String sessionId,
  });
}

class NoopAccountDeletionApi implements AccountDeletionApi {
  const NoopAccountDeletionApi();

  @override
  Future<AccountDeletionResult> deleteAccountAndData({
    required String userId,
    required String sessionId,
  }) async {
    return const AccountDeletionResult(
      status: AccountDeletionStatus.unsupported,
      errorCode: 'account-deletion-unsupported',
      errorMessage: 'Account deletion is not configured for this environment.',
    );
  }
}
