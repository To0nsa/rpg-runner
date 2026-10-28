import 'dart:async';

import 'package:runner_core/meta/meta_service.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/auth/auth_api.dart';
import 'package:rpg_runner/ui/state/inbox/inbox_api.dart';
import 'package:rpg_runner/ui/state/inbox/inbox_models.dart';
import 'package:rpg_runner/ui/state/ownership/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';

class InboxFixture {
  InboxFixture() {
    inbox = TestInboxApi(ownership);
    app = AppState(
      authApi: auth,
      loadoutOwnershipApi: ownership,
      inboxApi: inbox,
    );
  }
  final auth = TestInboxAuth();
  final ownership = TestInboxOwnership();
  late final TestInboxApi inbox;
  late final AppState app;
}

class TestInboxAuth implements AuthApi {
  String uid = 'inbox-player';
  @override
  Future<AuthSession> ensureAuthenticatedSession() async => AuthSession(
    userId: uid,
    sessionId: 'session',
    isAnonymous: false,
    expiresAtMs: 0,
  );
  @override
  Future<AuthSession> loadSession() => ensureAuthenticatedSession();
  @override
  Future<AuthSession> reauthenticateForSensitiveOperation() =>
      ensureAuthenticatedSession();
  @override
  Future<void> clearSession() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestInboxOwnership implements LoadoutOwnershipApi {
  OwnershipCanonicalState canonical = OwnershipCanonicalState(
    profileId: 'main',
    revision: 0,
    selection: SelectionState.defaults,
    meta: const MetaService().createNew(),
    progression: ProgressionState.initial,
  );
  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async => canonical;
  @override
  Future<OwnershipCommandResult> setSelection(
    SetSelectionCommand command,
  ) async {
    canonical = canonical.copyWith(revision: canonical.revision + 1);
    return OwnershipCommandResult(
      canonicalState: canonical,
      newRevision: canonical.revision,
      replayedFromIdempotency: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestInboxApi implements InboxApi {
  TestInboxApi(this.ownership);
  final TestInboxOwnership ownership;
  List<InboxMessage> messages = [
    const InboxMessage(
      id: 'gift',
      title: 'Level 2 reached',
      body: 'You have reached level 2. Your gold reward is ready to claim.',
      createdAtMs: 1792530000000,
      goldAmount: 25,
    ),
  ];
  int revision = 1;
  int claimCalls = 0;
  bool failLoad = false;
  bool failRead = false;
  bool loseNextClaimResponse = false;
  bool staleNextClaim = false;
  bool failDelete = false;
  bool loseNextDeleteResponse = false;
  int deleteCalls = 0;
  Completer<void>? deleteGate;
  final Set<String> deletedIds = {};
  Completer<InboxPage>? delayedPage;
  Completer<void>? claimGate;
  final List<int> expectedRevisions = [];
  InboxSummary get summary => InboxSummary(
    revision: revision,
    unreadCount: messages.where((m) => m.isUnread).length,
    unclaimedCount: messages.where((m) => m.canClaim).length,
  );
  @override
  Future<InboxSummary> loadSummary({required String userId}) async => summary;
  @override
  Future<InboxPage> loadPage({
    required String userId,
    InboxCursor? cursor,
  }) async {
    if (failLoad) throw StateError('Offline');
    if (delayedPage != null) return delayedPage!.future;
    return InboxPage(messages: List.of(messages), summary: summary);
  }

  void _replace(InboxMessage next) {
    messages = messages
        .map((message) => message.id == next.id ? next : message)
        .toList();
    revision += 1;
  }

  @override
  Future<InboxMessageUpdate> markRead({
    required String userId,
    required String messageId,
  }) async {
    if (failRead) throw StateError('Offline');
    final old = messages.firstWhere((m) => m.id == messageId);
    final next = InboxMessage(
      id: old.id,
      title: old.title,
      body: old.body,
      createdAtMs: old.createdAtMs,
      readAtMs: old.readAtMs ?? 1,
      claimedAtMs: old.claimedAtMs,
      goldAmount: old.goldAmount,
    );
    _replace(next);
    return InboxMessageUpdate(message: next, summary: summary);
  }

  @override
  Future<InboxSummary> deleteMessage({
    required String userId,
    required String messageId,
  }) async {
    deleteCalls += 1;
    if (deleteGate != null) await deleteGate!.future;
    if (failDelete) throw StateError('Offline');
    final message = messages.where((m) => m.id == messageId).firstOrNull;
    if (message?.canClaim ?? false) throw StateError('Unclaimed gift');
    if (message == null && !deletedIds.contains(messageId)) {
      throw StateError('Not found');
    }
    if (message != null) {
      messages = messages.where((m) => m.id != messageId).toList();
      deletedIds.add(messageId);
      revision += 1;
    }
    if (loseNextDeleteResponse) {
      loseNextDeleteResponse = false;
      throw StateError('Connection lost after commit');
    }
    return summary;
  }

  @override
  Future<InboxClaimResult> claim({
    required String userId,
    required String messageId,
    required String commandId,
    required int expectedRevision,
  }) async {
    claimCalls += 1;
    expectedRevisions.add(expectedRevision);
    if (claimGate != null) await claimGate!.future;
    var message = messages.firstWhere((m) => m.id == messageId);
    if (staleNextClaim) {
      staleNextClaim = false;
      ownership.canonical = ownership.canonical.copyWith(revision: 2);
      return InboxClaimResult(
        message: message,
        summary: summary,
        ownership: OwnershipCommandResult(
          canonicalState: ownership.canonical,
          newRevision: 2,
          replayedFromIdempotency: false,
          rejectedReason: OwnershipRejectedReason.staleRevision,
        ),
      );
    }
    if (message.canClaim) {
      ownership.canonical = ownership.canonical.copyWith(
        revision: ownership.canonical.revision + 1,
        progression: ownership.canonical.progression.copyWith(
          gold: ownership.canonical.progression.gold + message.goldAmount,
        ),
      );
      message = InboxMessage(
        id: message.id,
        title: message.title,
        body: message.body,
        createdAtMs: message.createdAtMs,
        readAtMs: message.readAtMs,
        claimedAtMs: 2,
        goldAmount: message.goldAmount,
      );
      _replace(message);
    }
    if (loseNextClaimResponse) {
      loseNextClaimResponse = false;
      throw StateError('Connection lost after commit');
    }
    return InboxClaimResult(
      message: message,
      summary: summary,
      ownership: OwnershipCommandResult(
        canonicalState: ownership.canonical,
        newRevision: ownership.canonical.revision,
        replayedFromIdempotency: false,
      ),
    );
  }
}
