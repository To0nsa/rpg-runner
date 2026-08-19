import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/input/runner_gameplay_action.dart';
import 'package:rpg_runner/ui/input/desktop/runner_desktop_bindings.dart';

void main() {
  test('default keyboard bindings match the Windows gameplay contract', () {
    final expected = <PhysicalKeyboardKey, RunnerGameplayAction>{
      PhysicalKeyboardKey.keyA: RunnerGameplayAction.moveLeft,
      PhysicalKeyboardKey.arrowLeft: RunnerGameplayAction.moveLeft,
      PhysicalKeyboardKey.keyD: RunnerGameplayAction.moveRight,
      PhysicalKeyboardKey.arrowRight: RunnerGameplayAction.moveRight,
      PhysicalKeyboardKey.space: RunnerGameplayAction.jump,
      PhysicalKeyboardKey.keyW: RunnerGameplayAction.jump,
      PhysicalKeyboardKey.arrowUp: RunnerGameplayAction.jump,
      PhysicalKeyboardKey.shiftLeft: RunnerGameplayAction.mobility,
      PhysicalKeyboardKey.shiftRight: RunnerGameplayAction.mobility,
      PhysicalKeyboardKey.keyJ: RunnerGameplayAction.primary,
      PhysicalKeyboardKey.keyK: RunnerGameplayAction.projectile,
      PhysicalKeyboardKey.keyQ: RunnerGameplayAction.secondary,
      PhysicalKeyboardKey.keyE: RunnerGameplayAction.spell,
      PhysicalKeyboardKey.keyL: RunnerGameplayAction.spell,
    };

    final actual = <PhysicalKeyboardKey, RunnerGameplayAction>{
      for (final binding in RunnerDesktopBindings.keyboard)
        binding.key: binding.action,
    };

    expect(actual, expected);
    expect(actual, hasLength(RunnerDesktopBindings.keyboard.length));
  });

  test('default mouse bindings match the Windows gameplay contract', () {
    const expected = <int, RunnerGameplayAction>{
      kPrimaryMouseButton: RunnerGameplayAction.primary,
      kSecondaryMouseButton: RunnerGameplayAction.projectile,
    };

    final actual = <int, RunnerGameplayAction>{
      for (final binding in RunnerDesktopBindings.mouse)
        binding.buttons: binding.action,
    };

    expect(actual, expected);
    expect(actual, hasLength(RunnerDesktopBindings.mouse.length));
  });

  test('bindings cover every semantic gameplay action', () {
    final boundActions = <RunnerGameplayAction>{
      for (final binding in RunnerDesktopBindings.keyboard) binding.action,
      for (final binding in RunnerDesktopBindings.mouse) binding.action,
    };

    expect(boundActions, RunnerGameplayAction.values.toSet());
  });

  test('movement and Shift alternates preserve their semantic grouping', () {
    final byKey = <PhysicalKeyboardKey, RunnerGameplayAction>{
      for (final binding in RunnerDesktopBindings.keyboard)
        binding.key: binding.action,
    };

    expect(byKey[PhysicalKeyboardKey.shiftLeft], RunnerGameplayAction.mobility);
    expect(
      byKey[PhysicalKeyboardKey.shiftRight],
      RunnerGameplayAction.mobility,
    );
    expect(
      byKey[PhysicalKeyboardKey.keyA],
      isNot(byKey[PhysicalKeyboardKey.keyD]),
    );
    expect(
      byKey[PhysicalKeyboardKey.arrowLeft],
      byKey[PhysicalKeyboardKey.keyA],
    );
    expect(
      byKey[PhysicalKeyboardKey.arrowRight],
      byKey[PhysicalKeyboardKey.keyD],
    );
  });

  test('editor host shortcuts are not gameplay bindings', () {
    final boundKeys = RunnerDesktopBindings.keyboard
        .map((binding) => binding.key)
        .toSet();

    expect(boundKeys, isNot(contains(PhysicalKeyboardKey.f5)));
    expect(boundKeys, isNot(contains(PhysicalKeyboardKey.f6)));
    expect(boundKeys, isNot(contains(PhysicalKeyboardKey.escape)));
    expect(boundKeys, isNot(contains(PhysicalKeyboardKey.keyP)));
    expect(boundKeys, isNot(contains(PhysicalKeyboardKey.enter)));
  });
}
