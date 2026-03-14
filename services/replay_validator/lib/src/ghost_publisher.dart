import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:googleapis/storage/v1.dart' as storage;
import 'package:run_protocol/leaderboard_entry.dart';
import 'package:run_protocol/validated_run.dart';

import 'firestore_value_codec.dart';
import 'google_api_helpers.dart';

const Duration _defaultDemotionGrace = Duration(days: 7);

abstract class GhostPublisher {
  Future<void> updateGhostArtifacts({required String runSessionId});
}

class NoopGhostPublisher implements GhostPublisher {
  @override
  Future<void> updateGhostArtifacts({required String runSessionId}) async {}
}

enum GhostManifestStatus { active, demoted }

class GhostManifestRecord {
  const GhostManifestRecord({
    required this.boardId,
    required this.entryId,
    required this.runSessionId,
    required this.uid,
    required this.replayStorageRef,
    required this.sourceReplayStorageRef,
    required this.score,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.sortKey,
    required this.rank,
    required this.status,
    required this.exposed,
    required this.updatedAtMs,
    this.promotedAtMs,
    this.demotedAtMs,
    this.expiresAtMs,
  });

  final String boardId;
  final String entryId;
  final String runSessionId;
  final String uid;
  final String replayStorageRef;
  final String sourceReplayStorageRef;
  final int score;
  final int distanceMeters;
  final int durationSeconds;
  final String sortKey;
  final int rank;
  final GhostManifestStatus status;
  final bool exposed;
  final int updatedAtMs;
  final int? promotedAtMs;
  final int? demotedAtMs;
  final int? expiresAtMs;
}

abstract class GhostPublicationStore {
  Future<ValidatedRun?> loadValidatedRun({required String runSessionId});

  Future<List<LeaderboardEntry>> loadTop10Entries({required String boardId});

  Future<List<GhostManifestRecord>> listGhostManifests({
    required String boardId,
  });

  Future<void> upsertGhostManifest({required GhostManifestRecord manifest});

  Future<void> deleteGhostManifest({
    required String boardId,
    required String entryId,
  });
}

abstract class GhostObjectStore {
  Future<void> promoteReplayToGhost({
    required String sourceObjectPath,
    required String destinationObjectPath,
  });

  Future<void> deleteGhostObject({required String objectPath});
}

class FirestoreGhostPublisher implements GhostPublisher {
  FirestoreGhostPublisher({
    required String projectId,
    required String replayStorageBucket,
    GoogleCloudApiProvider? apiProvider,
    GhostPublicationStore? publicationStore,
    GhostObjectStore? objectStore,
    int Function()? clockMs,
    Duration demotionGrace = _defaultDemotionGrace,
  }) : _store =
           publicationStore ??
           FirestoreGhostPublicationStore(
             projectId: projectId,
             apiProvider: apiProvider ?? GoogleCloudApiProvider(),
           ),
       _objectStore =
           objectStore ??
           GoogleCloudStorageGhostObjectStore(
             bucketName: replayStorageBucket,
             apiProvider: apiProvider ?? GoogleCloudApiProvider(),
           ),
       _clockMs = clockMs ?? _defaultClockMs,
       _demotionGrace = demotionGrace;

  final GhostPublicationStore _store;
  final GhostObjectStore _objectStore;
  final int Function() _clockMs;
  final Duration _demotionGrace;

  @override
  Future<void> updateGhostArtifacts({required String runSessionId}) async {
    final validatedRun = await _store.loadValidatedRun(
      runSessionId: runSessionId,
    );
    if (validatedRun == null ||
        !validatedRun.accepted ||
        !validatedRun.mode.requiresBoard ||
        validatedRun.boardId == null) {
      return;
    }

    final boardId = validatedRun.boardId!;
    final nowMs = _clockMs();
    final topEntries = await _store.loadTop10Entries(boardId: boardId);
    if (topEntries.isEmpty) {
      return;
    }
    final topByEntryId = <String, LeaderboardEntry>{
      for (final entry in topEntries) entry.entryId: entry,
    };

    for (final entry in topEntries) {
      await _promoteTopEntry(entry: entry, nowMs: nowMs);
    }

    final manifests = await _store.listGhostManifests(boardId: boardId);
    for (final manifest in manifests) {
      final stillTop = topByEntryId.containsKey(manifest.entryId);
      if (stillTop) {
        continue;
      }
      if (manifest.status == GhostManifestStatus.demoted &&
          manifest.expiresAtMs != null &&
          manifest.expiresAtMs! <= nowMs) {
        await _objectStore.deleteGhostObject(
          objectPath: manifest.replayStorageRef,
        );
        await _store.deleteGhostManifest(
          boardId: manifest.boardId,
          entryId: manifest.entryId,
        );
        continue;
      }

      if (manifest.status == GhostManifestStatus.demoted) {
        continue;
      }

      await _store.upsertGhostManifest(
        manifest: GhostManifestRecord(
          boardId: manifest.boardId,
          entryId: manifest.entryId,
          runSessionId: manifest.runSessionId,
          uid: manifest.uid,
          replayStorageRef: manifest.replayStorageRef,
          sourceReplayStorageRef: manifest.sourceReplayStorageRef,
          score: manifest.score,
          distanceMeters: manifest.distanceMeters,
          durationSeconds: manifest.durationSeconds,
          sortKey: manifest.sortKey,
          rank: manifest.rank,
          status: GhostManifestStatus.demoted,
          exposed: false,
          updatedAtMs: nowMs,
          promotedAtMs: manifest.promotedAtMs,
          demotedAtMs: nowMs,
          expiresAtMs: nowMs + _demotionGrace.inMilliseconds,
        ),
      );
    }
  }

