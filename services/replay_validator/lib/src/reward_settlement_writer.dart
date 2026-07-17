import 'package:googleapis/firestore/v1.dart' as firestore;

import 'firestore_value_codec.dart';
import 'google_api_helpers.dart';

abstract class RewardGrantWriter {
  Future<void> settleRevokedRewardGrant({
    required String runSessionId,
    required String settlementReason,
  });
}

class NoopRewardGrantWriter implements RewardGrantWriter {
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
  String _rewardGrantDocPath(String runSessionId) =>
      '$_databaseRoot/documents/reward_grants/$runSessionId';

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
}

int _defaultClockMs() => DateTime.now().millisecondsSinceEpoch;
