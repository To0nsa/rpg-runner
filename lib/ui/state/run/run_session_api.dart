import 'package:runner_core/levels/level_id.dart';
import 'package:run_protocol/run_mode.dart';
import 'package:run_protocol/submission_status.dart';
import 'package:run_protocol/run_ticket.dart';

import 'run_start_remote_exception.dart';

final class RunUploadGrant {
  const RunUploadGrant({
    required this.runSessionId,
    required this.objectPath,
    required this.uploadUrl,
    required this.uploadMethod,
    required this.uploadFields,
    required this.contentType,
    required this.maxBytes,
    required this.expiresAtMs,
  });

  final String runSessionId;
  final String objectPath;
  final String uploadUrl;
  final String uploadMethod;
  final Map<String, String> uploadFields;
  final String contentType;
  final int maxBytes;
  final int expiresAtMs;

  factory RunUploadGrant.fromJson(Object? raw) {
    if (raw is! Map) {
      throw FormatException('runUploadGrant must be a JSON object.');
    }
    final json = Map<Object?, Object?>.from(raw);
    final runSessionId = json['runSessionId'];
    final objectPath = json['objectPath'];
    final uploadUrl = json['uploadUrl'];
    final uploadMethod = json['uploadMethod'];
    final uploadFields = json['uploadFields'];
    final contentType = json['contentType'];
    final maxBytes = json['maxBytes'];
    final expiresAtMs = json['expiresAtMs'];
    if (runSessionId is! String || runSessionId.trim().isEmpty) {
      throw FormatException('runUploadGrant.runSessionId must be non-empty.');
    }
    if (objectPath is! String || objectPath.trim().isEmpty) {
      throw FormatException('runUploadGrant.objectPath must be non-empty.');
    }
    if (uploadUrl is! String || uploadUrl.trim().isEmpty) {
      throw FormatException('runUploadGrant.uploadUrl must be non-empty.');
    }
    if (uploadMethod is! String ||
        uploadMethod.trim().toUpperCase() != 'POST') {
      throw FormatException('runUploadGrant.uploadMethod must be POST.');
    }
    if (contentType is! String || contentType.trim().isEmpty) {
      throw FormatException('runUploadGrant.contentType must be non-empty.');
    }
    if (maxBytes is! int || maxBytes <= 0) {
      throw FormatException('runUploadGrant.maxBytes must be > 0.');
    }
    if (expiresAtMs is! int || expiresAtMs <= 0) {
      throw FormatException('runUploadGrant.expiresAtMs must be > 0.');
    }
    final fields = _decodeUploadFields(uploadFields);
    if (fields['Content-Type'] != contentType) {
      throw FormatException(
        'runUploadGrant.uploadFields must bind the grant content type.',
      );
    }
    return RunUploadGrant(
      runSessionId: runSessionId,
      objectPath: objectPath,
      uploadUrl: uploadUrl,
      uploadMethod: uploadMethod,
      uploadFields: fields,
      contentType: contentType,
      maxBytes: maxBytes,
      expiresAtMs: expiresAtMs,
    );
  }
}

Map<String, String> _decodeUploadFields(Object? raw) {
  if (raw is! Map || raw.isEmpty) {
    throw FormatException('runUploadGrant.uploadFields must be non-empty.');
  }
  final fields = <String, String>{};
  for (final entry in raw.entries) {
    if (entry.key is! String || entry.value is! String) {
      throw FormatException(
        'runUploadGrant.uploadFields must contain strings.',
      );
    }
    final name = entry.key as String;
    final value = entry.value as String;
    if (name.isEmpty ||
        value.isEmpty ||
        _containsMultipartLineBreak(name) ||
        _containsMultipartLineBreak(value)) {
      throw FormatException(
        'runUploadGrant.uploadFields contains an invalid form field.',
      );
    }
    fields[name] = value;
  }
  return Map<String, String>.unmodifiable(fields);
}

bool _containsMultipartLineBreak(String value) =>
    value.contains('\r') || value.contains('\n');

abstract class RunSessionApi {
  Future<RunTicket> createRunSession({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  });

  Future<RunUploadGrant> createUploadGrant({
    required String userId,
    required String sessionId,
    required String runSessionId,
  });

  Future<SubmissionStatus> finalizeUpload({
    required String userId,
    required String sessionId,
    required String runSessionId,
    required String canonicalSha256,
    required int contentLengthBytes,
    String? contentType,
    String? objectPath,
    Map<String, Object?>? provisionalSummary,
  });

  Future<SubmissionStatus> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  });
}

class NoopRunSessionApi implements RunSessionApi {
  const NoopRunSessionApi();

  @override
  Future<RunTicket> createRunSession({
    required String userId,
    required String sessionId,
    required RunMode mode,
    required LevelId levelId,
    required String gameCompatVersion,
  }) {
    throw const RunStartRemoteException(
      code: 'unimplemented',
      message: 'Run session API is not configured for this environment.',
    );
  }

  @override
  Future<RunUploadGrant> createUploadGrant({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) {
    throw const RunStartRemoteException(
      code: 'unimplemented',
      message: 'Run session API is not configured for this environment.',
    );
  }

  @override
  Future<SubmissionStatus> finalizeUpload({
    required String userId,
    required String sessionId,
    required String runSessionId,
    required String canonicalSha256,
    required int contentLengthBytes,
    String? contentType,
    String? objectPath,
    Map<String, Object?>? provisionalSummary,
  }) {
    throw const RunStartRemoteException(
      code: 'unimplemented',
      message: 'Run session API is not configured for this environment.',
    );
  }

  @override
  Future<SubmissionStatus> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) {
    throw const RunStartRemoteException(
      code: 'unimplemented',
      message: 'Run session API is not configured for this environment.',
    );
  }
}
