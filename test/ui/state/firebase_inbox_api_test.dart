import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/state/inbox/firebase_inbox_api.dart';
import 'package:rpg_runner/ui/state/inbox/inbox_models.dart';

import '../test_support/inbox_fixture.dart';

void main() {
  test(
    'delete requires an explicit matching receipt and sends only identity',
    () async {
      final source = _Source({
        'messageId': 'info',
        'deleted': true,
        'summary': {'revision': 2, 'unreadCount': 0, 'unclaimedCount': 0},
      });
      final api = FirebaseInboxApi(source: source);
      final summary = await api.deleteMessage(userId: 'uid', messageId: 'info');
      expect(summary.revision, 2);
      expect(source.lastName, 'inboxDeleteMessage');
      expect(source.lastData, {'userId': 'uid', 'messageId': 'info'});
      for (final invalid in [null, false, 'true', 1]) {
        source.response['deleted'] = invalid;
        await expectLater(
          api.deleteMessage(userId: 'uid', messageId: 'info'),
          throwsFormatException,
        );
      }
      source.response['deleted'] = true;
      source.response['messageId'] = 'other';
      await expectLater(
        api.deleteMessage(userId: 'uid', messageId: 'info'),
        throwsFormatException,
      );
      source.response['messageId'] = 'info';
      source.response.remove('summary');
      await expectLater(
        api.deleteMessage(userId: 'uid', messageId: 'info'),
        throwsFormatException,
      );
    },
  );

  final message = <String, Object?>{
    'schemaVersion': 1,
    'id': 'gift',
    'title': 'Level 2',
    'body': 'A reward.',
    'createdAtMs': 1,
    'readAtMs': 1,
    'claimedAtMs': 2,
    'rewards': [
      {'kind': 'gold', 'amount': 25},
    ],
  };

  test('version two decodes mixed and item-only gifts with strict duplicate validation', () {
    final gift = {'kind': 'gear', 'slot': 'mainWeapon', 'itemId': 'waspfang'};
    final skill = {
      'kind': 'ability',
      'slot': 'spell',
      'itemId': 'eloise.arcane_ward',
      'characterId': 'eloiseWip',
    };
    final decoded = InboxMessage.fromJson({
      ...message,
      'schemaVersion': 2,
      'claimedAtMs': null,
      'rewards': [
        {'kind': 'gold', 'amount': 20},
        gift,
        skill,
      ],
    });
    expect(decoded.goldAmount, 20);
    expect(decoded.attachments.map((e) => e.label), [
      'Waspfang',
      'Arcane Ward · eloiseWip',
    ]);
    expect(decoded.canClaim, isTrue);
    expect(
      InboxMessage.fromJson({
        ...message,
        'schemaVersion': 2,
        'claimedAtMs': null,
        'rewards': [gift],
      }).canClaim,
      isTrue,
    );
    for (final rewards in [
      [gift, gift],
      [
        {...gift, 'amount': 3},
      ],
      [
        {...skill, 'characterId': null},
      ],
      [
        {...skill, 'characterId': 'missing'},
      ],
      [
        {...skill, 'characterId': 5},
      ],
      [
        {...gift, 'itemId': 'invented'},
      ],
    ]) {
      expect(
        () => InboxMessage.fromJson({
          ...message,
          'schemaVersion': 2,
          'rewards': rewards,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => InboxMessage.fromJson({
        ...message,
        'rewards': [gift],
      }),
      throwsFormatException,
    );
  });

  test(
    'strict message decoding rejects unsupported rewards and malformed amounts',
    () {
      expect(InboxMessage.fromJson(message).goldAmount, 25);
      for (final rewards in [
        [
          {'kind': 'item', 'amount': 1},
        ],
        [
          {'kind': 'gold', 'amount': 1.5},
        ],
        [
          {'kind': 'gold', 'amount': -1},
        ],
        [
          {'kind': 'gold', 'amount': 0},
        ],
      ]) {
        expect(
          () => InboxMessage.fromJson({...message, 'rewards': rewards}),
          throwsFormatException,
        );
      }
    },
  );

  test('claim sends only identity and revision; unknown outcomes cannot imply success', () async {
    final ownership = TestInboxOwnership();
    final source = _Source({
      'message': message,
      'summary': {'revision': 3, 'unreadCount': 0, 'unclaimedCount': 0},
      'result': {
        'canonicalState': ownership.canonical.toJson(),
        'newRevision': 0,
        'replayedFromIdempotency': false,
        'rejectedReason': null,
      },
    });
    final api = FirebaseInboxApi(source: source);
    final result = await api.claim(
      userId: 'uid',
      messageId: 'gift',
      commandId: 'command',
      expectedRevision: 0,
    );
    expect(result.ownership.accepted, isTrue);
    expect(source.lastName, 'inboxClaimReward');
    expect(source.lastData, {
      'userId': 'uid',
      'messageId': 'gift',
      'commandId': 'command',
      'expectedRevision': 0,
    });
    final rawResult = source.response['result']! as Map<String, Object?>;
    rawResult['rejectedReason'] = 'newUnknownFailure';
    await expectLater(
      api.claim(
        userId: 'uid',
        messageId: 'gift',
        commandId: 'command',
        expectedRevision: 0,
      ),
      throwsFormatException,
    );
  });

  test('missing claim receipt and wrong read identity are rejected', () async {
    final source = _Source({
      'message': {...message, 'id': 'another'},
      'summary': {'revision': 1, 'unreadCount': 0, 'unclaimedCount': 1},
    });
    final api = FirebaseInboxApi(source: source);
    await expectLater(
      api.markRead(userId: 'uid', messageId: 'gift'),
      throwsFormatException,
    );
    await expectLater(
      api.claim(
        userId: 'uid',
        messageId: 'gift',
        commandId: 'command',
        expectedRevision: 0,
      ),
      throwsFormatException,
    );
  });
}

class _Source implements FirebaseInboxSource {
  _Source(this.response);
  final Map<String, dynamic> response;
  String? lastName;
  Map<String, Object?>? lastData;
  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, Object?> data,
  ) async {
    lastName = name;
    lastData = data;
    return response;
  }
}
