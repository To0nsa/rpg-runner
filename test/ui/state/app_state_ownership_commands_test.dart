import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/auth_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/ownership_sync_policy.dart';
import 'package:rpg_runner/ui/state/progression_state.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';

void main() {
  test(
    'AppState routes slot and projectile selection through dedicated commands',
    () async {
      final api = _RecordingOwnershipApi();
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: api,
      );

      await appState.bootstrap(force: true);
      final characterId = appState.selection.selectedCharacterId;
      final abilityId = appState.selection
          .loadoutFor(characterId)
          .abilitySpellId;

      await appState.setAbilitySlot(
        characterId: characterId,
        slot: AbilitySlot.spell,
        abilityId: abilityId,
      );
      await appState.setProjectileSpell(
        characterId: characterId,
        spellId: ProjectileId.holyBolt,
      );
      await appState.flushOwnershipEdits(
        trigger: OwnershipFlushTrigger.manual,
      );

      expect(api.setAbilitySlotCalls, 1);
      expect(api.setProjectileSpellCalls, 1);
      expect(api.setLoadoutCalls, 0);
    },
  );

  test(
    'AppState routes learn and unlock mutations through dedicated commands',
    () async {
      final api = _RecordingOwnershipApi();
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: api,
      );

      await appState.bootstrap(force: true);
      final characterId = appState.selection.selectedCharacterId;

      await appState.learnProjectileSpell(
        characterId: characterId,
        spellId: ProjectileId.acidBolt,
      );
      await appState.learnSpellAbility(
        characterId: characterId,
        abilityId: appState.selection.loadoutFor(characterId).abilitySpellId,
      );
      await appState.unlockGear(
        slot: GearSlot.accessory,
        itemId: AccessoryId.strengthBelt,
      );

      expect(api.learnProjectileSpellCalls, 1);
      expect(api.learnSpellAbilityCalls, 1);
      expect(api.unlockGearCalls, 1);
    },
  );

  test(
    'AppState routes store purchase and refresh through dedicated commands',
    () async {
      final api = _RecordingOwnershipApi();
      final appState = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: api,
      );

      await appState.bootstrap(force: true);
      await appState.purchaseStoreOffer(offerId: 'gear:mainWeapon:waspfang');
      await appState.refreshStore(method: StoreRefreshMethod.gold);

      expect(api.purchaseStoreOfferCalls, 1);
      expect(api.refreshStoreCalls, 1);
    },
  );
}

class _RecordingOwnershipApi implements LoadoutOwnershipApi {
  int _revision = 0;
  final MetaService _metaService = const MetaService();

  int setLoadoutCalls = 0;
  int setAbilitySlotCalls = 0;
  int setProjectileSpellCalls = 0;
  int learnProjectileSpellCalls = 0;
  int learnSpellAbilityCalls = 0;
  int unlockGearCalls = 0;
  int purchaseStoreOfferCalls = 0;
  int refreshStoreCalls = 0;

  OwnershipCanonicalState _canonical() {
    return OwnershipCanonicalState(
      profileId: 'test_profile',
      revision: _revision,
      selection: SelectionState.defaults,
      meta: _metaService.createNew(),
      progression: ProgressionState.initial,
    );
  }

  OwnershipCommandResult _acceptedResult() {
    _revision += 1;
    final canonical = _canonical();
    return OwnershipCommandResult(
      canonicalState: canonical,
      newRevision: canonical.revision,
      replayedFromIdempotency: false,
    );
  }

  @override
  Future<OwnershipCanonicalState> loadCanonicalState({
    required String userId,
    required String sessionId,
  }) async {
    return _canonical();
  }

  @override
  Future<OwnershipCommandResult> setSelection(
    SetSelectionCommand command,
  ) async {
    return _acceptedResult();
  }

  @override
  Future<OwnershipCommandResult> resetOwnership(
    ResetOwnershipCommand command,
  ) async {
    return _acceptedResult();
  }

  @override
  Future<OwnershipCommandResult> equipGear(EquipGearCommand command) async {
    return _acceptedResult();
  }

  @override
  Future<OwnershipCommandResult> setLoadout(SetLoadoutCommand command) async {
    setLoadoutCalls += 1;
    return _acceptedResult();
  }

  @override
  Future<OwnershipCommandResult> setAbilitySlot(
    SetAbilitySlotCommand command,
  ) async {
    setAbilitySlotCalls += 1;
    return _acceptedResult();
  }

  @override
  Future<OwnershipCommandResult> setProjectileSpell(
    SetProjectileSpellCommand command,
  ) async {
    setProjectileSpellCalls += 1;
    return _acceptedResult();
  }

  @override
  Future<OwnershipCommandResult> learnProjectileSpell(
    LearnProjectileSpellCommand command,
  ) async {
    learnProjectileSpellCalls += 1;
    return _acceptedResult();
  }

  @override
  Future<OwnershipCommandResult> learnSpellAbility(
    LearnSpellAbilityCommand command,
  ) async {
    learnSpellAbilityCalls += 1;
    return _acceptedResult();
  }

  @override
  Future<OwnershipCommandResult> unlockGear(UnlockGearCommand command) async {
    unlockGearCalls += 1;
    return _acceptedResult();
  }

  @override
  Future<OwnershipCommandResult> awardRunGold(
    AwardRunGoldCommand command,
  ) async {
    return _acceptedResult();
  }

  @override
  Future<OwnershipCommandResult> purchaseStoreOffer(
    PurchaseStoreOfferCommand command,
  ) async {
    purchaseStoreOfferCalls += 1;
    return _acceptedResult();
  }

  @override
  Future<OwnershipCommandResult> refreshStore(
    RefreshStoreCommand command,
  ) async {
    refreshStoreCalls += 1;
    return _acceptedResult();
  }
}

class _StaticAuthApi implements AuthApi {
  _StaticAuthApi._(this._session);

  factory _StaticAuthApi.authenticated() {
    return _StaticAuthApi._(
      const AuthSession(
        userId: 'u1',
        sessionId: 's1',
        isAnonymous: true,
        expiresAtMs: 0,
      ),
    );
  }

  final AuthSession _session;

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
