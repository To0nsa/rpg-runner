import 'codecs/json_value_reader.dart';
import 'validated_run.dart';

enum RunSessionState {
  issued,
  uploading,
  uploaded,
  pendingValidation,
  validating,
  validated,
  rejected,
  expired,
  cancelled,
  internalError;

  String get wireValue => switch (this) {
    RunSessionState.pendingValidation => 'pending_validation',
    RunSessionState.internalError => 'internal_error',
    _ => name,
  };

  static RunSessionState parse(Object? raw) {
    if (raw is! String) {
      throw FormatException('state must be a string.');
    }
    return switch (raw) {
      'issued' => RunSessionState.issued,
      'uploading' => RunSessionState.uploading,
      'uploaded' => RunSessionState.uploaded,
      'pending_validation' => RunSessionState.pendingValidation,
      'validating' => RunSessionState.validating,
      'validated' => RunSessionState.validated,
      'rejected' => RunSessionState.rejected,
      'expired' => RunSessionState.expired,
      'cancelled' => RunSessionState.cancelled,
      'internal_error' => RunSessionState.internalError,
      _ => throw FormatException('Unknown run session state: $raw'),
    };
  }
}

final class SubmissionStatus {
  const SubmissionStatus({
    required this.runSessionId,
    required this.state,
    required this.updatedAtMs,
    this.message,
    this.validatedRun,
  }) : assert(updatedAtMs >= 0);

  final String runSessionId;
  final RunSessionState state;
  final int updatedAtMs;
  final String? message;
  final ValidatedRun? validatedRun;

  bool get isTerminal => switch (state) {
    RunSessionState.validated ||
    RunSessionState.rejected ||
    RunSessionState.expired ||
    RunSessionState.cancelled ||
    RunSessionState.internalError => true,
    _ => false,
  };

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'runSessionId': runSessionId,
      'state': state.wireValue,
      'updatedAtMs': updatedAtMs,
      if (message != null) 'message': message,
      if (validatedRun != null) 'validatedRun': validatedRun!.toJson(),
    };
  }

  factory SubmissionStatus.fromJson(Object? raw) {
    final json = asObjectMap(raw, fieldName: 'submissionStatus');
    return SubmissionStatus(
      runSessionId: readRequiredString(json, 'runSessionId'),
      state: RunSessionState.parse(json['state']),
      updatedAtMs: readRequiredInt(json, 'updatedAtMs'),
      message: readOptionalString(json, 'message'),
      validatedRun: json['validatedRun'] == null
          ? null
          : ValidatedRun.fromJson(json['validatedRun']),
    );
  }
}
