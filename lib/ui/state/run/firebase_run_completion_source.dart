import 'package:cloud_firestore/cloud_firestore.dart';

import 'run_submission_response.dart';

final class FirebaseRunCompletionSource implements RunCompletionSource {
  FirebaseRunCompletionSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<RunSubmissionResponse> watch({
    required String userId,
    required String runSessionId,
  }) => _firestore
      .collection('run_completion_receipts')
      .doc(userId)
      .collection('runs')
      .doc(runSessionId)
      .snapshots(includeMetadataChanges: true)
      .where(
        (snapshot) =>
            snapshot.exists &&
            !snapshot.metadata.isFromCache &&
            !snapshot.metadata.hasPendingWrites,
      )
      .map(
        (snapshot) => RunSubmissionResponse.fromReceipt(
          snapshot.data(),
          userId: userId,
          runSessionId: runSessionId,
        ),
      );
}
