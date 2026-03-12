import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/meta/meta_state.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import '../app/ui_routes.dart';
import 'account_deletion_api.dart';
import 'auth_api.dart';
import 'loadout_ownership_api.dart';
import 'progression_state.dart';
import 'selection_state.dart';
import 'user_profile.dart';
import 'user_profile_remote_api.dart';

class AppState extends ChangeNotifier {
  factory AppState({
    required AuthApi authApi,
    UserProfileRemoteApi? userProfileRemoteApi,
    AccountDeletionApi? accountDeletionApi,
    required LoadoutOwnershipApi loadoutOwnershipApi,
  }) {
    return AppState._internal(
      authApi: authApi,
      userProfileRemoteApi: userProfileRemoteApi,
      accountDeletionApi: accountDeletionApi,
      loadoutOwnershipApi: loadoutOwnershipApi,
    );
  }

  AppState._internal({
    required AuthApi authApi,
    UserProfileRemoteApi? userProfileRemoteApi,
    AccountDeletionApi? accountDeletionApi,
    required LoadoutOwnershipApi loadoutOwnershipApi,
  }) : _authApi = authApi,
       _profileRemoteApi =
           userProfileRemoteApi ?? const NoopUserProfileRemoteApi(),
       _accountDeletionApi =
           accountDeletionApi ?? const NoopAccountDeletionApi(),
       _ownershipApi = loadoutOwnershipApi;

  final Random _random = Random();
  final AuthApi _authApi;
  final UserProfileRemoteApi _profileRemoteApi;
  final AccountDeletionApi _accountDeletionApi;
  final LoadoutOwnershipApi _ownershipApi;

  SelectionState _selection = SelectionState.defaults;
  MetaState _meta = const MetaService().createNew();
  ProgressionState _progression = ProgressionState.initial;
  UserProfile _profile = UserProfile.empty;
  AuthSession _authSession = AuthSession.unauthenticated;
  String _profileId = defaultOwnershipProfileId;
  int _ownershipRevision = 0;
  bool _bootstrapped = false;
  bool _warmupStarted = false;

  SelectionState get selection => _selection;
  MetaState get meta => _meta;
  ProgressionState get progression => _progression;
  UserProfile get profile => _profile;
  AuthSession get authSession => _authSession;
  String get profileId => _profileId;
  bool get isBootstrapped => _bootstrapped;
  int get ownershipRevision => _ownershipRevision;

  Future<void> bootstrap({bool force = false}) async {
    if (_bootstrapped && !force) return;
    final session = await _ensureAuthSession();
    final loadedProfile = await _profileRemoteApi.loadProfile(
      userId: session.userId,
      sessionId: session.sessionId,
    );
    final canonical = await _ownershipApi.loadCanonicalState(
      userId: session.userId,
      sessionId: session.sessionId,
    );
    _profile = loadedProfile;
    _applyCanonicalState(canonical);
    _bootstrapped = true;
    notifyListeners();
  }

  Future<void> applyDefaults() async {
    final session = await _ensureAuthSession();
    try {
      _profile = await _profileRemoteApi.loadProfile(
        userId: session.userId,
        sessionId: session.sessionId,
      );
    } catch (error) {
      debugPrint('Profile fallback load failed: $error');
      _profile = UserProfile.empty;
    }

    OwnershipCanonicalState canonical;
    try {
      canonical = await _ownershipApi.loadCanonicalState(
        userId: session.userId,
        sessionId: session.sessionId,
      );
    } catch (error) {
      debugPrint('Ownership fallback load failed: $error');
      canonical = OwnershipCanonicalState(
        profileId: defaultOwnershipProfileId,
        revision: 0,
        selection: SelectionState.defaults,
        meta: const MetaService().createNew(),
        progression: ProgressionState.initial,
      );
    }
    _applyCanonicalState(canonical);

    try {
      final resetResult = await _ownershipApi.resetOwnership(
        ResetOwnershipCommand(
          userId: session.userId,
          sessionId: session.sessionId,
          expectedRevision: _ownershipRevision,
          commandId: _newCommandId(),
        ),
      );
      _applyOwnershipResult(resetResult);
    } catch (error) {
      debugPrint('Ownership fallback reset failed: $error');
    }
    _bootstrapped = true;
    notifyListeners();
  }

