import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/assets/ui_asset_lifecycle.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:rpg_runner/ui/pages/selectCharacter/character_selection_page.dart';
import 'package:rpg_runner/ui/pages/selectCharacter/loadout_setup_page.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/developer/developer_profile_store.dart';
import 'package:rpg_runner/ui/theme/ui_button_theme.dart';
import 'package:rpg_runner/ui/theme/ui_skill_icon_theme.dart';
import 'package:rpg_runner/ui/theme/ui_tokens.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final size in [
    const Size(568, 320),
    const Size(390, 844),
    const Size(320, 640),
  ]) {
    testWidgets('French build controls support larger text at $size', (
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
      const buildName = 'Configuration pour la route';
      await state.setBuildName(buildName);
      await tester.runAsync(() async {
        for (final (family, path) in [
          ('CrimsonText', 'assets/fonts/Crimson_Text/CrimsonText-Regular.ttf'),
          ('Inter', 'assets/fonts/Inter/static/Inter_24pt-Regular.ttf'),
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
            locale: const Locale('fr'),
            supportedLocales: RunnerLocalizations.supportedLocales,
            localizationsDelegates: RunnerLocalizations.delegates,
            theme: ThemeData(
              extensions: [
                UiTokens.standard,
                UiButtonTheme.standard,
                UiSkillIconTheme.standard,
              ],
            ),
            builder: (context, child) => RepaintBoundary(
              key: boundary,
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.25)),
                child: child!,
              ),
            ),
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
      await tester.pump(const Duration(milliseconds: 350));
      final strings = appStringsFor(const Locale('fr'));
      final edit = find.byTooltip(
        strings.characterEditBuildSemantics(
          build: strings.defaultBuildName(number: 1),
          character: 'Willow',
        ),
      );
      await tester.ensureVisible(edit);
      await tester.pump();
      expect(tester.getSize(edit).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(edit).width, greaterThanOrEqualTo(48));
      expect(find.text(strings.characterActiveBuild), findsOneWidget);
      expect(find.text(strings.uiEdit), findsNothing);
      expect(find.text(strings.characterNextRun), findsNothing);
      expect(find.text(strings.characterSelected), findsNothing);
      expect(find.text('Last used'), findsNothing);
      await _capture(tester, boundary, size, 'chooser');
      expect(tester.takeException(), isNull);
      if (size.width < 540) return;
      await tester.tap(edit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(LoadoutSetupPage), findsOneWidget);
      expect(state.selection.selectedCharacterId, PlayerCharacterId.eloise);
      expect(find.text(strings.characterUseBuild).hitTestable(), findsNothing);
      expect(
        find.byTooltip(strings.uiRenameBuild).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await _capture(tester, boundary, size, 'editor');
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CharacterSelectionPage), findsOneWidget);
    });
  }
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundary,
  Size size,
  String screen,
) async {
  if (Platform.environment['BOUNTY_HUNTER_CAPTURE'] != 'true') return;
  await tester.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '.tmp/character_cards_fr_${screen}_${size.width.toInt()}x${size.height.toInt()}.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
