import 'dart:convert';

abstract class ValidatorMetrics {
  Future<void> recordDispatch({
    required String runSessionId,
    required String status,
    String? message,
    int? attempt,
    String? mode,
    String? phase,
    String? rejectionReason,
    int? durationMs,
    String? errorClass,
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
    int? durationMs,
    String? errorClass,
  }) async {
    // JSON stdout becomes structured Cloud Logging payload without player data.
    // ignore: avoid_print
    print(
      jsonEncode(<String, Object?>{
        'event': 'replay_validator.dispatch',
        'metricVersion': 1,
        'runSessionId': runSessionId,
        'status': status,
        'attempt': ?attempt,
        'mode': ?mode,
        'phase': ?phase,
        'rejectionReason': ?rejectionReason,
        'durationMs': ?durationMs,
        'errorClass': ?errorClass,
      }),
    );
  }
}
