import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:run_protocol/validated_run.dart';

import 'firestore_value_codec.dart';
import 'google_api_helpers.dart';

abstract class RewardGrantWriter {
  Future<void> settleValidatedRewardGrant({
    required String runSessionId,
  });

  Future<void> settleRevokedRewardGrant({
    required String runSessionId,
    required String settlementReason,
  });
}

class NoopRewardGrantWriter implements RewardGrantWriter {
  @override
  Future<void> settleValidatedRewardGrant({
    required String runSessionId,
  }) async {}

  @override
  Future<void> settleRevokedRewardGrant({
    required String runSessionId,
    required String settlementReason,
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
  Future<void> settleValidatedRewardGrant({
    required String runSessionId,
  }) async {
    final firestoreApi = await apiProvider.firestoreApi();
    final rewardDocPath = _rewardGrantDocPath(runSessionId);

    final nowMs = _clockMs();
    final validatedRun = await _loadValidatedRun(
      firestoreApi: firestoreApi,
      runSessionId: runSessionId,
    );
    final acceptedGold =
        validatedRun != null && validatedRun.accepted
            ? validatedRun.goldEarned
            : null;

    try {
      await firestoreApi.projects.databases.documents.patch(
        firestore.Document(
          fields: encodeFirestoreFields(<String, Object?>{
            'lifecycleState': 'validated_settled',
            'updatedAtMs': nowMs,
            'validatedAtMs': nowMs,
            if (acceptedGold != null && acceptedGold >= 0)
              'goldAmount': acceptedGold,
            if (validatedRun != null) 'uid': validatedRun.uid,
            if (validatedRun?.mode != null) 'mode': validatedRun!.mode.name,
            if (validatedRun?.boardId != null) 'boardId': validatedRun!.boardId,
            if (validatedRun?.boardKey != null)
              'boardKey': validatedRun!.boardKey!.toJson(),
            if (validatedRun != null)
              'validatedRunRef': 'validated_runs/$runSessionId',
            'lastTransitionBy': 'validator',
            'settlementReason': null,
          }),
        ),
        rewardDocPath,
        updateMask_fieldPaths: const <String>[
          'lifecycleState',
          'updatedAtMs',
          'validatedAtMs',
          'goldAmount',
          'uid',
          'mode',
          'boardId',
          'boardKey',
          'validatedRunRef',
          'lastTransitionBy',
          'settlementReason',
        ],
      );
    } catch (error) {
      if (isApiNotFound(error)) {
        // Finalize is authoritative for grant creation. If the grant is missing,
        // skip settlement to preserve idempotency.
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> settleRevokedRewardGrant({
    required String runSessionId,
    required String settlementReason,
  }) async {
    final firestoreApi = await apiProvider.firestoreApi();
    final rewardDocPath = _rewardGrantDocPath(runSessionId);
    final nowMs = _clockMs();

    try {
      await firestoreApi.projects.databases.documents.patch(
        firestore.Document(
          fields: encodeFirestoreFields(<String, Object?>{
            'lifecycleState': 'revocation_visible',
            'updatedAtMs': nowMs,
            'revokedAtMs': nowMs,
            'settlementReason': settlementReason,
            'lastTransitionBy': 'validator',
          }),
        ),
        rewardDocPath,
        updateMask_fieldPaths: const <String>[
          'lifecycleState',
          'updatedAtMs',
          'revokedAtMs',
          'settlementReason',
          'lastTransitionBy',
        ],
      );
    } catch (error) {
      if (isApiNotFound(error)) {
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
