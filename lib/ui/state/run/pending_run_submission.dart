import 'package:run_protocol/run_mode.dart';

enum PendingRunSubmissionStep {
  queued,
  requestingUploadGrant,
  uploading,
  finalizing,
  awaitingServerStatus,
  retryScheduled;

  static PendingRunSubmissionStep parse(Object? raw) {
    if (raw is! String) {
      throw FormatException('pendingRunSubmission.step must be a string.');
    }
    return switch (raw) {
      'queued' => PendingRunSubmissionStep.queued,
      'requestingUploadGrant' => PendingRunSubmissionStep.requestingUploadGrant,
      'uploading' => PendingRunSubmissionStep.uploading,
      'finalizing' => PendingRunSubmissionStep.finalizing,
      'awaitingServerStatus' => PendingRunSubmissionStep.awaitingServerStatus,
      'retryScheduled' => PendingRunSubmissionStep.retryScheduled,
      _ => throw FormatException(
        'Unknown pendingRunSubmission.step value "$raw".',
      ),
    };
  }
}

final class PendingRunSubmission {
  const PendingRunSubmission({
    required this.runSessionId,
    required this.runMode,
    required this.replayFilePath,
    required this.canonicalSha256,
    required this.contentLengthBytes,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.contentType = 'application/octet-stream',
    this.step = PendingRunSubmissionStep.queued,
    this.attemptCount = 0,
    this.nextAttemptAtMs = 0,
    this.objectPath,
    this.uploadCompletedAtMs,
    this.finalizedAtMs,
    this.lastErrorCode,
    this.lastErrorMessage,
    this.provisionalSummary,
  }) : assert(runSessionId != ''),
       assert(replayFilePath != ''),
       assert(contentLengthBytes > 0),
       assert(createdAtMs >= 0),
       assert(updatedAtMs >= 0),
       assert(attemptCount >= 0),
       assert(nextAttemptAtMs >= 0);

  final String runSessionId;
  final RunMode runMode;
  final String replayFilePath;
  final String canonicalSha256;
  final int contentLengthBytes;
  final String contentType;
  final PendingRunSubmissionStep step;
  final int createdAtMs;
  final int updatedAtMs;
  final int attemptCount;
  final int nextAttemptAtMs;
  final String? objectPath;
  final int? uploadCompletedAtMs;
  final int? finalizedAtMs;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final Map<String, Object?>? provisionalSummary;

  bool get isReadyToRetry =>
      step != PendingRunSubmissionStep.retryScheduled || nextAttemptAtMs <= 0;

  PendingRunSubmission copyWith({
    String? runSessionId,
    RunMode? runMode,
    String? replayFilePath,
    String? canonicalSha256,
    int? contentLengthBytes,
    String? contentType,
    PendingRunSubmissionStep? step,
    int? createdAtMs,
    int? updatedAtMs,
    int? attemptCount,
    int? nextAttemptAtMs,
    Object? objectPath = _unset,
    Object? uploadCompletedAtMs = _unset,
    Object? finalizedAtMs = _unset,
    Object? lastErrorCode = _unset,
    Object? lastErrorMessage = _unset,
    Object? provisionalSummary = _unset,
  }) {
    return PendingRunSubmission(
      runSessionId: runSessionId ?? this.runSessionId,
      runMode: runMode ?? this.runMode,
      replayFilePath: replayFilePath ?? this.replayFilePath,
      canonicalSha256: canonicalSha256 ?? this.canonicalSha256,
      contentLengthBytes: contentLengthBytes ?? this.contentLengthBytes,
      contentType: contentType ?? this.contentType,
      step: step ?? this.step,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAtMs: nextAttemptAtMs ?? this.nextAttemptAtMs,
      objectPath: identical(objectPath, _unset)
          ? this.objectPath
          : objectPath as String?,
      uploadCompletedAtMs: identical(uploadCompletedAtMs, _unset)
          ? this.uploadCompletedAtMs
          : uploadCompletedAtMs as int?,
      finalizedAtMs: identical(finalizedAtMs, _unset)
          ? this.finalizedAtMs
          : finalizedAtMs as int?,
      lastErrorCode: identical(lastErrorCode, _unset)
          ? this.lastErrorCode
          : lastErrorCode as String?,
      lastErrorMessage: identical(lastErrorMessage, _unset)
          ? this.lastErrorMessage
          : lastErrorMessage as String?,
      provisionalSummary: identical(provisionalSummary, _unset)
          ? this.provisionalSummary
          : provisionalSummary as Map<String, Object?>?,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'runSessionId': runSessionId,
      'runMode': runMode.name,
      'replayFilePath': replayFilePath,
      'canonicalSha256': canonicalSha256,
      'contentLengthBytes': contentLengthBytes,
      'contentType': contentType,
      'step': step.name,
      'createdAtMs': createdAtMs,
      'updatedAtMs': updatedAtMs,
      'attemptCount': attemptCount,
      'nextAttemptAtMs': nextAttemptAtMs,
      'objectPath': ?objectPath,
      'uploadCompletedAtMs': ?uploadCompletedAtMs,
      'finalizedAtMs': ?finalizedAtMs,
      'lastErrorCode': ?lastErrorCode,
      'lastErrorMessage': ?lastErrorMessage,
      'provisionalSummary': ?provisionalSummary,
    };
  }

