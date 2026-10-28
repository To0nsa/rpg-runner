import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_presentation/catalog_item.dart';
import 'package:lothringen_admin/src/admin_controller.dart';
import 'package:lothringen_admin/src/admin_draft.dart';
import 'package:lothringen_admin/src/admin_service.dart';

void main() {
  test(
    'real local service catalog, lost response, durable retry and confirmation',
    () async {
      final repository = Directory.current.parent.parent.path;
      final service = await LocalAdminService.start(repository, fixture: true);
      final directory = await Directory.systemTemp.createTemp(
        'admin-draft-test-',
      );
      final store = FileAdminDraftStore(File('${directory.path}/draft.json'));
      addTearDown(() async {
        await service.close();
        await directory.delete(recursive: true);
      });
      var controller = AdminController(service: service, store: store);
      await controller.initialize();
      expect(controller.ready, isTrue);
      await controller.selectEnvironment('dev');
      expect(controller.catalog.length, greaterThan(40));
      expect(controller.catalogMessage, isEmpty);
      for (final item in controller.catalog) {
        expect(GameCatalogItem.fromJson(item.toJson()).displayName, isNotEmpty);
      }
      controller.edit(
        controller.draft.copyWith(
          uid: 'retry-player',
          title: 'Equipment',
          body: 'Claim these gifts.',
          goldAmount: 25,
        ),
      );
      controller.toggleGift(
        controller.catalog.firstWhere((e) => e.itemId == 'waspfang'),
        'eloise',
      );
      controller.toggleGift(
        controller.catalog.firstWhere((e) => e.itemId == 'eloise.arcane_ward'),
        'eloiseWip',
      );
      await controller.createPreview();
      expect(controller.error, isNull);
      final identity = controller.draft.sourceId;
      await controller.send();
      expect(controller.error, contains('could not be confirmed'));
      expect(controller.draft.attempted, isTrue);
      expect(controller.canEdit, isFalse);
      controller.dispose();
      controller = AdminController(service: service, store: store);
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.draft.sourceId, identity);
      expect(controller.draft.attachments.length, 2);
      await controller.selectEnvironment('prod');
      expect(controller.draft.environment, 'dev');
      await controller.createPreview();
      expect(controller.error, isNull);
      await controller.send();
      expect(controller.error, isNull);
      expect(controller.draft.receipt?['status'], 'delivered');
      final imported = AdminDraft.fromJson(controller.draft.toJson());
      expect(imported.receipt, isNull);
      expect(imported.attempted, isTrue);
      expect(imported.sourceId, identity);
      final loaded = await store.load();
      expect(
        loaded!.receipt?['messageId'],
        controller.draft.receipt!['messageId'],
      );
    },
  );
}
