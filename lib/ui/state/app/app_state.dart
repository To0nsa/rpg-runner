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
import '../../app/ui_routes.dart';
import '../profile/account_deletion_api.dart';
import '../auth/auth_api.dart';
import '../boards/ghost_api.dart';
import '../boards/ghost_replay_cache.dart';
import '../boards/leaderboard_api.dart';
import '../boards/run_boards_api.dart';
import '../run/run_submission_coordinator.dart';
import '../run/run_submission_spool_store.dart';
import '../run/run_submission_status.dart';
import '../run/run_session_api.dart';
import '../run/run_start_remote_exception.dart';
import '../ownership/loadout_ownership_api.dart';
import '../ownership/ownership_outbox_store.dart';
import '../ownership/ownership_pending_command.dart';
import '../ownership/ownership_sync_policy.dart';
import '../ownership/ownership_sync_status.dart';
import '../ownership/progression_state.dart';
import '../ownership/selection_state.dart';
import '../profile/user_profile.dart';
import '../profile/user_profile_remote_api.dart';

part 'controllers/controller_base.dart';
part 'controllers/auth_profile_controller.dart';
part 'controllers/selection_ownership_controller.dart';
part 'controllers/ownership_sync_controller.dart';
part 'controllers/run_submission_controller.dart';
part 'controllers/boards_controller.dart';
part 'controllers/run_start_controller.dart';

const String _defaultGameCompatVersion = '2026.03.0';
const LevelId _defaultWeeklyFeaturedLevelId = LevelId.field;
const int _runTicketPrefetchCacheMaxEntries = 4;
const int _runTicketPrefetchExpirySafetySkewMs = 5000;
const int _runTicketPrefetchMinIntervalMs = 1500;
const int _ownershipSyncStatusFreshnessMaxAgeMs = 1500;

@immutable
final class _RunTicketPrefetchKey {
  const _RunTicketPrefetchKey({
    required this.userId,
    required this.ownershipRevision,
    required this.gameCompatVersion,
    required this.mode,
    required this.levelId,
    required this.playerCharacterId,
    required this.loadoutDigest,
  });

  final String userId;
  final int ownershipRevision;
  final String gameCompatVersion;
  final RunMode mode;
  final LevelId levelId;
  final PlayerCharacterId playerCharacterId;
  final String loadoutDigest;

  @override
  bool operator ==(Object other) {
    return other is _RunTicketPrefetchKey &&
        other.userId == userId &&
        other.ownershipRevision == ownershipRevision &&
        other.gameCompatVersion == gameCompatVersion &&
        other.mode == mode &&
        other.levelId == levelId &&
        other.playerCharacterId == playerCharacterId &&
        other.loadoutDigest == loadoutDigest;
  }

