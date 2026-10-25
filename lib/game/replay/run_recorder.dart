import 'package:run_protocol/board_key.dart';
import 'package:run_protocol/replay_blob.dart';

import 'run_recorder_unavailable.dart'
    if (dart.library.io) 'run_recorder_io.dart'
    as platform;

/// Immutable metadata for one local replay recording session.
class RunRecorderHeader {
  const RunRecorderHeader({
    required this.runSessionId,
    required this.tickHz,
    required this.seed,
    required this.levelId,
    required this.playerCharacterId,
    required this.loadoutSnapshot,
    this.boardId,
    this.boardKey,
  });

  final String runSessionId;
  final String? boardId;
  final BoardKey? boardKey;
  final int tickHz;
  final int seed;
  final String levelId;
  final String playerCharacterId;
  final Map<String, Object?> loadoutSnapshot;
}

/// Finalized replay and durable artifact metadata for submission.
/// The artifact ID is opaque outside the platform storage/transport adapter.
class RunRecorderFinalizeResult {
  const RunRecorderFinalizeResult({
    required this.replayBlob,
    required this.replayArtifactId,
    required this.contentLengthBytes,
    required this.streamDigestSha256,
    required this.framesRecorded,
  });

  final ReplayBlobV1 replayBlob;
  final String replayArtifactId;
  final int contentLengthBytes;
  final String streamDigestSha256;
  final int framesRecorded;
}

/// Records canonical frames without exposing native filesystem handles.
abstract interface class RunRecorder {
  /// Opens the platform's recorder; unavailable on Practice-only web builds.
  static Future<RunRecorder> create({required RunRecorderHeader header}) =>
      platform.createRunRecorder(header);

  void appendFrame(ReplayCommandFrameV1 frame);
  Future<RunRecorderFinalizeResult> finalize({
    Map<String, Object?>? clientSummary,
  });
  Future<void> close();
}
