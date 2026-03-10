import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/abilities/ability_def.dart';
import '../../core/ecs/stores/combat/equipped_loadout_store.dart';
import '../../core/levels/level_id.dart';
import '../../core/meta/gear_slot.dart';
import '../../core/meta/meta_service.dart';
import '../../core/meta/meta_state.dart';
import '../../core/players/player_character_definition.dart';
import '../../core/projectiles/projectile_id.dart';
import '../app/ui_routes.dart';
import 'auth_api.dart';
import 'local_auth_api.dart';
import 'loadout_ownership_api.dart';
import 'local_loadout_ownership_api.dart';
import 'meta_store.dart';
import 'selection_state.dart';
import 'selection_store.dart';
import 'user_profile.dart';
import 'user_profile_store.dart';

class AppState extends ChangeNotifier {
  factory AppState({
    SelectionStore? selectionStore,
    MetaStore? metaStore,
    UserProfileStore? userProfileStore,
    MetaService? metaService,
    AuthApi? authApi,
    LoadoutOwnershipApi? loadoutOwnershipApi,
  }) {
    final resolvedAuthApi = authApi ?? LocalAuthApi();
    final resolvedOwnershipApi =
        loadoutOwnershipApi ??
        LocalLoadoutOwnershipApi(
          selectionStore: selectionStore ?? SelectionStore(),
          metaStore: metaStore ?? MetaStore(),
          metaService: metaService ?? const MetaService(),
          authApi: resolvedAuthApi,
        );
    return AppState._internal(
      userProfileStore: userProfileStore,
      authApi: resolvedAuthApi,
      loadoutOwnershipApi: resolvedOwnershipApi,
    );
  }

  AppState._internal({
    UserProfileStore? userProfileStore,
    required AuthApi authApi,
    required LoadoutOwnershipApi loadoutOwnershipApi,
  }) : _profileStore = userProfileStore ?? UserProfileStore(),
       _authApi = authApi,
       _ownershipApi = loadoutOwnershipApi;

  final Random _random = Random();
  final AuthApi _authApi;
  final LoadoutOwnershipApi _ownershipApi;
  final UserProfileStore _profileStore;

  SelectionState _selection = SelectionState.defaults;
  MetaState _meta = const MetaService().createNew();
  UserProfile _profile = UserProfile.empty();
  AuthSession _authSession = AuthSession.unauthenticated;
  int _ownershipRevision = 0;
  bool _bootstrapped = false;
  bool _warmupStarted = false;

  SelectionState get selection => _selection;
  MetaState get meta => _meta;
  UserProfile get profile => _profile;
  AuthSession get authSession => _authSession;
  bool get isBootstrapped => _bootstrapped;
  int get ownershipRevision => _ownershipRevision;

  Future<void> bootstrap({bool force = false}) async {
    if (_bootstrapped && !force) return;
    final session = await _ensureAuthSession();
    final loadedProfile = await _profileStore.load();
    final canonical = await _ownershipApi.loadCanonicalState(
      profileId: loadedProfile.profileId,
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
    final freshProfile = _profileStore.createFresh();
    _profile = freshProfile;
    await _profileStore.save(freshProfile);
    final loaded = await _ownershipApi.loadCanonicalState(
      profileId: freshProfile.profileId,
      userId: session.userId,
      sessionId: session.sessionId,
    );
    _applyCanonicalState(loaded);
    final resetResult = await _ownershipApi.resetOwnership(
      ResetOwnershipCommand(
        profileId: freshProfile.profileId,
        userId: session.userId,
        sessionId: session.sessionId,
        expectedRevision: _ownershipRevision,
        commandId: _newCommandId(),
      ),
    );
    _applyOwnershipResult(resetResult);
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
        profileId: _profile.profileId,
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
        profileId: _profile.profileId,
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
        profileId: _profile.profileId,
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
        profileId: _profile.profileId,
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
        profileId: _profile.profileId,
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
        profileId: _profile.profileId,
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
        profileId: _profile.profileId,
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

  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    final result = await _authApi.linkAuthProvider(provider);
    _authSession = result.session;
    notifyListeners();
    return result;
  }

  Future<void> updateProfile(
    UserProfile Function(UserProfile current) fn,
  ) async {
    final current = _profile;
    final updated = fn(current);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final next = updated.copyWith(
      schemaVersion: UserProfile.latestSchemaVersion,
      profileId: updated.profileId.isEmpty
          ? current.profileId
          : updated.profileId,
      createdAtMs: updated.createdAtMs == 0
          ? current.createdAtMs
          : updated.createdAtMs,
      updatedAtMs: nowMs,
      revision: current.revision + 1,
    );
    _profile = next;
    await _profileStore.save(next);
    notifyListeners();
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
        profileId: _profile.profileId,
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
    _selection = canonical.selection;
    _meta = canonical.meta;
    _ownershipRevision = canonical.revision;
  }

  Future<AuthSession> _ensureAuthSession() async {
    final session = await _authApi.ensureAuthenticatedSession();
    _authSession = session;
    return session;
  }

  String _newCommandId() {
    final nowMs = DateTime.now().microsecondsSinceEpoch;
    final salt = _random.nextInt(1 << 31);
    return 'cmd_${nowMs.toRadixString(36)}_${salt.toRadixString(36)}';
  }
}
