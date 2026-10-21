import 'package:flutter/foundation.dart';

import '../state/app/app_state.dart';
import '../state/settings/control_settings.dart';
import '../state/developer/developer_profile_store.dart';
import '../state/ownership/ownership_sync_policy.dart';

/// Owns service initialization and the app state's lifetime.
///
/// Initialization is shared by concurrent callers and retried after failure.
/// The online factory runs only after services are ready; debug developer
/// startup requests and preferences can bypass online initialization entirely.
/// The app shell must dispose this owner; providers expose its state without
/// taking ownership.
class AppServices extends ChangeNotifier {
  /// [startInDeveloperMode] selects local Practice for this owner's startup
  /// without changing the saved toggle. It requires debug mode and a developer
  /// store, and does not override later profile switches through Options.
  AppServices({
    required Future<void> Function() initialize,
    required AppState Function() createAppState,
    DeveloperProfileStore? developerProfileStore,
    ControlSettingsStore? controlSettingsStore,
    bool startInDeveloperMode = false,
  }) : _initialize = initialize,
       controlSettings = ControlSettings(store: controlSettingsStore),
       _createAppState = createAppState,
       _developerProfileStore = developerProfileStore,
       _startInDeveloperMode = startInDeveloperMode;

  final Future<void> Function() _initialize;

  /// Device preferences survive replacement of the authenticated app state.
  final ControlSettings controlSettings;
  final AppState Function() _createAppState;
  final DeveloperProfileStore? _developerProfileStore;
  final bool _startInDeveloperMode;
  bool _switchingProfile = false;
  Future<AppState>? _initialization;
  AppState? _appState;
  bool _disposed = false;

  /// Debug builds explicitly wired with local storage expose the Options toggle.
  bool get developerModeAvailable =>
      kDebugMode && _developerProfileStore != null;

  /// Menu navigation and lifecycle refreshes must wait until switching finishes.
  bool get isSwitchingProfile => _switchingProfile;

  /// Null until service initialization and state construction have succeeded.
  AppState? get readyAppState => _appState;

  /// Access for authenticated routes, after [initialize] has succeeded.
  AppState get appState =>
      _appState ?? (throw StateError('App services are not initialized.'));

  /// Returns the shared state after initialization, or throws on failure.
  /// A later call retries failure; disposal permanently prevents construction.
  Future<AppState> initialize() async {
    if (_disposed) throw StateError('App services have been disposed.');
    final ready = _appState;
    if (ready != null) return ready;
    final active = _initialization;
    if (active != null) return active;
    final pending = _initializeState();
    _initialization = pending;
    try {
      return await pending;
    } finally {
      if (identical(_initialization, pending)) _initialization = null;
    }
  }

  Future<AppState> _initializeState() async {
    await controlSettings.load();
    if (_disposed) throw StateError('App services have been disposed.');
    if (developerModeAvailable &&
        (_startInDeveloperMode ||
            await _developerProfileStore!.loadEnabled())) {
      if (_disposed) throw StateError('App services have been disposed.');
      return _appState = AppState.developer(store: _developerProfileStore!);
    }
    await _initialize();
    if (_disposed) throw StateError('App services have been disposed.');
    return _appState = _createAppState();
  }

  /// Switches menu profiles without signing out or sharing account persistence.
  /// A failed bootstrap or preference write leaves the current profile active.
  /// Call only outside a run; the menu resets its routes after success.
  Future<void> setDeveloperMode(bool enabled) async {
    if (_disposed) throw StateError('App services have been disposed.');
    if (!developerModeAvailable) {
      throw StateError('Developer mode requires a debug build.');
    }
    if (_switchingProfile) {
      throw StateError('A profile switch is already running.');
    }
    final previous = appState;
    if (previous.isDeveloperMode == enabled) return;
    _switchingProfile = true;
    notifyListeners();
    AppState? candidate;
    try {
      if (previous.isDeveloperMode) {
        await previous.flushOwnershipEdits(
          trigger: OwnershipFlushTrigger.manual,
        );
      }
      if (!enabled) await _initialize();
      if (_disposed) throw StateError('App services have been disposed.');
      candidate = enabled
          ? AppState.developer(store: _developerProfileStore!)
          : _createAppState();
      await candidate.bootstrap();
      if (_disposed) throw StateError('App services have been disposed.');
      await _developerProfileStore!.saveEnabled(enabled);
      if (_disposed) throw StateError('App services have been disposed.');
      _appState = candidate;
      candidate = null;
      previous.dispose();
    } finally {
      candidate?.dispose();
      _switchingProfile = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    controlSettings.dispose();
    _appState?.dispose();
    _appState = null;
    super.dispose();
  }
}
