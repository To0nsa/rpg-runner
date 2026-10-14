import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/controls/movement_control_mode.dart';
import 'package:rpg_runner/ui/state/settings/control_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'missing, unknown and malformed saved modes fall back to arrows',
    () async {
      for (final raw in [null, 'future-mode', 42]) {
        SharedPreferences.setMockInitialValues({
          'controls.movement_mode.v1': ?raw,
        });
        expect(
          await SharedPrefsControlSettingsStore().loadMovementMode(),
          MovementControlMode.arrows,
        );
      }
    },
  );

  test('choice survives recreation and supports changing back', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = ControlSettings(store: SharedPrefsControlSettingsStore());
    addTearDown(settings.dispose);
    await settings.load();
    await settings.setMovementMode(MovementControlMode.joystick);
    final restored = ControlSettings(store: SharedPrefsControlSettingsStore());
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.movementMode, MovementControlMode.joystick);
    await restored.setMovementMode(MovementControlMode.arrows);
    expect(
      await SharedPrefsControlSettingsStore().loadMovementMode(),
      MovementControlMode.arrows,
    );
  });

  test(
    'failed writes retain selection and release the saving guard for retry',
    () async {
      final store = _Store();
      final settings = ControlSettings(store: store);
      addTearDown(settings.dispose);
      await settings.load();
      final saving = settings.setMovementMode(MovementControlMode.joystick);
      expect(settings.isSaving, isTrue);
      expect(settings.movementMode, MovementControlMode.arrows);
      final failure = expectLater(saving, throwsStateError);
      store.pending.completeError(StateError('disk failure'));
      await failure;
      expect(settings.isSaving, isFalse);
      expect(settings.movementMode, MovementControlMode.arrows);
      store.pending = Completer<void>();
      final retry = settings.setMovementMode(MovementControlMode.joystick);
      store.pending.complete();
      await retry;
      expect(settings.movementMode, MovementControlMode.joystick);
    },
  );
}

class _Store implements ControlSettingsStore {
  Completer<void> pending = Completer<void>();
  @override
  Future<MovementControlMode> loadMovementMode() async =>
      MovementControlMode.arrows;
  @override
  Future<void> saveMovementMode(MovementControlMode mode) => pending.future;
}
