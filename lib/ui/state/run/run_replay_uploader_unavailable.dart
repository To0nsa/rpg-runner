import 'run_replay_uploader.dart';
import 'run_session_api.dart';

RunReplayUploader createRunReplayUploader() =>
    const _UnavailableReplayUploader();

class _UnavailableReplayUploader implements RunReplayUploader {
  const _UnavailableReplayUploader();

  @override
  Future<void> uploadReplay({
    required RunUploadGrant uploadGrant,
    required String replayArtifactId,
    required int contentLengthBytes,
    required String contentType,
  }) async {
    throw UnsupportedError('Replay uploads are unavailable on this platform.');
  }
}
