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
    required this.contentType,
    required this.maxBytes,
    required this.expiresAtMs,
  });

  final String runSessionId;
  final String objectPath;
  final String uploadUrl;
  final String uploadMethod;
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
    if (uploadMethod is! String || uploadMethod.trim().isEmpty) {
      throw FormatException('runUploadGrant.uploadMethod must be non-empty.');
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
    return RunUploadGrant(
      runSessionId: runSessionId,
      objectPath: objectPath,
      uploadUrl: uploadUrl,
      uploadMethod: uploadMethod,
      contentType: contentType,
      maxBytes: maxBytes,
      expiresAtMs: expiresAtMs,
    );
  }
}

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
