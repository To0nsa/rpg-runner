import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_content_pipeline/item_source.dart';
import 'package:runner_editor/src/app/pages/items/items_page.dart';
import 'package:runner_editor/src/app/pages/items/item_fields_form.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/items/item_domain_plugin.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  testWidgets(
    'omitted choices and booleans display inheritance and preserve explicit false',
    (tester) async {
      final values = <String, dynamic>{};
      final schema = itemFields(ItemCategory.projectile);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => ItemFieldsForm(
                values: values,
                fields: {
                  'damageType': schema['damageType']!,
                  'ballistic': schema['ballistic']!,
                },
                onChanged: () => update(() {}),
              ),
            ),
          ),
        ),
      );
      final choice = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('data.damageType:')),
      );
      expect(choice.initialValue, '');
      final boolean = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('data.ballistic:')),
      );
      expect(boolean.initialValue, '');
      boolean.onChanged!('false');
      await tester.pump();
      expect(values['ballistic'], isFalse);
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('data.ballistic:false')),
          )
          .onChanged!('');
      await tester.pump();
      expect(values.containsKey('ballistic'), isFalse);
    },
  );
  late Directory fixture;
  late EditorWorkspace workspace;
  late ItemDomainPlugin plugin;
  late ItemDocument initial;
  setUp(() async {
    fixture = Directory.systemTemp.createTempSync('item_authoring_');
    workspace = EditorWorkspace(rootPath: fixture.path);
    final target = File(workspace.resolve(itemSourcePath));
    target.parent.createSync(recursive: true);
    File('../../$itemSourcePath').copySync(target.path);
    plugin = ItemDomainPlugin();
    initial = await plugin.loadFromRepo(workspace);
  });
  tearDown(() => fixture.deleteSync(recursive: true));
  ItemDocument replace(
    ItemDocument document,
    ItemSource old,
    Map<String, Object?> row,
  ) => plugin.applyEdit(
    document,
    AuthoringCommand(
      kind: ItemDomainPlugin.replace,
      payload: {'id': old.id, 'expected': old.toJson(), 'item': row},
    ),
  );

  for (final category in ItemCategory.values) {
    test(
      '${category.name}: create, edit, duplicate, save/reload and immutable history',
      () async {
        final created = plugin.applyEdit(
          initial,
          AuthoringCommand(
            kind: ItemDomainPlugin.create,
            payload: {
              'category': category.name,
              'newId': 'test${category.name}',
              'name': {'en': 'Test item', 'fr': 'Objet test'},
            },
          ),
        );
        final item = created.selected!;
        final row = item.toJson();
        final data = row['data'] as Map;
        data['stats'] = {'globalPowerBonusBp': 750};
        if (category != ItemCategory.accessory) {
          data['procs'] = [
            {'hook': 'onHit', 'statusProfileId': 'slowOnHit', 'chanceBp': 2500},
          ];
        }
        if (category == ItemCategory.projectile) {
          data['speedUnitsPerSecond'] = 777.0;
        }
        final edited = replace(created, item, row);
        final duplicate = plugin.applyEdit(
          edited,
          AuthoringCommand(
            kind: ItemDomainPlugin.duplicate,
            payload: {'category': category.name, 'templateId': item.id},
          ),
        );
        expect(duplicate.selectedId, isNot(item.id));
        expect(duplicate.selected!.data, edited.selected!.data);
        final second = plugin.applyEdit(
          duplicate,
          AuthoringCommand(
            kind: ItemDomainPlugin.duplicate,
            payload: {'category': category.name, 'templateId': item.id},
          ),
        );
        expect(second.selectedId, isNot(duplicate.selectedId));
        expect(
          (await plugin.exportToRepo(workspace, document: second)).applied,
          isTrue,
        );
        final reloaded = await plugin.loadFromRepo(workspace);
        expect(reloaded.catalog.encode(), second.catalog.encode());
        expect(
          plugin.restoreContent(current: reloaded, historical: initial),
          isNull,
        );
        expect(
          plugin
              .describePendingChanges(workspace, document: reloaded)
              .hasChanges,
          isFalse,
        );
      },
    );
  }
  test('rejects immutable and retired IDs, invalid numbers/effects, duplicates, eligibility and art', () {
    final old = initial.selected!;
    for (final id in [
      'ironBracers',
      'values',
      'toString',
      'noSuchMethod',
      '1item',
      old.id,
    ]) {
      expect(
        () => plugin.applyEdit(
          initial,
          AuthoringCommand(
            kind: ItemDomainPlugin.create,
            payload: {
              'category': 'weapon',
              'newId': id,
              'name': {'en': 'Name', 'fr': 'Nom'},
            },
          ),
        ),
        throwsFormatException,
      );
    }
    final changed = old.toJson()..['id'] = 'renamed';
    expect(() => replace(initial, old, changed), throwsFormatException);
    final family = old.toJson();
    (family['data'] as Map)['weaponType'] = 'hunterBlade';
    expect(
      () => replace(initial, old, family),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'compatibility',
          contains('saved loadouts'),
        ),
      ),
    );
    final icon = old.toJson()..['icon'] = 'missing';
    expect(() => replace(initial, old, icon), throwsFormatException);
    final stats = old.toJson();
    (stats['data'] as Map)['stats'] = {'globalPowerBonusBp': double.nan};
    expect(() => replace(initial, old, stats), throwsFormatException);
    final effect = old.toJson();
    (effect['data'] as Map)['procs'] = [
      {
        'hook': 'onHit',
        'statusProfileId': 'slowOnHit',
        'statusTuning': {
          'dot': {'magnitude': 100},
        },
      },
    ];
    expect(() => replace(initial, old, effect), throwsFormatException);
  });
  test(
    'source drift and replacement failure leave source and draft intact',
    () async {
      final row = initial.selected!.toJson()
        ..['name'] = {'en': 'Edited', 'fr': 'Modifié'};
      final edited = replace(initial, initial.selected!, row);
      final file = File(workspace.resolve(itemSourcePath)),
          before = file.readAsStringSync();
      file.writeAsStringSync('$before\n');
      expect(
        (await plugin.exportToRepo(workspace, document: edited)).outcome,
        ExportOutcome.sourceDrift,
      );
      expect(file.readAsStringSync(), '$before\n');
      file.writeAsStringSync(before);
      final failing = ItemDomainPlugin(
        verifyReplacements: () =>
            throw StateError('Injected disk verification failure'),
      );
      expect(
        (await failing.exportToRepo(workspace, document: edited)).outcome,
        ExportOutcome.failed,
      );
      expect(file.readAsStringSync(), before);
      expect(
        plugin.describePendingChanges(workspace, document: edited).hasChanges,
        isTrue,
      );
    },
  );
  test('Undo after Save retains current baseline and restores content without deleting identity', () async {
    final edited = replace(
      initial,
      initial.selected!,
      initial.selected!.toJson()..['name'] = {'en': 'Edited', 'fr': 'Modifié'},
    );
    await plugin.exportToRepo(workspace, document: edited);
    final saved = await plugin.loadFromRepo(workspace);
    final restored = plugin.restoreContent(
      current: saved,
      historical: initial,
    ) as ItemDocument;
    expect(restored.baseline, saved.baseline);
    expect(
      (await plugin.exportToRepo(workspace, document: restored)).applied,
      isTrue,
    );
    expect(
      (await plugin.loadFromRepo(workspace)).catalog.encode(),
      initial.catalog.encode(),
    );
  });
  testWidgets(
    'visible fields save, invalid fields stay visible, local Undo, duplicate selection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(plugins: [plugin]),
        initialPluginId: plugin.id,
        initialWorkspacePath: fixture.path,
      );
      addTearDown(controller.dispose);
      await tester.runAsync(controller.loadWorkspace);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemsPage(key: key, controller: controller),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('item_name_en')),
        'Edited weapon',
      );
      await tester.pump();
      expect(
        (key.currentState as EditorPageLocalDraftState).hasLocalDraftChanges,
        isTrue,
      );
      final result = await tester.runAsync(
        () => (key.currentState as EditorPageSaveHandler).saveEditorPage(),
      );
      await tester.pump();
      expect(result, EditorPageSaveResult.saved);
      expect(
        jsonDecode(
          File(workspace.resolve(itemSourcePath)).readAsStringSync(),
        )['items'][0]['name']['en'],
        'Edited weapon',
      );
      await tester.enterText(find.byKey(const ValueKey('item_name_en')), '');
      await tester.pump();
      expect(
        await (key.currentState as EditorPageSaveHandler).saveEditorPage(),
        EditorPageSaveResult.blocked,
      );
      (key.currentState as EditorPageSessionShortcutHandler)
          .handleUndoSessionShortcut();
      await tester.pump();
      expect(find.text('Edited weapon'), findsWidgets);
      await tester.tap(find.text('Duplicate'));
      await tester.pump();
      expect(
        (controller.document as ItemDocument).selectedId,
        endsWith('Copy'),
      );
      expect(controller.pendingChanges.hasChanges, isTrue);
      await tester.binding.setSurfaceSize(const Size(520, 700));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('item_name_en')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
