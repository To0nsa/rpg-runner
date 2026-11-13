import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/assets/ui_asset_lifecycle.dart';
import 'package:rpg_runner/ui/pages/selectCharacter/character_selection_page.dart';
import 'package:rpg_runner/ui/pages/selectCharacter/loadout_setup_page.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/developer/developer_profile_store.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';
import 'package:rpg_runner/ui/theme/ui_tokens.dart';
import 'package:rpg_runner/ui/theme/ui_button_theme.dart';
import 'package:rpg_runner/ui/theme/ui_skill_icon_theme.dart';

void main() {
  for (final size in [
    const Size(1200, 720),
    const Size(800, 450),
    const Size(800, 360),
    const Size(568, 320),
  ]) {
    testWidgets('selection and independent build editing at $size', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final store = _RenameStore();
      final state = AppState.developer(store: store);
      final assets = UiAssetLifecycle();
      addTearDown(state.dispose);
      addTearDown(assets.dispose);
      await state.bootstrap();
      await state.setProjectileSpell(
        characterId: PlayerCharacterId.bountyHunter,
        spellId: ProjectileId.hunterCrossbow,
      );
      final eloise =
          (state.selection.toJson()['buildsByCharacter'] as Map)['eloise'];
      final eloiseName = PlayerCharacterRegistry.eloise.displayName;
      await tester.runAsync(() async {
        for (final (family, path) in [
          ('CrimsonText', 'assets/fonts/Crimson_Text/CrimsonText-Regular.ttf'),
          ('Inter', 'assets/fonts/Inter/static/Inter_24pt-Regular.ttf'),
          ('Cinzel', 'assets/fonts/Cinzel/static/Cinzel-Regular.ttf'),
          ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
        ]) {
          await (FontLoader(family)..addFont(rootBundle.load(path))).load();
        }
        await assets.getIdle(PlayerCharacterId.eloise);
        await assets.getIdle(PlayerCharacterId.bountyHunter);
      });
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: state),
            Provider<UiAssetLifecycle>.value(value: assets),
          ],
          child: MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'Inter',
              extensions: [
                UiTokens.standard,
                UiButtonTheme.standard,
                UiSkillIconTheme.standard,
              ],
            ),
            builder: (context, child) =>
                RepaintBoundary(key: boundary, child: child),
            home: const Scaffold(body: Text('Hub')),
            initialRoute: UiRoutes.selectCharacter,
            routes: {
              UiRoutes.selectCharacter: (_) => const CharacterSelectionPage(),
              UiRoutes.setupLoadout: (context) => LoadoutSetupPage(
                args:
                    ModalRoute.of(context)!.settings.arguments
                        as LoadoutSetupArgs?,
              ),
            },
          ),
        ),
      );
      await tester.pump();
      final semantics = tester.ensureSemantics();
      try {
        expect(
          find.bySemanticsLabel('Use Build 1 with Willow'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Edit Build 1 for Willow'),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
      final willowCard = find.byKey(
        const ValueKey('character-card-bountyHunter'),
      );
      final eloiseCard = find.byKey(const ValueKey('character-card-eloise'));
      final buildWillow = find.descendant(
        of: willowCard,
        matching: find.text('Build 1'),
      );
      final buildEloise = find.descendant(
        of: eloiseCard,
        matching: find.text('Build 1'),
      );
      expect(find.text('Build 1'), findsNWidgets(2));
      expect(find.text('Build 2'), findsNothing);
      expect(find.text('Build 3'), findsNothing);
      expect(find.text('Change build'), findsNothing);
      expect(find.text('Unlocks at level 5'), findsNWidgets(2));
      expect(find.text('Unlocks at level 12'), findsNWidgets(2));
      for (final element
          in find.textContaining('Unlocks at level ').evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      expect(find.text('Eloise WIP'), findsNothing);
      expect(find.text('CURRENT CHARACTER'), findsNothing);
      expect(
        find.text('Choose a fighting style, then shape your build.'),
        findsNothing,
      );
      expect(find.textContaining('Sword · Shield'), findsNothing);
      expect(find.textContaining('Pick a gun'), findsNothing);
      expect(find.text('Last used'), findsNothing);
      expect(find.text('SAVED BUILDS'), findsNothing);
      expect(find.text('Steel & spellcraft'), findsNothing);
      expect(find.text('Bounty hunter'), findsNothing);
      expect(find.text('Active build'), findsOneWidget);
      expect(find.text('Selected'), findsNothing);
      expect(find.text('Select Willow'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Selected for next run'), findsNothing);
      final expectedHeight = {
        const Size(1200, 720): 360.0,
        const Size(800, 450): 318.0,
        const Size(800, 360): 228.0,
        const Size(568, 320): 216.0,
      }[size]!;
      for (final card in [willowCard, eloiseCard]) {
        final rect = tester.getRect(card);
        expect(rect.height, expectedHeight);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.top, greaterThanOrEqualTo(kToolbarHeight));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }
      expect(buildWillow.hitTestable(), findsOneWidget);
      expect(buildEloise.hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('character-unselected-bountyHunter')),
        findsNothing,
      );
      if (Platform.environment['BOUNTY_HUNTER_CAPTURE'] == 'true') {
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/images/backgrounds/playHub_bgDark.png'),
            tester.element(find.byType(CharacterSelectionPage)),
          ),
        );
        await tester.pump();
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '.tmp/character_builds_${size.width.toInt()}x${size.height.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(
        find.byKey(const ValueKey('select-character-bountyHunter')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        state.selection.selectedCharacterId,
        PlayerCharacterId.bountyHunter,
      );
      expect(find.byType(CharacterSelectionPage), findsOneWidget);
      expect(find.byType(LoadoutSetupPage), findsNothing);
      expect(
        find.byKey(const ValueKey('character-unselected-bountyHunter')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('character-unselected-eloise')),
        findsNothing,
      );
      await tester.tap(find.text(eloiseName));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(state.selection.selectedCharacterId, PlayerCharacterId.eloise);
      expect(find.byType(CharacterSelectionPage), findsOneWidget);
      // Build selection stays on the chooser; editing preserves the chosen pair.
      await tester.tap(buildWillow);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(LoadoutSetupPage), findsNothing);
      expect(
        state.selection.selectedCharacterId,
        PlayerCharacterId.bountyHunter,
      );
      expect(
        state.selection
            .loadoutFor(PlayerCharacterId.bountyHunter)
            .projectileSlotSpellId,
        ProjectileId.hunterCrossbow,
      );
      expect(
        (state.selection.toJson()['buildsByCharacter'] as Map)['eloise'],
        eloise,
      );
      await tester.tap(buildEloise);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byTooltip('Edit Build 1 for Willow'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(LoadoutSetupPage), findsOneWidget);
      expect(state.selection.selectedCharacterId, PlayerCharacterId.eloise);
      expect(find.text('Willow · Build 1'), findsNothing);
      expect(find.text('Rename'), findsNothing);
      expect(find.text('Use this build'), findsNothing);
      expect(tester.getSize(find.byType(TabBar)).height, 44);
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
      await _capture(tester, boundary, size, 'builder');
      await tester.tap(find.byTooltip('Rename build'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await _capture(tester, boundary, size, 'rename');
      tester.view.viewInsets = FakeViewPadding(
        bottom: 140 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.text('Save')).bottom,
        lessThanOrEqualTo(size.height - 140),
      );
      expect(find.text('Save').hitTestable(), findsOneWidget);
      await _capture(tester, boundary, size, 'rename_keyboard');
      tester.view.resetViewInsets();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.enterText(
        find.byType(TextField),
        '123456789012345678901234567890',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '1234567890123456789012345678',
      );
      await tester.enterText(find.byType(TextField), ' ');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Enter a build name.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(state.selection.buildName, 'Build 1');
      await tester.tap(find.byTooltip('Rename build'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.enterText(
        find.byType(TextField),
        'Willow crossbow practice kit',
      );
      store.failNextSave = true;
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.text('Could not save the name. Please try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(Dialog), findsNothing);
      expect(state.selection.buildName, 'Build 1');
      expect(
        state.selection
            .buildsFor(PlayerCharacterId.bountyHunter)
            .builds[0]
            .name,
        'Willow crossbow practice kit',
      );
      expect(find.text('Willow crossbow practice kit'), findsOneWidget);
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byType(CharacterSelectionPage), findsOneWidget);
      expect(find.byType(LoadoutSetupPage), findsNothing);
      expect(find.text('Willow crossbow practice kit'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('build-eloise-1')));
      await tester.pump();
      expect(find.byType(CharacterSelectionPage), findsOneWidget);
      expect(state.selection.selectedCharacterId, PlayerCharacterId.eloise);
      await tester.tap(find.text('Willow crossbow practice kit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        state.selection.selectedCharacterId,
        PlayerCharacterId.bountyHunter,
      );
      expect(find.byType(LoadoutSetupPage), findsNothing);
      await tester.tap(find.byTooltip('Edit Build 1 for $eloiseName'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        state.selection.selectedCharacterId,
        PlayerCharacterId.bountyHunter,
      );
      expect(find.text('Use this build'), findsNothing);
      expect(
        state.selection.selectedCharacterId,
        PlayerCharacterId.bountyHunter,
      );
      expect(state.selection.buildName, 'Willow crossbow practice kit');
      expect(
        state.selection
            .loadoutFor(PlayerCharacterId.bountyHunter)
            .projectileSlotSpellId,
        ProjectileId.hunterCrossbow,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CharacterSelectionPage), findsOneWidget);
      expect(find.byType(LoadoutSetupPage), findsNothing);
      expect(
        state.selection.selectedCharacterId,
        PlayerCharacterId.bountyHunter,
      );
      await tester.tap(buildEloise);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(state.selection.selectedCharacterId, PlayerCharacterId.eloise);

      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Hub'), findsOneWidget);
      expect(find.byType(CharacterSelectionPage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundary,
  Size size,
  String view,
) async {
  if (Platform.environment['BOUNTY_HUNTER_CAPTURE'] != 'true') return;
  await tester.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '.tmp/character_builds_${view}_${size.width.toInt()}x${size.height.toInt()}.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class _RenameStore extends SharedPrefsDeveloperProfileStore {
  bool failNextSave = false;
  @override
  Future<void> saveSelection(SelectionState selection) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('Disk unavailable');
    }
    await super.saveSelection(selection);
  }
}
