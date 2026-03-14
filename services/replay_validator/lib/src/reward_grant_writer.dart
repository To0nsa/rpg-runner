import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:run_protocol/validated_run.dart';

import 'firestore_value_codec.dart';
import 'google_api_helpers.dart';

abstract class RewardGrantWriter {
  Future<void> writeRewardGrant({
    required String runSessionId,
  });
}

class NoopRewardGrantWriter implements RewardGrantWriter {
  @override
  Future<void> writeRewardGrant({
    required String runSessionId,
  }) async {}
}

class FirestoreRewardGrantWriter implements RewardGrantWriter {
  FirestoreRewardGrantWriter({
    required this.projectId,
    required this.apiProvider,
    int Function()? clockMs,
  }) : _clockMs = clockMs ?? _defaultClockMs;

  final String projectId;
  final GoogleCloudApiProvider apiProvider;
  final int Function() _clockMs;

  String get _databaseRoot => 'projects/$projectId/databases/(default)';
  String _validatedRunDocPath(String runSessionId) =>
      '$_databaseRoot/documents/validated_runs/$runSessionId';
  String _rewardGrantDocPath(String runSessionId) =>
      '$_databaseRoot/documents/reward_grants/$runSessionId';

  @override
  Future<void> writeRewardGrant({
    required String runSessionId,
  }) async {
    final firestoreApi = await apiProvider.firestoreApi();
    final rewardDocPath = _rewardGrantDocPath(runSessionId);
    try {
      await firestoreApi.projects.databases.documents.get(rewardDocPath);
      return;
    } catch (error) {
      if (!isApiNotFound(error)) {
        rethrow;
      }
    }

    final validatedRun = await _loadValidatedRun(
      firestoreApi: firestoreApi,
      runSessionId: runSessionId,
    );
    if (validatedRun == null || !validatedRun.accepted || validatedRun.goldEarned <= 0) {
      return;
    }

    final nowMs = _clockMs();
    final payload = <String, Object?>{
      'runSessionId': runSessionId,
      'uid': validatedRun.uid,
      'state': 'pending_apply',
      'goldAmount': validatedRun.goldEarned,
      'mode': validatedRun.mode.name,
      'validatedRunRef': 'validated_runs/$runSessionId',
      'createdAtMs': nowMs,
      'updatedAtMs': nowMs,
      if (validatedRun.boardId != null) 'boardId': validatedRun.boardId,
      if (validatedRun.boardKey != null)
        'boardKey': validatedRun.boardKey!.toJson(),
    };
    final parentPath = '$_databaseRoot/documents';
    try {
      await firestoreApi.projects.databases.documents.createDocument(
        firestore.Document(fields: encodeFirestoreFields(payload)),
        parentPath,
        'reward_grants',
        documentId: runSessionId,
      );
    } catch (error) {
      if (isApiAlreadyExists(error)) {
        return;
      }
      rethrow;
    }
  }

  Future<ValidatedRun?> _loadValidatedRun({
    required firestore.FirestoreApi firestoreApi,
    required String runSessionId,
  }) async {
    final validatedPath = _validatedRunDocPath(runSessionId);
    firestore.Document document;
    try {
      document = await firestoreApi.projects.databases.documents.get(validatedPath);
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
}

int _defaultClockMs() => DateTime.now().millisecondsSinceEpoch;
