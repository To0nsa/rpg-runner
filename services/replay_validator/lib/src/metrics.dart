abstract class ValidatorMetrics {
  Future<void> recordDispatch({
    required String runSessionId,
    required String status,
    String? message,
  });
}

class ConsoleValidatorMetrics implements ValidatorMetrics {
  @override
  Future<void> recordDispatch({
    required String runSessionId,
    required String status,
    String? message,
  }) async {
    // Keep logging plain and structured for Cloud Run log filters.
    final suffix = message == null ? '' : ' message="$message"';
    // ignore: avoid_print
    print(
      'replay_validator.dispatch runSessionId="$runSessionId" '
      'status="$status"$suffix',
    );
  }
}

