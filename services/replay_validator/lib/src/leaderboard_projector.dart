import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:run_protocol/leaderboard_entry.dart';
import 'package:run_protocol/replay_digest.dart';
import 'package:run_protocol/sort_key.dart';
import 'package:run_protocol/validated_run.dart';

import 'account_deletion_fence.dart';
import 'firestore_value_codec.dart';
import 'google_api_helpers.dart';

abstract class LeaderboardProjector {
  Future<void> projectValidatedRun({
    required String runSessionId,
    ValidatedRun? validatedRun,
    String? characterId,
  });

  Future<void> reconcileBoard({required String boardId});
}

class NoopLeaderboardProjector implements LeaderboardProjector {
  @override
  Future<void> projectValidatedRun({
    required String runSessionId,
    ValidatedRun? validatedRun,
    String? characterId,
  }) async {}

  @override
  Future<void> reconcileBoard({required String boardId}) async {}
}

abstract class LeaderboardProjectionStore {
  Future<ValidatedRun?> loadValidatedRun({required String runSessionId});

  Future<String?> loadDisplayName({required String uid});

  Future<String?> loadCharacterId({required String runSessionId});

  Future<PlayerBestWriteResult> replacePlayerBestIfBetter({
    required LeaderboardEntry candidate,
  });

  Future<Top10ViewSnapshot> loadTop10View({required String boardId});

  Future<List<LeaderboardEntry>> listTopPlayerBests({
    required String boardId,
    required int limit,
  });

  /// Verified active ghost-manifest evidence keyed by leaderboard entry ID.
  ///
  /// Entries must be matched against the current player-best evidence before
  /// they are surfaced as available to clients.
  Future<Map<String, ActiveGhostManifestEvidence>> loadActiveGhostManifests({
    required String boardId,
  });

  Future<void> setPlayerBestGhostEligible({
    required String boardId,
    required String uid,
    required bool ghostEligible,
    required int nowMs,
  });

  Future<bool> writeTop10View({
    required String boardId,
    required List<LeaderboardEntry> entries,
    required int updatedAtMs,
    required Top10ViewSnapshot expected,
  });
}

/// The immutable evidence that makes an active ghost eligible for projection.
///
/// This is intentionally narrower than the callable response: projection only
/// needs the fields that bind a promoted object to the current leaderboard row.
final class ActiveGhostManifestEvidence {
  const ActiveGhostManifestEvidence({
    required this.boardId,
    required this.entryId,
    required this.runSessionId,
    required this.uid,
    required this.replayStorageRef,
    required this.sourceReplayStorageRef,
    required this.sourceReplayStorageGeneration,
    required this.promotedReplayStorageGeneration,
    required this.replayDigest,
  });

  final String boardId;
  final String entryId;
  final String runSessionId;
  final String uid;
  final String replayStorageRef;
  final String sourceReplayStorageRef;
  final String sourceReplayStorageGeneration;
  final String promotedReplayStorageGeneration;
  final String replayDigest;

  /// Whether this publication is the promoted copy of [entry]'s current replay
  /// evidence, rather than merely another active manifest with the same ID.
  bool matchesEntry(LeaderboardEntry entry) {
    return boardId == entry.boardId &&
        entryId == entry.entryId &&
        runSessionId == entry.runSessionId &&
        uid == entry.uid &&
        sourceReplayStorageRef == entry.replayStorageRef &&
        sourceReplayStorageGeneration == entry.replayStorageGeneration &&
        replayDigest == entry.replayDigest;
  }
}

enum PlayerBestWriteResult { improved, unchanged }

final class Top10ViewSnapshot {
  const Top10ViewSnapshot({
    required this.entries,
    required this.exists,
    this.updateTime,
  });

  const Top10ViewSnapshot.missing()
    : entries = const <LeaderboardEntry>[],
      exists = false,
      updateTime = null;

  final List<LeaderboardEntry> entries;
  final bool exists;
  final String? updateTime;
}

class FirestoreLeaderboardProjector implements LeaderboardProjector {
  FirestoreLeaderboardProjector({
    required String projectId,
    GoogleCloudApiProvider? apiProvider,
    LeaderboardProjectionStore? store,
    int Function()? clockMs,
  }) : _store =
           store ??
           FirestoreLeaderboardProjectionStore(
             projectId: projectId,
             apiProvider: apiProvider ?? GoogleCloudApiProvider(),
           ),
       _clockMs = clockMs ?? _defaultClockMs;

