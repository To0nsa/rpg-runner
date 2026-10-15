import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:rpg_runner/ui/app/ui_router.dart';
import 'package:rpg_runner/ui/codex/codex_catalog.dart';
import 'package:rpg_runner/ui/pages/library/codex_entry_page.dart';
import 'package:rpg_runner/ui/pages/library/library_page.dart';
import 'package:rpg_runner/ui/pages/town/town_page.dart';
import 'package:rpg_runner/ui/pages/town/town_region_map.dart';
import 'package:rpg_runner/ui/pages/town/town_store_page.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/ownership/codex_progress.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';

void main() {
  testWidgets('entry gates react to settled progress and account reset', (
    tester,
  ) async {
    final app = _CodexAppState();
    addTearDown(app.dispose);
    await tester.pumpWidget(
      _app(app, const CodexEntryPage.enemy(EnemyId.grojib)),
    );
    expect(find.text('Entry locked'), findsOneWidget);
    expect(find.text('Attacks'), findsNothing);
    expect(find.text(CodexCatalog.enemyLore(EnemyId.grojib)), findsNothing);
    app.setProgress(CodexProgress(enemyKills: {'grojib': 10}));
    await tester.pumpAndSettle();
    expect(find.text('Entry locked'), findsNothing);
    expect(find.text('Attacks'), findsOneWidget);
    expect(find.text('Resistances'), findsOneWidget);
    expect(find.text('Weaknesses'), findsOneWidget);
    expect(find.text(CodexCatalog.enemyLore(EnemyId.grojib)), findsOneWidget);
    app.setProgress(CodexProgress.empty);
    await tester.pumpAndSettle();
    expect(find.text('Entry locked'), findsOneWidget);
    expect(find.text('Attacks'), findsNothing);
  });

  testWidgets(
    'places show two independent 10000 gates and opening uses PDF timeline',
    (tester) async {
      final app = _CodexAppState();
      addTearDown(app.dispose);
      await tester.pumpWidget(_app(app, const LibraryPage()));
      await tester.tap(find.text('Places'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('codex-level-new_level')), findsNothing);
      expect(find.text('0 / 10,000 best Competitive score'), findsNWidgets(2));
      await tester.tap(find.text('Forest'));
      await tester.pumpAndSettle();
      expect(find.text('Entry locked'), findsOneWidget);
      app.setProgress(CodexProgress(competitiveBestScores: {'forest': 10000}));
      await tester.pumpAndSettle();
      expect(find.text(CodexCatalog.levelLore(LevelId.forest)), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();
      expect(find.text(CodexCatalog.opening), findsOneWidget);
      expect(find.textContaining('Six centuries'), findsOneWidget);
    },
  );

  testWidgets('boss filter shows only bosses with five-kill goals', (
    tester,
  ) async {
    final app = _CodexAppState();
    addTearDown(app.dispose);
    await tester.pumpWidget(_app(app, const LibraryPage()));
    await tester.tap(find.text('Bosses'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('codex-enemy-grojib')), findsNothing);
    expect(
      find.byKey(const ValueKey('codex-enemy-bringerOfDeath')),
      findsOneWidget,
    );
    expect(find.text('0 / 5 defeated'), findsWidgets);
    expect(find.text('0 / 10 defeated'), findsNothing);
  });

  for (final size in [const Size(640, 360), const Size(360, 640)]) {
    testWidgets('Town map stays usable at $size with large text and zoom', (
      tester,
    ) async {
      tester.view.reset();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = _CodexAppState();
      addTearDown(app.dispose);
      await tester.pumpWidget(_app(app, const TownPage(), textScale: 1.5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TownRegionMap), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('town-store-marker')));
      await tester.pumpAndSettle();
      expect(find.byType(TownStorePage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(1),
      );
      await tester.drag(find.byType(InteractiveViewer), const Offset(40, 20));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Zoom out'));
      await tester.pumpAndSettle();
      expect(viewer.transformationController!.value, Matrix4.identity());
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reset map'));
      await tester.pumpAndSettle();
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
      await tester.tap(find.byKey(const ValueKey('town-library-marker')));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(TownRegionMap), findsOneWidget);
    });
  }
}

Widget _app(AppState app, Widget home, {double textScale = 1}) =>
    ChangeNotifierProvider<AppState>.value(
      value: app,
      child: MaterialApp(
        theme: createUiTheme(),
        onGenerateRoute: UiRouter.onGenerateRoute,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      ),
    );

class _CodexAppState extends ChangeNotifier implements AppState {
  @override
  SelectionState get selection => SelectionState.defaults;
  @override
  ProgressionState progression = ProgressionState.initial;

  void setProgress(CodexProgress codex) {
    progression = progression.copyWith(codex: codex);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
