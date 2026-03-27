part of 'package:rpg_runner/ui/state/app/app_state.dart';

final class _AppStateAuthProfileController extends _AppStateController {
  _AppStateAuthProfileController(super._app);
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
    _notifyListeners();
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
    _notifyListeners();
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
    _notifyListeners();
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
    _notifyListeners();
  }

  Future<AuthLinkResult> linkAuthProvider(AuthLinkProvider provider) async {
    final result = await _authApi.linkAuthProvider(provider);
    _authSession = result.session;
    _notifyListeners();
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
    _ownershipSyncStatusUpdatedAtMs = null;
    _runSubmissionStatuses.clear();
    _clearRunTicketPrefetchState();
    _bootstrapped = false;
    _warmupStarted = false;
    _notifyListeners();
    return result;
  }

  void startWarmup() {
    if (_warmupStarted) return;
    _warmupStarted = true;
    unawaited(() async {
      await _refreshOwnershipSyncStatusFromOutbox();
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
