import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_editor/src/app/pages/campaign/campaign_settings_dialog.dart';
import 'package:runner_editor/src/campaign/campaign_domain_plugin.dart';
import 'package:runner_editor/src/campaign/campaign_map_asset.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  final repo = Directory.current.parent.parent.path;
  late Directory fixture;
  late EditorWorkspace workspace;
  late CampaignCatalogSource catalog;
  setUp(() async {
    fixture = await Directory.systemTemp.createTemp('campaign_settings_');
    workspace = EditorWorkspace(rootPath: fixture.path);
    for (final file in Directory(
      '$repo/assets/authoring',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      final target = File(
        '${fixture.path}/${file.path.substring(repo.length + 1)}',
      );
      target.parent.createSync(recursive: true);
      file.copySync(target.path);
    }
    catalog = CampaignCatalogSource.decode(
      File(workspace.resolve(campaignSourcePath)).readAsStringSync(),
    );
    for (final path in [
      catalog.map.assetPath,
      'assets/images/maps/selected.png',
    ]) {
      final target = File(workspace.resolve(path));
      target.parent.createSync(recursive: true);
      target.writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aQ1sAAAAASUVORK5CYII=',
        ),
      );
    }
  });
  tearDown(() async {
    expect(
      fixture.absolute.path,
      startsWith(Directory.systemTemp.absolute.path),
    );
    for (var attempt = 0; ; attempt++) {
      try {
        await fixture.delete(recursive: true);
        break;
      } on FileSystemException catch (error) {
        if (error.osError?.errorCode != 32 || attempt >= 9) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  AuthoringCommand command(CampaignDocument d) => AuthoringCommand(
    kind: CampaignDomainPlugin.editCampaign,
    payload: {
      'expectedSettings': d.catalog.settingsToJson(),
      'settings': {
        'title': {'en': 'New campaign', 'fr': 'Nouvelle campagne'},
        if (d.catalog.journal != null) 'journal': d.catalog.journal!.toJson(),
        'map': {
          'assetPath': 'assets/images/maps/selected.png',
          'width': 1,
          'height': 1,
        },
      },
    },
  );

  test('settings use guarded Save, reopen and Undo after Save without editing missions', () async {
    final plugin = CampaignDomainPlugin();
    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(plugins: [plugin]),
      initialPluginId: plugin.id,
      initialWorkspacePath: fixture.path,
    );
    addTearDown(controller.dispose);
    await controller.loadWorkspace();
    final original = controller.document as CampaignDocument;
    final edit = command(original);
    controller.applyCommand(edit);
    expect(
      (controller.document as CampaignDocument).catalog.title['en'],
      'New campaign',
    );
    expect(
      (controller.document as CampaignDocument).catalog.chapters.map(
        (c) => c.toJson(),
      ),
      original.catalog.chapters.map((c) => c.toJson()),
    );
    expect(
      () => plugin.applyEdit(controller.document!, edit),
      throwsStateError,
    );
    controller.undo();
    expect(
      (controller.document as CampaignDocument).catalog.encode(),
      original.catalog.encode(),
    );
    controller.redo();
    await controller.exportDirectWrite();
    expect(controller.pendingChanges.hasChanges, isFalse);
    final saved = await plugin.loadFromRepo(workspace) as CampaignDocument;
    expect(saved.catalog.title['fr'], 'Nouvelle campagne');
    expect(saved.catalog.map.assetPath, 'assets/images/maps/selected.png');
    expect(saved.catalog.revision, original.catalog.revision + 1);
    controller.undo();
    expect(
      (controller.document as CampaignDocument).catalog.title,
      original.catalog.title,
    );
    expect(controller.pendingChanges.hasChanges, isTrue);
    final source = File(workspace.resolve(campaignSourcePath));
    source.writeAsStringSync('${source.readAsStringSync()}\n');
    final result = await plugin.exportToRepo(
      workspace,
      document: controller.document!,
    );
    expect(result.outcome, ExportOutcome.sourceDrift);
  });

  test(
    'Journal edits at all scopes preserve guarded Save and history',
    () async {
      final plugin = CampaignDomainPlugin();
      final controller = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(plugins: [plugin]),
        initialPluginId: plugin.id,
        initialWorkspacePath: fixture.path,
      );
      addTearDown(controller.dispose);
      await controller.loadWorkspace();
      final original = controller.document as CampaignDocument;
      Map<String, Object?> entry(String text) => {
        'title': {'en': text, 'fr': 'FR $text'},
        'body': {'en': '$text body', 'fr': 'FR $text texte'},
      };
      final opening = AuthoringCommand(
        kind: CampaignDomainPlugin.editCampaign,
        payload: {
          'expectedSettings': original.catalog.settingsToJson(),
          'settings': {
            ...original.catalog.settingsToJson(),
            'journal': entry('Opening'),
          },
        },
      );
      controller.applyCommand(opening);
      expect(
        () => plugin.applyEdit(controller.document!, opening),
        throwsStateError,
      );
      final chapter =
          (controller.document as CampaignDocument).catalog.chapters.first;
      controller.applyCommand(
        AuthoringCommand(
          kind: CampaignDomainPlugin.editChapter,
          payload: {
            'id': chapter.id,
            'expectedChapter': chapter.toJson(),
            'details': {...chapter.toJson(), 'journal': entry('Chapter')},
          },
        ),
      );
      final document = controller.document as CampaignDocument;
      final mission = document.selected;
      controller.applyCommand(
        AuthoringCommand(
          kind: CampaignDomainPlugin.replaceMission,
          payload: {
            'id': mission.id,
            'expectedRevision': mission.revision,
            'mission': {...mission.toJson(), 'journal': entry('Mission')},
          },
        ),
      );
      await controller.exportDirectWrite();
      final saved = await plugin.loadFromRepo(workspace) as CampaignDocument;
      expect(saved.catalog.journal!.titleFor('en'), 'Opening');
      expect(
        saved.catalog.chapters.first.journal!.titleFor('fr'),
        'FR Chapter',
      );
      expect(saved.selected.journal!.titleFor('en'), 'Mission');
      expect(saved.selected.revision, mission.revision + 1);
      expect(
        saved.catalog.missions.map((m) => m.id),
        original.catalog.missions.map((m) => m.id),
      );
      controller.undo();
      expect(
        (controller.document as CampaignDocument).selected.journal!.toJson(),
        mission.journal!.toJson(),
      );
      controller.redo();
      expect(
        (controller.document as CampaignDocument).selected.journal!.titleFor(
          'en',
        ),
        'Mission',
      );
    },
  );

  testWidgets(
    'native selection reads dimensions and Apply returns settings; Cancel discards them',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.binding.setSurfaceSize(null);
      });
      final previewWorkspace = EditorWorkspace(rootPath: repo);
      const pickedPath = 'assets/images/maps/lothringen_bonfire.jpg';
      Map<String, Object?>? result;
      String? openedDirectory;
      Future<void> open() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showDialog<Map<String, Object?>>(
                      context: context,
                      builder: (_) => CampaignSettingsDialog(
                        catalog: catalog,
                        workspace: previewWorkspace,
                        filePicker: ({required initialDirectory}) async {
                          openedDirectory = initialDirectory;
                          return previewWorkspace.resolve(pickedPath);
                        },
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
      }

      await open();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Campaign name (en)'),
        'Named campaign',
      );
      expect(find.text('Campaign name (fr)'), findsNothing);
      await tester.tap(find.text('Français').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Campaign name (fr)'),
        '',
      );
      await tester.tap(find.text('English').first);
      await tester.pumpAndSettle();
      expect(find.text('Named campaign'), findsOneWidget);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Campaign name (fr)'), findsOneWidget);
      expect(find.text('Required.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Campaign name (fr)'),
        'Campagne nommée',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('campaign_choose_map')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('campaign_choose_map')).hitTestable(),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('campaign_choose_map')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      for (
        var attempt = 0;
        attempt < 50 && find.text(pickedPath).evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(find.text(pickedPath), findsOneWidget);
      expect(openedDirectory, previewWorkspace.resolve('assets/images/maps'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect((result!['title'] as Map)['en'], 'Named campaign');
      expect((result!['title'] as Map)['fr'], 'Campagne nommée');
      expect((result!['map'] as Map)['assetPath'], pickedPath);
      expect((result!['map'] as Map)['width'], greaterThan(1));
      expect((result!['map'] as Map)['height'], greaterThan(1));
      await open();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Campaign name (en)'),
        'Discarded',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(
        CampaignCatalogSource.decode(
          File(workspace.resolve(campaignSourcePath)).readAsStringSync(),
        ).title,
        catalog.title,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('map selection rejects external paths and corrupt images', () async {
    final image = await readCampaignMapAsset(
      workspace,
      workspace.resolve('assets/images/maps/selected.png'),
    );
    expect(image.width, 1);
    expect(image.height, 1);
    await expectLater(
      readCampaignMapAsset(workspace, '$repo/assets/images/maps/theodonis.jpg'),
      throwsFormatException,
    );
    File(workspace.resolve('assets/images/maps/broken.png'))
        .writeAsStringSync('not an image');
    await expectLater(
      readCampaignMapAsset(
        workspace,
        workspace.resolve('assets/images/maps/broken.png'),
      ),
      throwsA(anything),
    );
  });
}