  final LeaderboardProjectionStore _store;
  final int Function() _clockMs;

  @override
  Future<void> projectValidatedRun({
    required String runSessionId,
    ValidatedRun? validatedRun,
    String? characterId,
  }) async {
    final validatedRunMatch =
        validatedRun != null && validatedRun.runSessionId == runSessionId
        ? validatedRun
        : null;
    final resolvedValidatedRun =
        validatedRunMatch ??
        await _store.loadValidatedRun(runSessionId: runSessionId);
    if (resolvedValidatedRun == null ||
        !resolvedValidatedRun.accepted ||
        !resolvedValidatedRun.mode.requiresBoard ||
        resolvedValidatedRun.boardId == null) {
      return;
    }

    final boardId = resolvedValidatedRun.boardId!;
    final uid = resolvedValidatedRun.uid;
    final nowMs = _clockMs();
    final displayName = await _store.loadDisplayName(uid: uid) ?? uid;
    final resolvedCharacterId =
        _nonEmptyString(characterId) ??
        await _store.loadCharacterId(runSessionId: runSessionId) ??
        'eloise';
    final candidate = LeaderboardEntry(
      boardId: boardId,
      entryId: runSessionId,
      runSessionId: runSessionId,
      uid: uid,
      displayName: displayName,
      characterId: resolvedCharacterId,
      score: resolvedValidatedRun.score,
      distanceMeters: resolvedValidatedRun.distanceMeters,
      durationSeconds: resolvedValidatedRun.durationSeconds,
      sortKey: buildLeaderboardSortKey(
        score: resolvedValidatedRun.score,
        distanceMeters: resolvedValidatedRun.distanceMeters,
        durationSeconds: resolvedValidatedRun.durationSeconds,
        entryId: runSessionId,
      ),
      ghostEligible: false,
      replayStorageRef: resolvedValidatedRun.replayStorageRef,
      replayStorageGeneration: resolvedValidatedRun.replayStorageGeneration,
      replayDigest: resolvedValidatedRun.replayDigest,
      updatedAtMs: nowMs,
    );
    await _store.replacePlayerBestIfBetter(candidate: candidate);
    // Always rebuild the materialized view. A duplicate task may be resuming
    // after the player-best write but before top-10/ghost projection completed.
    await _refreshTop10View(boardId: boardId, nowMs: nowMs);
  }

  @override
  Future<void> reconcileBoard({required String boardId}) async {
    final normalizedBoardId = boardId.trim();
    if (normalizedBoardId.isEmpty) {
      throw ArgumentError.value(boardId, 'boardId', 'must be non-empty');
    }
    await _refreshTop10View(boardId: normalizedBoardId, nowMs: _clockMs());
  }

  Future<void> _refreshTop10View({
    required String boardId,
    required int nowMs,
  }) async {
    for (
      var projectionAttempt = 0;
      projectionAttempt < 5;
      projectionAttempt++
    ) {
      final previous = await _store.loadTop10View(boardId: boardId);
      final listed = await _store.listTopPlayerBests(
        boardId: boardId,
        limit: 10,
      );
      final activeGhostManifests = await _store.loadActiveGhostManifests(
        boardId: boardId,
      );

      final topEntries = <LeaderboardEntry>[];
      final topUids = <String>{};
      for (var i = 0; i < listed.length; i += 1) {
        final parsed = listed[i];
        final ranked = LeaderboardEntry(
          boardId: parsed.boardId,
          entryId: parsed.entryId,
          runSessionId: parsed.runSessionId,
          uid: parsed.uid,
          displayName: parsed.displayName,
          characterId: parsed.characterId,
          score: parsed.score,
          distanceMeters: parsed.distanceMeters,
          durationSeconds: parsed.durationSeconds,
          sortKey: parsed.sortKey,
          ghostEligible: true,
          ghostAvailable:
              activeGhostManifests[parsed.entryId]?.matchesEntry(parsed) ??
              false,
          replayStorageRef: parsed.replayStorageRef,
          replayStorageGeneration: parsed.replayStorageGeneration,
          replayDigest: parsed.replayDigest,
          updatedAtMs: nowMs,
          rank: i + 1,
        );
        topEntries.add(ranked);
        topUids.add(ranked.uid);
        await _store.setPlayerBestGhostEligible(
          boardId: boardId,
          uid: ranked.uid,
          ghostEligible: true,
          nowMs: nowMs,
        );
      }

      final previousTopUids = <String>{
        for (final entry in previous.entries) entry.uid,
      };
      for (final uid in previousTopUids) {
        if (topUids.contains(uid)) {
          continue;
        }
        await _store.setPlayerBestGhostEligible(
          boardId: boardId,
          uid: uid,
          ghostEligible: false,
          nowMs: nowMs,
        );
      }

      final committed = await _store.writeTop10View(
        boardId: boardId,
        entries: topEntries,
        updatedAtMs: nowMs,
        expected: previous,
      );
      if (committed) {
        return;
      }
    }
    throw StateError(
      'Top-10 projection conflicted repeatedly for board "$boardId".',
    );
  }
}

