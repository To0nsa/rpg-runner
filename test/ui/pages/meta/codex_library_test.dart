import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:rpg_runner/ui/app/ui_router.dart';
import 'package:rpg_runner/ui/assets/ui_asset_lifecycle.dart';
import 'package:rpg_runner/ui/pages/library/enemy_portrait.dart';
import 'package:rpg_runner/ui/codex/codex_catalog.dart';
import 'package:rpg_runner/ui/pages/library/codex_entry_page.dart';
import 'package:rpg_runner/ui/pages/library/library_page.dart';
import 'package:rpg_runner/ui/pages/town/town_page.dart';
import 'package:rpg_runner/ui/pages/town/town_map.dart';
import 'package:rpg_runner/ui/pages/town/town_store_page.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/ownership/codex_progress.dart';
import 'package:rpg_runner/ui/state/ownership/enemy_defeats.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';

void main() {
  testWidgets('compact rows use idle portraits and progress beside the name', (
    tester,
  ) async {
    final app = _CodexAppState();
    addTearDown(app.dispose);
    await tester.pumpWidget(_app(app, const LibraryPage()));
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing);
    expect(find.textContaining('entries discovered'), findsNothing);
    expect(find.textContaining('Defeat an enemy 10 times'), findsNothing);
    expect(find.text('Enemy • Locked'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
    expect(
      find.byKey(const ValueKey('codex-enemy-shoggothMinion')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('codex-enemy-voidTentacle')),
      findsNothing,
    );
    final row = find.byKey(const ValueKey('codex-enemy-unocoDemon'));
    expect(
      find.descendant(of: row, matching: find.byType(EnemyPortrait)),
      findsNothing,
    );
    expect(tester.getSize(row).height, lessThanOrEqualTo(72));
    expect(find.text('Unoco Demon'), findsNothing);
    final nameRect = tester.getRect(
      find.descendant(of: row, matching: find.text('Entry locked')),
    );
    final progressRect = tester.getRect(
      find.descendant(of: row, matching: find.text('Defeat 0 / 10 to unlock')),
    );
    expect(progressRect.left, greaterThan(nameRect.right));
    expect((progressRect.center.dy - nameRect.center.dy).abs(), lessThan(1));
    expect(
      tester.getRect(find.byTooltip('Bestiary')).right,
      lessThan(tester.getRect(row).left),
    );
    await tester.tap(find.byTooltip('Locations'));
    await tester.pumpAndSettle();
    expect(find.text('Library · Locations'), findsOneWidget);
    expect(find.text('Know the land'), findsNothing);
    expect(find.textContaining('Reach the required score'), findsNothing);
    expect(find.text('Places'), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('codex-level-forest'))).height,
      lessThanOrEqualTo(72),
    );
  });

  testWidgets('one defeat reveals the idle frame before unlocking Bestiary', (
    tester,
  ) async {
    final app = _CodexAppState();
    addTearDown(app.dispose);
    await tester.pumpWidget(_app(app, const LibraryPage()));
    final row = find.byKey(const ValueKey('codex-enemy-unocoDemon'));
    expect(
      find.descendant(of: row, matching: find.byType(EnemyPortrait)),
      findsNothing,
    );

    app.setDefeats({'unocoDemon': 1});
    await tester.pump();
    expect(
      find.descendant(of: row, matching: find.text('Defeat 0 / 10 to unlock')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: row, matching: find.byType(EnemyPortrait)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('Entry locked')),
      findsOneWidget,
    );
    expect(find.text('Unoco Demon'), findsNothing);
    expect(
      find.descendant(of: row, matching: find.text('Defeat 1 / 10 to unlock')),
      findsOneWidget,
    );

    app.setDefeats({'unocoDemon': 10});
    await tester.pump();
    expect(find.descendant(of: row, matching: find.text('Open')), findsNothing);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: row, matching: find.text('Unoco Demon')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('Open')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Bestiary and Locations fill on entry and show Open at the gate',
    (tester) async {
      final app = _CodexAppState();
      addTearDown(app.dispose);
      app.setDefeats({'unocoDemon': 10});
      app.setProgress(CodexProgress(competitiveBestScores: {'forest': 12000}));
      await tester.pumpWidget(_app(app, const LibraryPage()));

      final enemy = find.byKey(const ValueKey('codex-enemy-unocoDemon'));
      expect(
        find.descendant(of: enemy, matching: find.text('0 / 10')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        find.descendant(of: enemy, matching: find.text('Open')),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        find.descendant(of: enemy, matching: find.text('Open')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Locations'));
      await tester.pump();
      final location = find.byKey(const ValueKey('codex-level-forest'));
      expect(
        find.descendant(of: location, matching: find.text('0 / 10,000')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 1200));
      expect(
        find.descendant(of: location, matching: find.text('Open')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Bestiary'));
      await tester.pump();
      expect(
        find.descendant(of: enemy, matching: find.text('0 / 10')),
        findsOneWidget,
      );
    },
  );

  for (final pair in {
    EnemyId.shoggoth: EnemyId.shoggothMinion,
    EnemyId.voidcaller: EnemyId.voidTentacle,
  }.entries) {
    testWidgets('${pair.value.displayName} is revealed inside its boss entry', (
      tester,
    ) async {
      final app = _CodexAppState();
      addTearDown(app.dispose);
      app.setDefeats({pair.value.name: 10, pair.key.name: 4});
      await tester.pumpWidget(_app(app, CodexEntryPage.enemy(pair.value)));
      expect(find.text('Entry locked'), findsOneWidget);
      expect(find.text(CodexCatalog.enemyLore(pair.value)), findsNothing);
      app.setDefeats({pair.key.name: 5});
      await tester.pumpAndSettle();
      expect(find.text('Entry locked'), findsNothing);
      expect(find.text(pair.value.displayName), findsOneWidget);
      expect(find.text(CodexCatalog.enemyLore(pair.value)), findsOneWidget);
      expect(find.text(CodexCatalog.enemyLore(pair.key)), findsOneWidget);
    });
  }

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
    app.setDefeats({'grojib': 10});
    await tester.pumpAndSettle();
    expect(find.text('Entry locked'), findsNothing);
    expect(find.text('Attacks'), findsOneWidget);
    expect(find.text('Resistances'), findsOneWidget);
    expect(find.text('Weaknesses'), findsOneWidget);
    expect(find.text(CodexCatalog.enemyLore(EnemyId.grojib)), findsOneWidget);
    expect(find.textContaining('Second Strike • melee'), findsOneWidget);
    expect(find.textContaining('can stun on hit'), findsOneWidget);
    expect(find.textContaining('Strike2'), findsNothing);
    app.setDefeats({});
    await tester.pumpAndSettle();
    expect(find.text('Entry locked'), findsOneWidget);
    expect(find.text('Attacks'), findsNothing);
  });

  testWidgets(
    'locations show two independent 10000 gates and opening uses PDF timeline',
    (tester) async {
      final app = _CodexAppState();
      addTearDown(app.dispose);
      await tester.pumpWidget(_app(app, const LibraryPage()));
      await tester.tap(find.byTooltip('Locations'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('codex-level-new_level')), findsNothing);
      expect(find.text('0 / 10,000'), findsNWidgets(2));
      await tester.tap(find.text('The Val Outpost'));
      await tester.pumpAndSettle();
      expect(find.text('Entry locked'), findsOneWidget);
      app.setProgress(CodexProgress(competitiveBestScores: {'forest': 10000}));
      await tester.pumpAndSettle();
      expect(find.text(CodexCatalog.levelLore(LevelId.forest)), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Journal'));
      await tester.pumpAndSettle();
      expect(find.text('Library · Journal'), findsOneWidget);
      expect(find.text(CodexCatalog.opening), findsOneWidget);
      expect(find.textContaining('Éloïse of Elingen'), findsOneWidget);
    },
  );

  testWidgets('bestiary lists enemies and bosses without filters', (
    tester,
  ) async {
    final app = _CodexAppState();
    addTearDown(app.dispose);
    await tester.pumpWidget(_app(app, const LibraryPage()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('codex-enemy-grojib')), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Library · Bestiary'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('codex-enemy-bringerOfDeath')),
      findsOneWidget,
    );
    expect(find.text('Defeat 0 / 5 to unlock'), findsWidgets);
    expect(find.text('Defeat 0 / 10 to unlock'), findsWidgets);
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
      expect(find.byType(TownMap), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('town-store-marker')));
      await tester.pumpAndSettle();
      expect(find.byType(TownStorePage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Library marker'));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Zoom in'), findsNothing);
      expect(find.byTooltip('Zoom out'), findsNothing);
      expect(find.textContaining('Visit a city service'), findsNothing);
      final viewerFinder = find.byType(InteractiveViewer);
      final viewer = tester.widget<InteractiveViewer>(viewerFinder);
      final initial = viewer.transformationController!.value.clone();
      final imageSize = tester.getSize(
        find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is ResizeImage,
        ),
      );
      final viewportSize = tester.getSize(viewerFinder);
      expect(imageSize.width, greaterThanOrEqualTo(viewportSize.width));
      expect(imageSize.height, greaterThanOrEqualTo(viewportSize.height));
      final center = tester.getCenter(viewerFinder);
      final first = await tester.startGesture(
        center - const Offset(30, 0),
        pointer: 1,
      );
      final second = await tester.startGesture(
        center + const Offset(30, 0),
        pointer: 2,
      );
      await tester.pump();
      await first.moveTo(center - const Offset(60, 0));
      await second.moveTo(center + const Offset(60, 0));
      await tester.pump();
      await first.moveTo(center - const Offset(90, 0));
      await second.moveTo(center + const Offset(90, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(1),
      );
      await tester.drag(viewerFinder, const Offset(40, 20));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reset map'));
      await tester.pumpAndSettle();
      expect(viewer.transformationController!.value, initial);
      await tester.tap(find.byKey(const ValueKey('town-library-marker')));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(TownMap), findsOneWidget);
    });
  }
}

Widget _app(AppState app, Widget home, {double textScale = 1}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AppState>.value(value: app),
    Provider<UiAssetLifecycle>(
      create: (_) => UiAssetLifecycle(),
      dispose: (_, owner) => owner.dispose(),
    ),
  ],
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

  void setDefeats(Map<String, int> byEnemy) {
    progression = progression.copyWith(
      enemyDefeats: EnemyDefeats(byEnemy: byEnemy),
    );
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