  factory PendingRunSubmission.fromJson(Object? raw) {
    if (raw is! Map) {
      throw FormatException('pendingRunSubmission must be a JSON object.');
    }
    final json = Map<Object?, Object?>.from(raw);
    final runSessionId = _readRequiredString(json, 'runSessionId');
    final replayFilePath = _readRequiredString(json, 'replayFilePath');
    final canonicalSha256 = _readRequiredString(json, 'canonicalSha256');
    final contentLengthBytes = _readRequiredInt(json, 'contentLengthBytes');
    final contentType = _readRequiredString(json, 'contentType');
    final createdAtMs = _readRequiredInt(json, 'createdAtMs');
    final updatedAtMs = _readRequiredInt(json, 'updatedAtMs');
    final attemptCount = _readRequiredInt(json, 'attemptCount');
    final nextAttemptAtMs = _readRequiredInt(json, 'nextAttemptAtMs');
    final rawProvisionalSummary = json['provisionalSummary'];
    return PendingRunSubmission(
      runSessionId: runSessionId,
      runMode: RunMode.parse(json['runMode'], fieldName: 'runMode'),
      replayFilePath: replayFilePath,
      canonicalSha256: canonicalSha256,
      contentLengthBytes: contentLengthBytes,
      contentType: contentType,
      step: PendingRunSubmissionStep.parse(json['step']),
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs,
      attemptCount: attemptCount,
      nextAttemptAtMs: nextAttemptAtMs,
      objectPath: _readOptionalString(json, 'objectPath'),
      uploadCompletedAtMs: _readOptionalInt(json, 'uploadCompletedAtMs'),
      finalizedAtMs: _readOptionalInt(json, 'finalizedAtMs'),
      lastErrorCode: _readOptionalString(json, 'lastErrorCode'),
      lastErrorMessage: _readOptionalString(json, 'lastErrorMessage'),
      provisionalSummary: rawProvisionalSummary == null
          ? null
          : Map<String, Object?>.from(
              _readRequiredMap(json, 'provisionalSummary'),
            ),
    );
  }
}

const Object _unset = Object();

String _readRequiredString(Map<Object?, Object?> json, String fieldName) {
  final value = json[fieldName];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('pendingRunSubmission.$fieldName must be non-empty.');
  }
  return value;
}

String? _readOptionalString(Map<Object?, Object?> json, String fieldName) {
  final value = json[fieldName];
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return value;
}

int _readRequiredInt(Map<Object?, Object?> json, String fieldName) {
  final value = json[fieldName];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('pendingRunSubmission.$fieldName must be an integer.');
}

int? _readOptionalInt(Map<Object?, Object?> json, String fieldName) {
  final value = json[fieldName];
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException(
    'pendingRunSubmission.$fieldName must be an integer when present.',
  );
}

Map<Object?, Object?> _readRequiredMap(
  Map<Object?, Object?> json,
  String fieldName,
) {
  final value = json[fieldName];
  if (value is! Map) {
    throw FormatException('pendingRunSubmission.$fieldName must be an object.');
  }
  return Map<Object?, Object?>.from(value);
}
