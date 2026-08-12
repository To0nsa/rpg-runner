import 'package:googleapis/firestore/v1.dart' as firestore;

import 'google_api_helpers.dart';

/// Raised when an asynchronous worker attempts to write data for an account
/// whose deletion tombstone already exists.
final class AccountDeletionInProgressException implements Exception {
  const AccountDeletionInProgressException(this.uid);

  final String uid;

  @override
  String toString() => 'Account deletion is in progress for uid "$uid".';
}

/// Starts Firestore transactions that atomically fence user-owned writes
/// against `account_deletion_requests/{uid}`.
///
/// The tombstone documents are read in the same transaction that commits the
/// caller's writes. A concurrent tombstone creation therefore invalidates the
/// commit instead of allowing a projection or ghost write to reintroduce data.
final class FirestoreAccountDeletionFence {
  FirestoreAccountDeletionFence({
    required this.projectId,
    required this.apiProvider,
  });

  final String projectId;
  final GoogleCloudApiProvider apiProvider;

  String get _databaseRoot => 'projects/$projectId/databases/(default)';

  Future<DeletionFencedFirestoreTransaction> begin({
    required Iterable<String> uids,
  }) async {
    final firestoreApi = await apiProvider.firestoreApi();
    final response = await firestoreApi.projects.databases.documents
        .beginTransaction(firestore.BeginTransactionRequest(), _databaseRoot);
    final transaction = response.transaction;
    if (transaction == null || transaction.isEmpty) {
      throw StateError('Firestore did not return a transaction id.');
    }

    final distinctUids = <String>{
      for (final uid in uids)
        if (uid.trim().isNotEmpty) uid.trim(),
    };
    try {
      for (final uid in distinctUids) {
        try {
          await firestoreApi.projects.databases.documents.get(
            '$_databaseRoot/documents/account_deletion_requests/$uid',
            transaction: transaction,
          );
        } catch (error) {
          if (isApiNotFound(error)) {
            continue;
          }
          rethrow;
        }
        throw AccountDeletionInProgressException(uid);
      }
    } catch (_) {
      await _bestEffortRollback(
        firestoreApi: firestoreApi,
        databaseRoot: _databaseRoot,
        transaction: transaction,
      );
      rethrow;
    }

    return DeletionFencedFirestoreTransaction._(
      firestoreApi: firestoreApi,
      databaseRoot: _databaseRoot,
      transaction: transaction,
    );
  }
}

/// A Firestore transaction whose commit is fenced by one or more absent
/// account-deletion tombstones.
final class DeletionFencedFirestoreTransaction {
  const DeletionFencedFirestoreTransaction._({
    required this.firestoreApi,
    required this.databaseRoot,
    required this.transaction,
  });

  final firestore.FirestoreApi firestoreApi;
  final String databaseRoot;
  final String transaction;

  Future<firestore.Document?> get(String path) async {
    try {
      return await firestoreApi.projects.databases.documents.get(
        path,
        transaction: transaction,
      );
    } catch (error) {
      if (isApiNotFound(error)) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> commit(List<firestore.Write> writes) async {
    await firestoreApi.projects.databases.documents.commit(
      firestore.CommitRequest(transaction: transaction, writes: writes),
      databaseRoot,
    );
  }

  /// Releases the transaction when a compare-and-replace needs no write.
  Future<void> rollback() async {
    await firestoreApi.projects.databases.documents.rollback(
      firestore.RollbackRequest(transaction: transaction),
      databaseRoot,
    );
  }
}

Future<void> _bestEffortRollback({
  required firestore.FirestoreApi firestoreApi,
  required String databaseRoot,
  required String transaction,
}) async {
  try {
    await firestoreApi.projects.databases.documents.rollback(
      firestore.RollbackRequest(transaction: transaction),
      databaseRoot,
    );
  } catch (_) {
    // Preserve the fence failure that prevented the user-owned write.
  }
}
