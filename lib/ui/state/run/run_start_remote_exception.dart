class RunStartRemoteException implements Exception {
  const RunStartRemoteException({
    required this.code,
    this.message,
    this.details,
  });

  final String code;
  final String? message;
  final Object? details;

  bool get isUnauthorized =>
      code == 'unauthenticated' || code == 'permission-denied';

  bool get isUnavailable =>
      code == 'unavailable' ||
      code == 'deadline-exceeded' ||
      code == 'network-request-failed';

  bool get isPreconditionFailed =>
      code == 'failed-precondition' || code == 'aborted';

  bool get isLevelUnavailable => code == 'level-unavailable';

  bool get isUpdateRequired =>
      code == 'failed-precondition' && _releaseReason == 'update-required';

  bool get isReleaseMaintenance =>
      code == 'unavailable' && _releaseReason == 'release-maintenance';

  String? get _releaseReason {
    final value = details;
    return value is Map && value['reason'] is String
        ? value['reason'] as String
        : null;
  }

  @override
  String toString() {
    final resolvedMessage = message?.trim();
    if (resolvedMessage != null && resolvedMessage.isNotEmpty) {
      return 'RunStartRemoteException($code): $resolvedMessage';
    }
    return 'RunStartRemoteException($code)';
  }
}
