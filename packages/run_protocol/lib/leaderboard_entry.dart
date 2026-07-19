import 'codecs/json_value_reader.dart';
import 'replay_digest.dart';

final class LeaderboardEntry {
  LeaderboardEntry({
    required this.boardId,
    required this.entryId,
    required this.runSessionId,
    required this.uid,
    required this.displayName,
    required this.characterId,
    required this.score,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.sortKey,
    required this.ghostEligible,
    required this.updatedAtMs,
    this.replayStorageRef,
    this.replayStorageGeneration,
    this.replayDigest,
    this.rank,
  }) {
    _requireNonEmpty(boardId, 'boardId');
    _requireNonEmpty(entryId, 'entryId');
    _requireNonEmpty(runSessionId, 'runSessionId');
    _requireNonEmpty(uid, 'uid');
    _requireNonEmpty(displayName, 'displayName');
    _requireNonEmpty(characterId, 'characterId');
    _requireNonEmpty(sortKey, 'sortKey');
    if (score < 0 ||
        distanceMeters < 0 ||
        durationSeconds < 0 ||
        updatedAtMs < 0 ||
        (rank != null && rank! <= 0)) {
      throw ArgumentError(
        'Leaderboard score, distance, duration, updatedAtMs, and rank must be non-negative.',
      );
    }
    if (replayStorageRef != null && replayStorageRef!.isEmpty) {
      throw ArgumentError.value(
        replayStorageRef,
        'replayStorageRef',
        'must be non-empty when set',
      );
    }
    if (replayStorageGeneration != null &&
        !RegExp(r'^[1-9][0-9]*$').hasMatch(replayStorageGeneration!)) {
      throw ArgumentError.value(
        replayStorageGeneration,
        'replayStorageGeneration',
        'must be a positive integer string when set.',
      );
    }
    if (replayDigest != null && !ReplayDigest.isValidSha256Hex(replayDigest!)) {
      throw ArgumentError.value(
        replayDigest,
        'replayDigest',
        'must be a lower-case SHA-256 digest when set.',
      );
    }
  }

  final String boardId;
  final String entryId;
  final String runSessionId;
  final String uid;
  final String displayName;
  final String characterId;
  final int score;
  final int distanceMeters;
  final int durationSeconds;
  final String sortKey;
  final bool ghostEligible;
  final String? replayStorageRef;

  /// Immutable source generation used when promoting this entry as a ghost.
  final String? replayStorageGeneration;

  /// Canonical SHA-256 of the replay evidence represented by this entry.
  final String? replayDigest;
  final int updatedAtMs;
  final int? rank;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'boardId': boardId,
      'entryId': entryId,
      'runSessionId': runSessionId,
      'uid': uid,
      'displayName': displayName,
      'characterId': characterId,
      'score': score,
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'sortKey': sortKey,
      'ghostEligible': ghostEligible,
      if (replayStorageRef != null) 'replayStorageRef': replayStorageRef,
      if (replayStorageGeneration != null)
        'replayStorageGeneration': replayStorageGeneration,
      if (replayDigest != null) 'replayDigest': replayDigest,
      'updatedAtMs': updatedAtMs,
      if (rank != null) 'rank': rank,
    };
  }

  factory LeaderboardEntry.fromJson(Object? raw) {
    final json = asObjectMap(raw, fieldName: 'leaderboardEntry');
    return LeaderboardEntry(
      boardId: readRequiredString(json, 'boardId'),
      entryId: readRequiredString(json, 'entryId'),
      runSessionId: readRequiredString(json, 'runSessionId'),
      uid: readRequiredString(json, 'uid'),
      displayName: readRequiredString(json, 'displayName'),
      characterId: readRequiredString(json, 'characterId'),
      score: readRequiredInt(json, 'score'),
      distanceMeters: readRequiredInt(json, 'distanceMeters'),
      durationSeconds: readRequiredInt(json, 'durationSeconds'),
      sortKey: readRequiredString(json, 'sortKey'),
      ghostEligible: readRequiredBool(json, 'ghostEligible'),
      replayStorageRef: readOptionalString(json, 'replayStorageRef'),
      replayStorageGeneration: readOptionalString(
        json,
        'replayStorageGeneration',
      ),
      replayDigest: readOptionalString(json, 'replayDigest'),
      updatedAtMs: readRequiredInt(json, 'updatedAtMs'),
      rank: readOptionalInt(json, 'rank'),
    );
  }

  static void _requireNonEmpty(String value, String name) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, name, 'must be non-empty');
    }
  }
}