  Future<void> setLevel(LevelId levelId) async {
    final nextSelection = _selection.copyWith(selectedLevelId: levelId);
    await _setSelection(nextSelection);
  }

  Future<void> setRunType(RunType runType) async {
    final nextSelection = _selection.copyWith(selectedRunType: runType);
    await _setSelection(nextSelection);
  }

  Future<void> setCharacter(PlayerCharacterId id) async {
    final nextSelection = _selection.copyWith(selectedCharacterId: id);
    await _setSelection(nextSelection);
  }

  Future<void> setLoadout(EquippedLoadoutDef loadout) async {
    final session = await _ensureAuthSession();
    final result = await _ownershipApi.setLoadout(
      SetLoadoutCommand(
        userId: session.userId,
        sessionId: session.sessionId,
        expectedRevision: _ownershipRevision,
        commandId: _newCommandId(),
        characterId: _selection.selectedCharacterId,
        loadout: loadout,
      ),
    );
    _applyOwnershipResult(result);
    notifyListeners();
  }

  Future<void> setAbilitySlot({
    required PlayerCharacterId characterId,
    required AbilitySlot slot,
    required AbilityKey abilityId,
  }) async {
    final session = await _ensureAuthSession();
    final result = await _ownershipApi.setAbilitySlot(
      SetAbilitySlotCommand(
        userId: session.userId,
        sessionId: session.sessionId,
        expectedRevision: _ownershipRevision,
        commandId: _newCommandId(),
        characterId: characterId,
        slot: slot,
        abilityId: abilityId,
      ),
    );
    _applyOwnershipResult(result);
    notifyListeners();
  }

  Future<void> setProjectileSpell({
    required PlayerCharacterId characterId,
    required ProjectileId spellId,
  }) async {
    final session = await _ensureAuthSession();
    final result = await _ownershipApi.setProjectileSpell(
      SetProjectileSpellCommand(
        userId: session.userId,
        sessionId: session.sessionId,
        expectedRevision: _ownershipRevision,
        commandId: _newCommandId(),
        characterId: characterId,
        spellId: spellId,
      ),
    );
    _applyOwnershipResult(result);
    notifyListeners();
  }

  Future<void> learnProjectileSpell({
    required PlayerCharacterId characterId,
    required ProjectileId spellId,
  }) async {
    final session = await _ensureAuthSession();
    final result = await _ownershipApi.learnProjectileSpell(
      LearnProjectileSpellCommand(
        userId: session.userId,
        sessionId: session.sessionId,
        expectedRevision: _ownershipRevision,
        commandId: _newCommandId(),
        characterId: characterId,
        spellId: spellId,
      ),
    );
    _applyOwnershipResult(result);
    notifyListeners();
  }

  Future<void> learnSpellAbility({
    required PlayerCharacterId characterId,
    required AbilityKey abilityId,
  }) async {
    final session = await _ensureAuthSession();
    final result = await _ownershipApi.learnSpellAbility(
      LearnSpellAbilityCommand(
        userId: session.userId,
        sessionId: session.sessionId,
        expectedRevision: _ownershipRevision,
        commandId: _newCommandId(),
        characterId: characterId,
        abilityId: abilityId,
      ),
    );
    _applyOwnershipResult(result);
    notifyListeners();
  }

  Future<void> unlockGear({
    required GearSlot slot,
    required Object itemId,
  }) async {
    final session = await _ensureAuthSession();
    final result = await _ownershipApi.unlockGear(
      UnlockGearCommand(
        userId: session.userId,
        sessionId: session.sessionId,
        expectedRevision: _ownershipRevision,
        commandId: _newCommandId(),
        slot: slot,
        itemId: itemId,
      ),
    );
    _applyOwnershipResult(result);
    notifyListeners();
  }

  Future<void> equipGear({
    required PlayerCharacterId characterId,
    required GearSlot slot,
    required Object itemId,
  }) async {
    final session = await _ensureAuthSession();
    final result = await _ownershipApi.equipGear(
      EquipGearCommand(
        userId: session.userId,
        sessionId: session.sessionId,
        expectedRevision: _ownershipRevision,
        commandId: _newCommandId(),
        characterId: characterId,
        slot: slot,
        itemId: itemId,
      ),
    );
    _applyOwnershipResult(result);
    notifyListeners();
  }

