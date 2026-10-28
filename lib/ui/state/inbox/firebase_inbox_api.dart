import 'package:cloud_functions/cloud_functions.dart';
import 'package:runner_core/meta/meta_service.dart';

import '../ownership/loadout_ownership_api.dart';
import '../ownership/progression_state.dart';
import '../ownership/selection_state.dart';
import 'inbox_api.dart';
import 'inbox_models.dart';

/// Injectable transport keeps callable handling outside widgets and state tests.
abstract interface class FirebaseInboxSource {
  Future<Map<String, dynamic>> call(String name, Map<String, Object?> data);
}

class PluginFirebaseInboxSource implements FirebaseInboxSource {
  PluginFirebaseInboxSource({required FirebaseFunctions functions})
    : _functions = functions;
  final FirebaseFunctions _functions;
  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, Object?> data,
  ) async => inboxObject(
    (await _functions.httpsCallable(name).call<Object?>(data)).data,
  );
}

/// Decodes supported inbox contracts strictly; unknown claim outcomes never mean success.
class FirebaseInboxApi implements InboxApi {
  FirebaseInboxApi({required FirebaseInboxSource source}) : _source = source;
  final FirebaseInboxSource _source;

  @override
  Future<InboxSummary> loadSummary({required String userId}) async =>
      InboxSummary.fromJson(
        (await _source.call('inboxLoadSummary', {'userId': userId}))['summary'],
      );

  @override
  Future<InboxPage> loadPage({
    required String userId,
    InboxCursor? cursor,
  }) async => InboxPage.fromJson(
    await _source.call('inboxList', {
      'userId': userId,
      if (cursor != null) 'cursor': cursor.toJson(),
    }),
  );

  @override
  Future<InboxMessageUpdate> markRead({
    required String userId,
    required String messageId,
  }) async {
    final update = InboxMessageUpdate.fromJson(
      await _source.call('inboxMarkRead', {
        'userId': userId,
        'messageId': messageId,
      }),
    );
    if (update.message.id != messageId || update.message.isUnread) {
      throw const FormatException('Invalid read receipt.');
    }
    return update;
  }

  @override
  Future<InboxSummary> deleteMessage({
    required String userId,
    required String messageId,
  }) async {
    final response = await _source.call('inboxDeleteMessage', {
      'userId': userId,
      'messageId': messageId,
    });
    if (response['deleted'] != true || response['messageId'] != messageId) {
      throw const FormatException('Invalid message deletion receipt.');
    }
    return InboxSummary.fromJson(response['summary']);
  }

  @override
  Future<InboxClaimResult> claim({
    required String userId,
    required String messageId,
    required String commandId,
    required int expectedRevision,
  }) async {
    final response = await _source.call('inboxClaimReward', {
      'userId': userId,
      'messageId': messageId,
      'commandId': commandId,
      'expectedRevision': expectedRevision,
    });
    final update = InboxMessageUpdate.fromJson(response);
    final result = inboxObject(response['result']);
    if (!result.containsKey('rejectedReason') ||
        result['replayedFromIdempotency'] is! bool) {
      throw const FormatException('Invalid claim result.');
    }
    final reason = result['rejectedReason'];
    if (reason != null &&
        !OwnershipRejectedReason.values.any((value) => value.name == reason)) {
      throw const FormatException('Unknown claim outcome.');
    }
    final canonical = inboxObject(result['canonicalState']);
    inboxText(canonical['profileId']);
    final revision = inboxInteger(canonical['revision']);
    if (revision != inboxInteger(result['newRevision'])) {
      throw const FormatException('Invalid ownership revision.');
    }
    inboxObject(canonical['selection']);
    inboxObject(canonical['meta']);
    inboxInteger(inboxObject(canonical['progression'])['gold']);
    if (update.message.id != messageId ||
        (reason == null && update.message.claimedAtMs == null)) {
      throw const FormatException('Invalid claim receipt.');
    }
    final ownership = OwnershipCommandResult.fromJson(
      result,
      fallbackCanonicalState: OwnershipCanonicalState(
        profileId: defaultOwnershipProfileId,
        revision: 0,
        selection: SelectionState.defaults,
        meta: const MetaService().createNew(),
        progression: ProgressionState.initial,
      ),
    );
    return InboxClaimResult(
      message: update.message,
      summary: update.summary,
      ownership: ownership,
    );
  }
}
