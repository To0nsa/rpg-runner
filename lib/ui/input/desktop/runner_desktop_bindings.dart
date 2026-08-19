import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:rpg_runner/game/input/runner_gameplay_action.dart';

/// An immutable physical-key mapping to a device-neutral gameplay action.
@immutable
final class RunnerDesktopKeyBinding {
  const RunnerDesktopKeyBinding({required this.key, required this.action});

  final PhysicalKeyboardKey key;
  final RunnerGameplayAction action;
}

/// An immutable mouse-button mapping to a device-neutral gameplay action.
@immutable
final class RunnerDesktopMouseBinding {
  const RunnerDesktopMouseBinding({
    required this.buttons,
    required this.action,
  });

  final int buttons;
  final RunnerGameplayAction action;
}

/// Fixed gameplay bindings shared by Windows runner hosts.
///
/// Host controls such as play, pause, stop, and focus restoration deliberately
/// live outside this table so editor shortcuts cannot leak into gameplay input.
abstract final class RunnerDesktopBindings {
  static const List<RunnerDesktopKeyBinding> keyboard =
      <RunnerDesktopKeyBinding>[
        RunnerDesktopKeyBinding(
          key: PhysicalKeyboardKey.keyA,
          action: RunnerGameplayAction.moveLeft,
        ),
        RunnerDesktopKeyBinding(
          key: PhysicalKeyboardKey.arrowLeft,
          action: RunnerGameplayAction.moveLeft,
        ),
        RunnerDesktopKeyBinding(
          key: PhysicalKeyboardKey.keyD,
          action: RunnerGameplayAction.moveRight,
        ),
        RunnerDesktopKeyBinding(
          key: PhysicalKeyboardKey.arrowRight,
          action: RunnerGameplayAction.moveRight,
        ),
        RunnerDesktopKeyBinding(
          key: PhysicalKeyboardKey.space,
          action: RunnerGameplayAction.jump,
        ),
        RunnerDesktopKeyBinding(
          key: PhysicalKeyboardKey.keyW,
          action: RunnerGameplayAction.jump,
        ),
        RunnerDesktopKeyBinding(
          key: PhysicalKeyboardKey.arrowUp,
          action: RunnerGameplayAction.jump,
        ),
        RunnerDesktopKeyBinding(
          key: PhysicalKeyboardKey.shiftLeft,
          action: RunnerGameplayAction.mobility,
        ),
        RunnerDesktopKeyBinding(
          key: PhysicalKeyboardKey.shiftRight,
          action: RunnerGameplayAction.mobility,
        ),
        RunnerDesktopKeyBinding(
          key: PhysicalKeyboardKey.keyJ,
          action: RunnerGameplayAction.primary,
        ),
        RunnerDesktopKeyBinding(
          key: PhysicalKeyboardKey.keyK,
          action: RunnerGameplayAction.projectile,
        ),
        RunnerDesktopKeyBinding(
          key: PhysicalKeyboardKey.keyQ,
          action: RunnerGameplayAction.secondary,
        ),
        RunnerDesktopKeyBinding(
          key: PhysicalKeyboardKey.keyE,
          action: RunnerGameplayAction.spell,
        ),
        RunnerDesktopKeyBinding(
          key: PhysicalKeyboardKey.keyL,
          action: RunnerGameplayAction.spell,
        ),
      ];

  static const List<RunnerDesktopMouseBinding> mouse =
      <RunnerDesktopMouseBinding>[
        RunnerDesktopMouseBinding(
          buttons: kPrimaryMouseButton,
          action: RunnerGameplayAction.primary,
        ),
        RunnerDesktopMouseBinding(
          buttons: kSecondaryMouseButton,
          action: RunnerGameplayAction.projectile,
        ),
      ];
}