  Future<void> setBuildName(String buildName) async {
    final normalized = SelectionState.normalizeBuildName(buildName);
    if (normalized == _selection.buildName) return;
    final nextSelection = _selection.copyWith(buildName: normalized);
    await _setSelection(nextSelection);
  }

  Future<void> updateDisplayName(String displayName) async {
    final session = await _ensureAuthSession();
    final trimmed = displayName.trim();
    if (trimmed == _profile.displayName) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final shouldSetCooldown = _profile.displayName.isNotEmpty;
    final nextProfile = await _profileRemoteApi.updateProfile(
      userId: session.userId,
      sessionId: session.sessionId,
      update: UserProfileUpdate(
        displayName: trimmed,
        displayNameLastChangedAtMs: shouldSetCooldown
            ? nowMs
            : _profile.displayNameLastChangedAtMs,
      ),
    );
    _profile = nextProfile;
    notifyListeners();
  }

  Future<void> completeNamePrompt({String? displayName}) async {
    final session = await _ensureAuthSession();
    final trimmed = displayName?.trim();
    final shouldUpdateDisplayName = trimmed != null && trimmed.isNotEmpty;
    final shouldSetCooldown =
        shouldUpdateDisplayName && _profile.displayName.isNotEmpty;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final nextProfile = await _profileRemoteApi.updateProfile(
      userId: session.userId,
      sessionId: session.sessionId,
      update: UserProfileUpdate(
        displayName: shouldUpdateDisplayName ? trimmed : null,
        displayNameLastChangedAtMs: shouldUpdateDisplayName
            ? (shouldSetCooldown ? nowMs : _profile.displayNameLastChangedAtMs)
            : null,
        namePromptCompleted: true,
      ),
    );
    _profile = nextProfile;
    notifyListeners();
  }

  Future<void> awardRunGold({
    required int runId,
    required int goldEarned,
  }) async {
    if (goldEarned <= 0) {
      return;
    }
    final session = await _ensureAuthSession();
    var result = await _ownershipApi.awardRunGold(
      _newAwardRunGoldCommand(
        session: session,
        runId: runId,
        goldEarned: goldEarned,
      ),
    );
    if (result.rejectedReason == OwnershipRejectedReason.staleRevision) {
      final canonical = await _ownershipApi.loadCanonicalState(
        userId: session.userId,
        sessionId: session.sessionId,
      );
      _applyCanonicalState(canonical);
      result = await _ownershipApi.awardRunGold(
        _newAwardRunGoldCommand(
          session: session,
          runId: runId,
          goldEarned: goldEarned,
        ),
      );
    }
    _applyOwnershipResult(result);
    notifyListeners();
  }

  Future<OwnershipCommandResult> purchaseStoreOffer({
    required String offerId,
  }) async {
    final session = await _ensureAuthSession();
    var result = await _ownershipApi.purchaseStoreOffer(
      PurchaseStoreOfferCommand(
        userId: session.userId,
        sessionId: session.sessionId,
        expectedRevision: _ownershipRevision,
        commandId: 'purchase_store_offer_${_newCommandId()}',
        offerId: offerId,
      ),
    );
    if (result.rejectedReason == OwnershipRejectedReason.staleRevision) {
      final canonical = await _ownershipApi.loadCanonicalState(
        userId: session.userId,
        sessionId: session.sessionId,
      );
      _applyCanonicalState(canonical);
      result = await _ownershipApi.purchaseStoreOffer(
        PurchaseStoreOfferCommand(
          userId: session.userId,
          sessionId: session.sessionId,
          expectedRevision: _ownershipRevision,
          commandId: 'purchase_store_offer_${_newCommandId()}',
          offerId: offerId,
        ),
      );
    }
    _applyOwnershipResult(result);
    notifyListeners();
    return result;
  }

