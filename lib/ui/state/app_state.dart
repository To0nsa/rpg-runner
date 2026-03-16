import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';

import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/meta/equipped_gear.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/meta/meta_state.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/weapons/weapon_id.dart';
import 'package:run_protocol/run_ticket.dart';
import '../app/ui_routes.dart';
import 'account_deletion_api.dart';
import 'auth_api.dart';
import 'ghost_api.dart';
import 'ghost_replay_cache.dart';
import 'leaderboard_api.dart';
import 'run_boards_api.dart';
import 'run_submission_coordinator.dart';
import 'run_submission_spool_store.dart';
import 'run_submission_status.dart';
import 'run_session_api.dart';
import 'run_start_remote_exception.dart';
import 'loadout_ownership_api.dart';
import 'ownership_outbox_store.dart';
import 'ownership_pending_command.dart';
import 'ownership_sync_policy.dart';
import 'ownership_sync_status.dart';
import 'progression_state.dart';
import 'selection_state.dart';
import 'user_profile.dart';
import 'user_profile_remote_api.dart';

const String _defaultGameCompatVersion = '2026.03.0';
const LevelId _defaultWeeklyFeaturedLevelId = LevelId.field;

class AppState extends ChangeNotifier {
  factory AppState({
    required AuthApi authApi,
    UserProfileRemoteApi? userProfileRemoteApi,
    AccountDeletionApi? accountDeletionApi,
    required LoadoutOwnershipApi loadoutOwnershipApi,
    RunBoardsApi? runBoardsApi,
    RunSessionApi? runSessionApi,
    LeaderboardApi? leaderboardApi,
    GhostApi? ghostApi,
    GhostReplayCache? ghostReplayCache,
    OwnershipSyncPolicy? ownershipSyncPolicy,
    OwnershipOutboxStore? ownershipOutboxStore,
    RunSubmissionCoordinator? runSubmissionCoordinator,
    RunSubmissionSpoolStore? runSubmissionSpoolStore,
  }) {
    final resolvedRunSessionApi = runSessionApi ?? const NoopRunSessionApi();
    final resolvedLeaderboardApi = leaderboardApi ?? const NoopLeaderboardApi();
    final resolvedGhostApi = ghostApi ?? const NoopGhostApi();
    final resolvedGhostReplayCache = ghostReplayCache ?? FileGhostReplayCache();
    return AppState._internal(
      authApi: authApi,
      userProfileRemoteApi: userProfileRemoteApi,
      accountDeletionApi: accountDeletionApi,
      loadoutOwnershipApi: loadoutOwnershipApi,
      runBoardsApi: runBoardsApi,
      runSessionApi: resolvedRunSessionApi,
      leaderboardApi: resolvedLeaderboardApi,
      ghostApi: resolvedGhostApi,
      ghostReplayCache: resolvedGhostReplayCache,
      ownershipSyncPolicy: ownershipSyncPolicy,
      ownershipOutboxStore: ownershipOutboxStore,
      runSubmissionCoordinator:
          runSubmissionCoordinator ??
          RunSubmissionCoordinator(
            runSessionApi: resolvedRunSessionApi,
            spoolStore:
                runSubmissionSpoolStore ?? SharedPrefsRunSubmissionSpoolStore(),
          ),
    );
  }

  AppState._internal({
    required AuthApi authApi,
    UserProfileRemoteApi? userProfileRemoteApi,
    AccountDeletionApi? accountDeletionApi,
    required LoadoutOwnershipApi loadoutOwnershipApi,
    RunBoardsApi? runBoardsApi,
    required RunSessionApi runSessionApi,
    required LeaderboardApi leaderboardApi,
    required GhostApi ghostApi,
    required GhostReplayCache ghostReplayCache,
    OwnershipSyncPolicy? ownershipSyncPolicy,
    OwnershipOutboxStore? ownershipOutboxStore,
    required RunSubmissionCoordinator runSubmissionCoordinator,
  }) : _authApi = authApi,
       _profileRemoteApi =
           userProfileRemoteApi ?? const NoopUserProfileRemoteApi(),
       _accountDeletionApi =
           accountDeletionApi ?? const NoopAccountDeletionApi(),
       _ownershipApi = loadoutOwnershipApi,
       _runBoardsApi = runBoardsApi ?? const NoopRunBoardsApi(),
       _runSessionApi = runSessionApi,
       _leaderboardApi = leaderboardApi,
       _ghostApi = ghostApi,
       _ghostReplayCache = ghostReplayCache,
       _ownershipSyncPolicy =
           ownershipSyncPolicy ?? OwnershipSyncPolicy.defaults,
       _ownershipOutboxStore =
           ownershipOutboxStore ?? InMemoryOwnershipOutboxStore(),
       _runSubmissionCoordinator = runSubmissionCoordinator;

  final Random _random = Random();
  final AuthApi _authApi;
  final UserProfileRemoteApi _profileRemoteApi;
  final AccountDeletionApi _accountDeletionApi;
  final LoadoutOwnershipApi _ownershipApi;
  final RunBoardsApi _runBoardsApi;
  final RunSessionApi _runSessionApi;
  final LeaderboardApi _leaderboardApi;
  final GhostApi _ghostApi;
  final GhostReplayCache _ghostReplayCache;
  final OwnershipSyncPolicy _ownershipSyncPolicy;
  final OwnershipOutboxStore _ownershipOutboxStore;
  final RunSubmissionCoordinator _runSubmissionCoordinator;

