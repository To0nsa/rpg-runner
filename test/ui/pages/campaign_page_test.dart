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
import 'package:rpg_runner/ui/campaign/campaign_chapter_dialog.dart';
import 'package:rpg_runner/ui/campaign/campaign_map.dart';
import 'package:rpg_runner/ui/campaign/generated_campaign_catalog.dart';
import 'package:rpg_runner/ui/components/map_label_button.dart';
import 'package:rpg_runner/ui/components/app_button.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:rpg_runner/ui/pages/hub/play_hub_page.dart';
import 'package:rpg_runner/ui/pages/hub/components/hub_select_card_frame.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/auth/auth_api.dart';
import 'package:rpg_runner/ui/state/ownership/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/pages/selectCharacter/character_selection_page.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:rpg_runner/ui/state/developer/developer_profile_store.dart';
import 'package:rpg_runner/ui/state/ownership/campaign_progress.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';
import 'package:rpg_runner/ui/theme/ui_button_theme.dart';
import 'package:rpg_runner/ui/theme/ui_tokens.dart';

void main() {
  testWidgets(
    'locked Willow explains the chapter requirement on a compact screen',
    (tester) async {
      await _loadCampaignFonts(tester);
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
  for (final language in ['en', 'fr']) {
    testWidgets(
      'chapter modal gates mission actions and starts through bootstrap in $language',
      (tester) async {
        await _loadCampaignFonts(tester);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(568, 320);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final source = (campaignCatalogData['chapters'] as List).first as Map;
        final missions = source['missions'] as List;
        final chapter = CampaignChapter({
          ...Map<String, Object?>.from(source),
          'missions': [
            for (var index = 0; index < 3; index++)
              {
                ...Map<String, Object?>.from(missions[index] as Map),
                'available': index < 2,
              },
          ],
        });
        final ownership = _CampaignOwnership();
        final state = AppState(
          authApi: _CampaignAuth(),
          loadoutOwnershipApi: ownership,
        );
        addTearDown(state.dispose);
        RunStartBootstrapArgs? launched;
        final boundary = GlobalKey();
        await tester.pumpWidget(
          ChangeNotifierProvider<AppState>.value(
            value: state,
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
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => CampaignChapterDialog(chapter: chapter),
                    ),
                    child: const Text('Open chapter'),
                  ),
                ),
              ),
              onGenerateRoute: (settings) {
                expect(settings.name, UiRoutes.runBootstrap);
                launched = settings.arguments as RunStartBootstrapArgs;
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => Scaffold(appBar: AppBar()),
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('Open chapter'));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(CampaignChapterDialog)),
        )!;
        final play = find.widgetWithText(AppButton, l10n.playButton);
        final locked = find.widgetWithText(AppButton, l10n.campaignLocked);
        final comingSoon = find.widgetWithText(
          AppButton,
          l10n.campaignComingSoon,
        );
        expect(play, findsOneWidget);
        expect(locked, findsOneWidget);
        expect(comingSoon, findsOneWidget);
        expect(
          find.descendant(of: play, matching: find.byIcon(Icons.play_arrow)),
          findsNothing,
        );
        expect(
          find.descendant(
            of: locked,
            matching: find.byIcon(Icons.lock_outline),
          ),
          findsOneWidget,
        );
        expect(tester.widget<AppButton>(locked).onPressed, isNull);
        expect(tester.widget<AppButton>(comingSoon).onPressed, isNull);
        _expectMissionLayout(tester, chapter, language);
        final actionWidth = tester.getSize(play).width;
        await _capture(tester, boundary, 'locked_missions_$language');
        for (final mission in chapter.missions.skip(1)) {
          final details = find.byKey(
            ValueKey('campaign-mission-details-${mission.id}'),
          );
          await tester.ensureVisible(details);
          await tester.tap(details);
          await tester.pumpAndSettle();
          expect(find.text(mission.title(language)), findsNothing);
          expect(find.byTooltip(mission.title(language)), findsNothing);
          expect(find.bySemanticsLabel(mission.title(language)), findsNothing);
          expect(find.text(mission.description(language)), findsNothing);
          expect(
            find.descendant(of: details, matching: find.byType(Icon)),
            findsNothing,
          );
        }
        await tester.ensureVisible(locked);
        await tester.tap(locked);
        await tester.pumpAndSettle();
        expect(launched, isNull);
        final firstTitle = find.text(chapter.missions.first.title(language));
        await tester.ensureVisible(firstTitle);
        await tester.tap(firstTitle);
        await tester.pumpAndSettle();
        await tester.ensureVisible(play);
        await tester.tap(play);
        await tester.pumpAndSettle();
        expect(launched?.campaignMissionId, chapter.missions.first.id);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(CampaignChapterDialog), findsOneWidget);
        expect(tester.widget<AppButton>(play).onPressed, isNotNull);
        expect(
          find.text(chapter.missions.first.description(language)),
          findsOneWidget,
        );
        ownership.progress = CampaignProgress.fromJson({
          'schemaVersion': 1,
          'missions': {
            chapter.missions.first.id: {
              'cleared': true,
              'attempts': 1,
              'bests': {},
            },
          },
        });
        await state.bootstrap(force: true);
        await tester.pumpAndSettle();
        final next = chapter.missions[1];
        expect(find.text(next.title(language)), findsOneWidget);
        expect(locked, findsNothing);
        expect(play, findsNWidgets(2));
        _expectMissionLayout(tester, chapter, language);
        expect(tester.getSize(play.last).width, actionWidth);
        await tester.ensureVisible(find.text(next.title(language)));
        await tester.tap(find.text(next.title(language)));
        await tester.pumpAndSettle();
        expect(find.text(next.description(language)), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
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
        await _loadCampaignFonts(tester);
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
        _expectFullScreenMap(tester, size);
        await _capture(tester, boundary, 'map_${size.width.toInt()}_$language');
        final viewerFinder = find.byType(InteractiveViewer);
        final viewer = tester.widget<InteractiveViewer>(viewerFinder);
        final transform = viewer.transformationController!;
        final initial = transform.value.clone();
        await tester.drag(viewerFinder, const Offset(0, -50));
        await tester.pumpAndSettle();
        expect(transform.value, isNot(initial));

        final center = tester.getCenter(viewerFinder);
        final first = await tester.startGesture(center - const Offset(30, 0));
        final second = await tester.startGesture(
          center + const Offset(30, 0),
          pointer: 2,
        );
        await first.moveTo(center - const Offset(60, 0));
        await second.moveTo(center + const Offset(60, 0));
        await tester.pump();
        await first.moveTo(center - const Offset(90, 0));
        await second.moveTo(center + const Offset(90, 0));
        await tester.pump();
        await first.up();
        await second.up();
        await tester.pumpAndSettle();
        expect(transform.value.getMaxScaleOnAxis(), greaterThan(1));
        await tester.tap(find.byIcon(Icons.center_focus_strong));
        await tester.pumpAndSettle();
        expect(transform.value, initial);

        await tester.drag(viewerFinder, const Offset(0, -20));
        await tester.pumpAndSettle();
        final mapBeforeChapter = transform.value.clone();
        final chapter = CampaignCatalog.chapters.first;
        await tester.tap(find.text(chapter.title(language)).last);
        await tester.pumpAndSettle();
        _expectChapterPanel(tester, size);
        _expectMissionLayout(tester, chapter, language);
        expect(
          tester
              .widget<InteractiveViewer>(viewerFinder)
              .transformationController,
          same(transform),
        );
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
        final mission = chapter.missions.first;
        final disclosure = find.byKey(
          ValueKey('campaign-mission-details-${mission.id}'),
        );
        final card = find.byKey(ValueKey('campaign-mission-${mission.id}'));
        final collapsedHeight = tester.getSize(card).height;
        for (final entry in chapter.missions) {
          expect(find.text(entry.description(language)), findsNothing);
        }
        await tester.ensureVisible(disclosure);
        await tester.tap(
          find.descendant(
            of: disclosure,
            matching: find.byIcon(Icons.chevron_right),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(mission.description(language)), findsOneWidget);
        expect(
          find.descendant(
            of: disclosure,
            matching: find.byIcon(Icons.expand_more),
          ),
          findsOneWidget,
        );
        expect(tester.getSize(card).height, greaterThan(collapsedHeight));
        final actionRect = tester.getRect(
          find.descendant(of: card, matching: find.byType(AppButton)),
        );
        final descriptionRect = tester.getRect(
          find.text(mission.description(language)),
        );
        expect(descriptionRect.top, greaterThan(actionRect.bottom));
        expect(descriptionRect.width, greaterThan(actionRect.width));
        await _capture(
          tester,
          boundary,
          'mission_expanded_${size.width.toInt()}_$language',
        );
        await tester.tap(find.text(mission.title(language)));
        await tester.pumpAndSettle();
        expect(find.text(mission.description(language)), findsNothing);
        expect(tester.getSize(card).height, collapsedHeight);
        await tester.ensureVisible(
          find.textContaining(chapter.missions.last.title(language)),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.close).hitTestable(), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          find.textContaining(chapter.missions.first.title(language)),
          findsNothing,
        );
        expect(find.text(chapter.title(language)), findsOneWidget);
        _expectFullScreenMap(tester, size);
        expect(transform.value, mapBeforeChapter);
        await tester.tap(find.text(chapter.title(language)));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.byType(CampaignChapterDialog), findsNothing);
        await tester.tap(find.text(chapter.title(language)));
        await tester.pumpAndSettle();
        await tester.dragFrom(
          Offset(size.width * .85, size.height * .75),
          const Offset(0, -20),
        );
        await tester.pumpAndSettle();
        expect(transform.value, mapBeforeChapter);
        await tester.tapAt(Offset(size.width * .85, size.height * .75));
        await tester.pumpAndSettle();
        expect(find.byType(CampaignChapterDialog), findsNothing);
        expect(transform.value, mapBeforeChapter);

        const portrait = Size(390, 844);
        tester.view.physicalSize = portrait;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
        addTearDown(tester.view.resetPadding);
        await tester.pumpAndSettle();
        _expectFullScreenMap(tester, portrait);
        final labelRect = tester.getRect(find.byType(MapLabelButton));
        expect(labelRect.left, greaterThanOrEqualTo(0));
        expect(labelRect.right, lessThanOrEqualTo(portrait.width));
        expect(labelRect.top, greaterThanOrEqualTo(24 + kToolbarHeight));
        expect(labelRect.bottom, lessThanOrEqualTo(portrait.height - 20));
        expect(
          find.text(chapter.title(language)).hitTestable(),
          findsOneWidget,
        );
        await _capture(tester, boundary, 'map_portrait_$language');
        await tester.tap(find.text(chapter.title(language)));
        await tester.pumpAndSettle();
        _expectChapterPanel(
          tester,
          portrait,
          padding: const EdgeInsets.only(top: 24, bottom: 20),
        );
        _expectMissionLayout(tester, chapter, language);
        expect(
          tester
              .getTopLeft(
                find.descendant(
                  of: find.byType(CampaignChapterDialog),
                  matching: find.text(chapter.title(language)),
                ),
              )
              .dy,
          greaterThanOrEqualTo(24),
        );
        expect(
          tester.getTopLeft(find.byIcon(Icons.close)).dy,
          greaterThanOrEqualTo(24),
        );
        await _capture(tester, boundary, 'missions_portrait_$language');
        await tester.ensureVisible(
          find.textContaining(chapter.missions.last.title(language)),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.close).hitTestable(), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Rotate with the chapter open, covering cutouts on either phone edge.
        await tester.tap(find.text(chapter.title(language)));
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(844, 390);
        for (final padding in [
          const EdgeInsets.only(left: 44, bottom: 21),
          const EdgeInsets.only(right: 44, bottom: 21),
        ]) {
          tester.view.padding = FakeViewPadding(
            left: padding.left,
            right: padding.right,
            bottom: padding.bottom,
          );
          await tester.pumpAndSettle();
          _expectChapterPanel(tester, const Size(844, 390), padding: padding);
          _expectMissionLayout(tester, chapter, language);
          expect(find.byIcon(Icons.close).hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await _capture(
            tester,
            boundary,
            'missions_notch_${padding.left > 0 ? 'left' : 'right'}_$language',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

class _UnusedAuth extends Fake implements AuthApi {}

class _UnusedOwnership extends Fake implements LoadoutOwnershipApi {}

class _CampaignAuth extends Fake implements AuthApi {
  static const session = AuthSession(
    userId: 'campaign-player',
    sessionId: 'campaign-session',
    isAnonymous: true,
    expiresAtMs: 0,
  );

  @override
  Future<AuthSession> loadSession() async => session;

  @override
  Future<AuthSession> ensureAuthenticatedSession() async => session;
}

class _CampaignOwnership extends Fake implements LoadoutOwnershipApi {
  CampaignProgress progress = CampaignProgress.empty;
  int revision = 0;

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async => OwnershipCanonicalState(
    profileId: defaultOwnershipProfileId,
    revision: ++revision,
    selection: SelectionState.defaults,
    meta: const MetaService().createNew(),
    progression: ProgressionState.initial.copyWith(campaign: progress),
  );
}

Future<void> _loadCampaignFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final (family, path) in [
      ('CrimsonText', 'assets/fonts/Crimson_Text/CrimsonText-Regular.ttf'),
      ('Inter', 'assets/fonts/Inter/static/Inter_24pt-Regular.ttf'),
      ('Cinzel', 'assets/fonts/Cinzel/static/Cinzel-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });
}

void _expectChapterPanel(
  WidgetTester tester,
  Size viewport, {
  EdgeInsets padding = EdgeInsets.zero,
}) {
  expect(find.byType(CampaignRegionalMap), findsOneWidget);
  final panel = tester.getRect(
    find.byKey(const ValueKey('campaign-chapter-panel')),
  );
  const margin = 12.0;
  expect(panel.left, padding.left + margin);
  expect(panel.top, padding.top + margin);
  expect(
    panel.width,
    closeTo((viewport.width - padding.horizontal) * 2 / 3, .01),
  );
  expect(panel.bottom, viewport.height - padding.bottom - margin);
  expect(
    panel.right,
    lessThanOrEqualTo(viewport.width - padding.right - margin),
  );
}

void _expectMissionLayout(
  WidgetTester tester,
  CampaignChapter chapter,
  String language,
) {
  final heading = find.descendant(
    of: find.byType(CampaignChapterDialog),
    matching: find.text(chapter.title(language)),
  );
  TextStyle? renderedStyle(Finder text) => tester
      .renderObject<RenderParagraph>(
        find.descendant(of: text, matching: find.byType(RichText)),
      )
      .text
      .style;
  final state = tester.element(heading).read<AppState>();
  final l10n = AppLocalizations.of(tester.element(heading))!;
  final actionWidths = <double>{};
  for (final mission in chapter.missions) {
    final unlocked =
        state.isDeveloperMode || state.progression.campaign.isUnlocked(mission);
    final card = find.byKey(ValueKey('campaign-mission-${mission.id}'));
    final disclosure = find.byKey(
      ValueKey('campaign-mission-details-${mission.id}'),
    );
    final title = find.descendant(
      of: disclosure,
      matching: find.text(
        unlocked ? mission.title(language) : l10n.campaignLocked,
      ),
    );
    expect(
      renderedStyle(title)?.fontFamily,
      renderedStyle(heading)?.fontFamily,
    );
    expect(
      renderedStyle(title)?.fontWeight,
      renderedStyle(heading)?.fontWeight,
    );
    expect(
      renderedStyle(title)?.fontSize,
      lessThan(renderedStyle(heading)!.fontSize!),
    );
    expect(tester.widget<Text>(title).maxLines, 1);
    final actionFinder = find.descendant(
      of: card,
      matching: find.byType(AppButton),
    );
    final action = tester.getRect(actionFinder);
    actionWidths.add(action.width);
    final titleRect = tester.getRect(title);
    final buttonLabel = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.descendant(
          of: actionFinder,
          matching: find.text(tester.widget<AppButton>(actionFinder).label),
        ),
        matching: find.byType(RichText),
      ),
    );
    expect(buttonLabel.didExceedMaxLines, isFalse);
    final arrow = find.descendant(of: disclosure, matching: find.byType(Icon));
    if (unlocked) {
      expect(tester.getRect(arrow).right, lessThan(titleRect.left));
    } else {
      expect(arrow, findsNothing);
    }
    expect(titleRect.right, lessThan(action.left));
    expect(titleRect.center.dy, closeTo(action.center.dy, .01));
    expect(action.right, lessThan(tester.getRect(card).right));
    expect(action.height, greaterThanOrEqualTo(48));
    expect(tester.getSize(disclosure).height, greaterThanOrEqualTo(48));
  }
  expect(actionWidths, hasLength(1));
}

void _expectFullScreenMap(WidgetTester tester, Size viewport) {
  expect(
    tester.getRect(find.byType(CampaignRegionalMap)),
    Offset.zero & viewport,
  );
  final image = find.descendant(
    of: find.byType(CampaignRegionalMap),
    matching: find.byType(Image),
  );
  final rect = tester.getRect(image);
  expect(rect.left, lessThanOrEqualTo(0));
  expect(rect.top, lessThanOrEqualTo(0));
  expect(rect.right, greaterThanOrEqualTo(viewport.width));
  expect(rect.bottom, greaterThanOrEqualTo(viewport.height));
  expect(rect.width / rect.height, closeTo(1361 / 1156, 0.0001));
}

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
