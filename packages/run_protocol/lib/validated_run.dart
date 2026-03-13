import 'board_key.dart';
import 'codecs/json_value_reader.dart';
import 'replay_digest.dart';
import 'run_mode.dart';

final class ValidatedRun {
  ValidatedRun({
    required this.runSessionId,
    required this.uid,
    required this.mode,
    required this.accepted,
    required this.score,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.tick,
    required this.endedReason,
    required this.goldEarned,
    required this.stats,
    required this.replayDigest,
    required this.replayStorageRef,
    required this.createdAtMs,
    this.boardId,
    this.boardKey,
    this.rejectionReason,
  }) : assert(score >= 0),
       assert(distanceMeters >= 0),
       assert(durationSeconds >= 0),
       assert(tick >= 0),
       assert(goldEarned >= 0) {
    if (accepted && rejectionReason != null) {
      throw ArgumentError('accepted runs must not include rejectionReason.');
    }
    if (!accepted && rejectionReason == null) {
      throw ArgumentError('rejected runs must include rejectionReason.');
    }
    if (mode.requiresBoard) {
      if (boardId == null || boardKey == null) {
        throw ArgumentError('Competitive/Weekly validated runs require board fields.');
      }
    } else if (boardId != null || boardKey != null) {
      throw ArgumentError('Practice validated runs must omit board fields.');
    }
    if (!ReplayDigest.isValidSha256Hex(replayDigest)) {
      throw ArgumentError.value(
        replayDigest,
        'replayDigest',
        'must be a lower-case 64-char SHA-256 hex string.',
      );
    }
  }

  final String runSessionId;
  final String uid;
  final String? boardId;
  final BoardKey? boardKey;
  final RunMode mode;
  final bool accepted;
  final String? rejectionReason;
  final int score;
  final int distanceMeters;
  final int durationSeconds;
  final int tick;
  final String endedReason;
  final int goldEarned;
  final Map<String, Object?> stats;
  final String replayDigest;
  final String replayStorageRef;
  final int createdAtMs;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'runSessionId': runSessionId,
      'uid': uid,
      if (boardId != null) 'boardId': boardId,
      if (boardKey != null) 'boardKey': boardKey!.toJson(),
      'mode': mode.name,
      'accepted': accepted,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'score': score,
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'tick': tick,
      'endedReason': endedReason,
      'goldEarned': goldEarned,
      'stats': stats,
      'replayDigest': replayDigest,
      'replayStorageRef': replayStorageRef,
      'createdAtMs': createdAtMs,
    };
  }

  factory ValidatedRun.fromJson(Object? raw) {
    final json = asObjectMap(raw, fieldName: 'validatedRun');
    return ValidatedRun(
      runSessionId: readRequiredString(json, 'runSessionId'),
      uid: readRequiredString(json, 'uid'),
      boardId: readOptionalString(json, 'boardId'),
      boardKey: json['boardKey'] == null ? null : BoardKey.fromJson(json['boardKey']),
      mode: RunMode.parse(json['mode'], fieldName: 'mode'),
      accepted: readRequiredBool(json, 'accepted'),
      rejectionReason: readOptionalString(json, 'rejectionReason'),
      score: readRequiredInt(json, 'score'),
      distanceMeters: readRequiredInt(json, 'distanceMeters'),
      durationSeconds: readRequiredInt(json, 'durationSeconds'),
      tick: readRequiredInt(json, 'tick'),
      endedReason: readRequiredString(json, 'endedReason'),
      goldEarned: readRequiredInt(json, 'goldEarned'),
      stats: readRequiredObject(json, 'stats'),
      replayDigest: readRequiredString(json, 'replayDigest'),
      replayStorageRef: readRequiredString(json, 'replayStorageRef'),
      createdAtMs: readRequiredInt(json, 'createdAtMs'),
    );
  }
}
