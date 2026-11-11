import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rpg_runner/ui/app/ui_routes.dart';
import 'package:rpg_runner/ui/assets/ui_asset_lifecycle.dart';
import 'package:rpg_runner/ui/campaign/campaign_page.dart';
import 'package:rpg_runner/ui/campaign/campaign_catalog.dart';
import 'package:rpg_runner/ui/campaign/campaign_chapter_rewards.dart';
import 'package:rpg_runner/ui/campaign/generated_campaign_catalog.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:rpg_runner/ui/pages/hub/play_hub_page.dart';
import 'package:rpg_runner/ui/pages/hub/components/hub_select_card_frame.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/auth/auth_api.dart';
import 'package:rpg_runner/ui/state/ownership/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/pages/selectCharacter/character_selection_page.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:rpg_runner/ui/state/developer/developer_profile_store.dart';
import 'package:rpg_runner/ui/state/ownership/campaign_progress.dart';
import 'package:rpg_runner/ui/theme/ui_button_theme.dart';
import 'package:rpg_runner/ui/theme/ui_tokens.dart';

void main() {
  testWidgets(
    'locked Willow explains the chapter requirement on a compact screen',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(568, 320);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final state = AppState(
        authApi: _UnusedAuth(),
        loadoutOwnershipApi: _UnusedOwnership(),
      );
      final assets = UiAssetLifecycle();
      addTearDown(state.dispose);
      addTearDown(assets.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: state),
            Provider<UiAssetLifecycle>.value(value: assets),
          ],
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(
              extensions: [UiTokens.standard, UiButtonTheme.standard],
            ),
            home: const CharacterSelectionPage(),
          ),
        ),
      );
      await tester.pump();
      final willow = find.byKey(const ValueKey('character-card-bountyHunter'));
      expect(willow, findsOneWidget);
      expect(
        find.descendant(of: willow, matching: find.byIcon(Icons.lock_outline)),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('build-bountyHunter-0')), findsNothing);
      await tester.tap(willow);
      await tester.pump();
      expect(state.selection.selectedCharacterId, PlayerCharacterId.eloise);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'mission access uses canonical clears and old progress has no unlocks',
    () {
      final missions = CampaignCatalog.chapters.first.missions;
      expect(CampaignProgress.empty.isUnlocked(missions.first), isTrue);
      expect(CampaignProgress.empty.isUnlocked(missions[1]), isFalse);
      final progress = CampaignProgress.fromJson({
        'schemaVersion': 1,
        'missions': {
          missions.first.id: {'cleared': true, 'attempts': 1, 'bests': {}},
        },
      });
      expect(progress.isUnlocked(missions[1]), isTrue);
      expect(progress.chapterCleared(CampaignCatalog.chapters.first), isFalse);
    },
  );
  test(
    'chapter settlement receipts survive serialization and are immutable',
    () {
      final raw = <String, Object?>{
        'schemaVersion': 1,
        'missions': <String, Object?>{},
        'chapters': {
          'val_outpost': {
            'grantedAtMs': 123,
            'xp': 75,
            'gold': 250,
            'characterId': 'bountyHunter',
            'items': [
              {'kind': 'gear', 'slot': 'mainWeapon', 'itemId': 'cinderedge'},
            ],
          },
        },
      };
      final progress = CampaignProgress.fromJson(raw);
      expect(progress.chapterRewardClaimed('val_outpost'), isTrue);
      expect(progress.chapterRewardClaimed('other'), isFalse);
      expect(progress.toJson(), raw);
      ((raw['chapters'] as Map)['val_outpost'] as Map)['xp'] = 999;
      expect(
        ((progress.toJson()['chapters'] as Map)['val_outpost'] as Map)['xp'],
        75,
      );
      expect(
        () => CampaignProgress.fromJson({...raw, 'chapters': null}),
        throwsFormatException,
      );
    },
  );
  for (final locale in ['en', 'fr']) {
    testWidgets('chapter reward names and amounts fit compact $locale UI', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source =
          (campaignCatalogData['chapters'] as List).first
              as Map<String, Object?>;
      final chapter = CampaignChapter({
        ...source,
        'rewardXp': 75,
        'rewardGold': 250,
        'rewardItems': [
          {'kind': 'gear', 'slot': 'mainWeapon', 'itemId': 'cinderedge'},
          {
            'kind': 'ability',
            'slot': 'jump',
            'itemId': 'eloise.double_jump',
            'characterId': 'eloise',
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            extensions: [UiTokens.standard, UiButtonTheme.standard],
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CampaignChapterRewards(chapter: chapter),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(locale == 'fr' ? '75 EXP' : '75 XP'),
        findsOneWidget,
      );
      expect(find.textContaining('250'), findsOneWidget);
      expect(find.text('Willow'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final size in [const Size(568, 320), const Size(1280, 720)]) {
    for (final language in ['en', 'fr']) {
      testWidgets('campaign navigation and three-card row at $size $language', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('dev.fluttercommunity.plus/charging'),
              (_) async => null,
            );
        await tester.runAsync(() async {
          for (final (family, path) in [
            (
              'CrimsonText',
              'assets/fonts/Crimson_Text/CrimsonText-Regular.ttf',
            ),
            ('Inter', 'assets/fonts/Inter/static/Inter_24pt-Regular.ttf'),
            ('Cinzel', 'assets/fonts/Cinzel/static/Cinzel-Regular.ttf'),
            ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
          ]) {
            await (FontLoader(family)..addFont(rootBundle.load(path))).load();
          }
        });
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final state = AppState.developer(
          store: SharedPrefsDeveloperProfileStore(),
        );
        final assets = UiAssetLifecycle();
        addTearDown(state.dispose);
        addTearDown(assets.dispose);
        await state.bootstrap();
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppState>.value(value: state),
              Provider<UiAssetLifecycle>.value(value: assets),
            ],
            child: MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(
                extensions: [UiTokens.standard, UiButtonTheme.standard],
              ),
              builder: (context, child) => RepaintBoundary(
                key: boundary,
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.2)),
                  child: child!,
                ),
              ),
              home: const PlayHubPage(),
              routes: {UiRoutes.campaign: (_) => const CampaignPage()},
            ),
          ),
        );
        await tester.pump();
        final frames = find.byType(HubSelectCardFrame);
        expect(frames, findsNWidgets(3));
        final rects = [
          for (var i = 0; i < 3; i++) tester.getRect(frames.at(i)),
        ];
        expect(rects.map((r) => r.top).toSet(), hasLength(1));
        expect(rects.last.right, lessThanOrEqualTo(size.width));
        expect(tester.takeException(), isNull);
        await _capture(tester, boundary, 'hub_${size.width.toInt()}_$language');
        await tester.tap(frames.last);
        await tester.pumpAndSettle();
        final chapter = CampaignCatalog.chapters.first;
        await tester.tap(find.text(chapter.title(language)).last);
        await tester.pumpAndSettle();
        expect(
          find.textContaining(chapter.missions.first.title(language)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await _capture(
          tester,
          boundary,
          'missions_${size.width.toInt()}_$language',
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(chapter.missions.first.title(language)),
          findsNothing,
        );
        expect(find.text(chapter.title(language)), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

class _UnusedAuth extends Fake implements AuthApi {}

class _UnusedOwnership extends Fake implements LoadoutOwnershipApi {}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (Platform.environment['CAMPAIGN_CAPTURE'] != 'true') return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('.tmp/campaign_$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
