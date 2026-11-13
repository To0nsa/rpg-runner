import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_editor/src/app/pages/campaign/campaign_journal_fields.dart';
import 'package:runner_editor/src/app/pages/campaign/campaign_journal_preview.dart';
import 'package:runner_editor/src/app/pages/campaign/campaign_mission_settings.dart';
import 'package:runner_editor/src/campaign/campaign_domain_plugin.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  testWidgets(
    'mission Journal joins local draft Apply and Reset without editing the source document',
    (tester) async {
      final document = await tester.runAsync(
        () async => await CampaignDomainPlugin().loadFromRepo(
          EditorWorkspace(rootPath: Directory.current.parent.parent.path),
        ) as CampaignDocument,
      );
      final key = GlobalKey<CampaignMissionSettingsState>();
      CampaignMissionSource? applied;
      await tester.binding.setSurfaceSize(const Size(1100, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CampaignMissionSettings(
                key: key,
                document: document!,
                onApply: (value) => applied = value,
                onDraftChanged: () {},
              ),
            ),
          ),
        ),
      );
      final field = find.widgetWithText(TextFormField, 'Journal title (en)');
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Changed arrival');
      await tester.pump();
      expect(key.currentState!.hasDraft, isTrue);
      expect(key.currentState!.save(), isTrue);
      await tester.pump();
      expect(applied!.journal!.titleFor('en'), 'Changed arrival');
      expect(
        document.selected.journal!.titleFor('en'),
        isNot('Changed arrival'),
      );
      final changed = find.widgetWithText(TextFormField, 'Journal title (en)');
      await tester.ensureVisible(changed);
      await tester.enterText(changed, 'Discarded');
      await tester.pump();
      key.currentState!.cancel();
      await tester.pumpAndSettle();
      expect(key.currentState!.hasDraft, isFalse);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Journal title (en)'),
            )
            .initialValue,
        document.selected.journal!.titleFor('en'),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'optional Journal validates both languages and preserves toggled drafts',
    (tester) async {
      final form = GlobalKey<FormState>();
      final fields = GlobalKey<CampaignJournalFieldsState>();
      await tester.binding.setSurfaceSize(const Size(900, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: form,
                child: CampaignJournalFields(
                  key: fields,
                  label: 'Opening',
                  entry: null,
                ),
              ),
            ),
          ),
        ),
      );
      expect(form.currentState!.validate(), isTrue);
      expect(fields.currentState!.value, isNull);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Journal title (en)'),
        'First report',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Journal text (en)'),
        'First paragraph.\n\nSecond paragraph.',
      );
      expect(form.currentState!.validate(), isFalse);
      fields.currentState!.revealFirstError();
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'Journal title (fr)'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Journal title (fr)'),
        'Premier rapport',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Journal text (fr)'),
        'Premier paragraphe.',
      );
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(fields.currentState!.value, isNull);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(form.currentState!.validate(), isTrue);
      form.currentState!.save();
      final saved = fields.currentState!.value!;
      expect(saved.titleFor('fr'), 'Premier rapport');
      expect(saved.bodyFor('en'), 'First paragraph.\n\nSecond paragraph.');
    },
  );

  testWidgets(
    'every Val mission preview keeps the full initial location entry before its updates',
    (tester) async {
      final catalog = CampaignCatalogSource.decode(
        File('../../assets/authoring/campaign/chapter_defs.json')
            .readAsStringSync(),
      );
      final chapter = catalog.chapters.firstWhere((c) => c.id == 'val_outpost');
      final locationLore = {
        for (final language in ['en', 'fr'])
          language:
              (jsonDecode(
                    File('../../lib/ui/l10n/app_$language.arb')
                        .readAsStringSync(),
                  ) as Map<String, dynamic>)['codexForestLore']
                  as String,
      };
      await tester.binding.setSurfaceSize(const Size(1100, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final mission in chapter.missions) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(mission.id),
            home: CampaignJournalPreview(
              catalog: catalog,
              missionId: mission.id,
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final language in ['en', 'fr']) {
          if (language == 'fr') {
            await tester.tap(find.widgetWithText(Tab, 'Français'));
            await tester.pumpAndSettle();
          }
          final titles = language == 'en'
              ? ['Val Outpost', 'After Le feu de joie']
              : ['L’avant-poste du Val', 'Après Le feu de joie'];
          final opening = find.text(titles[0]);
          expect(opening.hitTestable(), findsOneWidget);
          final introduction = find.text(titles[1]);
          expect(introduction, findsOneWidget);
          final body = find.text(catalog.journal!.bodyFor(language));
          expect(body, findsOneWidget);
          expect(
            catalog.journal!.bodyFor(language),
            locationLore[language]!.replaceAll(r'\n', '\n'),
            reason: 'Retain the complete spoiler-free Library location entry.',
          );
          expect(
            tester.getTopLeft(opening).dy,
            lessThan(tester.getTopLeft(introduction).dy),
          );
          expect(
            tester.getTopLeft(introduction).dy,
            lessThan(
              tester
                  .getTopLeft(find.text(mission.journal!.titleFor(language)))
                  .dy,
            ),
          );
          await tester.ensureVisible(introduction);
          await tester.pumpAndSettle();
          expect(introduction.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'checkpoint preview renders English/French drafts without changing source',
    (tester) async {
      final catalog = CampaignCatalogSource.decode(
        File('../../assets/authoring/campaign/chapter_defs.json')
            .readAsStringSync(),
      );
      final baseline = catalog.encode();
      final mission = catalog.missions.last;
      await tester.binding.setSurfaceSize(const Size(1100, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: CampaignJournalPreview(catalog: catalog, missionId: mission.id),
        ),
      );
      expect(find.text(catalog.journal!.titleFor('en')), findsOneWidget);
      expect(find.text(mission.journal!.titleFor('en')), findsOneWidget);
      await tester.tap(find.widgetWithText(Tab, 'Français'));
      await tester.pumpAndSettle();
      expect(find.text(mission.journal!.titleFor('fr')), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('journal_preview_checkpoint')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Opening only').last);
      await tester.pumpAndSettle();
      expect(find.text(mission.journal!.titleFor('fr')), findsNothing);
      expect(find.text(catalog.journal!.titleFor('fr')), findsOneWidget);
      expect(catalog.encode(), baseline);
      expect(tester.takeException(), isNull);
    },
  );
}
