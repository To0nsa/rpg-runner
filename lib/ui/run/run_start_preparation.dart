import 'package:flutter/foundation.dart';

import '../app/ui_routes.dart';
import '../state/app/app_state.dart';
import '../state/run/run_start_remote_exception.dart';

/// Shared preflight for hub starts, leaderboard races, and restarts.
///
/// Selection writes and ticket validation stay in AppState. Disposal fences the
/// result and subsequent steps; already-issued backend calls may still finish.
class RunStartPreparation extends ChangeNotifier {
  RunStartPreparation({required this.appState, required this.request});

  final AppState appState;
  final RunStartBootstrapArgs request;
  bool _disposed = false;
  bool _inFlight = false;
  Object? _error;

  bool get inFlight => _inFlight;
  Object? get error => _error;
  String? get errorMessage => _error == null ? null : messageFor(_error!);

  /// Returns null on failure, disposal, or an already-running attempt.
  Future<RunStartDescriptor?> prepare() async {
    if (_disposed || _inFlight) return null;
    _inFlight = true;
    _error = null;
    notifyListeners();
    try {
      final mode = request.selectMode;
      final level = request.selectLevelId;
      if (mode != null && level != null) {
        if (appState.selection.selectedRunMode != mode ||
            appState.selection.selectedLevelId != level) {
          await appState.setRunModeAndLevel(runMode: mode, levelId: level);
        }
      } else if (mode != null && appState.selection.selectedRunMode != mode) {
        await appState.setRunMode(mode);
      } else if (level != null && appState.selection.selectedLevelId != level) {
        await appState.setLevel(level);
      }
      if (_disposed) return null;
      final descriptor = await appState.prepareRunStartDescriptor(
        expectedMode: request.expectedMode,
        expectedLevelId: request.expectedLevelId,
        ghostEntryId: request.ghostEntryId,
      );
      return _disposed ? null : descriptor;
    } catch (error, stack) {
      if (!_disposed) {
        _error = error;
        debugPrintStack(
          label: 'Run preflight failed: $error',
          stackTrace: stack,
          maxFrames: 12,
        );
      }
      return null;
    } finally {
      _inFlight = false;
      if (!_disposed) notifyListeners();
    }
  }

  static String messageFor(Object error) {
    if (error is RunStartRemoteException && error.isLevelUnavailable) {
      return 'This level is unavailable in this build. Return to the hub and select an available level.';
    }
    if (error is RunStartRemoteException && error.isPreconditionFailed) {
      return 'Run start requirements changed. Return to hub and try again.';
    }
    return 'Unable to start run right now. Check your connection and try again.';
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