  Future<void> _promoteTopEntry({
    required LeaderboardEntry entry,
    required int nowMs,
  }) async {
    final sourcePath = _nonEmpty(entry.replayStorageRef);
    if (sourcePath == null) {
      return;
    }
    final destinationPath = _ghostObjectPath(
      boardId: entry.boardId,
      entryId: entry.entryId,
    );

    if (sourcePath != destinationPath) {
      await _objectStore.promoteReplayToGhost(
        sourceObjectPath: sourcePath,
        destinationObjectPath: destinationPath,
      );
    }

    await _store.upsertGhostManifest(
      manifest: GhostManifestRecord(
        boardId: entry.boardId,
        entryId: entry.entryId,
        runSessionId: entry.runSessionId,
        uid: entry.uid,
        replayStorageRef: destinationPath,
        sourceReplayStorageRef: sourcePath,
        score: entry.score,
        distanceMeters: entry.distanceMeters,
        durationSeconds: entry.durationSeconds,
        sortKey: entry.sortKey,
        rank: entry.rank ?? 0,
        status: GhostManifestStatus.active,
        exposed: true,
        updatedAtMs: nowMs,
        promotedAtMs: nowMs,
      ),
    );
  }
}

class FirestoreGhostPublicationStore implements GhostPublicationStore {
  FirestoreGhostPublicationStore({
    required this.projectId,
    required this.apiProvider,
  });

  final String projectId;
  final GoogleCloudApiProvider apiProvider;

  String get _databaseRoot => 'projects/$projectId/databases/(default)';
  String _validatedRunDocPath(String runSessionId) =>
      '$_databaseRoot/documents/validated_runs/$runSessionId';
  String _top10ViewDocPath(String boardId) =>
      '$_databaseRoot/documents/leaderboard_boards/$boardId/views/top10';
  String _ghostManifestDocPath(String boardId, String entryId) =>
      '$_databaseRoot/documents/leaderboard_boards/$boardId/ghost_manifests/$entryId';
  String _boardParentDocPath(String boardId) =>
      '$_databaseRoot/documents/leaderboard_boards/$boardId';

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
  Future<List<LeaderboardEntry>> loadTop10Entries({
    required String boardId,
  }) async {
    final firestoreApi = await apiProvider.firestoreApi();
    firestore.Document document;
    try {
      document = await firestoreApi.projects.databases.documents.get(
        _top10ViewDocPath(boardId),
      );
    } catch (error) {
      if (isApiNotFound(error)) {
        return const <LeaderboardEntry>[];
      }
      rethrow;
    }
    final decoded = decodeFirestoreFields(document.fields);
    final rawEntries = decoded['entries'];
    if (rawEntries is! List) {
      return const <LeaderboardEntry>[];
    }
    final out = <LeaderboardEntry>[];
    for (final raw in rawEntries) {
      if (raw is! Map) {
        continue;
      }
      try {
        out.add(LeaderboardEntry.fromJson(Map<String, Object?>.from(raw)));
      } on FormatException {
        continue;
      } on ArgumentError {
        continue;
      }
    }
    return out;
  }

  @override
  Future<List<GhostManifestRecord>> listGhostManifests({
    required String boardId,
  }) async {
    final firestoreApi = await apiProvider.firestoreApi();
    final listed = await firestoreApi.projects.databases.documents.list(
      _boardParentDocPath(boardId),
      'ghost_manifests',
      orderBy: 'rank',
      pageSize: 100,
    );
    final docs = listed.documents ?? const <firestore.Document>[];
    final out = <GhostManifestRecord>[];
    for (final doc in docs) {
      final parsed = _parseGhostManifest(decodeFirestoreFields(doc.fields));
      if (parsed != null) {
        out.add(parsed);
      }
    }
    return out;
  }

