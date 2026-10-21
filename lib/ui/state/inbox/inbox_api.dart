import 'inbox_models.dart';

/// Account-authenticated system inbox. Only the server may issue messages.
abstract interface class InboxApi {
  Future<InboxSummary> loadSummary({required String userId});

  /// Loads a newest-first page without marking its messages read.
  Future<InboxPage> loadPage({required String userId, InboxCursor? cursor});

  /// Marks this message read once; an attached gift remains unclaimed.
  Future<InboxMessageUpdate> markRead({
    required String userId,
    required String messageId,
  });

  /// Claims a stored attachment with ownership revision and command identity.
  /// Retrying an already claimed gift must never credit the wallet again.
  Future<InboxClaimResult> claim({
    required String userId,
    required String messageId,
    required String commandId,
    required int expectedRevision,
  });
}
