part of 'package:rpg_runner/ui/state/app/app_state.dart';

abstract base class _AppStateController {
  _AppStateController(this._app);

  final AppState _app;

  AuthApi get _authApi => _app._authApi;
  UserProfileRemoteApi get _profileRemoteApi => _app._profileRemoteApi;
  AccountDeletionApi get _accountDeletionApi => _app._accountDeletionApi;
  LoadoutOwnershipApi get _ownershipApi => _app._ownershipApi;
  RunBoardsApi get _runBoardsApi => _app._runBoardsApi;
  RunSessionApi get _runSessionApi => _app._runSessionApi;
  LeaderboardApi get _leaderboardApi => _app._leaderboardApi;
  GhostApi get _ghostApi => _app._ghostApi;
  GhostReplayCache get _ghostReplayCache => _app._ghostReplayCache;
  OwnershipSyncPolicy get _ownershipSyncPolicy => _app._ownershipSyncPolicy;
  OwnershipOutboxStore get _ownershipOutboxStore => _app._ownershipOutboxStore;
  RunSubmissionCoordinator get _runSubmissionCoordinator =>
      _app._runSubmissionCoordinator;
  Random get _random => _app._random;

  SelectionState get _selection => _app._selection;
  set _selection(SelectionState value) => _app._selection = value;

  MetaState get _meta => _app._meta;
  set _meta(MetaState value) => _app._meta = value;

  set _progression(ProgressionState value) => _app._progression = value;

  UserProfile get _profile => _app._profile;
  set _profile(UserProfile value) => _app._profile = value;

  AuthSession get _authSession => _app._authSession;
  set _authSession(AuthSession value) => _app._authSession = value;

  set _profileId(String value) => _app._profileId = value;

  int get _ownershipRevision => _app._ownershipRevision;
  set _ownershipRevision(int value) => _app._ownershipRevision = value;

  bool get _bootstrapped => _app._bootstrapped;
  set _bootstrapped(bool value) => _app._bootstrapped = value;

  bool get _warmupStarted => _app._warmupStarted;
  set _warmupStarted(bool value) => _app._warmupStarted = value;

  OwnershipSyncStatus get _ownershipSyncStatus => _app._ownershipSyncStatus;
  set _ownershipSyncStatus(OwnershipSyncStatus value) =>
      _app._ownershipSyncStatus = value;

  Timer? get _ownershipFlushTimer => _app._ownershipFlushTimer;
  set _ownershipFlushTimer(Timer? value) => _app._ownershipFlushTimer = value;

  Future<void>? get _activeOwnershipFlush => _app._activeOwnershipFlush;
  set _activeOwnershipFlush(Future<void>? value) =>
      _app._activeOwnershipFlush = value;

  int? get _ownershipSyncStatusUpdatedAtMs =>
      _app._ownershipSyncStatusUpdatedAtMs;
  set _ownershipSyncStatusUpdatedAtMs(int? value) =>
      _app._ownershipSyncStatusUpdatedAtMs = value;

  Map<String, RunSubmissionStatus> get _runSubmissionStatuses =>
      _app._runSubmissionStatuses;

  Map<_RunTicketPrefetchKey, RunTicket> get _runTicketPrefetchCache =>
      _app._runTicketPrefetchCache;

  Map<_RunTicketPrefetchKey, Future<void>> get _runTicketPrefetchInFlight =>
      _app._runTicketPrefetchInFlight;

  Map<_RunTicketPrefetchKey, int> get _runTicketPrefetchLruClockByKey =>
      _app._runTicketPrefetchLruClockByKey;

  Map<_RunTicketPrefetchKey, int>
  get _runTicketPrefetchLastRequestedAtMsByKey =>
      _app._runTicketPrefetchLastRequestedAtMsByKey;

  int get _runTicketPrefetchLruClock => _app._runTicketPrefetchLruClock;
  set _runTicketPrefetchLruClock(int value) =>
      _app._runTicketPrefetchLruClock = value;

  void _notifyListeners() => _app._notifyListeners();

  Future<AuthSession> _ensureAuthSession() => _app._ensureAuthSession();

  Future<AuthSession?> _tryEnsureAuthSessionForRunTicketPrefetch() =>
      _app._tryEnsureAuthSessionForRunTicketPrefetch();

  void _applyOwnershipResult(OwnershipCommandResult result) =>
      _app._applyOwnershipResult(result);

  void _applyCanonicalState(OwnershipCanonicalState canonical) =>
      _app._applyCanonicalState(canonical);

  void _clearRunTicketPrefetchState() => _app._clearRunTicketPrefetchState();

  String _newCommandId() => _app._newCommandId();

  LevelId _effectiveLevelForMode({
    required RunMode mode,
    required LevelId selectedLevelId,
  }) =>
      _app._effectiveLevelForMode(mode: mode, selectedLevelId: selectedLevelId);

  T _enumByName<T extends Enum>(
    List<T> values,
    String raw, {
    required String fieldName,
  }) => _app._enumByName(values, raw, fieldName: fieldName);

  T _enumFromStringOrFallback<T extends Enum>(
    List<T> values,
    Object? raw,
    T fallback,
  ) => _app._enumFromStringOrFallback(values, raw, fallback);

  int _intOrFallback(Object? raw, int fallback) =>
      _app._intOrFallback(raw, fallback);

  String? _stringOrNull(Object? raw) => _app._stringOrNull(raw);

  Object _gearItemFromName({
    required GearSlot slot,
    required String itemIdName,
  }) => _app._gearItemFromName(slot: slot, itemIdName: itemIdName);

  Future<void> _enqueueOwnershipCommand(OwnershipPendingCommand command) =>
      _app._enqueueOwnershipCommand(command);

  Future<void> _refreshOwnershipSyncStatusFromOutbox() =>
      _app._refreshOwnershipSyncStatusFromOutbox();

  Future<void> _setSelection(SelectionState nextSelection) =>
      _app._setSelection(nextSelection);

  Future<void> _reconcileSelectionProjectionFromOutbox() =>
      _app._reconcileSelectionProjectionFromOutbox();

  Future<void> _resumePendingRunSubmissions() =>
      _app._resumePendingRunSubmissions();

  Future<void> ensureOwnershipSyncedBeforeRunStart() =>
      _app.ensureOwnershipSyncedBeforeRunStart();

  Future<void> startRunTicketPrefetchForCurrentSelection() =>
      _app.startRunTicketPrefetchForCurrentSelection();

  Future<void> startRunTicketPrefetchFor({
    required RunMode mode,
    required LevelId levelId,
  }) => _app.startRunTicketPrefetchFor(mode: mode, levelId: levelId);

  Future<GhostReplayBootstrap> loadGhostReplayBootstrap({
    required String boardId,
    required String entryId,
  }) => _app.loadGhostReplayBootstrap(boardId: boardId, entryId: entryId);
}