  @override
  Future<void> upsertGhostManifest({
    required GhostManifestRecord manifest,
  }) async {
    final firestoreApi = await apiProvider.firestoreApi();
    final payload = <String, Object?>{
      'boardId': manifest.boardId,
      'entryId': manifest.entryId,
      'runSessionId': manifest.runSessionId,
      'uid': manifest.uid,
      'replayStorageRef': manifest.replayStorageRef,
      'sourceReplayStorageRef': manifest.sourceReplayStorageRef,
      'score': manifest.score,
      'distanceMeters': manifest.distanceMeters,
      'durationSeconds': manifest.durationSeconds,
      'sortKey': manifest.sortKey,
      'rank': manifest.rank,
      'status': manifest.status.name,
      'exposed': manifest.exposed,
      'updatedAtMs': manifest.updatedAtMs,
      if (manifest.promotedAtMs != null) 'promotedAtMs': manifest.promotedAtMs,
      if (manifest.demotedAtMs != null) 'demotedAtMs': manifest.demotedAtMs,
      if (manifest.expiresAtMs != null) 'expiresAtMs': manifest.expiresAtMs,
    };
    await firestoreApi.projects.databases.documents.patch(
      firestore.Document(fields: encodeFirestoreFields(payload)),
      _ghostManifestDocPath(manifest.boardId, manifest.entryId),
      updateMask_fieldPaths: payload.keys.toList(growable: false),
    );
  }

  @override
  Future<void> deleteGhostManifest({
    required String boardId,
    required String entryId,
  }) async {
    final firestoreApi = await apiProvider.firestoreApi();
    try {
      await firestoreApi.projects.databases.documents.delete(
        _ghostManifestDocPath(boardId, entryId),
      );
    } catch (error) {
      if (isApiNotFound(error)) {
        return;
      }
      rethrow;
    }
  }

  GhostManifestRecord? _parseGhostManifest(Map<String, Object?> raw) {
    final boardId = _nonEmpty(raw['boardId']);
    final entryId = _nonEmpty(raw['entryId']);
    final runSessionId = _nonEmpty(raw['runSessionId']);
    final uid = _nonEmpty(raw['uid']);
    final replayStorageRef = _nonEmpty(raw['replayStorageRef']);
    final sourceReplayStorageRef = _nonEmpty(raw['sourceReplayStorageRef']);
    final score = _readInt(raw['score']);
    final distanceMeters = _readInt(raw['distanceMeters']);
    final durationSeconds = _readInt(raw['durationSeconds']);
    final sortKey = _nonEmpty(raw['sortKey']);
    final rank = _readInt(raw['rank']);
    final statusRaw = _nonEmpty(raw['status']);
    final exposed = raw['exposed'];
    final updatedAtMs = _readInt(raw['updatedAtMs']);
    if (boardId == null ||
        entryId == null ||
        runSessionId == null ||
        uid == null ||
        replayStorageRef == null ||
        sourceReplayStorageRef == null ||
        score == null ||
        distanceMeters == null ||
        durationSeconds == null ||
        sortKey == null ||
        rank == null ||
        statusRaw == null ||
        exposed is! bool ||
        updatedAtMs == null) {
      return null;
    }
    final status = switch (statusRaw) {
      'active' => GhostManifestStatus.active,
      'demoted' => GhostManifestStatus.demoted,
      _ => null,
    };
    if (status == null) {
      return null;
    }
    return GhostManifestRecord(
      boardId: boardId,
      entryId: entryId,
      runSessionId: runSessionId,
      uid: uid,
      replayStorageRef: replayStorageRef,
      sourceReplayStorageRef: sourceReplayStorageRef,
      score: score,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      sortKey: sortKey,
      rank: rank,
      status: status,
      exposed: exposed,
      updatedAtMs: updatedAtMs,
      promotedAtMs: _readInt(raw['promotedAtMs']),
      demotedAtMs: _readInt(raw['demotedAtMs']),
      expiresAtMs: _readInt(raw['expiresAtMs']),
    );
  }
}

class GoogleCloudStorageGhostObjectStore implements GhostObjectStore {
  GoogleCloudStorageGhostObjectStore({
    required this.bucketName,
    required this.apiProvider,
  });

  final String bucketName;
  final GoogleCloudApiProvider apiProvider;

  @override
  Future<void> promoteReplayToGhost({
    required String sourceObjectPath,
    required String destinationObjectPath,
  }) async {
    final storageApi = await apiProvider.storageApi();
    await storageApi.objects.copy(
      storage.Object(),
      bucketName,
      sourceObjectPath,
      bucketName,
      destinationObjectPath,
    );
  }

  @override
  Future<void> deleteGhostObject({required String objectPath}) async {
    final storageApi = await apiProvider.storageApi();
    try {
      await storageApi.objects.delete(bucketName, objectPath);
    } catch (error) {
      if (isApiNotFound(error)) {
        return;
      }
      rethrow;
    }
  }
}

String _ghostObjectPath({required String boardId, required String entryId}) {
  return 'ghosts/$boardId/$entryId/ghost.bin.gz';
}

String? _nonEmpty(Object? raw) {
  if (raw is! String) {
    return null;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

int? _readInt(Object? raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  return null;
}

int _defaultClockMs() => DateTime.now().millisecondsSinceEpoch;
