import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_runner/core/accessories/accessory_id.dart';
import 'package:rpg_runner/core/meta/meta_service.dart';
import 'package:rpg_runner/core/spellBook/spell_book_id.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';
import 'package:rpg_runner/ui/components/app_button.dart';
import 'package:rpg_runner/ui/components/gold_display.dart';
import 'package:rpg_runner/ui/pages/town/town_page.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/progression_state.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';
import 'package:rpg_runner/ui/theme/ui_button_theme.dart';
import 'package:rpg_runner/ui/theme/ui_tokens.dart';

void main() {
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

    expect(find.text('Town Store'), findsOneWidget);
    expect(find.text('Current Gold'), findsOneWidget);
    expect(find.text('Store refreshes left: 3'), findsOneWidget);
    expect(find.text('Waspfang'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
    expect(find.textContaining('is sold out'), findsNothing);
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

  testWidgets('Town disables gold refresh when player has less than 50 gold', (
    tester,
  ) async {
    final ownershipApi = _ScriptedOwnershipApi(
      canonical: _canonicalWithStore(
        gold: 40,
        activeOffers: <StoreOfferState>[_swordOffer()],
      ),
    );
    final appState = await _bootstrappedAppState(ownershipApi: ownershipApi);

    await tester.pumpWidget(_TestApp(appState: appState));

    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(ownershipApi.refreshStoreCalls, 0);
  });

  testWidgets('Town refresh for gold applies canonical response', (
    tester,
  ) async {
    final ownershipApi = _ScriptedOwnershipApi(
      canonical: _canonicalWithStore(
        gold: 500,
        activeOffers: <StoreOfferState>[_swordOffer()],
      ),
    );
    final appState = await _bootstrappedAppState(ownershipApi: ownershipApi);

    await tester.pumpWidget(_TestApp(appState: appState));

    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Refresh store?'), findsOneWidget);
    expect(find.text('Refreshing the store costs'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is GoldDisplay &&
            widget.gold == 50 &&
            widget.label == 'Cost' &&
            widget.variant == GoldDisplayVariant.body,
      ),
      findsOneWidget,
    );
    expect(
      find.text('Are you sure you want to refresh the store?'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Refresh').last);
    await tester.pumpAndSettle();

    expect(ownershipApi.refreshStoreCalls, 1);
    expect(find.text('Store refreshed.'), findsOneWidget);
  });

  testWidgets('Town refresh dialog cancel leaves store unchanged', (
    tester,
  ) async {
    final ownershipApi = _ScriptedOwnershipApi(
      canonical: _canonicalWithStore(
        gold: 500,
        activeOffers: <StoreOfferState>[_swordOffer()],
      ),
    );
    final appState = await _bootstrappedAppState(ownershipApi: ownershipApi);

    await tester.pumpWidget(_TestApp(appState: appState));

    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(ownershipApi.refreshStoreCalls, 0);
    expect(find.text('Refresh store?'), findsNothing);
  });

  testWidgets('Town disables refresh when no offer can change', (tester) async {
    final baseMeta = const MetaService().createNew();
    final allOwnedInventory = baseMeta.inventory.copyWith(
      unlockedWeaponIds: Set<WeaponId>.from(WeaponId.values),
      unlockedSpellBookIds: Set<SpellBookId>.from(SpellBookId.values),
      unlockedAccessoryIds: Set<AccessoryId>.from(AccessoryId.values),
    );
    final canonical = _canonicalWithStore(
      gold: 500,
      activeOffers: <StoreOfferState>[_swordOffer()],
    ).copyWith(meta: baseMeta.copyWith(inventory: allOwnedInventory));
    final ownershipApi = _ScriptedOwnershipApi(canonical: canonical);
    final appState = await _bootstrappedAppState(ownershipApi: ownershipApi);

    await tester.pumpWidget(_TestApp(appState: appState));

    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(ownershipApi.refreshStoreCalls, 0);
  });
}

Future<AppState> _bootstrappedAppState({
  required _ScriptedOwnershipApi ownershipApi,
}) async {
  final appState = AppState(
    authApi: const _StaticAuthApi(),
    loadoutOwnershipApi: ownershipApi,
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
        schemaVersion: 1,
        generation: 0,
        refreshDayKeyUtc: '2026-03-12',
        refreshesUsedToday: 0,
        activeOffers: activeOffers,
      ),
    ),
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: <ThemeExtension<dynamic>>[
            UiTokens.standard,
            UiButtonTheme.standard,
          ],
        ),
        home: const TownPage(),
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

class _ScriptedOwnershipApi implements LoadoutOwnershipApi {
  _ScriptedOwnershipApi({required OwnershipCanonicalState canonical})
    : _canonical = canonical;

  OwnershipCanonicalState _canonical;

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
  Future<OwnershipCommandResult> resetOwnership(
    ResetOwnershipCommand command,
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
  Future<OwnershipCommandResult> learnProjectileSpell(
    LearnProjectileSpellCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> learnSpellAbility(
    LearnSpellAbilityCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> unlockGear(UnlockGearCommand command) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> awardRunGold(
    AwardRunGoldCommand command,
  ) async {
    return _accepted();
  }

  @override
  Future<OwnershipCommandResult> purchaseStoreOffer(
    PurchaseStoreOfferCommand command,
  ) async {
    purchaseStoreOfferCalls += 1;
    final offer = _canonical.progression.store.activeOffers
        .where((value) => value.offerId == command.offerId)
        .first;
    final nextOffers = _canonical.progression.store.activeOffers
        .where((value) => value.offerId != command.offerId)
        .toList(growable: false);
    _canonical = _canonical.copyWith(
      revision: _canonical.revision + 1,
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
