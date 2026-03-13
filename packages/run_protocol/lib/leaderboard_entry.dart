import 'codecs/json_value_reader.dart';

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
    this.rank,
  }) : assert(score >= 0),
       assert(distanceMeters >= 0),
       assert(durationSeconds >= 0),
       assert(updatedAtMs >= 0),
       assert(rank == null || rank > 0);

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
      updatedAtMs: readRequiredInt(json, 'updatedAtMs'),
      rank: readOptionalInt(json, 'rank'),
    );
  }
}
