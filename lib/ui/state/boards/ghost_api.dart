import '../run/run_start_remote_exception.dart';

final class GhostManifest {
  const GhostManifest({
    required this.boardId,
    required this.entryId,
    required this.runSessionId,
    required this.uid,
    required this.replayStorageRef,
    required this.sourceReplayStorageRef,
    required this.downloadUrl,
    required this.downloadUrlExpiresAtMs,
    required this.score,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.sortKey,
    required this.rank,
    required this.updatedAtMs,
  });

  final String boardId;
  final String entryId;
  final String runSessionId;
  final String uid;
  final String replayStorageRef;
  final String sourceReplayStorageRef;
  final String downloadUrl;
  final int downloadUrlExpiresAtMs;
  final int score;
  final int distanceMeters;
  final int durationSeconds;
  final String sortKey;
  final int rank;
  final int updatedAtMs;

  factory GhostManifest.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('ghostManifest must be a JSON object.');
    }
    final json = Map<Object?, Object?>.from(raw);
    final boardId = _readRequiredString(json, 'boardId');
    final entryId = _readRequiredString(json, 'entryId');
    final runSessionId = _readRequiredString(json, 'runSessionId');
    final uid = _readRequiredString(json, 'uid');
    final replayStorageRef = _readRequiredString(json, 'replayStorageRef');
    final sourceReplayStorageRef = _readRequiredString(
      json,
      'sourceReplayStorageRef',
    );
    final downloadUrl = _readRequiredString(json, 'downloadUrl');
    final downloadUrlExpiresAtMs = _readRequiredInt(
      json,
      'downloadUrlExpiresAtMs',
    );
    final score = _readRequiredInt(json, 'score');
    final distanceMeters = _readRequiredInt(json, 'distanceMeters');
    final durationSeconds = _readRequiredInt(json, 'durationSeconds');
    final sortKey = _readRequiredString(json, 'sortKey');
    final rank = _readRequiredInt(json, 'rank');
    final updatedAtMs = _readRequiredInt(json, 'updatedAtMs');
    return GhostManifest(
      boardId: boardId,
      entryId: entryId,
      runSessionId: runSessionId,
      uid: uid,
      replayStorageRef: replayStorageRef,
      sourceReplayStorageRef: sourceReplayStorageRef,
      downloadUrl: downloadUrl,
      downloadUrlExpiresAtMs: downloadUrlExpiresAtMs,
      score: score,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      sortKey: sortKey,
      rank: rank,
      updatedAtMs: updatedAtMs,
    );
  }

  static String _readRequiredString(Map<Object?, Object?> json, String key) {
    final raw = json[key];
    if (raw is! String || raw.trim().isEmpty) {
      throw FormatException('ghostManifest.$key must be a non-empty string.');
    }
    return raw.trim();
  }

  static int _readRequiredInt(Map<Object?, Object?> json, String key) {
    final raw = json[key];
    if (raw is! int || raw < 0) {
      throw FormatException(
        'ghostManifest.$key must be a non-negative integer.',
      );
    }
    return raw;
  }
}

abstract class GhostApi {
  Future<GhostManifest> loadManifest({
    required String userId,
    required String sessionId,
    required String boardId,
    required String entryId,
  });
}

class NoopGhostApi implements GhostApi {
  const NoopGhostApi();

  @override
  Future<GhostManifest> loadManifest({
    required String userId,
    required String sessionId,
    required String boardId,
    required String entryId,
  }) {
    throw const RunStartRemoteException(
      code: 'unimplemented',
      message: 'Ghost API is not configured for this environment.',
    );
  }
}
