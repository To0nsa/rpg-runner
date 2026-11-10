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
import 'package:runner_core/weapons/weapon_id.dart';
import 'package:run_protocol/submission_status.dart';
import 'package:rpg_runner/ui/components/app_button.dart';
import 'package:rpg_runner/ui/components/gold_display.dart';
import 'package:rpg_runner/ui/pages/town/town_store_page.dart';
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
    'full catalogue supports category browsing and service switching',
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
      tester.view.physicalSize = const Size(1000, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final json = jsonDecode(
        File('functions/test/fixtures/town_catalogue.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final api = _ScriptedOwnershipApi(
        canonical: _canonicalWithStore(
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
      expect(find.text('Usable by both · One purchase'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('service-training')));
      await tester.tap(
        find.byKey(const ValueKey('catalogue-character-bountyHunter')),
      );
      await tester.pumpAndSettle();
      await _capture(tester, 'training');
      expect(find.text('Learn'), findsWidgets);
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
        await tester.tap(find.text(action == 'purchase' ? 'Buy' : 'Refresh'));
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
          await tester.tap(find.text('Buy'));
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
      await tester.tap(find.text('Buy'));
      await tester.pumpAndSettle();
      expect(ownership.purchaseStoreOfferCalls, 1);
      expect(find.text('Your rewards are on their way'), findsNothing);
      expect(app.progression.gold, 50);
      expect(app.displayedGold, 130);
    },
  );

  testWidgets('Town page renders active offers in a single list', (
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

    expect(find.text('Equipment'), findsNWidgets(2));
    expect(find.text('Current Gold'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(GoldDisplay),
      ),
      findsOneWidget,
    );
    expect(find.text('Refresh'), findsNothing);
    expect(find.text('Waspfang'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
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

  testWidgets('Town store offer expands to show item details', (tester) async {
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
      findsNothing,
    );

    await tester.tap(find.text('Waspfang'));
    await tester.pumpAndSettle();

    expect(
      find.text('Bleed pressure sword with lower upfront power.'),
      findsOneWidget,
    );
    expect(find.text('On Hit'), findsWidgets);
    expect(find.textContaining('Compared with Plainsteel'), findsOneWidget);

    await tester.tap(find.text('Waspfang'));
    await tester.pumpAndSettle();

    expect(
      find.text('Bleed pressure sword with lower upfront power.'),
      findsNothing,
    );
  });

  testWidgets('Town purchase uses direct buy interaction', (tester) async {
    final ownershipApi = _ScriptedOwnershipApi(
      canonical: _canonicalWithStore(
        gold: 500,
        activeOffers: <StoreOfferState>[_swordOffer()],
      ),
    );
    final appState = await _bootstrappedAppState(ownershipApi: ownershipApi);

    await tester.pumpWidget(_TestApp(appState: appState));

    await tester.tap(find.text('Buy'));
    await tester.pumpAndSettle();

    expect(ownershipApi.purchaseStoreOfferCalls, 1);
    expect(find.text('Purchased Waspfang.'), findsOneWidget);
  });

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

    expect(find.text('150'), findsOneWidget);
    await tester.tap(find.text('Buy'));
    await tester.pumpAndSettle();
    expect(ownershipApi.purchaseStoreOfferCalls, 0);
  });

  testWidgets('browsing and learning for Willow preserves the run selection', (
    tester,
  ) async {
    final api = _ScriptedOwnershipApi(
      canonical: _canonicalWithStore(
        gold: 500,
        activeOffers: [_swordOffer(), _willowAbility()],
      ),
    );
    final app = await _bootstrappedAppState(ownershipApi: api);
    addTearDown(app.dispose);
    await tester.pumpWidget(_TestApp(appState: app));
    await tester.tap(find.byKey(const ValueKey('service-training')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('catalogue-character-bountyHunter')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Blink Dash'), findsOneWidget);
    expect(find.text('Waspfang'), findsNothing);
    await tester.ensureVisible(find.text('Learn'));
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(api.lastPurchase?.characterId, PlayerCharacterId.bountyHunter);
    expect(app.selection.selectedCharacterId, PlayerCharacterId.eloise);
  });

  testWidgets(
    'owned shared accessories stay inspectable without another purchase',
    (tester) async {
      final api = _ScriptedOwnershipApi(
        canonical: _canonicalWithStore(
          gold: 500,
          activeOffers: [_sharedAccessory()],
        ),
      );
      final app = await _bootstrappedAppState(ownershipApi: api);
      addTearDown(app.dispose);
      await tester.pumpWidget(_TestApp(appState: app));
      expect(find.text('Owned'), findsOneWidget);
      expect(find.text('Usable by both · One purchase'), findsOneWidget);
      expect(find.text('Buy'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('catalogue-character-bountyHunter')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Owned'), findsOneWidget);
      await tester.tap(find.text('Not yet unlocked'));
      await tester.pumpAndSettle();
      expect(find.text('No entries match these filters.'), findsOneWidget);
      expect(api.purchaseStoreOfferCalls, 0);
      expect(api.refreshStoreCalls, 0);
    },
  );

  for (final size in [const Size(360, 640), const Size(640, 360)]) {
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
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('offer-gear:mainWeapon:waspfang')),
        200,
      );
      await tester.tap(find.text('Croc de guêpe'));
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

OwnershipCanonicalState _canonicalWithStore({
  required int gold,
  required List<StoreOfferState> activeOffers,
}) {
  return OwnershipCanonicalState(
    profileId: 'town_profile',
    revision: 0,
    selection: SelectionState.defaults,
    meta: const MetaService().createNew(),
    progression: ProgressionState(
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
  });
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
          home: const TownStorePage(),
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
    final offer = _canonical.progression.store.activeOffers
        .where((value) => value.offerId == command.offerId)
        .first;
    final nextOffers = _canonical.progression.store.activeOffers
        .where((value) => value.offerId != command.offerId)
        .toList(growable: false);
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
          : _canonical.meta,
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
    await Directory('.tmp/town-services/previews').create(recursive: true);
    await File('.tmp/town-services/previews/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
