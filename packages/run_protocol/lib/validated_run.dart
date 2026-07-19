import 'board_key.dart';
import 'codecs/json_value_copy.dart';
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
    required Map<String, Object?> stats,
    required this.replayDigest,
    required this.replayStorageRef,
    required this.createdAtMs,
    this.boardId,
    this.boardKey,
    this.rejectionReason,
    this.replayStorageGeneration,
  }) : stats = immutableJsonObject(stats, fieldName: 'stats') {
    _requireNonEmpty(runSessionId, 'runSessionId');
    _requireNonEmpty(uid, 'uid');
    _requireNonEmpty(endedReason, 'endedReason');
    _requireNonEmpty(replayStorageRef, 'replayStorageRef');
    if (score < 0 ||
        distanceMeters < 0 ||
        durationSeconds < 0 ||
        tick < 0 ||
        goldEarned < 0) {
      throw ArgumentError(
        'Validated-run score, distance, duration, tick, and gold must be non-negative.',
      );
    }
    if (accepted && rejectionReason != null) {
      throw ArgumentError('accepted runs must not include rejectionReason.');
    }
    if (!accepted && rejectionReason == null) {
      throw ArgumentError('rejected runs must include rejectionReason.');
    }
    if (rejectionReason != null && rejectionReason!.isEmpty) {
      throw ArgumentError.value(
        rejectionReason,
        'rejectionReason',
        'must be non-empty when set',
      );
    }
    if (mode.requiresBoard) {
      if (boardId == null || boardKey == null) {
        throw ArgumentError(
          'Competitive/Weekly validated runs require board fields.',
        );
      }
      _requireNonEmpty(boardId!, 'boardId');
      if (boardKey!.mode != mode) {
        throw ArgumentError(
          'Competitive/Weekly validated runs must bind boardKey to their mode.',
        );
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
    if (replayStorageGeneration != null &&
        !RegExp(r'^[1-9][0-9]*$').hasMatch(replayStorageGeneration!)) {
      throw ArgumentError.value(
        replayStorageGeneration,
        'replayStorageGeneration',
        'must be a positive integer string when set.',
      );
    }
    if (createdAtMs < 0) {
      throw ArgumentError.value(
        createdAtMs,
        'createdAtMs',
        'must be non-negative',
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

  /// Positive Cloud Storage generation of the exact replay bytes validated.
  ///
  /// Null is retained only for backward reads of legacy evidence.
  final String? replayStorageGeneration;
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
      'stats': mutableJsonObjectCopy(stats, fieldName: 'stats'),
      'replayDigest': replayDigest,
      'replayStorageRef': replayStorageRef,
      if (replayStorageGeneration != null)
        'replayStorageGeneration': replayStorageGeneration,
      'createdAtMs': createdAtMs,
    };
  }

  factory ValidatedRun.fromJson(Object? raw) {
    final json = asObjectMap(raw, fieldName: 'validatedRun');
    return ValidatedRun(
      runSessionId: readRequiredString(json, 'runSessionId'),
      uid: readRequiredString(json, 'uid'),
      boardId: readOptionalString(json, 'boardId'),
      boardKey: json['boardKey'] == null
          ? null
          : BoardKey.fromJson(json['boardKey']),
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
      replayStorageGeneration: readOptionalString(
        json,
        'replayStorageGeneration',
      ),
      createdAtMs: readRequiredInt(json, 'createdAtMs'),
    );
  }

  static void _requireNonEmpty(String value, String name) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, name, 'must be non-empty');
    }
  }
}
