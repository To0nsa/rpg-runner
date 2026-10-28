import 'package:game_presentation/catalog_gift.dart';

import '../ownership/loadout_ownership_api.dart';

/// Versioned whole-inbox attention, independent of the loaded page.
class InboxSummary {
  const InboxSummary({
    this.revision = 0,
    this.unreadCount = 0,
    this.unclaimedCount = 0,
  });
  final int revision, unreadCount, unclaimedCount;
  bool get needsAttention => unreadCount > 0 || unclaimedCount > 0;

  factory InboxSummary.fromJson(Object? raw) {
    final json = inboxObject(raw);
    return InboxSummary(
      revision: inboxInteger(json['revision']),
      unreadCount: inboxInteger(json['unreadCount']),
      unclaimedCount: inboxInteger(json['unclaimedCount']),
    );
  }
}

/// Immutable system mail; read and reward-claim state are deliberately separate.
class InboxMessage {
  const InboxMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAtMs,
    this.readAtMs,
    this.claimedAtMs,
    this.goldAmount = 0,
    this.attachments = const [],
  });
  final String id, title, body;
  final int createdAtMs, goldAmount;
  final int? readAtMs, claimedAtMs;
  final List<CatalogGift> attachments;
  bool get isUnread => readAtMs == null;
  bool get hasReward => goldAmount > 0 || attachments.isNotEmpty;
  bool get canClaim => hasReward && claimedAtMs == null;

  factory InboxMessage.fromJson(Object? raw) {
    final json = inboxObject(raw);
    if (![1, 2].contains(json['schemaVersion'])) {
      throw const FormatException('Unsupported message version.');
    }
    final rewards = json['rewards'];
    if (rewards is! List ||
        rewards.length > (json['schemaVersion'] == 1 ? 1 : 9)) {
      throw const FormatException('Invalid rewards.');
    }
    var gold = 0;
    final attachments = <CatalogGift>[];
    for (final rawReward in rewards) {
      final reward = inboxObject(rawReward);
      if (reward['kind'] == 'gold') {
        if (gold > 0 ||
            reward.keys.any((key) => !{'kind', 'amount'}.contains(key))) {
          throw const FormatException('Invalid gold attachment.');
        }
        gold = inboxInteger(reward['amount']);
        if (gold == 0) throw const FormatException('Empty reward.');
      } else {
        if (json['schemaVersion'] != 2) {
          throw const FormatException('Unsupported reward type.');
        }
        final gift = CatalogGift.fromJson(reward);
        if (attachments.any((entry) => entry.key == gift.key)) {
          throw const FormatException('Duplicate gift.');
        }
        attachments.add(gift);
      }
    }
    if (!json.containsKey('readAtMs') || !json.containsKey('claimedAtMs')) {
      throw const FormatException('Missing message state.');
    }
    return InboxMessage(
      id: inboxText(json['id']),
      title: inboxText(json['title']),
      body: inboxText(json['body']),
      createdAtMs: inboxInteger(json['createdAtMs']),
      readAtMs: json['readAtMs'] == null
          ? null
          : inboxInteger(json['readAtMs']),
      claimedAtMs: json['claimedAtMs'] == null
          ? null
          : inboxInteger(json['claimedAtMs']),
      goldAmount: gold,
      attachments: List.unmodifiable(attachments),
    );
  }
}

/// Stable pagination through messages with equal creation times.
class InboxCursor {
  const InboxCursor({required this.createdAtMs, required this.messageId});
  final int createdAtMs;
  final String messageId;
  Map<String, Object> toJson() => {
    'createdAtMs': createdAtMs,
    'messageId': messageId,
  };
  factory InboxCursor.fromJson(Object? raw) {
    final json = inboxObject(raw);
    return InboxCursor(
      createdAtMs: inboxInteger(json['createdAtMs']),
      messageId: inboxText(json['messageId']),
    );
  }
}

class InboxPage {
  const InboxPage({
    required this.messages,
    required this.summary,
    this.nextCursor,
  });
  final List<InboxMessage> messages;
  final InboxSummary summary;
  final InboxCursor? nextCursor;
  factory InboxPage.fromJson(Object? raw) {
    final json = inboxObject(raw);
    final messages = json['messages'];
    if (messages is! List ||
        messages.length > 20 ||
        !json.containsKey('nextCursor')) {
      throw const FormatException('Invalid inbox page.');
    }
    return InboxPage(
      messages: List.unmodifiable(messages.map(InboxMessage.fromJson)),
      summary: InboxSummary.fromJson(json['summary']),
      nextCursor: json['nextCursor'] == null
          ? null
          : InboxCursor.fromJson(json['nextCursor']),
    );
  }
}

class InboxMessageUpdate {
  const InboxMessageUpdate({required this.message, required this.summary});
  final InboxMessage message;
  final InboxSummary summary;
  factory InboxMessageUpdate.fromJson(Object? raw) {
    final json = inboxObject(raw);
    return InboxMessageUpdate(
      message: InboxMessage.fromJson(json['message']),
      summary: InboxSummary.fromJson(json['summary']),
    );
  }
}

/// A claim publishes message state and canonical ownership from one transaction.
class InboxClaimResult extends InboxMessageUpdate {
  const InboxClaimResult({
    required super.message,
    required super.summary,
    required this.ownership,
  });
  final OwnershipCommandResult ownership;
}

Map<String, dynamic> inboxObject(Object? raw) {
  if (raw is! Map) throw const FormatException('Expected an inbox object.');
  return Map<String, dynamic>.from(raw);
}

int inboxInteger(Object? raw) {
  if (raw is! num ||
      !raw.isFinite ||
      raw < 0 ||
      raw > 9007199254740991 ||
      raw != raw.truncateToDouble()) {
    throw const FormatException('Expected a non-negative safe integer.');
  }
  return raw.toInt();
}

String inboxText(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    throw const FormatException('Expected message text.');
  }
  return raw;
}