class FirestoreLeaderboardProjectionStore
    implements LeaderboardProjectionStore {
  FirestoreLeaderboardProjectionStore({
    required this.projectId,
    required this.apiProvider,
    FirestoreAccountDeletionFence? deletionFence,
  }) : _deletionFence =
           deletionFence ??
           FirestoreAccountDeletionFence(
             projectId: projectId,
             apiProvider: apiProvider,
           );

  final String projectId;
  final GoogleCloudApiProvider apiProvider;
  final FirestoreAccountDeletionFence _deletionFence;

  String get _databaseRoot => 'projects/$projectId/databases/(default)';
  String _validatedRunDocPath(String runSessionId) =>
      '$_databaseRoot/documents/validated_runs/$runSessionId';
  String _runSessionDocPath(String runSessionId) =>
      '$_databaseRoot/documents/run_sessions/$runSessionId';
  String _playerProfileDocPath(String uid) =>
      '$_databaseRoot/documents/player_profiles/$uid';
  String _playerBestDocPath(String boardId, String uid) =>
      '$_databaseRoot/documents/leaderboard_boards/$boardId/player_bests/$uid';
  String _top10ViewDocPath(String boardId) =>
      '$_databaseRoot/documents/leaderboard_boards/$boardId/views/top10';
  String _boardParentDocPath(String boardId) =>
      '$_databaseRoot/documents/leaderboard_boards/$boardId';
  String _ghostManifestDocPath(String boardId, String entryId) =>
      '${_boardParentDocPath(boardId)}/ghost_manifests/$entryId';

  @override
  Future<ValidatedRun?> loadValidatedRun({required String runSessionId}) async {
    final firestoreApi = await apiProvider.firestoreApi();
    firestore.Document document;
    try {
      document = await firestoreApi.projects.databases.documents.get(
        _validatedRunDocPath(runSessionId),
      );
    } catch (error) {
      if (isApiNotFound(error)) {
        return null;
      }
      rethrow;
    }
    final decoded = decodeFirestoreFields(document.fields);
    try {
      return ValidatedRun.fromJson(decoded);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  @override
  Future<String?> loadDisplayName({required String uid}) async {
    final firestoreApi = await apiProvider.firestoreApi();
    firestore.Document document;
    try {
      document = await firestoreApi.projects.databases.documents.get(
        _playerProfileDocPath(uid),
      );
    } catch (error) {
      if (isApiNotFound(error)) {
        return null;
      }
      rethrow;
    }
    final decoded = decodeFirestoreFields(document.fields);
    final displayName = decoded['displayName'];
    if (displayName is String && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }
    return null;
  }

  @override
  Future<String?> loadCharacterId({required String runSessionId}) async {
    final firestoreApi = await apiProvider.firestoreApi();
    firestore.Document document;
    try {
      document = await firestoreApi.projects.databases.documents.get(
        _runSessionDocPath(runSessionId),
      );
    } catch (error) {
      if (isApiNotFound(error)) {
        return null;
      }
      rethrow;
    }
    final decoded = decodeFirestoreFields(document.fields);
    final characterId = decoded['playerCharacterId'];
    if (characterId is String && characterId.trim().isNotEmpty) {
      return characterId.trim();
    }
    final runTicket = decoded['runTicket'];
    if (runTicket is Map) {
      final fromTicket = runTicket['playerCharacterId'];
      if (fromTicket is String && fromTicket.trim().isNotEmpty) {
        return fromTicket.trim();
      }
    }
    return null;
  }

  @override
  Future<PlayerBestWriteResult> replacePlayerBestIfBetter({
    required LeaderboardEntry candidate,
  }) async {
    final path = _playerBestDocPath(candidate.boardId, candidate.uid);
    for (var attempt = 0; attempt < 5; attempt++) {
      final transaction = await _deletionFence.begin(
        uids: <String>[candidate.uid],
      );
      final existingDocument = await transaction.get(path);
      final existing = existingDocument == null
          ? null
          : _parseLeaderboardEntry(
              decodeFirestoreFields(existingDocument.fields),
            );
      if (existing != null &&
          existing.sortKey.compareTo(candidate.sortKey) <= 0) {
        await transaction.rollback();
        return PlayerBestWriteResult.unchanged;
      }
      final payload = candidate.toJson();
      try {
        await transaction.commit(<firestore.Write>[
          firestore.Write(
            update: firestore.Document(
              name: path,
              fields: encodeFirestoreFields(payload),
            ),
            updateMask: firestore.DocumentMask(
              fieldPaths: payload.keys.toList(growable: false),
            ),
            currentDocument: firestore.Precondition(
              exists: existingDocument == null ? false : null,
              updateTime: existingDocument?.updateTime,
            ),
          ),
        ]);
        return PlayerBestWriteResult.improved;
      } catch (error) {
        if (!isApiConflict(error)) {
          rethrow;
        }
      }
    }
    throw StateError(
      'Player-best compare-and-replace conflicted repeatedly for '
      '"${candidate.boardId}/${candidate.uid}".',
    );
  }

  @override
  Future<Top10ViewSnapshot> loadTop10View({required String boardId}) async {
    final firestoreApi = await apiProvider.firestoreApi();
    firestore.Document document;
    try {
      document = await firestoreApi.projects.databases.documents.get(
        _top10ViewDocPath(boardId),
      );
    } catch (error) {
      if (isApiNotFound(error)) {
        return const Top10ViewSnapshot.missing();
      }
      rethrow;
    }
    final decoded = decodeFirestoreFields(document.fields);
    final updateTime = document.updateTime;
    if (updateTime == null || updateTime.isEmpty) {
      throw StateError(
        'Top-10 view "$boardId" is missing its Firestore updateTime.',
      );
    }
    final rawEntries = decoded['entries'];
    if (rawEntries is! List) {
      return Top10ViewSnapshot(
        entries: const <LeaderboardEntry>[],
        exists: true,
        updateTime: updateTime,
      );
    }
    final out = <LeaderboardEntry>[];
    for (final raw in rawEntries) {
      final parsed = _parseLeaderboardEntry(raw);
      if (parsed != null) {
        out.add(parsed);
      }
    }
    return Top10ViewSnapshot(
      entries: out,
      exists: true,
      updateTime: updateTime,
    );
  }

  @override
  Future<List<LeaderboardEntry>> listTopPlayerBests({
    required String boardId,
    required int limit,
  }) async {
    final firestoreApi = await apiProvider.firestoreApi();
    final listed = await firestoreApi.projects.databases.documents.list(
      _boardParentDocPath(boardId),
      'player_bests',
      orderBy: 'sortKey',
      pageSize: limit,
    );
    final documents = listed.documents ?? const <firestore.Document>[];
    final out = <LeaderboardEntry>[];
    for (final doc in documents) {
      final parsed = _parseLeaderboardEntry(decodeFirestoreFields(doc.fields));
      if (parsed != null) {
        out.add(parsed);
      }
    }
    return out;
  }

  @override
  Future<Map<String, ActiveGhostManifestEvidence>> loadActiveGhostManifests({
    required String boardId,
  }) async {
    final firestoreApi = await apiProvider.firestoreApi();
    final manifestsByEntryId = <String, ActiveGhostManifestEvidence>{};
    String? pageToken;
    do {
      final listed = await firestoreApi.projects.databases.documents.list(
        _boardParentDocPath(boardId),
        'ghost_manifests',
        pageSize: 100,
        pageToken: pageToken,
      );
      final documents = listed.documents ?? const <firestore.Document>[];
      for (final document in documents) {
        final decoded = decodeFirestoreFields(document.fields);
        final evidence = _activeGhostManifestEvidence(
          boardId: boardId,
          raw: decoded,
        );
        if (evidence != null &&
            document.name == _ghostManifestDocPath(boardId, evidence.entryId)) {
          manifestsByEntryId[evidence.entryId] = evidence;
        }
      }
      pageToken = _nonEmptyString(listed.nextPageToken);
    } while (pageToken != null);
    return manifestsByEntryId;
  }

  @override
  Future<void> setPlayerBestGhostEligible({
    required String boardId,
    required String uid,
    required bool ghostEligible,
    required int nowMs,
  }) async {
    final payload = <String, Object?>{
      'ghostEligible': ghostEligible,
      'updatedAtMs': nowMs,
    };
    final transaction = await _deletionFence.begin(uids: <String>[uid]);
    await transaction.commit(<firestore.Write>[
      firestore.Write(
        update: firestore.Document(
          name: _playerBestDocPath(boardId, uid),
          fields: encodeFirestoreFields(payload),
        ),
        updateMask: firestore.DocumentMask(
          fieldPaths: payload.keys.toList(growable: false),
        ),
        currentDocument: firestore.Precondition(exists: true),
      ),
    ]);
  }

  @override
  Future<bool> writeTop10View({
    required String boardId,
    required List<LeaderboardEntry> entries,
    required int updatedAtMs,
    required Top10ViewSnapshot expected,
  }) async {
    final payload = <String, Object?>{
      'boardId': boardId,
      'entries': entries.map((e) => e.toJson()).toList(growable: false),
      'sourceRevision': ReplayDigest.canonicalSha256ForMap(<String, Object?>{
        'entries': entries
            .map(
              (entry) => <String, Object?>{
                'uid': entry.uid,
                'runSessionId': entry.runSessionId,
                'sortKey': entry.sortKey,
              },
            )
            .toList(growable: false),
      }),
      'updatedAtMs': updatedAtMs,
    };
    try {
      final transaction = await _deletionFence.begin(
        uids: entries.map((entry) => entry.uid),
      );
      await transaction.commit(<firestore.Write>[
        firestore.Write(
          update: firestore.Document(
            name: _top10ViewDocPath(boardId),
            fields: encodeFirestoreFields(payload),
          ),
          updateMask: firestore.DocumentMask(
            fieldPaths: payload.keys.toList(growable: false),
          ),
          currentDocument: firestore.Precondition(
            exists: expected.exists ? null : false,
            updateTime: expected.updateTime,
          ),
        ),
      ]);
      return true;
    } catch (error) {
      if (isApiConflict(error)) {
        return false;
      }
      rethrow;
    }
  }
}

LeaderboardEntry? _parseLeaderboardEntry(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  try {
    return LeaderboardEntry.fromJson(Map<String, Object?>.from(raw));
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
}

int _defaultClockMs() => DateTime.now().millisecondsSinceEpoch;

String? _nonEmptyString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

ActiveGhostManifestEvidence? _activeGhostManifestEvidence({
  required String boardId,
  required Map<String, Object?> raw,
}) {
  if (raw['status'] != 'active' || raw['exposed'] != true) {
    return null;
  }
  final manifestBoardId = _nonEmptyString(raw['boardId']);
  final entryId = _nonEmptyString(raw['entryId']);
  final runSessionId = _nonEmptyString(raw['runSessionId']);
  final uid = _nonEmptyString(raw['uid']);
  final replayStorageRef = _nonEmptyString(raw['replayStorageRef']);
  final sourceReplayStorageRef = _nonEmptyString(raw['sourceReplayStorageRef']);
  final sourceReplayStorageGeneration = _positiveGeneration(
    raw['sourceReplayStorageGeneration'],
  );
  final promotedReplayStorageGeneration = _positiveGeneration(
    raw['promotedReplayStorageGeneration'],
  );
  final replayDigest = _sha256Digest(raw['replayDigest']);
  if (manifestBoardId == null ||
      manifestBoardId != boardId ||
      entryId == null ||
      runSessionId == null ||
      uid == null ||
      replayStorageRef == null ||
      !replayStorageRef.startsWith('ghosts/') ||
      sourceReplayStorageRef == null ||
      sourceReplayStorageGeneration == null ||
      promotedReplayStorageGeneration == null ||
      replayDigest == null) {
    return null;
  }
  return ActiveGhostManifestEvidence(
    boardId: manifestBoardId,
    entryId: entryId,
    runSessionId: runSessionId,
    uid: uid,
    replayStorageRef: replayStorageRef,
    sourceReplayStorageRef: sourceReplayStorageRef,
    sourceReplayStorageGeneration: sourceReplayStorageGeneration,
    promotedReplayStorageGeneration: promotedReplayStorageGeneration,
    replayDigest: replayDigest,
  );
}

String? _positiveGeneration(Object? value) {
  final parsed = _nonEmptyString(value);
  if (parsed == null || !RegExp(r'^[1-9][0-9]*$').hasMatch(parsed)) {
    return null;
  }
  return parsed;
}

String? _sha256Digest(Object? value) {
  final parsed = _nonEmptyString(value);
  if (parsed == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(parsed)) {
    return null;
  }
  return parsed;
}
