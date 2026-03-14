import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';

import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_id.dart';
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
import 'progression_state.dart';
import 'selection_state.dart';
import 'user_profile.dart';
import 'user_profile_remote_api.dart';

const String _defaultGameCompatVersion = '2026.03.0';

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
  final Map<String, RunSubmissionStatus> _runSubmissionStatuses =
      <String, RunSubmissionStatus>{};

  SelectionState get selection => _selection;
  MetaState get meta => _meta;
  ProgressionState get progression => _progression;
  UserProfile get profile => _profile;
  AuthSession get authSession => _authSession;
  String get profileId => _profileId;
  bool get isBootstrapped => _bootstrapped;
  int get ownershipRevision => _ownershipRevision;
  RunSubmissionStatus? runSubmissionStatusFor(String runSessionId) =>
      _runSubmissionStatuses[runSessionId];

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

  Future<void> setRunMode(RunMode runMode) async {
    final nextSelection = _selection.copyWith(selectedRunMode: runMode);
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
    _runSubmissionStatuses.clear();
    _bootstrapped = false;
    _warmupStarted = false;
    notifyListeners();
    return result;
  }

  void startWarmup() {
    if (_warmupStarted) return;
    _warmupStarted = true;
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
  }) async {
    final session = await _ensureAuthSession();
    // Force a live backend read before run start. If this fails, run start
    // fails closed for all modes.
    final canonical = await _ownershipApi.loadCanonicalState(
      userId: session.userId,
      sessionId: session.sessionId,
    );
    _applyCanonicalState(canonical);
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
      await _runBoardsApi.loadActiveBoard(
        userId: session.userId,
        sessionId: session.sessionId,
        mode: mode,
        levelId: levelId,
        gameCompatVersion: _defaultGameCompatVersion,
      );
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
    final ghostReplayBootstrap = await _tryLoadTopGhostReplayBootstrap(
      userId: session.userId,
      sessionId: session.sessionId,
      boardId: descriptor.boardId!,
    );
    if (ghostReplayBootstrap == null) {
      return descriptor;
    }
    return descriptor.copyWith(ghostReplayBootstrap: ghostReplayBootstrap);
  }

  Future<GhostReplayBootstrap?> _tryLoadTopGhostReplayBootstrap({
    required String userId,
    required String sessionId,
    required String boardId,
  }) async {
    try {
      final board = await _leaderboardApi.loadBoard(
        userId: userId,
        sessionId: sessionId,
        boardId: boardId,
      );
      for (final entry in board.topEntries) {
        if (!entry.ghostEligible) {
          continue;
        }
        final entryId = entry.entryId.trim();
        if (entryId.isEmpty) {
          continue;
        }
        try {
          return loadGhostReplayBootstrap(boardId: boardId, entryId: entryId);
        } catch (error) {
          debugPrint(
            'Ghost bootstrap load failed for boardId=$boardId entryId=$entryId: '
            '$error',
          );
        }
      }
    } catch (error) {
      debugPrint(
        'Ghost leaderboard bootstrap skipped for boardId=$boardId: $error',
      );
    }
    return null;
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
