import 'run_session_api.dart';
import 'run_replay_uploader_unavailable.dart'
    if (dart.library.io) 'run_replay_uploader_io.dart'
    as platform;

/// Uploads an opaque durable artifact through the selected platform transport.
abstract class RunReplayUploader {
  Future<void> uploadReplay({
    required RunUploadGrant uploadGrant,
    required String replayArtifactId,
    required int contentLengthBytes,
    required String contentType,
  });
}

final class RunReplayUploadException implements Exception {
  const RunReplayUploadException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() {
    final statusSegment = statusCode == null ? '' : ' statusCode=$statusCode';
    return 'RunReplayUploadException(code=$code$statusSegment, message=$message)';
  }
}

RunReplayUploader createRunReplayUploader() =>
    platform.createRunReplayUploader();