  Future<OwnershipCommandResult> refreshStore({
    required StoreRefreshMethod method,
    String? refreshGrantId,
  }) async {
    final session = await _ensureAuthSession();
    var result = await _ownershipApi.refreshStore(
      RefreshStoreCommand(
        userId: session.userId,
        sessionId: session.sessionId,
        expectedRevision: _ownershipRevision,
        commandId: 'refresh_store_${method.name}_${_newCommandId()}',
        method: method,
        refreshGrantId: refreshGrantId,
      ),
    );
    if (result.rejectedReason == OwnershipRejectedReason.staleRevision) {
      final canonical = await _ownershipApi.loadCanonicalState(
        userId: session.userId,
        sessionId: session.sessionId,
      );
      _applyCanonicalState(canonical);
      result = await _ownershipApi.refreshStore(
        RefreshStoreCommand(
          userId: session.userId,
          sessionId: session.sessionId,
          expectedRevision: _ownershipRevision,
          commandId: 'refresh_store_${method.name}_${_newCommandId()}',
          method: method,
          refreshGrantId: refreshGrantId,
        ),
      );
    }
    _applyOwnershipResult(result);
    notifyListeners();
    return result;
  }

  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    final result = await _authApi.linkAuthProvider(provider);
    _authSession = result.session;
    notifyListeners();
    return result;
  }

  Future<AccountDeletionResult> deleteAccountAndData() async {
    final session = await _ensureAuthSession();
    final result = await _accountDeletionApi.deleteAccountAndData(
      userId: session.userId,
      sessionId: session.sessionId,
    );
    if (!result.succeeded) {
      return result;
    }

    await _authApi.clearSession();
    _selection = SelectionState.defaults;
    _meta = const MetaService().createNew();
    _progression = ProgressionState.initial;
    _profile = UserProfile.empty;
    _authSession = AuthSession.unauthenticated;
    _profileId = defaultOwnershipProfileId;
    _ownershipRevision = 0;
    _bootstrapped = false;
    _warmupStarted = false;
    notifyListeners();
    return result;
  }

  void startWarmup() {
    if (_warmupStarted) return;
    _warmupStarted = true;
  }

  RunStartArgs buildRunStartArgs({int? seed}) {
    final characterId = _selection.selectedCharacterId;
    return RunStartArgs(
      runId: createRunId(),
      seed: seed ?? _random.nextInt(1 << 31),
      levelId: _selection.selectedLevelId,
      playerCharacterId: characterId,
      runType: _selection.selectedRunType,
      equippedLoadout: _selection.loadoutFor(characterId),
    );
  }

  int createRunId() => _createRunId();

  int _createRunId() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final salt = _random.nextInt(1 << 20);
    return (nowMs << 20) | salt;
  }

  Future<void> _setSelection(SelectionState nextSelection) async {
    final session = await _ensureAuthSession();
    final result = await _ownershipApi.setSelection(
      SetSelectionCommand(
        userId: session.userId,
        sessionId: session.sessionId,
        expectedRevision: _ownershipRevision,
        commandId: _newCommandId(),
        selection: nextSelection,
      ),
    );
    _applyOwnershipResult(result);
    notifyListeners();
  }

  void _applyOwnershipResult(OwnershipCommandResult result) {
    _applyCanonicalState(result.canonicalState);
  }

  void _applyCanonicalState(OwnershipCanonicalState canonical) {
    _profileId = canonical.profileId;
    _selection = canonical.selection;
    _meta = canonical.meta;
    _progression = canonical.progression;
    _ownershipRevision = canonical.revision;
  }

  Future<AuthSession> _ensureAuthSession() async {
    final session = await _authApi.ensureAuthenticatedSession();
    _authSession = session;
    return session;
  }

  AwardRunGoldCommand _newAwardRunGoldCommand({
    required AuthSession session,
    required int runId,
    required int goldEarned,
  }) {
    return AwardRunGoldCommand(
      userId: session.userId,
      sessionId: session.sessionId,
      expectedRevision: _ownershipRevision,
      commandId: 'award_run_gold_${runId}_${_newCommandId()}',
      runId: runId,
      goldEarned: goldEarned,
    );
  }

  String _newCommandId() {
    final nowMs = DateTime.now().microsecondsSinceEpoch;
    final salt = _random.nextInt(1 << 31);
    return 'cmd_${nowMs.toRadixString(36)}_${salt.toRadixString(36)}';
  }
}
