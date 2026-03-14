abstract class ValidatorMetrics {
  Future<void> recordDispatch({
    required String runSessionId,
    required String status,
    String? message,
    int? attempt,
    String? mode,
    String? phase,
    String? rejectionReason,
  });
}

class ConsoleValidatorMetrics implements ValidatorMetrics {
  @override
  Future<void> recordDispatch({
    required String runSessionId,
    required String status,
    String? message,
    int? attempt,
    String? mode,
    String? phase,
    String? rejectionReason,
  }) async {
    // Keep logging plain and structured for Cloud Run log filters.
    final suffix = message == null ? '' : ' message="$message"';
    final attemptSegment = attempt == null ? '' : ' attempt=$attempt';
    final modeSegment = mode == null ? '' : ' mode="$mode"';
    final phaseSegment = phase == null ? '' : ' phase="$phase"';
    final rejectionSegment = rejectionReason == null
        ? ''
        : ' rejectionReason="$rejectionReason"';
    // ignore: avoid_print
    print(
      'replay_validator.dispatch runSessionId="$runSessionId" '
      'status="$status"$attemptSegment$modeSegment$phaseSegment'
      '$rejectionSegment$suffix',
    );
  }
}
