import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_runner/ui/campaign/campaign_catalog.dart';
import 'package:rpg_runner/ui/assets/ui_asset_lifecycle.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:rpg_runner/ui/pages/library/library_page.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/auth/auth_api.dart';
import 'package:rpg_runner/ui/state/ownership/campaign_progress.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';
import 'package:rpg_runner/ui/state/presentation/library_progress_tracker.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';

void main() {
  final chapter = CampaignCatalog.chapters.first;
  final mission = chapter.missions.first;
  final draft = CampaignCatalog.chapters.first.missions.firstWhere(
    (m) => !m.available,
  );

  for (final locale in ['en', 'fr']) {
    testWidgets(
      'Journal follows confirmed clears without duplicates or draft spoilers in $locale',
      (tester) async {
        final app = _JournalAppState();
        addTearDown(app.dispose);
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_app(app, Locale(locale)));
        await tester.tap(
          find.byTooltip(appStringsFor(Locale(locale)).uiJournal),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(CampaignCatalog.journal.opening!.bodyFor(locale)),
          findsOneWidget,
        );
        expect(
          CampaignCatalog.journal.opening!.bodyFor(locale),
          appStringsFor(Locale(locale)).codexForestLore.replaceAll(r'\n', '\n'),
          reason:
              'The initial Val location entry remains before earned updates.',
        );
        final titles = locale == 'en'
            ? ['Val Outpost', 'After Le feu de joie']
            : ['L’avant-poste du Val', 'Après Le feu de joie'];
        final opening = find.text(titles[0]);
        final setup = find.text(titles[1]);
        expect(opening, findsOneWidget);
        expect(setup, findsOneWidget);
        expect(
          tester.getTopLeft(opening).dy,
          lessThan(tester.getTopLeft(setup).dy),
        );
        expect(find.text(chapter.journal!.bodyFor(locale)), findsOneWidget);
        expect(
          find.byKey(ValueKey('journal-mission:${mission.id}')),
          findsNothing,
        );

        app.setMission(mission.id, cleared: false);
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('journal-mission:${mission.id}')),
          findsNothing,
        );
        app.setMission(mission.id, cleared: true);
        await tester.pumpAndSettle();
        final earned = find.byKey(ValueKey('journal-mission:${mission.id}'));
        expect(earned, findsOneWidget);
        expect(
          tester.getTopLeft(find.text(chapter.journal!.titleFor(locale))).dy,
          lessThan(tester.getTopLeft(earned).dy),
        );
        await tester.ensureVisible(earned);
        await tester.pumpAndSettle();
        expect(find.text(mission.journal!.bodyFor(locale)), findsOneWidget);
        app.setMission(mission.id, cleared: true);
        app.setMission(draft.id, cleared: true);
        await tester.pumpAndSettle();
        expect(earned, findsOneWidget);
        expect(
          find.byKey(ValueKey('journal-mission:${draft.id}')),
          findsNothing,
        );

        app.resetAccount();
        await tester.pumpAndSettle();
        expect(earned, findsNothing);
        expect(
          find.text(CampaignCatalog.journal.opening!.bodyFor(locale)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'restored clears and a live locale switch retain the Journal section',
    (tester) async {
      final app = _JournalAppState()..setMission(mission.id, cleared: true);
      addTearDown(app.dispose);
      await tester.pumpWidget(_app(app, const Locale('en')));
      await tester.tap(find.byTooltip('Journal'));
      await tester.pumpAndSettle();
      expect(find.text(mission.journal!.titleFor('en')), findsOneWidget);
      await tester.pumpWidget(_app(app, const Locale('fr')));
      await tester.pumpAndSettle();
      expect(find.text('Bibliothèque · Journal'), findsOneWidget);
      expect(find.text(mission.journal!.titleFor('fr')), findsOneWidget);
      expect(find.text(mission.journal!.titleFor('en')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app(AppState app, Locale locale) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AppState>.value(value: app),
    Provider<UiAssetLifecycle>(
      create: (_) => UiAssetLifecycle(),
      dispose: (_, owner) => owner.dispose(),
    ),
  ],
  child: MaterialApp(
    theme: createUiTheme(),
    locale: locale,
    localizationsDelegates: RunnerLocalizations.delegates,
    supportedLocales: RunnerLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.6)),
      child: child!,
    ),
    home: const LibraryPage(),
  ),
);

class _JournalAppState extends ChangeNotifier implements AppState {
  @override
  final libraryProgressTracker = LibraryProgressTracker();
  @override
  AuthSession get authSession => AuthSession.unauthenticated;
  @override
  String get profileId => 'journal-test';
  @override
  ProgressionState progression = ProgressionState.initial;
  final _missions = <String, Object?>{};

  void setMission(String id, {required bool cleared}) {
    _missions[id] = {
      'cleared': cleared,
      'attempts': 1,
      'bests': <String, Object?>{},
    };
    progression = progression.copyWith(
      campaign: CampaignProgress.fromJson({
        'schemaVersion': 1,
        'missions': _missions,
      }),
    );
    notifyListeners();
  }

  void resetAccount() {
    _missions.clear();
    progression = ProgressionState.initial;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
