import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:game_presentation/catalog_gift.dart';

/// Durable delivery identity. A send attempt locks the exact destination and contents.
class AdminDraft {
  const AdminDraft({
    required this.sourceId,
    this.environment = '',
    this.uid = '',
    this.title = '',
    this.body = '',
    this.goldAmount = 0,
    this.attachments = const [],
    this.attempted = false,
    this.receipt,
  });
  factory AdminDraft.fresh([String environment = '']) => AdminDraft(
    sourceId: List.generate(
      24,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join(),
    environment: environment,
  );
  final String sourceId, environment, uid, title, body;
  final int goldAmount;
  final List<CatalogGift> attachments;
  final bool attempted;
  final Map<String, dynamic>? receipt;
  Map<String, Object?> get message => {
    'sourceId': sourceId,
    'uid': uid,
    'title': title,
    'body': body,
    'goldAmount': goldAmount,
    if (attachments.isNotEmpty)
      'attachments': attachments.map((g) => g.toJson()).toList(),
  };
  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'environment': environment,
    'message': message,
    'attempted': attempted,
    if (receipt != null) 'receipt': receipt,
  };
  AdminDraft copyWith({
    String? environment,
    String? uid,
    String? title,
    String? body,
    int? goldAmount,
    List<CatalogGift>? attachments,
    bool? attempted,
    Map<String, dynamic>? receipt,
  }) => AdminDraft(
    sourceId: sourceId,
    environment: environment ?? this.environment,
    uid: uid ?? this.uid,
    title: title ?? this.title,
    body: body ?? this.body,
    goldAmount: goldAmount ?? this.goldAmount,
    attachments: List.unmodifiable(attachments ?? this.attachments),
    attempted: attempted ?? this.attempted,
    receipt: receipt ?? this.receipt,
  );

  /// Browser draft exports remain readable; imported confirmations are never trusted.
  factory AdminDraft.fromJson(
    Map<String, dynamic> raw, {
    bool trustReceipt = false,
  }) {
    final message = raw['message'];
    if (raw['schemaVersion'] != 1 ||
        message is! Map<String, dynamic> ||
        !['', 'dev', 'staging', 'prod'].contains(raw['environment']) ||
        [
          'uid',
          'title',
          'body',
          'sourceId',
        ].any((key) => message[key] is! String) ||
        (message['uid'] as String).length > 128 ||
        (message['title'] as String).length > 120 ||
        (message['body'] as String).length > 2000 ||
        (message['sourceId'] as String).trim().isEmpty ||
        (message['sourceId'] as String).length > 180 ||
        message['goldAmount'] is! int ||
        message['goldAmount'] < 0 ||
        message['goldAmount'] > 9007199254740991 ||
        (raw['attempted'] != null && raw['attempted'] is! bool)) {
      throw const FormatException('Invalid Admin draft.');
    }
    final rows = message['attachments'] ?? [];
    if (rows is! List || rows.length > 8) {
      throw const FormatException('Invalid attachments.');
    }
    final gifts = rows
        .map((r) => CatalogGift.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
    if (gifts.map((g) => g.key).toSet().length != gifts.length) {
      throw const FormatException('Duplicate gift.');
    }
    return AdminDraft(
      sourceId: message['sourceId'],
      environment: raw['environment'],
      uid: message['uid'],
      title: message['title'],
      body: message['body'],
      goldAmount: message['goldAmount'],
      attachments: List.unmodifiable(gifts),
      attempted: raw['attempted'] == true,
      receipt: trustReceipt && raw['receipt'] is Map<String, dynamic>
          ? raw['receipt']
          : null,
    );
  }
}

abstract interface class AdminDraftStore {
  Future<AdminDraft?> load();
  Future<void> save(AdminDraft draft);
}

/// One local draft, serialized and replaced after a flushed write. A failed save blocks send.
class FileAdminDraftStore implements AdminDraftStore {
  FileAdminDraftStore(this.file);
  final File file;
  Future<void> _writes = Future.value();
  @override
  Future<AdminDraft?> load() async {
    if (!await file.exists()) return null;
    if (await file.length() > 64 * 1024) {
      throw const FormatException('Saved draft is too large.');
    }
    return AdminDraft.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      trustReceipt: true,
    );
  }

  @override
  Future<void> save(AdminDraft draft) {
    final next = _writes.then((_) async {
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.pending');
      await temp.writeAsString(jsonEncode(draft.toJson()), flush: true);
      await temp.rename(file.path);
    });
    _writes = next.catchError((Object _) {});
    return next;
  }
}