  SelectionState _selection = SelectionState.defaults;
  MetaState _meta = const MetaService().createNew();
  ProgressionState _progression = ProgressionState.initial;
  UserProfile _profile = UserProfile.empty;
  AuthSession _authSession = AuthSession.unauthenticated;
  String _profileId = defaultOwnershipProfileId;
  int _ownershipRevision = 0;
  bool _bootstrapped = false;
  bool _warmupStarted = false;
  OwnershipSyncStatus _ownershipSyncStatus = OwnershipSyncStatus.idle;
  Timer? _ownershipFlushTimer;
  Future<void>? _activeOwnershipFlush;
  final Map<String, RunSubmissionStatus> _runSubmissionStatuses =
      <String, RunSubmissionStatus>{};

  SelectionState get selection => _selection;
  LevelId get weeklyFeaturedLevelId => _defaultWeeklyFeaturedLevelId;
  MetaState get meta => _meta;
  ProgressionState get progression => _progression;
  UserProfile get profile => _profile;
  AuthSession get authSession => _authSession;
  String get profileId => _profileId;
  bool get isBootstrapped => _bootstrapped;
  int get ownershipRevision => _ownershipRevision;
  OwnershipSyncPolicy get ownershipSyncPolicy => _ownershipSyncPolicy;
  OwnershipSyncStatus get ownershipSyncStatus => _ownershipSyncStatus;
  RunSubmissionStatus? runSubmissionStatusFor(String runSessionId) =>
      _runSubmissionStatuses[runSessionId];

  Future<void> flushOwnershipEdits({
    required OwnershipFlushTrigger trigger,
  }) async {
    final active = _activeOwnershipFlush;
    if (active != null) {
      await active;
      return;
    }
    final pending = _flushOwnershipEditsInternal(trigger: trigger);
    _activeOwnershipFlush = pending;
    try {
      await pending;
    } finally {
      if (identical(_activeOwnershipFlush, pending)) {
        _activeOwnershipFlush = null;
      }
    }
  }

  Future<void> ensureOwnershipSyncedBeforeRunStart() {
    return _ensureOwnershipSyncedBeforeRunStartInternal();
  }

  Future<void> ensureSelectionSyncedBeforeLeavingLevelSetup() {
    return flushOwnershipEdits(trigger: OwnershipFlushTrigger.leaveLevelSetup);
  }

