part of 'package:rpg_runner/ui/state/app/app_state.dart';

final class _AppStateAuthProfileController extends _AppStateController {
  _AppStateAuthProfileController(super._app);
  AccountDeletionResult? _acceptedDeletionResult;
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
    if (_app._accountDeletionAccepted) return;
    _profile = loadedProfile;
    _applyCanonicalState(canonical);
    _bootstrapped = true;
    _notifyListeners();
  }

  Future<void> applyDefaults() async {
    final session = await _ensureAuthSession();
    UserProfile loadedProfile;
    try {
      loadedProfile = await _profileRemoteApi.loadProfile(
        userId: session.userId,
        sessionId: session.sessionId,
      );
    } catch (error) {
      debugPrint('Profile fallback load failed: $error');
      loadedProfile = UserProfile.empty;
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
    if (_app._accountDeletionAccepted) return;
    _profile = loadedProfile;
    _applyCanonicalState(canonical);
    _bootstrapped = true;
    _notifyListeners();
  }

  Future<void> updateDisplayName(String displayName) async {
    final session = await _ensureAuthSession();
    final trimmed = displayName.trim();
    if (trimmed == _profile.displayName) {
      return;
    }
    final nextProfile = await _profileRemoteApi.updateProfile(
      userId: session.userId,
      sessionId: session.sessionId,
      update: UserProfileUpdate(displayName: trimmed),
    );
    if (_app._accountDeletionAccepted) return;
    _profile = nextProfile;
    _notifyListeners();
  }

  Future<void> completeNamePrompt({String? displayName}) async {
    final session = await _ensureAuthSession();
    final trimmed = displayName?.trim();
    final shouldUpdateDisplayName = trimmed != null && trimmed.isNotEmpty;
    final nextProfile = await _profileRemoteApi.updateProfile(
      userId: session.userId,
      sessionId: session.sessionId,
      update: UserProfileUpdate(
        displayName: shouldUpdateDisplayName ? trimmed : null,
        namePromptCompleted: true,
      ),
    );
    if (_app._accountDeletionAccepted) return;
    _profile = nextProfile;
    _notifyListeners();
  }

  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    final result = await _authApi.linkAuthProvider(provider);
    if (_app._accountDeletionAccepted) return result;
    _authSession = result.session;
    _notifyListeners();
    return result;
  }

  Future<AccountDeletionResult> deleteAccountAndData() async {
    if (_acceptedDeletionResult != null) {
      return retryAccountDeletionLocalCleanup();
    }
    final session = await _authApi.reauthenticateForSensitiveOperation();
    _authSession = session;
    final result = await _accountDeletionApi.deleteAccountAndData(
      userId: session.userId,
      sessionId: session.sessionId,
    );
    if (!result.succeeded) {
      return result;
    }

    _acceptedDeletionResult = result;
    _ownershipFlushTimer?.cancel();
    _ownershipFlushTimer = null;
    _selection = SelectionState.defaults;
    _meta = const MetaService().createNew();
    _progression = ProgressionState.initial;
    _profile = UserProfile.empty;
    _authSession = AuthSession.unauthenticated;
    _profileId = defaultOwnershipProfileId;
    _ownershipRevision = 0;
    _ownershipSyncStatusUpdatedAtMs = null;
    _ownershipSyncStatus = OwnershipSyncStatus.idle;
    _runSubmissionStatuses.clear();
    _clearRunTicketPrefetchState();
    _bootstrapped = false;
    _warmupStarted = false;
    _notifyListeners();
    return retryAccountDeletionLocalCleanup();
  }

  Future<AccountDeletionResult> retryAccountDeletionLocalCleanup() async {
    final result = _acceptedDeletionResult;
    if (result == null) {
      throw StateError('Account deletion has not been accepted.');
    }
    final issues = <AccountDeletionLocalCleanupIssue>[];
    _ownershipFlushTimer?.cancel();
    _ownershipFlushTimer = null;
    final flush = _app._activeOwnershipFlush;
    if (flush != null) {
      try {
        await flush;
      } catch (_) {
        /* Cleanup owns discarding failed delivery. */
      }
    }
    try {
      await _ownershipOutboxStore.clear();
    } catch (error, stackTrace) {
      issues.add(AccountDeletionLocalCleanupIssue.ownershipOutbox);
      debugPrint(
        'Account-deletion ownership cleanup failed: '
        '$error\n$stackTrace',
      );
    }
    try {
      await _runSubmissionCoordinator.discardAllLocalSubmissions();
    } catch (error, stackTrace) {
      issues.add(AccountDeletionLocalCleanupIssue.replaySubmissions);
      debugPrint(
        'Account-deletion replay cleanup failed: '
        '$error\n$stackTrace',
      );
    }
    try {
      await _authApi.clearSession();
    } catch (error, stackTrace) {
      issues.add(AccountDeletionLocalCleanupIssue.signOut);
      debugPrint('Account-deletion sign-out failed: $error\n$stackTrace');
    }
    return AccountDeletionResult(
      status: result.status,
      requestId: result.requestId,
      errorCode: result.errorCode,
      errorMessage: result.errorMessage,
      localCleanupIssues: List<AccountDeletionLocalCleanupIssue>.unmodifiable(
        issues,
      ),
    );
  }

  void startWarmup() {
    if (_app._accountDeletionAccepted) return;
    if (_warmupStarted) return;
    _warmupStarted = true;
    unawaited(() async {
      final session = await _ensureAuthSession();
      await _refreshOwnershipSyncStatusFromOutbox(ownerUserId: session.userId);
      _notifyListeners();
    }());
    unawaited(startRunTicketPrefetchForCurrentSelection());
    if (_selection.selectedRunMode != RunMode.weekly) {
      unawaited(
        startRunTicketPrefetchFor(
          mode: RunMode.weekly,
          levelId: _defaultWeeklyFeaturedLevelId,
        ),
      );
    }
    unawaited(_resumePendingRunSubmissions());
  }
}
