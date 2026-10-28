import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lothringen_admin/src/admin_controller.dart';
import 'package:lothringen_admin/src/admin_draft.dart';
import 'package:lothringen_admin/src/admin_service.dart';

class MemoryStore implements AdminDraftStore {
  AdminDraft? draft;
  bool fail = false;
  @override
  Future<AdminDraft?> load() async => draft;
  @override
  Future<void> save(AdminDraft next) async {
    if (fail) throw StateError('disk full');
    draft = next;
  }
}

class TestService implements AdminService {
  int sends = 0;
  bool wrongReceipt = false;
  final catalogs = <String, Completer<Map<String, dynamic>>>{};
  Map<String, dynamic>? preview;
  @override
  Future<void> close() async {}
  @override
  Future<Map<String, dynamic>> call(
    String path, [
    Map<String, Object?>? body,
  ]) async {
    if (path == '/api/environments') {
      return {
        'operatorAccount': 'test@example.com',
        'environments': [
          for (final name in ['dev', 'staging', 'prod'])
            {'name': name, 'projectId': 'project-$name'},
        ],
      };
    }
    if (path == '/api/catalog') {
      return catalogs[body!['environment']]?.future ??
          Future.value({
            'environment': body['environment'],
            'projectId': 'project-${body['environment']}',
            'enabled': false,
          });
    }
    if (path == '/api/preview') {
      return preview = {
        'environment': body!['environment'],
        'projectId': 'project-${body['environment']}',
        'previewId': 'preview',
        'messageId': 'a' * 64,
        ...body['message'] as Map<String, Object?>,
      };
    }
    sends++;
    return {
      ...preview!,
      'status': 'delivered',
      'confirmedAt': '2026-10-29T00:00:00Z',
      if (wrongReceipt) 'projectId': 'project-prod',
    };
  }
}

void main() {
  test(
    'failed persistence blocks send and receipt mismatch never confirms',
    () async {
      final service = TestService(), store = MemoryStore();
      final c = AdminController(service: service, store: store);
      addTearDown(c.dispose);
      await c.initialize();
      await c.selectEnvironment('dev');
      c.edit(c.draft.copyWith(uid: 'player', title: 'Hello', body: 'Message'));
      await c.createPreview();
      store.fail = true;
      await c.send();
      expect(service.sends, 0);
      expect(c.draft.attempted, isTrue);
      store.fail = false;
      service.wrongReceipt = true;
      await c.send();
      expect(c.draft.receipt, isNull);
      expect(c.error, contains('Invalid delivery'));
      service.wrongReceipt = false;
      await c.send();
      expect(c.draft.receipt?['status'], 'delivered');
    },
  );
  test('late catalog cannot replace a newer environment and edits invalidate preview', () async {
    final service = TestService(), store = MemoryStore();
    final c = AdminController(service: service, store: store);
    addTearDown(c.dispose);
    await c.initialize();
    service.catalogs['dev'] = Completer();
    final first = c.selectEnvironment('dev');
    await c.selectEnvironment('staging');
    service.catalogs['dev']!.complete({
      'environment': 'dev',
      'projectId': 'project-dev',
      'enabled': true,
      'entries': [],
      'characters': ['eloise'],
    });
    await first;
    expect(c.draft.environment, 'staging');
    expect(c.catalog, isEmpty);
    c.edit(c.draft.copyWith(uid: 'player', title: 'Hello', body: 'Message'));
    await c.createPreview();
    expect(c.preview, isNotNull);
    c.edit(c.draft.copyWith(title: 'Changed'));
    expect(c.preview, isNull);
    await c.send();
    expect(service.sends, 0);
  });
  test('legacy drafts import; malformed and duplicate gifts fail closed', () {
    final draft = AdminDraft.fresh('dev')
        .copyWith(uid: 'player', title: 'Hi', body: 'Text');
    expect(AdminDraft.fromJson(draft.toJson()).sourceId, draft.sourceId);
    final raw = draft.toJson();
    final message = raw['message'] as Map<String, Object?>;
    message['attachments'] = [
      {'kind': 'gear', 'itemId': 'invented', 'slot': 'mainWeapon'},
    ];
    expect(() => AdminDraft.fromJson(raw), throwsFormatException);
  });
}
