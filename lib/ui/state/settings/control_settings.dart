import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controls/movement_control_mode.dart';

/// Device-wide input preferences, independent of account and developer profiles.
abstract interface class ControlSettingsStore {
  /// Restores the choice, falling back to arrows for absent or invalid data.
  Future<MovementControlMode> loadMovementMode();

  /// Completes after persistence succeeds; throws on failure.
  Future<void> saveMovementMode(MovementControlMode mode);
}

/// Persists a device-wide choice without touching account/profile caches.
class SharedPrefsControlSettingsStore implements ControlSettingsStore {
  static const _movementKey = 'controls.movement_mode.v1';

  @override
  Future<MovementControlMode> loadMovementMode() async {
    final raw = (await SharedPreferences.getInstance()).get(_movementKey);
    return raw == 'joystick'
        ? MovementControlMode.joystick
        : MovementControlMode.arrows;
  }

  @override
  Future<void> saveMovementMode(MovementControlMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_movementKey, mode.name)) {
      throw StateError('Could not save movement controls.');
    }
  }
}

/// App-owned settings; a missing store provides an in-memory embedding default.
/// Changes publish only after persistence succeeds, with one write at a time.
class ControlSettings extends ChangeNotifier {
  ControlSettings({ControlSettingsStore? store}) : _store = store;

  final ControlSettingsStore? _store;
  MovementControlMode _movementMode = MovementControlMode.arrows;
  bool _saving = false;
  bool _loaded = false;
  bool _disposed = false;

  MovementControlMode get movementMode => _movementMode;
  bool get isSaving => _saving;

  /// Called by AppServices before exposing ready routes, including local mode.
  Future<void> load() async {
    if (_loaded) return;
    final mode = await _store?.loadMovementMode();
    if (_disposed) return;
    _movementMode = mode ?? MovementControlMode.arrows;
    _loaded = true;
  }

  /// Persists a selection before publishing it; concurrent changes are rejected.
  Future<void> setMovementMode(MovementControlMode mode) async {
    if (_disposed || mode == _movementMode) return;
    if (_saving) throw StateError('Movement controls are already being saved.');
    _saving = true;
    notifyListeners();
    try {
      await _store?.saveMovementMode(mode);
      if (!_disposed) _movementMode = mode;
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
