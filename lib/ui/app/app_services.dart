import '../state/app/app_state.dart';

/// Owns service initialization and the app state's lifetime.
///
/// Initialization is shared by concurrent callers and retried after failure.
/// The state factory runs only after services are ready. The app shell must
/// dispose this owner; providers expose its state without taking ownership.
class AppServices {
  AppServices({
    required Future<void> Function() initialize,
    required AppState Function() createAppState,
  }) : _initialize = initialize,
       _createAppState = createAppState;

  final Future<void> Function() _initialize;
  final AppState Function() _createAppState;
  Future<AppState>? _initialization;
  AppState? _appState;
  bool _disposed = false;

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
    await _initialize();
    if (_disposed) throw StateError('App services have been disposed.');
    return _appState = _createAppState();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _appState?.dispose();
    _appState = null;
  }
}
