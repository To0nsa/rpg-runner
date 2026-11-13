import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:rpg_runner/ui/components/map_label_button.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:rpg_runner/ui/app/ui_router.dart';
import 'package:rpg_runner/ui/assets/ui_asset_lifecycle.dart';
import 'package:rpg_runner/ui/components/enemy_portrait.dart';
import 'package:rpg_runner/ui/codex/codex_catalog.dart';
import 'package:rpg_runner/ui/campaign/campaign_catalog.dart';
import 'package:rpg_runner/ui/pages/library/codex_entry_page.dart';
import 'package:rpg_runner/ui/pages/library/bestiary_entry_view.dart';
import 'package:rpg_runner/ui/pages/library/library_page.dart';
import 'package:rpg_runner/ui/pages/library/location_map.dart';
import 'package:rpg_runner/ui/pages/town/town_page.dart';
import 'package:rpg_runner/ui/pages/town/town_map.dart';
import 'package:rpg_runner/ui/pages/town/town_store_page.dart';
import 'package:rpg_runner/ui/pages/town/town_catalog.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/auth/auth_api.dart';
import 'package:rpg_runner/ui/state/ownership/codex_progress.dart';
import 'package:rpg_runner/ui/state/ownership/enemy_defeats.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';
import 'package:rpg_runner/ui/state/presentation/library_progress_tracker.dart';
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
    expect(find.byType(LocationMap), findsOneWidget);
    expect(find.byType(MapLabelButton), findsNWidgets(2));
    expect(find.byKey(const ValueKey('codex-level-forest')), findsOneWidget);
    expect(find.byKey(const ValueKey('codex-level-field')), findsOneWidget);
    expect(find.text('Théodonis'), findsOneWidget);
    for (final label in [
      'Quartier Est',
      'Hagen',
      'Veymeringen',
      'Mont aux Étoiles',
      'Vosga',
    ]) {
      expect(find.text(label), findsNothing);
    }
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
    'settled Open entries stay open when switching Library sections',
    (tester) async {
      final app = _CodexAppState();
      addTearDown(app.dispose);
      app.setDefeats({'unocoDemon': 10});
      app.setProgress(CodexProgress(competitiveBestScores: {'forest': 12000}));
      await tester.pumpWidget(_app(app, const LibraryPage()));

      final enemy = find.byKey(const ValueKey('codex-enemy-unocoDemon'));
      expect(
        find.descendant(of: enemy, matching: find.text('Open')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Locations'));
      await tester.pump();
      final location = find.byKey(const ValueKey('codex-level-forest'));
      await tester.tap(location);
      await tester.pumpAndSettle();
      expect(
        find.text(CodexCatalog.levelLore(LevelId.forest, appStringsFor(null))),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close location'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Bestiary'));
      await tester.pump();
      expect(
        find.descendant(of: enemy, matching: find.text('Open')),
        findsOneWidget,
      );
    },
  );

  testWidgets('a map dialog updates from settled score to unlocked lore', (
    tester,
  ) async {
    final app = _CodexAppState();
    addTearDown(app.dispose);
    app.setProgress(CodexProgress(competitiveBestScores: {'forest': 4000}));
    await tester.pumpWidget(_app(app, const LibraryPage()));
    await tester.tap(find.byTooltip('Locations'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('codex-level-forest')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('4,000 / 10,000 best Competitive score'),
      findsOneWidget,
    );

    app.setProgress(CodexProgress(competitiveBestScores: {'forest': 12000}));
    await tester.pumpAndSettle();
    expect(
      find.text(CodexCatalog.levelLore(LevelId.forest, appStringsFor(null))),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Close location'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Journal'));
    await tester.pump();
    app.setProgress(
      CodexProgress(competitiveBestScores: {'forest': 12000, 'field': 10000}),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Locations'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('codex-level-field')));
    await tester.pumpAndSettle();
    expect(
      find.text(CodexCatalog.levelLore(LevelId.field, appStringsFor(null))),
      findsOneWidget,
    );
  });

  testWidgets('map dialog reads progress earned away from Library', (
    tester,
  ) async {
    final app = _CodexAppState();
    addTearDown(app.dispose);
    app.setProgress(CodexProgress(competitiveBestScores: {'forest': 4000}));
    await tester.pumpWidget(_app(app, const LibraryPage()));
    await tester.tap(find.byTooltip('Locations'));
    await tester.pump();
    await tester.pumpWidget(_app(app, const SizedBox()));

    app.setProgress(CodexProgress(competitiveBestScores: {'forest': 10000}));
    await tester.pumpWidget(_app(app, const LibraryPage()));
    await tester.tap(find.byTooltip('Locations'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('codex-level-forest')));
    await tester.pumpAndSettle();
    expect(
      find.text(CodexCatalog.levelLore(LevelId.forest, appStringsFor(null))),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Close location'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(app, const SizedBox()));
    await tester.pumpWidget(_app(app, const LibraryPage()));
    await tester.tap(find.byTooltip('Locations'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('codex-level-forest')));
    await tester.pumpAndSettle();
    expect(
      find.text(CodexCatalog.levelLore(LevelId.forest, appStringsFor(null))),
      findsOneWidget,
    );
  });

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
      expect(
        find.text(CodexCatalog.enemyLore(pair.value, appStringsFor(null))),
        findsNothing,
      );
      app.setDefeats({pair.key.name: 5});
      await tester.pumpAndSettle();
      expect(find.text('Entry locked'), findsNothing);
      expect(find.text(pair.value.displayName), findsOneWidget);
      expect(
        find.text(CodexCatalog.enemyLore(pair.value, appStringsFor(null))),
        findsOneWidget,
      );
      expect(
        find.text(CodexCatalog.enemyLore(pair.key, appStringsFor(null))),
        findsOneWidget,
      );
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
    expect(
      find.text(CodexCatalog.enemyLore(EnemyId.grojib, appStringsFor(null))),
      findsNothing,
    );
    app.setDefeats({'grojib': 10});
    await tester.pumpAndSettle();
    expect(find.text('Entry locked'), findsNothing);
    expect(find.text('Attacks'), findsOneWidget);
    expect(find.text('Resistances'), findsOneWidget);
    expect(find.text('Weaknesses'), findsOneWidget);
    expect(
      find.text(CodexCatalog.enemyLore(EnemyId.grojib, appStringsFor(null))),
      findsOneWidget,
    );
    final secondStrike = find.byKey(
      const ValueKey('bestiary-attack-grojib.strike2'),
    );
    expect(
      find.descendant(of: secondStrike, matching: find.text('Second Strike')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: secondStrike,
        matching: find.text('melee · Physical damage'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('can stun on hit'), findsOneWidget);
    expect(find.text('Leave room for the second swing.'), findsOneWidget);
    expect(find.text('Bestiary'), findsNothing);
    expect(find.text('Grojib'), findsOneWidget);
    expect(find.byType(EnemyPortrait), findsOneWidget);
    expect(find.textContaining('Strike2'), findsNothing);
    app.setDefeats({});
    await tester.pumpAndSettle();
    expect(find.text('Entry locked'), findsOneWidget);
    expect(find.text('Attacks'), findsNothing);
    expect(find.byType(BestiaryEntryView), findsNothing);
    expect(find.text('Leave room for the second swing.'), findsNothing);
  });

  for (final locale in [const Locale('en'), const Locale('fr')]) {
    testWidgets(
      'field guides retain every catalog attack and summon in $locale',
      (tester) async {
        final app = _CodexAppState();
        addTearDown(app.dispose);
        app.setDefeats({
          for (final id in CodexCatalog.bestiaryEntries)
            id.name: CodexCatalog.killsRequired(id),
        });
        final strings = appStringsFor(locale);
        for (final enemy in CodexCatalog.bestiaryEntries) {
          await tester.pumpWidget(
            _app(app, CodexEntryPage.enemy(enemy), locale: locale),
          );
          await tester.pumpAndSettle();
          for (final creature in [enemy, ...CodexCatalog.summonsFor(enemy)]) {
            expect(
              find.text(CodexCatalog.enemyAdvice(creature, strings)),
              findsOneWidget,
            );
            expect(
              find.text(CodexCatalog.enemyRole(creature, strings)),
              findsOneWidget,
            );
            expect(
              find.text(CodexCatalog.enemyLore(creature, strings)),
              findsOneWidget,
            );
            for (final ability in CodexCatalog.attacks(creature)) {
              expect(
                find.byKey(ValueKey('bestiary-attack-${ability.id}')),
                findsOneWidget,
              );
            }
          }
          expect(tester.takeException(), isNull);
        }
      },
    );

    for (final layout in [
      (size: const Size(568, 320), scale: 1.0, columns: true),
      (size: const Size(640, 360), scale: 1.0, columns: true),
      (size: const Size(844, 390), scale: 1.0, columns: true),
      (size: const Size(320, 640), scale: 1.8, columns: false),
      (size: const Size(568, 320), scale: 1.8, columns: false),
      (size: const Size(640, 360), scale: 1.8, columns: false),
      (size: const Size(1024, 768), scale: 1.0, columns: true),
    ]) {
      testWidgets(
        'field guide fits ${layout.size} at ${layout.scale} text in $locale',
        (tester) async {
          tester.view.physicalSize = layout.size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.runAsync(() async {
            final fonts = FontLoader('CrimsonText');
            for (final face in ['Regular', 'Bold', 'Italic']) {
              fonts.addFont(
                rootBundle.load(
                  'assets/fonts/Crimson_Text/CrimsonText-$face.ttf',
                ),
              );
            }
            await fonts.load();
          });
          final app = _CodexAppState();
          addTearDown(app.dispose);
          app.setDefeats({'voidcaller': 5});
          await tester.pumpWidget(
            _app(
              app,
              const CodexEntryPage.enemy(EnemyId.voidcaller),
              textScale: layout.scale,
              locale: locale,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(EnemyPortrait), findsNWidgets(2));
          final strings = appStringsFor(locale);
          final attacks = find.text(strings.uiAttacks).first;
          final behaviour = find.text(strings.uiBehaviour).first;
          if (layout.columns) {
            expect(
              tester.getTopLeft(behaviour).dx,
              greaterThan(tester.getTopRight(attacks).dx),
            );
            expect(
              tester.getTopLeft(behaviour).dy,
              closeTo(tester.getTopLeft(attacks).dy, 1),
            );
            expect(
              tester.getBottomLeft(attacks).dy,
              lessThan(layout.size.height),
            );
          } else {
            expect(
              tester.getTopLeft(behaviour).dy,
              greaterThan(tester.getTopLeft(attacks).dy),
            );
          }
          for (final text in tester.widgetList<Text>(find.byType(Text))) {
            expect(text.overflow, isNot(TextOverflow.ellipsis));
          }
          await tester.drag(
            find.byType(SingleChildScrollView).last,
            const Offset(0, -10000),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(CodexCatalog.enemyLore(EnemyId.voidTentacle, strings)),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'locations show two independent 10000 gates and Journal uses the post-fire timeline',
    (tester) async {
      final app = _CodexAppState();
      addTearDown(app.dispose);
      await tester.pumpWidget(_app(app, const LibraryPage()));
      await tester.tap(find.byTooltip('Locations'));
      await tester.pumpAndSettle();
      expect(
        (await rootBundle.load(LocationMap.assetPath)).lengthInBytes,
        greaterThan(0),
      );
      expect(find.byKey(const ValueKey('codex-level-new_level')), findsNothing);
      expect(find.byType(LocationMap), findsOneWidget);
      expect(find.text('Léonards’ farm'), findsOneWidget);
      expect(find.text('Val Outpost'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('codex-level-field')));
      await tester.pumpAndSettle();
      expect(find.text('Entry locked'), findsOneWidget);
      expect(
        find.textContaining('0 / 10,000 best Competitive score'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close location'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('codex-level-forest')));
      await tester.pumpAndSettle();
      expect(find.text('Entry locked'), findsOneWidget);
      app.setProgress(CodexProgress(competitiveBestScores: {'forest': 10000}));
      await tester.pumpAndSettle();
      expect(
        find.text(CodexCatalog.levelLore(LevelId.forest, appStringsFor(null))),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close location'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Journal'));
      await tester.pumpAndSettle();
      expect(find.text('Library · Journal'), findsOneWidget);
      expect(
        find.text(CampaignCatalog.journal.opening!.bodyFor('en')),
        findsOneWidget,
      );
      expect(find.textContaining('have reached Théodonis'), findsOneWidget);
    },
  );

  for (final size in [const Size(640, 360), const Size(360, 640)]) {
    testWidgets('location map markers work at $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(
        left: 16,
        top: 24,
        bottom: 16,
      );
      addTearDown(tester.view.reset);
      final app = _CodexAppState();
      addTearDown(app.dispose);
      await tester.pumpWidget(_app(app, const LibraryPage(), textScale: 1.4));
      await tester.tap(find.byTooltip('Locations'));
      await tester.pumpAndSettle();
      final viewer = find.byType(InteractiveViewer);
      expect(viewer, findsOneWidget);
      final viewport = tester.getRect(viewer);
      expect(viewport, Offset.zero & size);
      final artwork = tester.getRect(
        find.descendant(of: viewer, matching: find.byType(Image)),
      );
      expect(artwork.intersect(viewport), viewport);
      final toolbarBottom = tester.getBottomRight(find.byType(AppBar)).dy;
      final railRight = tester.getTopRight(find.byTooltip('Locations')).dx;
      final cityLabel = tester.getRect(find.text('Théodonis'));
      expect(cityLabel.top, greaterThanOrEqualTo(toolbarBottom));
      expect(cityLabel.left, greaterThan(railRight));
      expect(
        tester.getTopLeft(find.byTooltip('Reset map')).dy,
        greaterThanOrEqualTo(toolbarBottom),
      );
      for (final id in [LevelId.field, LevelId.forest]) {
        final marker = find.byKey(ValueKey('codex-level-${id.name}'));
        final bounds = tester.getRect(marker);
        expect(bounds.left, greaterThan(railRight));
        expect(bounds.top, greaterThanOrEqualTo(toolbarBottom));
        expect(bounds.right, lessThanOrEqualTo(viewport.right));
        expect(bounds.bottom, lessThanOrEqualTo(viewport.bottom - 16));
        expect(bounds.overlaps(cityLabel), isFalse);
        await tester.tap(marker);
        await tester.pumpAndSettle();
        expect(find.text('Entry locked'), findsOneWidget);
        await tester.tap(find.byTooltip('Close location'));
        await tester.pumpAndSettle();
      }
      final controller = tester
          .widget<InteractiveViewer>(viewer)
          .transformationController!;
      final initial = controller.value.clone();
      controller.value = initial.clone()
        ..setEntry(0, 0, initial.entry(0, 0) * 1.5)
        ..setEntry(1, 1, initial.entry(1, 1) * 1.5);
      await tester.pump();
      final zoomed = controller.value.clone();
      await tester.tap(find.byTooltip('Journal'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Locations'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<InteractiveViewer>(viewer).transformationController,
        same(controller),
      );
      expect(controller.value, zoomed);
      await tester.tap(find.byTooltip('Reset map'));
      await tester.pumpAndSettle();
      expect(controller.value, initial);
      expect(tester.takeException(), isNull);
    });
  }

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
      expect(find.byType(MapLabelButton), findsNWidgets(4));
      final labels = [
        'town-store-marker',
        'town-training-marker',
        'town-library-marker',
        'town-achievements-marker',
      ];
      for (var i = 0; i < labels.length; i++) {
        for (var j = i + 1; j < labels.length; j++) {
          expect(
            tester
                .getRect(find.byKey(ValueKey(labels[i])))
                .overlaps(tester.getRect(find.byKey(ValueKey(labels[j])))),
            isFalse,
            reason: "${labels[i]} overlaps ${labels[j]}",
          );
        }
      }
      await tester.tap(find.byKey(const ValueKey('town-store-marker')));
      await tester.pumpAndSettle();
      expect(find.byType(TownStorePage), findsOneWidget);
      expect(
        tester.widget<TownStorePage>(find.byType(TownStorePage)).initialService,
        TownService.equipment,
      );
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('town-training-marker')));
      await tester.pumpAndSettle();
      expect(find.text('Training Hall'), findsOneWidget);
      expect(
        tester.widget<TownStorePage>(find.byType(TownStorePage)).initialService,
        TownService.training,
      );
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

Widget _app(
  AppState app,
  Widget home, {
  double textScale = 1,
  Locale? locale,
}) => MultiProvider(
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
  final LibraryProgressTracker libraryProgressTracker =
      LibraryProgressTracker();

  @override
  AuthSession get authSession => AuthSession.unauthenticated;

  @override
  String get profileId => 'main';

  @override
  SelectionState get selection => SelectionState.defaults;
  @override
  ProgressionState progression = ProgressionState.initial;

  @override
  int get displayedGold => progression.gold;

  @override
  bool isCharacterUnlocked(PlayerCharacterId id) =>
      id == PlayerCharacterId.eloise;

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