  @override
  int get hashCode => Object.hash(
    userId,
    ownershipRevision,
    gameCompatVersion,
    mode,
    levelId,
    playerCharacterId,
    loadoutDigest,
  );
}

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
       _runSubmissionCoordinator = runSubmissionCoordinator {
    _authProfileController = _AppStateAuthProfileController(this);
    _selectionOwnershipController = _AppStateSelectionOwnershipController(this);
    _ownershipSyncController = _AppStateOwnershipSyncController(this);
    _runSubmissionController = _AppStateRunSubmissionController(this);
    _boardsController = _AppStateBoardsController(this);
    _runStartController = _AppStateRunStartController(this);
  }

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
  late final _AppStateAuthProfileController _authProfileController;
  late final _AppStateSelectionOwnershipController
  _selectionOwnershipController;
  late final _AppStateOwnershipSyncController _ownershipSyncController;
  late final _AppStateRunSubmissionController _runSubmissionController;
  late final _AppStateBoardsController _boardsController;
  late final _AppStateRunStartController _runStartController;

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
  int? _ownershipSyncStatusUpdatedAtMs;
  final Map<String, RunSubmissionStatus> _runSubmissionStatuses =
      <String, RunSubmissionStatus>{};
  final Map<_RunTicketPrefetchKey, RunTicket> _runTicketPrefetchCache =
      <_RunTicketPrefetchKey, RunTicket>{};
  final Map<_RunTicketPrefetchKey, Future<void>> _runTicketPrefetchInFlight =
      <_RunTicketPrefetchKey, Future<void>>{};
  final Map<_RunTicketPrefetchKey, int> _runTicketPrefetchLruClockByKey =
      <_RunTicketPrefetchKey, int>{};
  final Map<_RunTicketPrefetchKey, int>
  _runTicketPrefetchLastRequestedAtMsByKey = <_RunTicketPrefetchKey, int>{};
  int _runTicketPrefetchLruClock = 0;

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
  int get unverifiedGold => _runSubmissionStatuses.values
      .map((status) => status.displayProvisionalGold)
      .fold<int>(0, (sum, amount) => sum + amount);
  int get displayGold {
    final total = _progression.gold + unverifiedGold;
    return total < 0 ? 0 : total;
  }

  Future<void> bootstrap({bool force = false}) =>
      _authProfileController.bootstrap(force: force);

  Future<void> applyDefaults() => _authProfileController.applyDefaults();

  Future<void> updateDisplayName(String displayName) =>
      _authProfileController.updateDisplayName(displayName);

  Future<void> completeNamePrompt({String? displayName}) =>
      _authProfileController.completeNamePrompt(displayName: displayName);

  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) =>
      _authProfileController.linkAuthProvider(provider);

  Future<AccountDeletionResult> deleteAccountAndData() =>
      _authProfileController.deleteAccountAndData();

  void startWarmup() => _authProfileController.startWarmup();

  Future<void> setLevel(LevelId levelId) =>
      _selectionOwnershipController.setLevel(levelId);

  Future<void> setRunMode(RunMode runMode) =>
      _selectionOwnershipController.setRunMode(runMode);

  Future<void> setRunModeAndLevel({
    required RunMode runMode,
    required LevelId levelId,
  }) => _selectionOwnershipController.setRunModeAndLevel(
    runMode: runMode,
    levelId: levelId,
  );

  Future<void> setCharacter(PlayerCharacterId id) =>
      _selectionOwnershipController.setCharacter(id);

  Future<void> setLoadout(EquippedLoadoutDef loadout) =>
      _selectionOwnershipController.setLoadout(loadout);

  Future<void> setAbilitySlot({
    required PlayerCharacterId characterId,
    required AbilitySlot slot,
    required AbilityKey abilityId,
  }) => _selectionOwnershipController.setAbilitySlot(
    characterId: characterId,
    slot: slot,
    abilityId: abilityId,
  );

  Future<void> setProjectileSpell({
    required PlayerCharacterId characterId,
    required ProjectileId spellId,
  }) => _selectionOwnershipController.setProjectileSpell(
    characterId: characterId,
    spellId: spellId,
  );

  Future<void> learnProjectileSpell({
    required PlayerCharacterId characterId,
    required ProjectileId spellId,
  }) => _selectionOwnershipController.learnProjectileSpell(
    characterId: characterId,
    spellId: spellId,
  );

  Future<void> learnSpellAbility({
    required PlayerCharacterId characterId,
    required AbilityKey abilityId,
  }) => _selectionOwnershipController.learnSpellAbility(
    characterId: characterId,
    abilityId: abilityId,
  );

  Future<void> unlockGear({required GearSlot slot, required Object itemId}) =>
      _selectionOwnershipController.unlockGear(slot: slot, itemId: itemId);

  Future<void> equipGear({
    required PlayerCharacterId characterId,
    required GearSlot slot,
    required Object itemId,
  }) => _selectionOwnershipController.equipGear(
    characterId: characterId,
    slot: slot,
    itemId: itemId,
  );

  Future<void> setBuildName(String buildName) =>
      _selectionOwnershipController.setBuildName(buildName);

  Future<void> awardRunGold({required int runId, required int goldEarned}) =>
      _selectionOwnershipController.awardRunGold(
        runId: runId,
        goldEarned: goldEarned,
      );

  Future<OwnershipCommandResult> purchaseStoreOffer({
    required String offerId,
  }) => _selectionOwnershipController.purchaseStoreOffer(offerId: offerId);

  Future<OwnershipCommandResult> refreshStore({
    required StoreRefreshMethod method,
    String? refreshGrantId,
  }) => _selectionOwnershipController.refreshStore(
    method: method,
    refreshGrantId: refreshGrantId,
  );

  Future<void> flushOwnershipEdits({required OwnershipFlushTrigger trigger}) =>
      _ownershipSyncController.flushOwnershipEdits(trigger: trigger);

  Future<void> ensureOwnershipSyncedBeforeRunStart() =>
      _ownershipSyncController.ensureOwnershipSyncedBeforeRunStart();

  Future<void> ensureSelectionSyncedBeforeLeavingLevelSetup() =>
      _ownershipSyncController.ensureSelectionSyncedBeforeLeavingLevelSetup();

  Future<RunSubmissionStatus> submitRunReplay({
    required String runSessionId,
    required RunMode runMode,
    required String replayFilePath,
    required String canonicalSha256,
    required int contentLengthBytes,
    String contentType = 'application/octet-stream',
    Map<String, Object?>? provisionalSummary,
  }) => _runSubmissionController.submitRunReplay(
    runSessionId: runSessionId,
    runMode: runMode,
    replayFilePath: replayFilePath,
    canonicalSha256: canonicalSha256,
    contentLengthBytes: contentLengthBytes,
    contentType: contentType,
    provisionalSummary: provisionalSummary,
  );

  Future<RunSubmissionStatus> refreshRunSubmissionStatus({
    required String runSessionId,
  }) => _runSubmissionController.refreshRunSubmissionStatus(
    runSessionId: runSessionId,
  );

  Future<List<RunSubmissionStatus>> processPendingRunSubmissions() =>
      _runSubmissionController.processPendingRunSubmissions();

  Future<OnlineLeaderboardBoard> loadOnlineLeaderboardBoard({
    required RunMode mode,
    required LevelId levelId,
  }) => _boardsController.loadOnlineLeaderboardBoard(
    mode: mode,
    levelId: levelId,
  );

  Future<OnlineLeaderboardBoardData> loadOnlineLeaderboardData({
    required RunMode mode,
    required LevelId levelId,
  }) =>
      _boardsController.loadOnlineLeaderboardData(mode: mode, levelId: levelId);

  Future<OnlineLeaderboardMyRank> loadOnlineLeaderboardMyRank({
    required String boardId,
  }) => _boardsController.loadOnlineLeaderboardMyRank(boardId: boardId);

  Future<GhostManifest> loadGhostManifest({
    required String boardId,
    required String entryId,
  }) => _boardsController.loadGhostManifest(boardId: boardId, entryId: entryId);

  Future<GhostReplayBootstrap> loadGhostReplayBootstrap({
    required String boardId,
    required String entryId,
  }) => _boardsController.loadGhostReplayBootstrap(
    boardId: boardId,
    entryId: entryId,
  );

  Future<void> startRunTicketPrefetchForCurrentSelection() =>
      _runStartController.startRunTicketPrefetchForCurrentSelection();

  Future<void> startRunTicketPrefetchFor({
    required RunMode mode,
    required LevelId levelId,
  }) => _runStartController.startRunTicketPrefetchFor(
    mode: mode,
    levelId: levelId,
  );

  Future<RunStartDescriptor> prepareRunStartDescriptor({
    RunMode? expectedMode,
    LevelId? expectedLevelId,
    String? ghostEntryId,
  }) => _runStartController.prepareRunStartDescriptor(
    expectedMode: expectedMode,
    expectedLevelId: expectedLevelId,
    ghostEntryId: ghostEntryId,
  );

  Future<void> _enqueueOwnershipCommand(OwnershipPendingCommand command) =>
      _ownershipSyncController._enqueueOwnershipCommand(command);

  Future<void> _refreshOwnershipSyncStatusFromOutbox() =>
      _ownershipSyncController._refreshOwnershipSyncStatusFromOutbox();

  Future<void> _setSelection(SelectionState nextSelection) =>
      _selectionOwnershipController._setSelection(nextSelection);

  Future<void> _reconcileSelectionProjectionFromOutbox() =>
      _selectionOwnershipController._reconcileSelectionProjectionFromOutbox();

  Future<void> _resumePendingRunSubmissions() =>
      _runSubmissionController._resumePendingRunSubmissions();

  void _notifyListeners() {
    notifyListeners();
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

  void _applyOwnershipResult(OwnershipCommandResult result) {
    _applyCanonicalState(result.canonicalState);
  }

  void _applyCanonicalState(OwnershipCanonicalState canonical) {
    _clearRunTicketPrefetchState();
    _profileId = canonical.profileId;
    _selection = canonical.selection;
    _meta = canonical.meta;
    _progression = canonical.progression;
    _ownershipRevision = canonical.revision;
  }

  Future<AuthSession> _ensureAuthSession() async {
    final session = await _authApi.ensureAuthenticatedSession();
    if (_authSession.userId != session.userId ||
        _authSession.sessionId != session.sessionId) {
      _clearRunTicketPrefetchState();
      _ownershipSyncStatusUpdatedAtMs = null;
    }
    _authSession = session;
    return session;
  }

  Future<AuthSession?> _tryEnsureAuthSessionForRunTicketPrefetch() async {
    try {
      final session = await _ensureAuthSession();
      if (!session.isAuthenticated) {
        return null;
      }
      return session;
    } catch (_) {
      return null;
    }
  }

  void _clearRunTicketPrefetchState() {
    _runTicketPrefetchCache.clear();
    _runTicketPrefetchInFlight.clear();
    _runTicketPrefetchLruClockByKey.clear();
    _runTicketPrefetchLastRequestedAtMsByKey.clear();
    _runTicketPrefetchLruClock = 0;
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
    _clearRunTicketPrefetchState();
    super.dispose();
  }
}
