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
    testWidgets('cards select in place and open remembered builds at $size', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final state = AppState.developer(
        store: SharedPrefsDeveloperProfileStore(),
      );
      final assets = UiAssetLifecycle();
      addTearDown(state.dispose);
      addTearDown(assets.dispose);
      await state.bootstrap();
      await state.setProjectileSpell(
        characterId: PlayerCharacterId.bountyHunter,
        spellId: ProjectileId.hunterCrossbow,
      );
      final eloise =
          (state.selection.toJson()['loadoutsByCharacter'] as Map)['eloise'];
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
              extensions: [
                UiTokens.standard,
                UiButtonTheme.standard,
                UiSkillIconTheme.standard,
              ],
            ),
            builder: (context, child) =>
                RepaintBoundary(key: boundary, child: child),
            home: const CharacterSelectionPage(),
            routes: {
              UiRoutes.selectCharacter: (_) => const CharacterSelectionPage(),
              UiRoutes.setupLoadout: (_) => const LoadoutSetupPage(),
            },
          ),
        ),
      );
      await tester.pump();
      final willowCard = find.byKey(
        const ValueKey('character-card-bountyHunter'),
      );
      final eloiseCard = find.byKey(const ValueKey('character-card-eloise'));
      final buildWillow = find.descendant(
        of: willowCard,
        matching: find.text('Change build'),
      );
      final buildEloise = find.descendant(
        of: eloiseCard,
        matching: find.text('Change build'),
      );
      expect(find.text('Change build'), findsNWidgets(2));
      expect(find.text('Eloise WIP'), findsNothing);
      expect(find.text('CURRENT CHARACTER'), findsNothing);
      expect(
        find.text('Choose a fighting style, then shape your build.'),
        findsNothing,
      );
      expect(find.textContaining('Sword · Shield'), findsNothing);
      expect(find.textContaining('Pick a gun'), findsNothing);
      expect(find.byType(Scrollable), findsNothing);
      for (final card in [willowCard, eloiseCard]) {
        final rect = tester.getRect(card);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.top, greaterThanOrEqualTo(kToolbarHeight));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }
      expect(buildWillow.hitTestable(), findsOneWidget);
      expect(buildEloise.hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('character-unselected-bountyHunter')),
        findsOneWidget,
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
            '.tmp/willow_selection_${size.width.toInt()}x${size.height.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Willow'));
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
        findsOneWidget,
      );
      await tester.tap(find.text(eloiseName));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(state.selection.selectedCharacterId, PlayerCharacterId.eloise);
      expect(find.byType(CharacterSelectionPage), findsOneWidget);
      // A build button also selects its own card before opening the builder.
      await tester.tap(buildWillow);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(LoadoutSetupPage), findsOneWidget);
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
        (state.selection.toJson()['loadoutsByCharacter'] as Map)['eloise'],
        eloise,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(TextButton, 'Willow'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(buildEloise);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(state.selection.selectedCharacterId, PlayerCharacterId.eloise);
      expect(
        state.selection
            .loadoutFor(PlayerCharacterId.bountyHunter)
            .projectileSlotSpellId,
        ProjectileId.hunterCrossbow,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
