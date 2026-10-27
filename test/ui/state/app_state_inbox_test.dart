import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/state/inbox/inbox_models.dart';

import '../test_support/inbox_fixture.dart';

void main() {
  test(
    'opening inbox does not clear attention; reading gift leaves claim pending',
    () async {
      final f = InboxFixture();
      addTearDown(f.app.dispose);
      await f.app.bootstrap();
      await f.app.loadInbox();
      expect(f.app.inboxSummary.needsAttention, isTrue);
      expect(f.app.inboxMessages.single.isUnread, isTrue);
      await f.app.markInboxMessageRead('gift');
      expect(f.app.inboxSummary.unreadCount, 0);
      expect(f.app.inboxSummary.needsAttention, isTrue);
      await f.app.claimInboxReward('gift');
      expect(f.app.progression.gold, 25);
      expect(f.app.inboxSummary.needsAttention, isFalse);
    },
  );

  test(
    'information message clears attention on read without a claim',
    () async {
      final f = InboxFixture();
      addTearDown(f.app.dispose);
      f.inbox.messages = [
        const InboxMessage(
          id: 'info',
          title: 'News',
          body: 'Game information.',
          createdAtMs: 1,
        ),
      ];
      await f.app.bootstrap();
      await f.app.loadInbox();
      await f.app.markInboxMessageRead('info');
      expect(f.app.inboxSummary.needsAttention, isFalse);
      expect(f.app.progression.gold, 0);
    },
  );

  test('lost claim response can be retried without double gold', () async {
    final f = InboxFixture();
    addTearDown(f.app.dispose);
    await f.app.bootstrap();
    await f.app.loadInbox();
    f.inbox.loseNextClaimResponse = true;
    await expectLater(f.app.claimInboxReward('gift'), throwsStateError);
    expect(f.app.progression.gold, 0);
    expect(f.app.inboxMessageBusy('gift'), isFalse);
    await f.app.claimInboxReward('gift');
    expect(f.app.progression.gold, 25);
    expect(f.inbox.claimCalls, 2);
  });

  test(
    'stale ownership revision retries against returned canonical state',
    () async {
      final f = InboxFixture();
      addTearDown(f.app.dispose);
      await f.app.bootstrap();
      await f.app.loadInbox();
      f.inbox.staleNextClaim = true;
      await f.app.claimInboxReward('gift');
      expect(f.inbox.expectedRevisions, [0, 2]);
      expect(f.app.progression.gold, 25);
      expect(f.app.ownershipRevision, 3);
    },
  );

  test('duplicate taps share one pending claim', () async {
    final f = InboxFixture();
    addTearDown(f.app.dispose);
    await f.app.bootstrap();
    await f.app.loadInbox();
    f.inbox.claimGate = Completer<void>();
    final first = f.app.claimInboxReward('gift');
    await Future<void>.delayed(Duration.zero);
    await f.app.claimInboxReward('gift');
    expect(f.inbox.claimCalls, 1);
    f.inbox.claimGate!.complete();
    await first;
    expect(f.app.progression.gold, 25);
  });

  test(
    'older page snapshot cannot undo a read or attention revision',
    () async {
      final f = InboxFixture();
      addTearDown(f.app.dispose);
      await f.app.bootstrap();
      await f.app.loadInbox();
      final oldPage = InboxPage(
        messages: List.of(f.inbox.messages),
        summary: f.inbox.summary,
      );
      f.inbox.delayedPage = Completer<InboxPage>();
      final loading = f.app.loadInbox();
      await Future<void>.delayed(Duration.zero);
      await f.app.markInboxMessageRead('gift');
      f.inbox.delayedPage!.complete(oldPage);
      await loading;
      expect(f.app.inboxMessages.single.isUnread, isFalse);
      expect(f.app.inboxSummary.unreadCount, 0);
    },
  );

  test(
    'old account response is discarded after identity replacement',
    () async {
      final f = InboxFixture();
      addTearDown(f.app.dispose);
      await f.app.bootstrap();
      await f.app.refreshInboxSummary();
      final oldPage = InboxPage(
        messages: List.of(f.inbox.messages),
        summary: f.inbox.summary,
      );
      f.inbox.delayedPage = Completer<InboxPage>();
      final loading = f.app.loadInbox();
      await Future<void>.delayed(Duration.zero);
      f.auth.uid = 'new-player';
      f.inbox.messages = [];
      f.inbox.revision = 0;
      await f.app.bootstrap(force: true);
      f.inbox.delayedPage!.complete(oldPage);
      await loading;
      expect(f.app.inboxMessages, isEmpty);
      expect(f.app.inboxSummary.needsAttention, isFalse);
    },
  );

  test('load failure retains known attention and supports retry', () async {
    final f = InboxFixture();
    addTearDown(f.app.dispose);
    await f.app.bootstrap();
    await f.app.refreshInboxSummary();
    f.inbox.failLoad = true;
    await f.app.loadInbox();
    expect(f.app.inboxLoadError, isNotNull);
    expect(f.app.inboxSummary.needsAttention, isTrue);
    f.inbox.failLoad = false;
    await f.app.loadInbox();
    expect(f.app.inboxLoadError, isNull);
    expect(f.app.inboxMessages, hasLength(1));
  });
}
