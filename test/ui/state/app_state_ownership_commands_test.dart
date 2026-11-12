import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:rpg_runner/ui/state/app/app_state.dart';
import 'package:rpg_runner/ui/campaign/campaign_catalog.dart';
import 'package:rpg_runner/ui/state/auth/auth_api.dart';
import 'package:rpg_runner/ui/state/ownership/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/ownership/ownership_sync_policy.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';
import 'package:rpg_runner/ui/state/ownership/campaign_progress.dart';
import 'package:rpg_runner/ui/state/ownership/selection_state.dart';

void main() {
  test(
    'purchase target stays pinned when stale revision reload changes selection',
    () async {
      final api = _RecordingOwnershipApi()..rejectFirstPurchase = true;
      final app = AppState(
        authApi: _StaticAuthApi.authenticated(),
        loadoutOwnershipApi: api,
      );
      addTearDown(app.dispose);
      await app.bootstrap(force: true);
      await app.purchaseStoreOffer(offerId: 'gear:mainWeapon:waspfang');
      expect(api.purchaseTargets, [
        PlayerCharacterId.eloise,
        PlayerCharacterId.eloise,
      ]);
      expect(app.selection.selectedCharacterId, PlayerCharacterId.bountyHunter);
    },
  );
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
      await appState.flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual);

      expect(api.setAbilitySlotCalls, 1);
      expect(api.setProjectileSpellCalls, 1);
      expect(api.setLoadoutCalls, 0);
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

class _RecordingOwnershipApi extends LoadoutOwnershipApi {
  int _revision = 0;
  final MetaService _metaService = const MetaService();

  int setLoadoutCalls = 0;
  int setAbilitySlotCalls = 0;
  int setProjectileSpellCalls = 0;
  bool rejectFirstPurchase = false;
  final purchaseTargets = <PlayerCharacterId?>[];
  int purchaseStoreOfferCalls = 0;
  int refreshStoreCalls = 0;

  OwnershipCanonicalState _canonical() {
    return OwnershipCanonicalState(
      profileId: 'test_profile',
      revision: _revision,
      selection: SelectionState.defaults.copyWith(
        selectedCharacterId: rejectFirstPurchase && purchaseStoreOfferCalls > 0
            ? PlayerCharacterId.bountyHunter
            : PlayerCharacterId.eloise,
      ),
      meta: _metaService.createNew(),
      progression: rejectFirstPurchase
          ? ProgressionState.initial.copyWith(
              campaign: CampaignProgress.fromJson({
                'schemaVersion': 1,
                'missions': {
                  for (final mission in CampaignCatalog.chapters.first.missions)
                    mission.id: {'cleared': true, 'attempts': 1, 'bests': {}},
                },
              }),
            )
          : ProgressionState.initial,
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
  Future<OwnershipCommandResult> purchaseStoreOffer(
    PurchaseStoreOfferCommand command,
  ) async {
    purchaseTargets.add(command.characterId);
    purchaseStoreOfferCalls += 1;
    if (rejectFirstPurchase && purchaseStoreOfferCalls == 1) {
      return OwnershipCommandResult(
        canonicalState: _canonical(),
        newRevision: _revision,
        replayedFromIdempotency: false,
        rejectedReason: OwnershipRejectedReason.staleRevision,
      );
    }
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
