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

  @override
  String toString() {
    final resolvedMessage = message?.trim();
    if (resolvedMessage != null && resolvedMessage.isNotEmpty) {
      return 'RunStartRemoteException($code): $resolvedMessage';
    }
    return 'RunStartRemoteException($code)';
  }
}
