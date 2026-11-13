import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/weapons/weapon_id.dart';
import 'package:run_protocol/submission_status.dart';
import 'package:rpg_runner/ui/components/app_button.dart';
import 'package:rpg_runner/ui/components/gold_display.dart';
import 'package:rpg_runner/ui/pages/town/town_store_page.dart';
import 'package:rpg_runner/ui/pages/town/town_catalog.dart';
import 'package:rpg_runner/ui/pages/town/town_equipment_args.dart';
import 'package:rpg_runner/ui/components/item_picker_tile.dart';
import 'package:rpg_runner/ui/components/app_segmented_control.dart';
import 'package:rpg_runner/ui/campaign/campaign_catalog.dart';
import 'package:rpg_runner/ui/state/ownership/campaign_progress.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/state/auth/auth_api.dart';
import 'package:rpg_runner/ui/state/ownership/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/run/pending_run_submission.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';
import 'package:rpg_runner/ui/state/run/run_session_api.dart';
import 'package:rpg_runner/ui/state/run/run_submission_coordinator.dart';
import 'package:rpg_runner/ui/state/run/run_submission_spool_store.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';

void main() {
  testWidgets(
    'equipment workspace browses categories and training has its own entrance',
    (tester) async {
      if (const bool.fromEnvironment('CAPTURE_TOWN_SERVICES')) {
        await tester.runAsync(() async {
          for (final font in {
            'Cinzel': 'assets/fonts/Cinzel/static/Cinzel-Regular.ttf',
            'CrimsonText': 'assets/fonts/Crimson_Text/CrimsonText-Regular.ttf',
            'Inter': 'assets/fonts/Inter/static/Inter_24pt-Regular.ttf',
            'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
          }.entries) {
            await (FontLoader(
              font.key,
            )..addFont(rootBundle.load(font.value))).load();
          }
        });
      }
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final json = jsonDecode(
        File('functions/test/fixtures/town_catalogue.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final api = _ScriptedOwnershipApi(
        canonical: _canonicalWithStore(
          willowUnlocked: true,
          gold: 450,
          activeOffers: TownStoreState.fromJson(json).catalogOffers,
        ),
      );
      final app = await _bootstrappedAppState(ownershipApi: api);
      addTearDown(app.dispose);
      await tester.pumpWidget(_TestApp(appState: app));
      await tester.pumpAndSettle();
      await _capture(tester, 'equipment');
      await tester.tap(find.byKey(const ValueKey('catalogue-slot-accessory')));
      await tester.pumpAndSettle();
      expect(find.text('Waspfang'), findsNothing);
      expect(find.text('Usable by both · One purchase'), findsNothing);
      await tester.pumpWidget(
        _TestApp(appState: app, service: TownService.training),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('catalogue-character-bountyHunter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('catalogue-slot-mobility')));
      await tester.pumpAndSettle();
      await _capture(tester, 'training');
      expect(find.widgetWithText(AppButton, 'Learn 150'), findsOneWidget);
      expect(app.selection.selectedCharacterId, PlayerCharacterId.eloise);
    },
  );
  for (final action in ['purchase']) {
    testWidgets(
      '$action explains unconfirmed funds without submitting a command',
      (tester) async {
        final confirmedGold = action == 'purchase' ? 100 : 40;
        final earnedGold = action == 'purchase' ? 80 : 20;
        final ownership = _ScriptedOwnershipApi(
          canonical: _canonicalWithStore(
            gold: confirmedGold,
            activeOffers: [_swordOffer()],
          ),
        );
        final app = await _bootstrappedAppState(ownershipApi: ownership);
        addTearDown(app.dispose);
        await app.journalRunReplay(
          runSessionId: 'shop_preview',
          runMode: RunMode.practice,
          replayArtifactId: 'replay',
          canonicalSha256: 'a' * 64,
          contentLengthBytes: 256,
          provisionalSummary: {'goldEarned': earnedGold, 'score': 400},
        );
        await tester.pumpWidget(_TestApp(appState: app));
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is GoldDisplay &&
                w.label == null &&
                w.gold == confirmedGold + earnedGold,
          ),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('buy-gear:mainWeapon:waspfang')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Your rewards are on their way'), findsOneWidget);
        expect(ownership.purchaseStoreOfferCalls, 0);
        expect(ownership.refreshStoreCalls, 0);

        ownership._canonical = ownership._canonical.copyWith(
          revision: 1,
          progression: ownership._canonical.progression.copyWith(
            gold: confirmedGold + earnedGold,
            appliedRewardGrantIds: ['shop_preview'],
          ),
        );
        await app.bootstrap(force: true);
        await tester.pumpAndSettle();
        expect(find.text('Your gold is ready'), findsOneWidget);
        expect(app.displayedGold, confirmedGold + earnedGold);
        expect(ownership.purchaseStoreOfferCalls, 0);
        expect(ownership.refreshStoreCalls, 0);
        await tester.tap(find.text('Back to store'));
        await tester.pumpAndSettle();
        expect(find.text('Your gold is ready'), findsNothing);
        if (action == 'purchase') {
          await tester.tap(
            find.byKey(const ValueKey('buy-gear:mainWeapon:waspfang')),
          );
        } else {
          await tester.tap(find.text('Refresh'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(AppButton, 'Refresh').last);
        }
        await tester.pumpAndSettle();
        expect(ownership.purchaseStoreOfferCalls, action == 'purchase' ? 1 : 0);
        expect(ownership.refreshStoreCalls, action == 'refresh' ? 1 : 0);
        expect(
          app.displayedGold,
          confirmedGold + earnedGold - (action == 'purchase' ? 150 : 50),
        );
      },
    );
  }

  testWidgets(
    'confirmed gold remains spendable while another run is verifying',
    (tester) async {
      final ownership = _ScriptedOwnershipApi(
        canonical: _canonicalWithStore(
          gold: 200,
          activeOffers: [_swordOffer()],
        ),
      );
      final app = await _bootstrappedAppState(ownershipApi: ownership);
      addTearDown(app.dispose);
      await app.journalRunReplay(
        runSessionId: 'later_reward',
        runMode: RunMode.practice,
        replayArtifactId: 'replay',
        canonicalSha256: 'a' * 64,
        contentLengthBytes: 256,
        provisionalSummary: {'goldEarned': 80, 'score': 1000},
      );
      await tester.pumpWidget(_TestApp(appState: app));
      await tester.tap(
        find.byKey(const ValueKey('buy-gear:mainWeapon:waspfang')),
      );
      await tester.pumpAndSettle();
      expect(ownership.purchaseStoreOfferCalls, 1);
      expect(find.text('Your rewards are on their way'), findsNothing);
      expect(app.progression.gold, 50);
      expect(app.displayedGold, 130);
    },
  );

  testWidgets('Equipment shows one selected purchase beside the item grid', (
    tester,
  ) async {
    final appState = await _bootstrappedAppState(
      ownershipApi: _ScriptedOwnershipApi(
        canonical: _canonicalWithStore(
          gold: 300,
          activeOffers: <StoreOfferState>[_swordOffer()],
        ),
      ),
    );

    await tester.pumpWidget(_TestApp(appState: appState));

    expect(find.text('Equipment store'), findsOneWidget);
    expect(find.byKey(const ValueKey('service-training')), findsNothing);
    expect(
      find.text(
        'Choose equipment for your next build. Every item is always available.',
      ),
      findsNothing,
    );
    expect(find.text('Current Gold'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(GoldDisplay),
      ),
      findsOneWidget,
    );
    expect(find.text('Refresh'), findsNothing);
    expect(find.text('Waspfang'), findsNWidgets(2));
    expect(find.widgetWithText(AppButton, 'Buy 150'), findsOneWidget);
    expect(find.textContaining('is sold out'), findsNothing);
  });

  testWidgets(
    'Town page current gold display excludes provisional reward gold',
    (tester) async {
      final ownershipApi = _ScriptedOwnershipApi(
        canonical: _canonicalWithStore(
          gold: 300,
          activeOffers: <StoreOfferState>[_swordOffer()],
        ),
      );
      final runSessionApi = _StatusOnlyRunSessionApi(
        SubmissionStatus(
          runSessionId: 'run_town_pending',
          state: RunSessionState.pendingValidation,
          updatedAtMs: 1,
          reward: SubmissionReward(
            status: SubmissionRewardStatus.provisional,
            provisionalGold: 25,
            effectiveGoldDelta: 0,
            spendableGoldDelta: 0,
            updatedAtMs: 1,
            grantId: 'run_town_pending',
          ),
        ),
      );
      final coordinator = RunSubmissionCoordinator(
        runSessionApi: runSessionApi,
        spoolStore: _InMemorySpoolStore(),
      );
      final appState = AppState(
        authApi: const _StaticAuthApi(),
        loadoutOwnershipApi: ownershipApi,
        runSessionApi: runSessionApi,
        runSubmissionCoordinator: coordinator,
      );
      await appState.bootstrap(force: true);
      await appState.refreshRunSubmissionStatus(
        runSessionId: 'run_town_pending',
      );

      await tester.pumpWidget(_TestApp(appState: appState));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is GoldDisplay &&
              widget.label == null &&
              widget.gold == 300 &&
              widget.variant == GoldDisplayVariant.headline,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Equipment shows only selected item details and centers its purchase action',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final appState = await _bootstrappedAppState(
          ownershipApi: _ScriptedOwnershipApi(
            canonical: _canonicalWithStore(
              gold: 300,
              activeOffers: <StoreOfferState>[_swordOffer()],
            ),
          ),
        );

        await tester.pumpWidget(_TestApp(appState: appState));

        expect(
          find.text('Bleed pressure sword with lower upfront power.'),
          findsOneWidget,
        );
        expect(find.text('On Hit'), findsOneWidget);
        expect(find.text('Item'), findsNothing);
        expect(find.text('Change'), findsNothing);
        expect(find.text('Show owned'), findsNothing);
        expect(find.textContaining('Compared with'), findsNothing);
        final purchase = tester.getRect(
          find.byKey(const ValueKey('buy-gear:mainWeapon:waspfang')),
        );
        final section = tester.getRect(
          find.byKey(const ValueKey('equipment-purchase-section')),
        );
        expect(purchase.center.dx, closeTo(section.center.dx, 0.1));
        final itemSemantics = tester
            .getSemantics(
              find.byKey(const ValueKey('offer-gear:mainWeapon:waspfang')),
            )
            .getSemanticsData();
        expect(itemSemantics.hasAction(ui.SemanticsAction.tap), isTrue);
        expect(itemSemantics.label, 'Waspfang');
        await tester.tap(
          find.byKey(const ValueKey('offer-gear:mainWeapon:waspfang')),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Bleed pressure sword with lower upfront power.'),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('Town purchase uses direct buy interaction', (tester) async {
    final ownershipApi = _ScriptedOwnershipApi(
      canonical: _canonicalWithStore(
        gold: 500,
        activeOffers: <StoreOfferState>[_swordOffer()],
      ),
    );
    final appState = await _bootstrappedAppState(ownershipApi: ownershipApi);

    await tester.pumpWidget(_TestApp(appState: appState));

    await tester.tap(
      find.byKey(const ValueKey('buy-gear:mainWeapon:waspfang')),
    );
    await tester.pumpAndSettle();

    expect(ownershipApi.purchaseStoreOfferCalls, 1);
    expect(find.text('Purchased Waspfang.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('offer-gear:mainWeapon:waspfang')),
      findsNothing,
    );
    expect(find.text('Owned'), findsNothing);
    expect(find.text('No entries match these filters.'), findsOneWidget);
    expect(find.byType(AppButton), findsNothing);
    expect(
      appState.selection.loadoutFor(PlayerCharacterId.eloise).mainWeaponId,
      WeaponId.plainsteel,
    );
    expect(appState.selection.selectedCharacterId, PlayerCharacterId.eloise);
  });

  testWidgets(
    'a purchased item disappears and the next available item is selected',
    (tester) async {
      final nextOffer = _swordOffer().copyWith(
        offerId: 'gear:mainWeapon:cinderedge',
        itemId: 'cinderedge',
      );
      final api = _ScriptedOwnershipApi(
        canonical: _canonicalWithStore(
          gold: 500,
          activeOffers: [_swordOffer(), nextOffer],
        ),
      );
      final app = await _bootstrappedAppState(ownershipApi: api);
      addTearDown(app.dispose);
      await tester.pumpWidget(_TestApp(appState: app));
      await tester.tap(
        find.byKey(const ValueKey('offer-gear:mainWeapon:waspfang')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('buy-gear:mainWeapon:waspfang')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('offer-gear:mainWeapon:waspfang')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('buy-gear:mainWeapon:waspfang')),
        findsNothing,
      );
      expect(
        tester
            .widget<ItemPickerTile>(
              find.byKey(const ValueKey('offer-gear:mainWeapon:cinderedge')),
            )
            .selected,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('buy-gear:mainWeapon:cinderedge')),
        findsOneWidget,
      );
      expect(api.purchaseStoreOfferCalls, 1);
      expect(
        app.selection.loadoutFor(PlayerCharacterId.eloise).mainWeaponId,
        WeaponId.plainsteel,
      );
    },
  );

  testWidgets('Town blocks purchase when player lacks offer gold cost', (
    tester,
  ) async {
    final ownershipApi = _ScriptedOwnershipApi(
      canonical: _canonicalWithStore(
        gold: 100,
        activeOffers: <StoreOfferState>[_swordOffer()],
      ),
    );
    final appState = await _bootstrappedAppState(ownershipApi: ownershipApi);

    await tester.pumpWidget(_TestApp(appState: appState));

    expect(find.widgetWithText(AppButton, 'Buy 150'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('buy-gear:mainWeapon:waspfang')),
    );
    await tester.pumpAndSettle();
    expect(ownershipApi.purchaseStoreOfferCalls, 0);
  });

  testWidgets('browsing and learning for Willow preserves the run selection', (
    tester,
  ) async {
    final api = _ScriptedOwnershipApi(
      canonical: _canonicalWithStore(
        willowUnlocked: true,
        gold: 500,
        activeOffers: [_swordOffer(), _willowAbility()],
      ),
    );
    final app = await _bootstrappedAppState(ownershipApi: api);
    addTearDown(app.dispose);
    await tester.pumpWidget(_TestApp(appState: app));
    await tester.pumpWidget(
      _TestApp(appState: app, service: TownService.training),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('catalogue-character-bountyHunter')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('service-equipment')), findsNothing);
    expect(
      find.text('Learn permanent techniques for the character you choose.'),
      findsNothing,
    );
    expect(find.text('Blink Dash'), findsNWidgets(2));
    expect(find.text('Waspfang'), findsNothing);
    await tester.ensureVisible(find.text('Learn 150'));
    await tester.tap(find.text('Learn 150'));
    await tester.pumpAndSettle();
    expect(api.lastPurchase?.characterId, PlayerCharacterId.bountyHunter);
    expect(app.selection.selectedCharacterId, PlayerCharacterId.eloise);
    expect(find.byType(AppButton), findsNothing);
    expect(find.text('Learned'), findsOneWidget);
    expect(
      tester
          .widget<ItemPickerTile>(
            find.byKey(
              const ValueKey('offer-ability:mobility:bounty_hunter.blink_dash'),
            ),
          )
          .statusLabel,
      'Learned',
    );
  });

  testWidgets('Training categories keep learned techniques inspectable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final api = _ScriptedOwnershipApi(
        canonical: _canonicalWithStore(
          gold: 500,
          activeOffers: [
            _eloiseTechnique(StoreSlot.mobility, 'eloise.dash'),
            _eloiseTechnique(StoreSlot.mobility, 'eloise.double_dash'),
            _eloiseTechnique(StoreSlot.jump, 'eloise.double_jump'),
          ],
        ),
      );
      final app = await _bootstrappedAppState(ownershipApi: api);
      addTearDown(app.dispose);
      final selection = app.selection;
      await tester.pumpWidget(
        _TestApp(appState: app, service: TownService.training),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('training-split')), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
      expect(find.text('Not yet unlocked'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('catalogue-slot-mobility')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('offer-ability:jump:eloise.double_jump')),
        findsNothing,
      );
      final dash = find.byKey(
        const ValueKey('offer-ability:mobility:eloise.dash'),
      );
      expect(tester.getSemantics(dash).getSemanticsData().value, 'Learned');
      await tester.tap(dash);
      await tester.pumpAndSettle();
      expect(find.text('Learned'), findsOneWidget);
      expect(find.byType(AppButton), findsNothing);
      expect(find.textContaining('Cooldown'), findsOneWidget);
      await _capture(tester, 'training-learned');
      final learned = find.byKey(
        const ValueKey('offer-ability:mobility:eloise.double_dash'),
      );
      await tester.tap(learned);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppButton, 'Learn 150'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('buy-ability:mobility:eloise.double_dash')),
      );
      await tester.pumpAndSettle();
      expect(dash, findsOneWidget);
      expect(tester.widget<ItemPickerTile>(learned).selected, isTrue);
      expect(tester.widget<ItemPickerTile>(learned).statusLabel, 'Learned');
      expect(find.text('Learned'), findsOneWidget);
      expect(find.byType(AppButton), findsNothing);
      expect(app.selection, same(selection));
      expect(api.purchaseStoreOfferCalls, 1);
      await tester.tap(find.byKey(const ValueKey('catalogue-slot-all')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('offer-ability:jump:eloise.double_jump')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('learning locks browsing and uses the selected server price', (
    tester,
  ) async {
    final gate = Completer<void>();
    final api = _ScriptedOwnershipApi(
      canonical: _canonicalWithStore(
        gold: 500,
        willowUnlocked: true,
        activeOffers: [
          _eloiseTechnique(
            StoreSlot.mobility,
            'eloise.double_dash',
          ).copyWith(priceGold: 225),
          _eloiseTechnique(StoreSlot.mobility, 'eloise.roll'),
        ],
      ),
    )..purchaseGate = gate;
    final app = await _bootstrappedAppState(ownershipApi: api);
    addTearDown(app.dispose);
    await tester.pumpWidget(
      _TestApp(appState: app, service: TownService.training),
    );
    await tester.pumpAndSettle();
    final buy = find.byKey(
      const ValueKey('buy-ability:mobility:eloise.double_dash'),
    );
    await tester.tap(
      find.byKey(const ValueKey('offer-ability:mobility:eloise.double_dash')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<AppButton>(buy).semanticLabel, 'Learn for 225 gold');
    await tester.tap(buy);
    await tester.pump();
    expect(api.purchaseStoreOfferCalls, 1);
    expect(tester.widget<AppButton>(buy).onPressed, isNull);
    expect(
      tester
          .widget<AppSegmentedControl<PlayerCharacterId>>(
            find.byKey(const ValueKey('catalogue-character-picker')),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<ItemPickerTile>(
            find.byKey(const ValueKey('catalogue-slot-primary')),
          )
          .onTap,
      isNull,
    );
    expect(
      tester
          .widget<ItemPickerTile>(
            find.byKey(const ValueKey('offer-ability:mobility:eloise.roll')),
          )
          .onTap,
      isNull,
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(api.lastPurchase?.characterId, PlayerCharacterId.eloise);
    expect(app.progression.gold, 275);
    expect(find.text('Learned'), findsOneWidget);
  });

  testWidgets('owned shared accessories are hidden for both characters', (
    tester,
  ) async {
    final api = _ScriptedOwnershipApi(
      canonical: _canonicalWithStore(
        willowUnlocked: true,
        gold: 500,
        activeOffers: [_sharedAccessory()],
      ),
    );
    final app = await _bootstrappedAppState(ownershipApi: api);
    addTearDown(app.dispose);
    await tester.pumpWidget(_TestApp(appState: app));
    await tester.tap(find.byKey(const ValueKey('catalogue-slot-accessory')));
    await tester.pumpAndSettle();
    expect(find.text('Show owned'), findsNothing);
    expect(find.text('Owned'), findsNothing);
    expect(
      find.byKey(const ValueKey('offer-gear:accessory:strengthBelt')),
      findsNothing,
    );
    expect(find.text('No entries match these filters.'), findsOneWidget);
    expect(find.byType(AppButton), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('catalogue-character-bountyHunter')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Owned'), findsNothing);
    expect(
      find.byKey(const ValueKey('offer-gear:accessory:strengthBelt')),
      findsNothing,
    );
    expect(find.text('No entries match these filters.'), findsOneWidget);
    expect(api.purchaseStoreOfferCalls, 0);
    expect(api.refreshStoreCalls, 0);
  });

  testWidgets(
    'equipment preserves ranged category when browsing another character',
    (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final json = jsonDecode(
        File('functions/test/fixtures/town_catalogue.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final api = _ScriptedOwnershipApi(
        canonical: _canonicalWithStore(
          willowUnlocked: true,
          gold: 500,
          activeOffers: TownStoreState.fromJson(json).catalogOffers,
        ),
      );
      final app = await _bootstrappedAppState(ownershipApi: api);
      addTearDown(app.dispose);
      await tester.pumpWidget(
        _TestApp(
          appState: app,
          equipmentArgs: const TownEquipmentArgs(
            characterId: PlayerCharacterId.bountyHunter,
            slot: StoreSlot.projectile,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ranged weapons'), findsOneWidget);
      final shotgun = find.byKey(
        const ValueKey('offer-projectileSpell:projectile:hunterRoadsidePistol'),
      );
      final grid = find.byKey(
        const ValueKey('equipment-grid-bountyHunter-projectile'),
      );
      await tester.scrollUntilVisible(
        shotgun,
        120,
        scrollable: find.descendant(
          of: grid,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(shotgun);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey('buy-projectileSpell:projectile:hunterRoadsidePistol'),
        ),
        findsOneWidget,
      );
      await _capture(tester, 'equipment-willow-ranged');
      expect(find.textContaining('Compared with'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('catalogue-character-eloise')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ranged spells'), findsOneWidget);
      expect(shotgun, findsNothing);
      expect(app.selection.selectedCharacterId, PlayerCharacterId.eloise);
      expect(api.purchaseStoreOfferCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('equipment uses the selected server price', (tester) async {
    final api = _ScriptedOwnershipApi(
      canonical: _canonicalWithStore(
        gold: 500,
        activeOffers: [_swordOffer().copyWith(priceGold: 225)],
      ),
    );
    final app = await _bootstrappedAppState(ownershipApi: api);
    addTearDown(app.dispose);
    await tester.pumpWidget(_TestApp(appState: app));
    expect(find.widgetWithText(AppButton, 'Buy 225'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('buy-gear:mainWeapon:waspfang')),
    );
    await tester.pumpAndSettle();
    expect(app.progression.gold, 275);
    expect(find.text('Owned'), findsNothing);
    expect(find.byType(AppButton), findsNothing);
  });

  testWidgets('a purchase pins its recipient and blocks repeated actions', (
    tester,
  ) async {
    final gate = Completer<void>();
    final api = _ScriptedOwnershipApi(
      canonical: _canonicalWithStore(gold: 500, activeOffers: [_swordOffer()]),
    )..purchaseGate = gate;
    final app = await _bootstrappedAppState(ownershipApi: api);
    addTearDown(app.dispose);
    await tester.pumpWidget(_TestApp(appState: app));
    await tester.tap(
      find.byKey(const ValueKey('buy-gear:mainWeapon:waspfang')),
    );
    await tester.pump();
    expect(api.purchaseStoreOfferCalls, 1);
    expect(
      tester
          .widget<AppSegmentedControl<PlayerCharacterId>>(
            find.byKey(const ValueKey('catalogue-character-picker')),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<ItemPickerTile>(
            find.byKey(const ValueKey('catalogue-slot-accessory')),
          )
          .onTap,
      isNull,
    );
    await tester.tap(
      find.byKey(const ValueKey('buy-gear:mainWeapon:waspfang')),
    );
    expect(api.purchaseStoreOfferCalls, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(api.lastPurchase?.characterId, PlayerCharacterId.eloise);
    expect(find.text('Owned'), findsNothing);
    expect(find.byType(AppButton), findsNothing);
    expect(
      app.selection.loadoutFor(PlayerCharacterId.eloise).mainWeaponId,
      WeaponId.plainsteel,
    );
  });

  testWidgets(
    'builder entry preserves browsing without showing a build comparison',
    (tester) async {
      final canonical = _canonicalWithStore(
        willowUnlocked: true,
        gold: 500,
        activeOffers: [_sharedAccessory()],
      );
      final namedBuild = canonical.selection.withBuildNameFor(
        PlayerCharacterId.bountyHunter,
        0,
        'Town comparison',
      );
      final api = _ScriptedOwnershipApi(
        canonical: canonical.copyWith(selection: namedBuild),
      );
      final app = await _bootstrappedAppState(ownershipApi: api);
      addTearDown(app.dispose);
      final before = app.selection;
      await tester.pumpWidget(
        _TestApp(
          appState: app,
          equipmentArgs: const TownEquipmentArgs(
            characterId: PlayerCharacterId.bountyHunter,
            slot: StoreSlot.accessory,
            buildIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Willow'), findsOneWidget);
      expect(find.textContaining('Town comparison'), findsNothing);
      expect(
        tester
            .widget<ItemPickerTile>(
              find.byKey(const ValueKey('catalogue-slot-accessory')),
            )
            .selected,
        isTrue,
      );
      expect(app.selection, same(before));
      expect(api.purchaseStoreOfferCalls, 0);
    },
  );

  for (final service in TownService.values) {
    testWidgets(
      '${service.name} locks Willow until Campaign makes her available',
      (tester) async {
        final api = _ScriptedOwnershipApi(
          canonical: _canonicalWithStore(
            gold: 500,
            activeOffers: [_swordOffer(), _willowEquipment(), _willowAbility()],
          ),
        );
        final app = await _bootstrappedAppState(ownershipApi: api);
        addTearDown(app.dispose);
        expect(
          app.isCharacterUnlocked(PlayerCharacterId.bountyHunter),
          isFalse,
        );
        await tester.pumpWidget(_TestApp(appState: app, service: service));
        await tester.pumpAndSettle();
        expect(find.byType(PopupMenuButton<PlayerCharacterId>), findsNothing);
        final control = tester.widget<AppSegmentedControl<PlayerCharacterId>>(
          find.byType(AppSegmentedControl<PlayerCharacterId>),
        );
        expect(
          control.isValueEnabled!(PlayerCharacterId.bountyHunter),
          isFalse,
        );
        expect(control.selected, PlayerCharacterId.eloise);
        expect(
          find.byTooltip('Complete the Val Outpost chapter to unlock Willow'),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('catalogue-character-bountyHunter')),
        );
        tester
            .widget<AppSegmentedControl<PlayerCharacterId>>(
              find.byKey(const ValueKey('catalogue-character-picker')),
            )
            .onChanged(PlayerCharacterId.bountyHunter);
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            const ValueKey(
              'offer-projectileSpell:projectile:hunterRoadsidePistol',
            ),
          ),
          findsNothing,
        );
        expect(
          find.byKey(
            const ValueKey('offer-ability:mobility:bounty_hunter.blink_dash'),
          ),
          findsNothing,
        );
        expect(api.purchaseStoreOfferCalls, 0);
        expect(app.selection.selectedCharacterId, PlayerCharacterId.eloise);
        await _capture(tester, 'locked-${service.name}');
      },
    );
  }

  testWidgets(
    'a direct Equipment entry cannot open the locked Willow catalogue',
    (tester) async {
      final api = _ScriptedOwnershipApi(
        canonical: _canonicalWithStore(
          gold: 500,
          activeOffers: [_willowEquipment()],
        ),
      );
      final app = await _bootstrappedAppState(ownershipApi: api);
      addTearDown(app.dispose);
      await tester.pumpWidget(
        _TestApp(
          appState: app,
          equipmentArgs: const TownEquipmentArgs(
            characterId: PlayerCharacterId.bountyHunter,
            slot: StoreSlot.projectile,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppSegmentedControl<PlayerCharacterId>>(
              find.byType(AppSegmentedControl<PlayerCharacterId>),
            )
            .selected,
        PlayerCharacterId.eloise,
      );
      expect(find.byType(AppButton), findsNothing);
      expect(
        find.byKey(
          const ValueKey(
            'offer-projectileSpell:projectile:hunterRoadsidePistol',
          ),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Campaign availability updates the Willow selector and gates stale purchases',
    (tester) async {
      final api = _ScriptedOwnershipApi(
        canonical: _canonicalWithStore(
          gold: 500,
          activeOffers: [_willowEquipment()],
        ),
      );
      final app = await _bootstrappedAppState(ownershipApi: api);
      addTearDown(app.dispose);
      await tester.pumpWidget(
        _TestApp(
          appState: app,
          equipmentArgs: const TownEquipmentArgs(
            characterId: PlayerCharacterId.eloise,
            slot: StoreSlot.projectile,
          ),
        ),
      );
      api._canonical = api._canonical.copyWith(
        revision: 1,
        progression: api._canonical.progression.copyWith(
          campaign: _willowUnlockedProgress(),
        ),
      );
      await app.bootstrap(force: true);
      await tester.pumpAndSettle();
      expect(app.isCharacterUnlocked(PlayerCharacterId.bountyHunter), isTrue);
      await tester.tap(
        find.byKey(const ValueKey('catalogue-character-bountyHunter')),
      );
      await tester.pumpAndSettle();
      final staleBuy = tester
          .widget<AppButton>(
            find.byKey(
              const ValueKey(
                'buy-projectileSpell:projectile:hunterRoadsidePistol',
              ),
            ),
          )
          .onPressed!;
      api._canonical = api._canonical.copyWith(
        revision: 2,
        progression: api._canonical.progression.copyWith(
          campaign: CampaignProgress.empty,
        ),
      );
      await app.bootstrap(force: true);
      await tester.pumpAndSettle();
      staleBuy();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppSegmentedControl<PlayerCharacterId>>(
              find.byType(AppSegmentedControl<PlayerCharacterId>),
            )
            .selected,
        PlayerCharacterId.eloise,
      );
      expect(
        find.byKey(
          const ValueKey('buy-projectileSpell:projectile:hunterRoadsidePistol'),
        ),
        findsNothing,
      );
      expect(api.purchaseStoreOfferCalls, 0);
    },
  );

  testWidgets('legacy catalogue guidance cannot expose a purchase action', (
    tester,
  ) async {
    final canonical = _canonicalWithStore(
      gold: 500,
      activeOffers: [_swordOffer()],
    );
    final api = _ScriptedOwnershipApi(
      canonical: canonical.copyWith(
        progression: canonical.progression.copyWith(
          store: canonical.progression.store.copyWith(schemaVersion: 1),
        ),
      ),
    );
    final app = await _bootstrappedAppState(ownershipApi: api);
    addTearDown(app.dispose);
    await tester.pumpWidget(_TestApp(appState: app));
    expect(
      find.textContaining('The catalogue is unavailable.'),
      findsOneWidget,
    );
    expect(find.byType(AppButton), findsNothing);
  });

  for (final size in [const Size(320, 640), const Size(640, 360)]) {
    testWidgets('French Training supports large text at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _ScriptedOwnershipApi(
        canonical: _canonicalWithStore(
          gold: 500,
          activeOffers: [
            _eloiseTechnique(StoreSlot.mobility, 'eloise.dash'),
            _eloiseTechnique(StoreSlot.mobility, 'eloise.double_dash'),
            _eloiseTechnique(StoreSlot.jump, 'eloise.double_jump'),
          ],
        ),
      );
      final app = await _bootstrappedAppState(ownershipApi: api);
      addTearDown(app.dispose);
      await tester.pumpWidget(
        _TestApp(
          appState: app,
          service: TownService.training,
          locale: const Locale('fr'),
          textScale: 1.8,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('training-stacked')), findsOneWidget);
      final offer = find.byKey(
        const ValueKey('offer-ability:mobility:eloise.double_dash'),
      );
      await tester.ensureVisible(offer);
      await tester.tap(offer);
      await tester.pumpAndSettle();
      final buy = find.byKey(
        const ValueKey('buy-ability:mobility:eloise.double_dash'),
      );
      await tester.ensureVisible(buy);
      await tester.pumpAndSettle();
      expect(tester.widget<AppButton>(buy).label, 'Apprendre 150');
      expect(
        tester.widget<AppButton>(buy).semanticLabel,
        'Apprendre pour 150 pièces d’or',
      );
      expect(tester.takeException(), isNull);
      await _capture(tester, 'training-fr-${size.width.toInt()}');
      await tester.tap(buy);
      await tester.pumpAndSettle();
      expect(api.purchaseStoreOfferCalls, 1);
      expect(find.text('Apprise'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('French catalogue supports large text at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _ScriptedOwnershipApi(
        canonical: _canonicalWithStore(
          gold: 500,
          activeOffers: [_swordOffer(), _willowAbility(), _sharedAccessory()],
        ),
      );
      final app = await _bootstrappedAppState(ownershipApi: api);
      addTearDown(app.dispose);
      await tester.pumpWidget(
        _TestApp(appState: app, locale: const Locale('fr'), textScale: 1.8),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(AppButton));
      await tester.pumpAndSettle();
      await _capture(tester, 'equipment-fr-${size.width.toInt()}');
      await tester.ensureVisible(
        find.byKey(const ValueKey('offer-gear:mainWeapon:waspfang')),
      );
      await tester.tap(
        find.byKey(const ValueKey('offer-gear:mainWeapon:waspfang')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

StoreOfferState _willowAbility() => const StoreOfferState(
  offerId: 'ability:mobility:bounty_hunter.blink_dash',
  bucket: StoreBucket.ability,
  domain: StoreDomain.ability,
  slot: StoreSlot.mobility,
  itemId: 'bounty_hunter.blink_dash',
  priceGold: 150,
  characterIds: [PlayerCharacterId.bountyHunter],
);

StoreOfferState _eloiseTechnique(StoreSlot slot, String id) => StoreOfferState(
  offerId: 'ability:${slot.name}:$id',
  bucket: StoreBucket.ability,
  domain: StoreDomain.ability,
  slot: slot,
  itemId: id,
  priceGold: 150,
  characterIds: const [PlayerCharacterId.eloise],
);

StoreOfferState _sharedAccessory() => const StoreOfferState(
  offerId: 'gear:accessory:strengthBelt',
  bucket: StoreBucket.accessory,
  domain: StoreDomain.gear,
  slot: StoreSlot.accessory,
  itemId: 'strengthBelt',
  priceGold: 150,
  characterIds: [PlayerCharacterId.eloise, PlayerCharacterId.bountyHunter],
);

Future<AppState> _bootstrappedAppState({
  required _ScriptedOwnershipApi ownershipApi,
}) async {
  final appState = AppState(
    authApi: const _StaticAuthApi(),
    loadoutOwnershipApi: ownershipApi,
    runSubmissionSpoolStore: _InMemorySpoolStore(),
  );
  await appState.bootstrap(force: true);
  return appState;
}

StoreOfferState _swordOffer() {
  return const StoreOfferState(
    offerId: 'gear:mainWeapon:waspfang',
    bucket: StoreBucket.sword,
    domain: StoreDomain.gear,
    slot: StoreSlot.mainWeapon,
    itemId: 'waspfang',
    priceGold: 150,
    characterIds: [PlayerCharacterId.eloise],
  );
}

CampaignProgress _willowUnlockedProgress() => CampaignProgress.fromJson({
  'schemaVersion': 1,
  'missions': {
    for (final chapter in CampaignCatalog.chapters)
      if (chapter.rewardCharacter == PlayerCharacterId.bountyHunter)
        for (final mission in chapter.missions)
          mission.id: {
            'cleared': true,
            'attempts': 1,
            'bests': <String, Object?>{},
          },
  },
});

StoreOfferState _willowEquipment() => const StoreOfferState(
  offerId: 'projectileSpell:projectile:hunterRoadsidePistol',
  bucket: StoreBucket.projectileSpell,
  domain: StoreDomain.projectileSpell,
  slot: StoreSlot.projectile,
  itemId: 'hunterRoadsidePistol',
  priceGold: 150,
  characterIds: [PlayerCharacterId.bountyHunter],
);

OwnershipCanonicalState _canonicalWithStore({
  required int gold,
  required List<StoreOfferState> activeOffers,
  bool willowUnlocked = false,
}) {
  return OwnershipCanonicalState(
    profileId: 'town_profile',
    revision: 0,
    selection: SelectionState.defaults,
    meta: const MetaService().createNew(),
    progression: ProgressionState(
      campaign: willowUnlocked
          ? _willowUnlockedProgress()
          : CampaignProgress.empty,
      gold: gold,
      store: TownStoreState(
        schemaVersion: 2,
        generation: 0,
        refreshDayKeyUtc: '2026-03-12',
        refreshesUsedToday: 0,
        activeOffers: activeOffers,
        catalogOffers: activeOffers,
      ),
    ),
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.appState,
    this.locale = const Locale('en'),
    this.textScale = 1,
    this.service = TownService.equipment,
    this.equipmentArgs,
  });
  final TownService service;
  final TownEquipmentArgs? equipmentArgs;
  final Locale locale;
  final double textScale;

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: RepaintBoundary(
        key: const ValueKey('town-preview'),
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: RunnerLocalizations.delegates,
          supportedLocales: RunnerLocalizations.supportedLocales,
          theme: createUiTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: TownStorePage(
            key: ValueKey(service),
            initialService: service,
            equipmentArgs: equipmentArgs,
          ),
        ),
      ),
    );
  }
}

class _StaticAuthApi implements AuthApi {
  const _StaticAuthApi();

  static const AuthSession _session = AuthSession(
    userId: 'u1',
    sessionId: 's1',
    isAnonymous: true,
    expiresAtMs: 0,
  );

  @override
  Future<AuthSession> ensureAuthenticatedSession() async => _session;

  @override
  Future<AuthSession> loadSession() async => _session;

  @override
  Future<AuthSession> reauthenticateForSensitiveOperation() =>
      ensureAuthenticatedSession();

  @override
  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    return AuthLinkResult(
      provider: provider,
      status: AuthLinkStatus.alreadyLinked,
      session: _session,
    );
  }

  @override
  Future<void> clearSession() async {}
}

class _ScriptedOwnershipApi extends LoadoutOwnershipApi {
  _ScriptedOwnershipApi({required OwnershipCanonicalState canonical})
    : _canonical = canonical;

  OwnershipCanonicalState _canonical;

  PurchaseStoreOfferCommand? lastPurchase;
  int purchaseStoreOfferCalls = 0;
  int refreshStoreCalls = 0;
  Completer<void>? purchaseGate;

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async {
    return _canonical;
  }

  @override
  Future<OwnershipCommandResult> setSelection(
    SetSelectionCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> setAbilitySlot(
    SetAbilitySlotCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> purchaseStoreOffer(
    PurchaseStoreOfferCommand command,
  ) async {
    lastPurchase = command;
    purchaseStoreOfferCalls += 1;
    await purchaseGate?.future;
    final offer = _canonical.progression.store.activeOffers
        .where((value) => value.offerId == command.offerId)
        .first;
    final nextOffers = _canonical.progression.store.activeOffers
        .where((value) => value.offerId != command.offerId)
        .toList(growable: false);
    var meta = _canonical.meta;
    if (offer.domain == StoreDomain.ability) {
      final recipient =
          command.characterId ?? _canonical.selection.selectedCharacterId;
      final ownership = meta.abilityOwnershipFor(recipient);
      final slot = AbilitySlot.values.byName(offer.slot.name);
      meta = meta.setAbilityOwnershipFor(
        recipient,
        ownership.copyWith(
          learnedAbilityIdsBySlot: {
            ...ownership.learnedAbilityIdsBySlot,
            slot: {...ownership.learnedAbilityIdsForSlot(slot), offer.itemId},
          },
        ),
      );
    }
    _canonical = _canonical.copyWith(
      revision: _canonical.revision + 1,
      meta:
          offer.domain == StoreDomain.gear && offer.slot == StoreSlot.mainWeapon
          ? _canonical.meta.copyWith(
              inventory: _canonical.meta.inventory.copyWith(
                unlockedWeaponIds: {
                  ..._canonical.meta.inventory.unlockedWeaponIds,
                  WeaponId.values.byName(offer.itemId),
                },
              ),
            )
          : meta,
      progression: _canonical.progression.copyWith(
        gold: _canonical.progression.gold - offer.priceGold,
        store: _canonical.progression.store.copyWith(activeOffers: nextOffers),
      ),
    );
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> refreshStore(
    RefreshStoreCommand command,
  ) async {
    refreshStoreCalls += 1;
    _canonical = _canonical.copyWith(
      revision: _canonical.revision + 1,
      progression: _canonical.progression.copyWith(
        gold: _canonical.progression.gold - 50,
        store: _canonical.progression.store.copyWith(
          generation: _canonical.progression.store.generation + 1,
          refreshesUsedToday:
              _canonical.progression.store.refreshesUsedToday + 1,
        ),
      ),
    );
    return _accepted();
  }

  OwnershipCommandResult _accepted() {
    return OwnershipCommandResult(
      canonicalState: _canonical,
      newRevision: _canonical.revision,
      replayedFromIdempotency: false,
    );
  }
}

class _StatusOnlyRunSessionApi extends NoopRunSessionApi {
  _StatusOnlyRunSessionApi(this.status);

  final SubmissionStatus status;

  @override
  Future<RunSubmissionResponse> loadSubmissionStatus({
    required String userId,
    required String sessionId,
    required String runSessionId,
  }) async {
    return RunSubmissionResponse(
      SubmissionStatus(
        runSessionId: runSessionId,
        state: status.state,
        updatedAtMs: status.updatedAtMs,
        message: status.message,
        validatedRun: status.validatedRun,
        reward: status.reward,
      ),
    );
  }
}

class _InMemorySpoolStore implements RunSubmissionSpoolStore {
  final Map<String, PendingRunSubmission> _entries =
      <String, PendingRunSubmission>{};

  @override
  Future<void> clear() async {
    _entries.clear();
  }

  @override
  Future<PendingRunSubmission?> load({required String runSessionId}) async {
    return _entries[runSessionId];
  }

  @override
  Future<List<PendingRunSubmission>> loadAll() async {
    return _entries.values.toList(growable: false);
  }

  @override
  Future<void> remove({required String runSessionId}) async {
    _entries.remove(runSessionId);
  }

  @override
  Future<void> upsert({required PendingRunSubmission submission}) async {
    _entries[submission.runSessionId] = submission;
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_TOWN_SERVICES')) return;
  final images = tester.widgetList<Image>(find.byType(Image)).toList();
  final context = tester.element(find.byType(TownStorePage));
  await tester.runAsync(() async {
    await Future.wait(
      images.map((widget) => precacheImage(widget.image, context)),
    );
  });
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('town-preview')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('.tmp/design-proposals/equipment-implementation')
        .create(recursive: true);
    await File('.tmp/design-proposals/equipment-implementation/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
