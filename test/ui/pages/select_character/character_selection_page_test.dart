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
  for (final size in [const Size(1200, 720), const Size(800, 450)]) {
    testWidgets('selection routes to each remembered build at $size', (
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
      final eloiseButton =
          'Build ${PlayerCharacterRegistry.eloise.displayName}';
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
      expect(find.text('Build Willow'), findsOneWidget);
      expect(find.text(eloiseButton), findsOneWidget);
      expect(find.text('Eloise WIP'), findsNothing);
      if (Platform.environment['BOUNTY_HUNTER_CAPTURE'] == 'true') {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('.tmp/bounty_selection_${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      final build = find.text('Build Willow');
      await tester.ensureVisible(build);
      await tester.tap(build);
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
      await tester.ensureVisible(find.text(eloiseButton));
      await tester.tap(find.text(eloiseButton));
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