  Future<void> _ensureOwnershipSyncedBeforeRunStartInternal() async {
    await flushOwnershipEdits(trigger: OwnershipFlushTrigger.runStart);
    await _refreshOwnershipSyncStatusFromOutbox();
    if (_ownershipSyncStatus.pendingCount > 0) {
      throw const RunStartRemoteException(
        code: 'failed-precondition',
        message:
            'Pending ownership changes are still syncing. Check your connection and try again.',
      );
    }
  }

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
    final resolvedLevelId = _effectiveLevelForMode(
      mode: _selection.selectedRunMode,
      selectedLevelId: levelId,
    );
    final nextSelection = _selection.copyWith(selectedLevelId: resolvedLevelId);
    await _updateSelectionOptimistically(nextSelection);
  }

  Future<void> setRunMode(RunMode runMode) async {
    final resolvedLevelId = _effectiveLevelForMode(
      mode: runMode,
      selectedLevelId: _selection.selectedLevelId,
    );
    final nextSelection = _selection.copyWith(
      selectedRunMode: runMode,
      selectedLevelId: resolvedLevelId,
    );
    await _updateSelectionOptimistically(nextSelection);
  }

  Future<void> setRunModeAndLevel({
    required RunMode runMode,
    required LevelId levelId,
  }) async {
    final resolvedLevelId = _effectiveLevelForMode(
      mode: runMode,
      selectedLevelId: levelId,
    );
    final nextSelection = _selection.copyWith(
      selectedRunMode: runMode,
      selectedLevelId: resolvedLevelId,
    );
    await _updateSelectionOptimistically(nextSelection);
  }

  Future<void> setCharacter(PlayerCharacterId id) async {
    final nextSelection = _selection.copyWith(selectedCharacterId: id);
    await _updateSelectionOptimistically(nextSelection);
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
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final currentLoadout = _selection.loadoutFor(characterId);
    final nextLoadout = _withAbilityInLoadout(
      loadout: currentLoadout,
      slot: slot,
      abilityId: abilityId,
    );
    _selection = _selection.withLoadoutFor(characterId, nextLoadout);
    notifyListeners();
    await _enqueueOwnershipCommand(
      OwnershipPendingCommand(
        coalesceKey: 'ability:${characterId.name}:${slot.name}',
        commandType: OwnershipPendingCommandType.setAbilitySlot,
        policyTier: OwnershipSyncTier.writeBehind,
        payloadJson: <String, Object?>{
          'characterId': characterId.name,
          'slot': slot.name,
          'abilityId': abilityId,
        },
        createdAtMs: nowMs,
        updatedAtMs: nowMs,
      ),
    );
  }

  Future<void> setProjectileSpell({
    required PlayerCharacterId characterId,
    required ProjectileId spellId,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final currentLoadout = _selection.loadoutFor(characterId);
    final nextLoadout = _copyLoadout(
      currentLoadout,
      projectileSlotSpellId: spellId,
    );
    _selection = _selection.withLoadoutFor(characterId, nextLoadout);
    notifyListeners();
    await _enqueueOwnershipCommand(
      OwnershipPendingCommand(
        coalesceKey: 'projectile:${characterId.name}',
        commandType: OwnershipPendingCommandType.setProjectileSpell,
        policyTier: OwnershipSyncTier.writeBehind,
        payloadJson: <String, Object?>{
          'characterId': characterId.name,
          'spellId': spellId.name,
        },
        createdAtMs: nowMs,
        updatedAtMs: nowMs,
      ),
    );
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
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final currentLoadout = _selection.loadoutFor(characterId);
    final nextLoadout = _withGearInLoadout(
      loadout: currentLoadout,
      slot: slot,
      itemId: itemId,
    );
    _selection = _selection.withLoadoutFor(characterId, nextLoadout);
    _meta = _meta.setEquippedFor(
      characterId,
      _withGearInMeta(
        equipped: _meta.equippedFor(characterId),
        slot: slot,
        itemId: itemId,
      ),
    );
    notifyListeners();
    await _enqueueOwnershipCommand(
      OwnershipPendingCommand(
        coalesceKey: 'gear:${characterId.name}:${slot.name}',
        commandType: OwnershipPendingCommandType.equipGear,
        policyTier: OwnershipSyncTier.writeBehind,
        payloadJson: <String, Object?>{
          'characterId': characterId.name,
          'slot': slot.name,
          'itemId': _gearItemIdAsName(slot: slot, itemId: itemId),
        },
        createdAtMs: nowMs,
        updatedAtMs: nowMs,
      ),
    );
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
    _runSubmissionStatuses.clear();
    _bootstrapped = false;
    _warmupStarted = false;
    notifyListeners();
    return result;
  }

  void startWarmup() {
    if (_warmupStarted) return;
    _warmupStarted = true;
    unawaited(() async {
      await _refreshOwnershipSyncStatusFromOutbox();
      notifyListeners();
    }());
    unawaited(_resumePendingRunSubmissions());
  }

  Future<RunSubmissionStatus> submitRunReplay({
    required String runSessionId,
    required RunMode runMode,
    required String replayFilePath,
    required String canonicalSha256,
    required int contentLengthBytes,
    String contentType = 'application/octet-stream',
    Map<String, Object?>? provisionalSummary,
  }) async {
    final session = await _ensureAuthSession();
    await _runSubmissionCoordinator.enqueueSubmission(
      runSessionId: runSessionId,
      runMode: runMode,
      replayFilePath: replayFilePath,
      canonicalSha256: canonicalSha256,
      contentLengthBytes: contentLengthBytes,
      contentType: contentType,
      provisionalSummary: provisionalSummary,
    );
    final status = await _runSubmissionCoordinator.processRunSession(
      userId: session.userId,
      sessionId: session.sessionId,
      runSessionId: runSessionId,
    );
    _runSubmissionStatuses[runSessionId] = status;
    notifyListeners();
    return status;
  }

  Future<RunSubmissionStatus> refreshRunSubmissionStatus({
    required String runSessionId,
  }) async {
    final session = await _ensureAuthSession();
    final status = await _runSubmissionCoordinator.refreshRunSessionStatus(
      userId: session.userId,
      sessionId: session.sessionId,
      runSessionId: runSessionId,
    );
    _runSubmissionStatuses[runSessionId] = status;
    notifyListeners();
    return status;
  }

  Future<List<RunSubmissionStatus>> processPendingRunSubmissions() async {
    final session = await _ensureAuthSession();
    final statuses = await _runSubmissionCoordinator.processReadySubmissions(
      userId: session.userId,
      sessionId: session.sessionId,
    );
    if (statuses.isEmpty) {
      return const <RunSubmissionStatus>[];
    }
    for (final status in statuses) {
      _runSubmissionStatuses[status.runSessionId] = status;
    }
    notifyListeners();
    return statuses;
  }

  Future<OnlineLeaderboardBoard> loadOnlineLeaderboardBoard({
    required RunMode mode,
    required LevelId levelId,
  }) async {
    if (!mode.requiresBoard) {
      throw const RunStartRemoteException(
        code: 'failed-precondition',
        message: 'Practice mode does not have an online leaderboard board.',
      );
    }
    final session = await _ensureAuthSession();
    final boardManifest = await _runBoardsApi.loadActiveBoard(
      userId: session.userId,
      sessionId: session.sessionId,
      mode: mode,
      levelId: levelId,
      gameCompatVersion: _defaultGameCompatVersion,
    );
    return _leaderboardApi.loadBoard(
      userId: session.userId,
      sessionId: session.sessionId,
      boardId: boardManifest.boardId,
    );
  }

  Future<OnlineLeaderboardMyRank> loadOnlineLeaderboardMyRank({
    required String boardId,
  }) async {
    final session = await _ensureAuthSession();
    return _leaderboardApi.loadMyRank(
      userId: session.userId,
      sessionId: session.sessionId,
      boardId: boardId,
    );
  }

  Future<GhostManifest> loadGhostManifest({
    required String boardId,
    required String entryId,
  }) async {
    final session = await _ensureAuthSession();
    return _ghostApi.loadManifest(
      userId: session.userId,
      sessionId: session.sessionId,
      boardId: boardId,
      entryId: entryId,
    );
  }

  Future<GhostReplayBootstrap> loadGhostReplayBootstrap({
    required String boardId,
    required String entryId,
  }) async {
    final manifest = await loadGhostManifest(
      boardId: boardId,
      entryId: entryId,
    );
    return _ghostReplayCache.loadReplay(manifest: manifest);
  }

  Future<RunStartDescriptor> prepareRunStartDescriptor({
    RunMode? expectedMode,
    LevelId? expectedLevelId,
    String? ghostEntryId,
  }) async {
    await ensureOwnershipSyncedBeforeRunStart();
    final session = await _ensureAuthSession();
    // Force a live backend read before run start. If this fails, run start
    // fails closed for all modes.
    final canonical = await _ownershipApi.loadCanonicalState(
      userId: session.userId,
      sessionId: session.sessionId,
    );
    _applyCanonicalState(canonical);
    if (_selection.selectedRunMode == RunMode.weekly &&
        _selection.selectedLevelId != _defaultWeeklyFeaturedLevelId) {
      await _setSelection(
        _selection.copyWith(selectedLevelId: _defaultWeeklyFeaturedLevelId),
      );
    }
    final canonicalMode = _selection.selectedRunMode;
    final canonicalLevelId = _selection.selectedLevelId;
    if (expectedMode != null && expectedMode != canonicalMode) {
      throw const RunStartRemoteException(
        code: 'failed-precondition',
        message:
            'Run mode changed in canonical state. Return to hub before restart.',
      );
    }
    if (expectedLevelId != null && expectedLevelId != canonicalLevelId) {
      throw const RunStartRemoteException(
        code: 'failed-precondition',
        message:
            'Selected level changed in canonical state. Return to hub before restart.',
      );
    }
    final mode = expectedMode ?? canonicalMode;
    final levelId = expectedLevelId ?? canonicalLevelId;

    if (mode.requiresBoard) {
      try {
        await _runBoardsApi.loadActiveBoard(
          userId: session.userId,
          sessionId: session.sessionId,
          mode: mode,
          levelId: levelId,
          gameCompatVersion: _defaultGameCompatVersion,
        );
      } on RunStartRemoteException catch (error) {
        if (error.isPreconditionFailed) {
          rethrow;
        }
        debugPrint(
          'Ranked board preflight failed for mode=${mode.name} '
          'level=${levelId.name}; falling back to runSessionCreate: $error',
        );
      } catch (error) {
        debugPrint(
          'Ranked board preflight failed for mode=${mode.name} '
          'level=${levelId.name}; falling back to runSessionCreate: $error',
        );
      }
    }
    final runTicket = await _runSessionApi.createRunSession(
      userId: session.userId,
      sessionId: session.sessionId,
      mode: mode,
      levelId: levelId,
      gameCompatVersion: _defaultGameCompatVersion,
    );
    final descriptor = _runStartDescriptorFromTicket(runTicket);
    if (!mode.requiresBoard || descriptor.boardId == null) {
      return descriptor;
    }
    final resolvedGhostEntryId = ghostEntryId?.trim();
    if (resolvedGhostEntryId == null || resolvedGhostEntryId.isEmpty) {
      return descriptor;
    }
    final ghostReplayBootstrap = await loadGhostReplayBootstrap(
      boardId: descriptor.boardId!,
      entryId: resolvedGhostEntryId,
    );
    return descriptor.copyWith(ghostReplayBootstrap: ghostReplayBootstrap);
  }

  RunStartDescriptor _runStartDescriptorFromTicket(RunTicket ticket) {
    final parsedLevelId = _levelIdFromWire(ticket.levelId);
    final parsedCharacterId = _characterIdFromWire(ticket.playerCharacterId);
    final fallbackLoadout = _selection.loadoutFor(parsedCharacterId);
    final equippedLoadout = _equippedLoadoutFromSnapshot(
      ticket.loadoutSnapshot,
      fallback: fallbackLoadout,
    );
    return RunStartDescriptor(
      runSessionId: ticket.runSessionId,
      runId: _runIdFromRunSessionId(ticket.runSessionId),
      seed: ticket.seed,
      levelId: parsedLevelId,
      playerCharacterId: parsedCharacterId,
      runMode: ticket.mode,
      equippedLoadout: equippedLoadout,
      boardId: ticket.boardId,
      boardKey: ticket.boardKey,
    );
  }

  int _runIdFromRunSessionId(String runSessionId) {
    final digestBytes = crypto.sha256.convert(utf8.encode(runSessionId)).bytes;
    final digestWord = ByteData.sublistView(
      Uint8List.fromList(digestBytes),
      0,
      4,
    ).getUint32(0, Endian.big);
    final positive = digestWord & 0x7fffffff;
    return positive == 0 ? 1 : positive;
  }

  LevelId _levelIdFromWire(String levelId) {
    return _enumByName(LevelId.values, levelId, fieldName: 'runTicket.levelId');
  }

  PlayerCharacterId _characterIdFromWire(String characterId) {
    return _enumByName(
      PlayerCharacterId.values,
      characterId,
      fieldName: 'runTicket.playerCharacterId',
    );
  }

  EquippedLoadoutDef _equippedLoadoutFromSnapshot(
    Map<String, Object?> snapshot, {
    required EquippedLoadoutDef fallback,
  }) {
    return EquippedLoadoutDef(
      mask: _intOrFallback(snapshot['mask'], fallback.mask),
      mainWeaponId: _enumFromStringOrFallback(
        WeaponId.values,
        snapshot['mainWeaponId'],
        fallback.mainWeaponId,
      ),
      offhandWeaponId: _enumFromStringOrFallback(
        WeaponId.values,
        snapshot['offhandWeaponId'],
        fallback.offhandWeaponId,
      ),
      spellBookId: _enumFromStringOrFallback(
        SpellBookId.values,
        snapshot['spellBookId'],
        fallback.spellBookId,
      ),
      projectileSlotSpellId: _enumFromStringOrFallback(
        ProjectileId.values,
        snapshot['projectileSlotSpellId'],
        fallback.projectileSlotSpellId,
      ),
      accessoryId: _enumFromStringOrFallback(
        AccessoryId.values,
        snapshot['accessoryId'],
        fallback.accessoryId,
      ),
      abilityPrimaryId:
          _stringOrNull(snapshot['abilityPrimaryId']) ??
          fallback.abilityPrimaryId,
      abilitySecondaryId:
          _stringOrNull(snapshot['abilitySecondaryId']) ??
          fallback.abilitySecondaryId,
      abilityProjectileId:
          _stringOrNull(snapshot['abilityProjectileId']) ??
          fallback.abilityProjectileId,
      abilitySpellId:
          _stringOrNull(snapshot['abilitySpellId']) ?? fallback.abilitySpellId,
      abilityMobilityId:
          _stringOrNull(snapshot['abilityMobilityId']) ??
          fallback.abilityMobilityId,
      abilityJumpId:
          _stringOrNull(snapshot['abilityJumpId']) ?? fallback.abilityJumpId,
    );
  }

  T _enumByName<T extends Enum>(
    List<T> values,
    String raw, {
    required String fieldName,
  }) {
    for (final value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    throw RunStartRemoteException(
      code: 'invalid-response',
      message: '$fieldName has unsupported value "$raw".',
    );
  }

  T _enumFromStringOrFallback<T extends Enum>(
    List<T> values,
    Object? raw,
    T fallback,
  ) {
    final rawName = _stringOrNull(raw);
    if (rawName == null) {
      return fallback;
    }
    for (final value in values) {
      if (value.name == rawName) {
        return value;
      }
    }
    return fallback;
  }

  int _intOrFallback(Object? raw, int fallback) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return fallback;
  }

  String? _stringOrNull(Object? raw) => raw is String ? raw : null;

  Future<void> _resumePendingRunSubmissions() async {
    try {
      await processPendingRunSubmissions();
    } catch (error) {
      debugPrint('Pending replay submission resume failed: $error');
    }
  }

  Future<void> _enqueueOwnershipCommand(OwnershipPendingCommand command) async {
    await _ownershipOutboxStore.upsertCoalesced(command: command);
    await _refreshOwnershipSyncStatusFromOutbox();
    _scheduleOwnershipFlush(policyTier: command.policyTier);
    notifyListeners();
  }

  void _scheduleOwnershipFlush({required OwnershipSyncTier policyTier}) {
    final debounceMs = _ownershipSyncPolicy.debounceMsFor(policyTier);
    _ownershipFlushTimer?.cancel();
    if (debounceMs <= 0) {
      unawaited(flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual));
      return;
    }
    _ownershipFlushTimer = Timer(Duration(milliseconds: debounceMs), () {
      unawaited(flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual));
    });
  }

  Future<void> _flushOwnershipEditsInternal({
    required OwnershipFlushTrigger trigger,
  }) async {
    _ownershipFlushTimer?.cancel();
    _ownershipFlushTimer = null;
    _ownershipSyncStatus = _ownershipSyncStatus.copyWith(
      isFlushing: true,
      clearLastSyncError: true,
    );
    notifyListeners();
    try {
      AuthSession? session;
      while (true) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final pending = await _ownershipOutboxStore.loadAll();
        OwnershipPendingCommand? ready;
        OwnershipPendingCommand? fallbackReady;
        int? earliestNextAttemptAtMs;
        for (final candidate in pending) {
          final attempt = candidate.deliveryAttempt;
          final ageMs = nowMs - candidate.createdAtMs;
          final exceededMaxStaleness =
              ageMs >= _ownershipSyncPolicy.maxStalenessMs;
          if (attempt == null ||
              attempt.nextAttemptAtMs <= nowMs ||
              exceededMaxStaleness) {
            fallbackReady ??= candidate;
            if (candidate.policyTier == OwnershipSyncTier.selectionFastSync) {
              ready = candidate;
              break;
            }
            continue;
          }
          final candidateNextAttemptAtMs = attempt.nextAttemptAtMs;
          if (earliestNextAttemptAtMs == null ||
              candidateNextAttemptAtMs < earliestNextAttemptAtMs) {
            earliestNextAttemptAtMs = candidateNextAttemptAtMs;
          }
        }
        ready ??= fallbackReady;
        if (ready == null) {
          if (earliestNextAttemptAtMs != null) {
            final delayMs = earliestNextAttemptAtMs - nowMs;
            _ownershipFlushTimer?.cancel();
            _ownershipFlushTimer = Timer(
              Duration(milliseconds: delayMs <= 0 ? 1 : delayMs),
              () {
                unawaited(
                  flushOwnershipEdits(trigger: OwnershipFlushTrigger.manual),
                );
              },
            );
          }
          break;
        }
        session ??= await _ensureAuthSession();
        await _deliverPendingOwnershipCommand(session: session, command: ready);
      }
      await _refreshOwnershipSyncStatusFromOutbox();
    } catch (error) {
      _ownershipSyncStatus = _ownershipSyncStatus.copyWith(
        lastSyncError: 'flush:${trigger.name}:$error',
      );
    } finally {
      _ownershipSyncStatus = _ownershipSyncStatus.copyWith(isFlushing: false);
      notifyListeners();
    }
  }

  Future<void> _deliverPendingOwnershipCommand({
    required AuthSession session,
    required OwnershipPendingCommand command,
  }) async {
    final alreadySuperseded = await _isPendingCommandSuperseded(
      command: command,
    );
    if (alreadySuperseded) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final payloadHash = crypto.sha256
        .convert(utf8.encode(jsonEncode(command.payloadJson)))
        .toString();
    final attempt =
        command.deliveryAttempt ??
        OwnershipDeliveryAttempt(
          commandId: _newCommandId(),
          expectedRevision: _ownershipRevision,
          attemptCount: 0,
          nextAttemptAtMs: nowMs,
          sentPayloadHash: payloadHash,
        );
    try {
      final result = await _sendPendingOwnershipCommand(
        session: session,
        command: command,
        attempt: attempt,
      );
      final superseded = await _isPendingCommandSuperseded(
        command: command,
        sentPayloadHash: payloadHash,
      );
      if (superseded) {
        return;
      }
      if (result.rejectedReason == OwnershipRejectedReason.staleRevision) {
        final canonical = await _ownershipApi.loadCanonicalState(
          userId: session.userId,
          sessionId: session.sessionId,
        );
        await _ownershipOutboxStore.upsertCoalesced(
          command: command.copyWith(
            updatedAtMs: nowMs,
            clearDeliveryAttempt: true,
          ),
        );
        _applyCanonicalState(canonical);
        await _reconcileSelectionProjectionFromOutbox();
        _ownershipSyncStatus = _ownershipSyncStatus.copyWith(
          conflictCount: _ownershipSyncStatus.conflictCount + 1,
        );
        notifyListeners();
        return;
      }

      _applyOwnershipResult(result);
      await _ownershipOutboxStore.removeByCoalesceKey(
        coalesceKey: command.coalesceKey,
      );
      await _reconcileSelectionProjectionFromOutbox();
      notifyListeners();
    } catch (_) {
      final superseded = await _isPendingCommandSuperseded(
        command: command,
        sentPayloadHash: payloadHash,
      );
      if (superseded) {
        return;
      }
      final nextAttemptCount = attempt.attemptCount + 1;
      final delayMs = _ownershipSyncPolicy.retryDelayMsForAttempt(
        nextAttemptCount,
        random: _random,
      );
      final nextAttempt = attempt.copyWith(
        attemptCount: nextAttemptCount,
        nextAttemptAtMs: nowMs + delayMs,
        sentPayloadHash: payloadHash,
      );
      await _ownershipOutboxStore.upsertCoalesced(
        command: command.copyWith(
          updatedAtMs: nowMs,
          deliveryAttempt: nextAttempt,
        ),
      );
      _ownershipSyncStatus = _ownershipSyncStatus.copyWith(
        retryCount: _ownershipSyncStatus.retryCount + 1,
      );
    }
  }

  Future<bool> _isPendingCommandSuperseded({
    required OwnershipPendingCommand command,
    String? sentPayloadHash,
  }) async {
    final latest = await _ownershipOutboxStore.loadByCoalesceKey(
      coalesceKey: command.coalesceKey,
    );
    if (latest == null) {
      return false;
    }
    if (latest.updatedAtMs > command.updatedAtMs) {
      return true;
    }
    final latestPayloadHash = crypto.sha256
        .convert(utf8.encode(jsonEncode(latest.payloadJson)))
        .toString();
    final referencePayloadHash =
        sentPayloadHash ??
        crypto.sha256
            .convert(utf8.encode(jsonEncode(command.payloadJson)))
            .toString();
    return latestPayloadHash != referencePayloadHash;
  }

  Future<OwnershipCommandResult> _sendPendingOwnershipCommand({
    required AuthSession session,
    required OwnershipPendingCommand command,
    required OwnershipDeliveryAttempt attempt,
  }) async {
    switch (command.commandType) {
      case OwnershipPendingCommandType.setSelection:
        final selectionRaw = command.payloadJson['selection'];
        if (selectionRaw is! Map) {
          throw FormatException('setSelection payload is invalid.');
        }
        final selection = SelectionState.fromJson(
          Map<String, dynamic>.from(selectionRaw),
        );
        return _ownershipApi.setSelection(
          SetSelectionCommand(
            userId: session.userId,
            sessionId: session.sessionId,
            expectedRevision: attempt.expectedRevision,
            commandId: attempt.commandId,
            selection: selection,
          ),
        );
      case OwnershipPendingCommandType.setAbilitySlot:
        final characterId = _enumByName(
          PlayerCharacterId.values,
          '${command.payloadJson['characterId']}',
          fieldName: 'setAbilitySlot.characterId',
        );
        final slot = _enumByName(
          AbilitySlot.values,
          '${command.payloadJson['slot']}',
          fieldName: 'setAbilitySlot.slot',
        );
        final abilityId = '${command.payloadJson['abilityId']}';
        return _ownershipApi.setAbilitySlot(
          SetAbilitySlotCommand(
            userId: session.userId,
            sessionId: session.sessionId,
            expectedRevision: attempt.expectedRevision,
            commandId: attempt.commandId,
            characterId: characterId,
            slot: slot,
            abilityId: abilityId,
          ),
        );
      case OwnershipPendingCommandType.setProjectileSpell:
        final characterId = _enumByName(
          PlayerCharacterId.values,
          '${command.payloadJson['characterId']}',
          fieldName: 'setProjectileSpell.characterId',
        );
        final spellId = _enumByName(
          ProjectileId.values,
          '${command.payloadJson['spellId']}',
          fieldName: 'setProjectileSpell.spellId',
        );
        return _ownershipApi.setProjectileSpell(
          SetProjectileSpellCommand(
            userId: session.userId,
            sessionId: session.sessionId,
            expectedRevision: attempt.expectedRevision,
            commandId: attempt.commandId,
            characterId: characterId,
            spellId: spellId,
          ),
        );
      case OwnershipPendingCommandType.equipGear:
        final characterId = _enumByName(
          PlayerCharacterId.values,
          '${command.payloadJson['characterId']}',
          fieldName: 'equipGear.characterId',
        );
        final slot = _enumByName(
          GearSlot.values,
          '${command.payloadJson['slot']}',
          fieldName: 'equipGear.slot',
        );
        final itemIdName = '${command.payloadJson['itemId']}';
        final itemId = _gearItemFromName(slot: slot, itemIdName: itemIdName);
        return _ownershipApi.equipGear(
          EquipGearCommand(
            userId: session.userId,
            sessionId: session.sessionId,
            expectedRevision: attempt.expectedRevision,
            commandId: attempt.commandId,
            characterId: characterId,
            slot: slot,
            itemId: itemId,
          ),
        );
      case OwnershipPendingCommandType.setLoadout:
        throw UnsupportedError(
          'setLoadout outbox delivery is not enabled yet.',
        );
    }
  }

  Future<void> _refreshOwnershipSyncStatusFromOutbox() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final pending = await _ownershipOutboxStore.loadAll();
    final pendingSelectionCount = pending
        .where(
          (entry) => entry.policyTier == OwnershipSyncTier.selectionFastSync,
        )
        .length;
    int oldestPendingAgeMs = 0;
    if (pending.isNotEmpty) {
      final oldestCreatedAtMs = pending
          .map((entry) => entry.createdAtMs)
          .reduce((a, b) => a < b ? a : b);
      oldestPendingAgeMs = nowMs - oldestCreatedAtMs;
      if (oldestPendingAgeMs < 0) {
        oldestPendingAgeMs = 0;
      }
    }
    _ownershipSyncStatus = _ownershipSyncStatus.copyWith(
      pendingCount: pending.length,
      pendingSelectionCount: pendingSelectionCount,
      oldestPendingAgeMs: oldestPendingAgeMs,
    );
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

  Future<void> _updateSelectionOptimistically(
    SelectionState nextSelection,
  ) async {
    if (_selection == nextSelection) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _selection = nextSelection;
    notifyListeners();
    await _enqueueOwnershipCommand(
      OwnershipPendingCommand(
        coalesceKey: 'selection',
        commandType: OwnershipPendingCommandType.setSelection,
        policyTier: OwnershipSyncTier.selectionFastSync,
        payloadJson: <String, Object?>{'selection': nextSelection.toJson()},
        createdAtMs: nowMs,
        updatedAtMs: nowMs,
      ),
    );
  }

  Future<void> _reconcileSelectionProjectionFromOutbox() async {
    final pending = await _ownershipOutboxStore.loadByCoalesceKey(
      coalesceKey: 'selection',
    );
    if (pending == null ||
        pending.commandType != OwnershipPendingCommandType.setSelection) {
      return;
    }
    final selectionRaw = pending.payloadJson['selection'];
    if (selectionRaw is! Map) {
      return;
    }
    final projectedSelection = SelectionState.fromJson(
      Map<String, dynamic>.from(selectionRaw),
    );
    _selection = projectedSelection;
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

  LevelId _effectiveLevelForMode({
    required RunMode mode,
    required LevelId selectedLevelId,
  }) {
    if (mode == RunMode.weekly) {
      return _defaultWeeklyFeaturedLevelId;
    }
    return selectedLevelId;
  }

  EquippedLoadoutDef _withAbilityInLoadout({
    required EquippedLoadoutDef loadout,
    required AbilitySlot slot,
    required AbilityKey abilityId,
  }) {
    switch (slot) {
      case AbilitySlot.primary:
        return _copyLoadout(loadout, abilityPrimaryId: abilityId);
      case AbilitySlot.secondary:
        return _copyLoadout(loadout, abilitySecondaryId: abilityId);
      case AbilitySlot.projectile:
        return _copyLoadout(loadout, abilityProjectileId: abilityId);
      case AbilitySlot.spell:
        return _copyLoadout(loadout, abilitySpellId: abilityId);
      case AbilitySlot.mobility:
        return _copyLoadout(loadout, abilityMobilityId: abilityId);
      case AbilitySlot.jump:
        return _copyLoadout(loadout, abilityJumpId: abilityId);
    }
  }

  EquippedLoadoutDef _withGearInLoadout({
    required EquippedLoadoutDef loadout,
    required GearSlot slot,
    required Object itemId,
  }) {
    switch (slot) {
      case GearSlot.mainWeapon:
        return _copyLoadout(
          loadout,
          mainWeaponId: itemId is WeaponId ? itemId : loadout.mainWeaponId,
        );
      case GearSlot.offhandWeapon:
        return _copyLoadout(
          loadout,
          offhandWeaponId: itemId is WeaponId
              ? itemId
              : loadout.offhandWeaponId,
        );
      case GearSlot.spellBook:
        return _copyLoadout(
          loadout,
          spellBookId: itemId is SpellBookId ? itemId : loadout.spellBookId,
        );
      case GearSlot.accessory:
        return _copyLoadout(
          loadout,
          accessoryId: itemId is AccessoryId ? itemId : loadout.accessoryId,
        );
    }
  }

  EquippedLoadoutDef _copyLoadout(
    EquippedLoadoutDef loadout, {
    int? mask,
    WeaponId? mainWeaponId,
    WeaponId? offhandWeaponId,
    SpellBookId? spellBookId,
    ProjectileId? projectileSlotSpellId,
    AccessoryId? accessoryId,
    AbilityKey? abilityPrimaryId,
    AbilityKey? abilitySecondaryId,
    AbilityKey? abilityProjectileId,
    AbilityKey? abilitySpellId,
    AbilityKey? abilityMobilityId,
    AbilityKey? abilityJumpId,
  }) {
    return EquippedLoadoutDef(
      mask: mask ?? loadout.mask,
      mainWeaponId: mainWeaponId ?? loadout.mainWeaponId,
      offhandWeaponId: offhandWeaponId ?? loadout.offhandWeaponId,
      spellBookId: spellBookId ?? loadout.spellBookId,
      projectileSlotSpellId:
          projectileSlotSpellId ?? loadout.projectileSlotSpellId,
      accessoryId: accessoryId ?? loadout.accessoryId,
      abilityPrimaryId: abilityPrimaryId ?? loadout.abilityPrimaryId,
      abilitySecondaryId: abilitySecondaryId ?? loadout.abilitySecondaryId,
      abilityProjectileId: abilityProjectileId ?? loadout.abilityProjectileId,
      abilitySpellId: abilitySpellId ?? loadout.abilitySpellId,
      abilityMobilityId: abilityMobilityId ?? loadout.abilityMobilityId,
      abilityJumpId: abilityJumpId ?? loadout.abilityJumpId,
    );
  }

  EquippedGear _withGearInMeta({
    required EquippedGear equipped,
    required GearSlot slot,
    required Object itemId,
  }) {
    switch (slot) {
      case GearSlot.mainWeapon:
        return equipped.copyWith(
          mainWeaponId: itemId is WeaponId ? itemId : equipped.mainWeaponId,
        );
      case GearSlot.offhandWeapon:
        return equipped.copyWith(
          offhandWeaponId: itemId is WeaponId
              ? itemId
              : equipped.offhandWeaponId,
        );
      case GearSlot.spellBook:
        return equipped.copyWith(
          spellBookId: itemId is SpellBookId ? itemId : equipped.spellBookId,
        );
      case GearSlot.accessory:
        return equipped.copyWith(
          accessoryId: itemId is AccessoryId ? itemId : equipped.accessoryId,
        );
    }
  }

  String _gearItemIdAsName({required GearSlot slot, required Object itemId}) {
    switch (slot) {
      case GearSlot.mainWeapon:
      case GearSlot.offhandWeapon:
        return (itemId is WeaponId ? itemId : WeaponId.plainsteel).name;
      case GearSlot.spellBook:
        return (itemId is SpellBookId ? itemId : SpellBookId.apprenticePrimer)
            .name;
      case GearSlot.accessory:
        return (itemId is AccessoryId ? itemId : AccessoryId.strengthBelt).name;
    }
  }

  Object _gearItemFromName({
    required GearSlot slot,
    required String itemIdName,
  }) {
    switch (slot) {
      case GearSlot.mainWeapon:
      case GearSlot.offhandWeapon:
        return _enumByName(
          WeaponId.values,
          itemIdName,
          fieldName: 'equipGear.itemId',
        );
      case GearSlot.spellBook:
        return _enumByName(
          SpellBookId.values,
          itemIdName,
          fieldName: 'equipGear.itemId',
        );
      case GearSlot.accessory:
        return _enumByName(
          AccessoryId.values,
          itemIdName,
          fieldName: 'equipGear.itemId',
        );
    }
  }

  @override
  void dispose() {
    _ownershipFlushTimer?.cancel();
    _ownershipFlushTimer = null;
    super.dispose();
  }
}
