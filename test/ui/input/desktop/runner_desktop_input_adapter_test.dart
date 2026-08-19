import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/game/input/runner_gameplay_action.dart';
import 'package:rpg_runner/game/input/runner_input_router.dart';
import 'package:rpg_runner/game/input/runner_semantic_action_dispatcher.dart';
import 'package:rpg_runner/ui/input/desktop/runner_desktop_aim_geometry.dart';
import 'package:rpg_runner/ui/input/desktop/runner_desktop_input_adapter.dart';

import '../../../support/test_level.dart';
import '../../../test_tunings.dart';

void main() {
  test('physical mappings emit their semantic tap actions', () {
    final expected = <PhysicalKeyboardKey, int>{
      PhysicalKeyboardKey.space: ReplayCommandFrameV1.pressedJumpBit,
      PhysicalKeyboardKey.keyW: ReplayCommandFrameV1.pressedJumpBit,
      PhysicalKeyboardKey.arrowUp: ReplayCommandFrameV1.pressedJumpBit,
      PhysicalKeyboardKey.shiftLeft: ReplayCommandFrameV1.pressedDashBit,
      PhysicalKeyboardKey.shiftRight: ReplayCommandFrameV1.pressedDashBit,
      PhysicalKeyboardKey.keyJ: ReplayCommandFrameV1.pressedStrikeBit,
      PhysicalKeyboardKey.keyK: ReplayCommandFrameV1.pressedProjectileBit,
      PhysicalKeyboardKey.keyQ: ReplayCommandFrameV1.pressedSecondaryBit,
      PhysicalKeyboardKey.keyE: ReplayCommandFrameV1.pressedSpellBit,
      PhysicalKeyboardKey.keyL: ReplayCommandFrameV1.pressedSpellBit,
    };

    for (final entry in expected.entries) {
      final harness = _DesktopHarness();
      expect(harness.keyDown(entry.key), KeyEventResult.handled);
      expect(
        harness.advance().pressedMask,
        entry.value,
        reason: '${entry.key}',
      );
      expect(harness.keyUp(entry.key), KeyEventResult.handled);
      harness.advance();
      harness.adapter.dispose();
    }
  });

  test('alternate movement keys remain active until their last release', () {
    final harness = _DesktopHarness();

    harness.keyDown(PhysicalKeyboardKey.keyA);
    expect(harness.advance().moveAxis, -1);

    harness.keyDown(PhysicalKeyboardKey.arrowLeft);
    expect(harness.advance().moveAxis, -1);

    harness.keyUp(PhysicalKeyboardKey.keyA);
    expect(harness.advance().moveAxis, -1);

    harness.keyDown(PhysicalKeyboardKey.keyD);
    expect(harness.advance().moveAxis, isNull);

    harness.keyUp(PhysicalKeyboardKey.arrowLeft);
    expect(harness.advance().moveAxis, 1);

    harness.keyUp(PhysicalKeyboardKey.keyD);
    expect(harness.advance().moveAxis, isNull);
  });

  test('repeat and duplicate down events do not duplicate action edges', () {
    final harness = _DesktopHarness(
      modes: const <RunnerGameplayAction, AbilityInputMode>{
        RunnerGameplayAction.primary: AbilityInputMode.holdMaintain,
      },
    );

    harness.keyDown(PhysicalKeyboardKey.keyJ);
    final begin = harness.advance();
    harness.keyRepeat(PhysicalKeyboardKey.keyJ);
    harness.keyDown(PhysicalKeyboardKey.keyJ);
    final repeated = harness.advance();

    expect(begin.strikePressed, isTrue);
    expect(begin.abilitySlotHeldValueMask, 1 << AbilitySlot.primary.index);
    expect(repeated.strikePressed, isFalse);
    expect(repeated.abilitySlotHeldChangedMask, 0);

    harness.keyUp(PhysicalKeyboardKey.keyJ);
    final release = harness.advance();
    expect(release.abilitySlotHeldChangedMask, 1 << AbilitySlot.primary.index);
    expect(release.abilitySlotHeldValueMask, 0);
  });

  test('editor host keys are ignored by the gameplay adapter', () {
    final harness = _DesktopHarness();

    for (final key in const <PhysicalKeyboardKey>[
      PhysicalKeyboardKey.f5,
      PhysicalKeyboardKey.f6,
      PhysicalKeyboardKey.escape,
      PhysicalKeyboardKey.keyP,
      PhysicalKeyboardKey.enter,
    ]) {
      expect(harness.keyDown(key), KeyEventResult.ignored);
      expect(harness.keyUp(key), KeyEventResult.ignored);
    }

    expect(harness.advance().pressedMask, 0);
  });

  test('mouse and keyboard references share one action lifecycle', () {
    final harness = _DesktopHarness(
      modes: const <RunnerGameplayAction, AbilityInputMode>{
        RunnerGameplayAction.primary: AbilityInputMode.holdRelease,
      },
    );
    harness.adapter.handleFocusChanged(true);

    harness.keyDown(PhysicalKeyboardKey.keyJ);
    expect(
      harness.advance().abilitySlotHeldValueMask,
      1 << AbilitySlot.primary.index,
    );

    harness.adapter.handlePointerDown(
      const Offset(300, 100),
      kPrimaryMouseButton,
    );
    expect(harness.advance().abilitySlotHeldChangedMask, 0);

    harness.keyUp(PhysicalKeyboardKey.keyJ);
    expect(harness.advance().abilitySlotHeldChangedMask, 0);

    harness.adapter.handlePointerUp(const Offset(300, 100), 0);
    final release = harness.advance();
    expect(release.strikePressed, isTrue);
    expect(release.abilitySlotHeldChangedMask, 1 << AbilitySlot.primary.index);
    expect(release.abilitySlotHeldValueMask, 0);
  });

  test('mouse chord transitions each bound action once', () {
    final harness = _DesktopHarness();

    harness.adapter.handlePointerDown(
      const Offset(300, 100),
      kPrimaryMouseButton,
    );
    expect(harness.advance().strikePressed, isTrue);

    harness.adapter.handlePointerDown(
      const Offset(300, 100),
      kPrimaryMouseButton | kSecondaryMouseButton,
    );
    final chord = harness.advance();
    expect(chord.strikePressed, isFalse);
    expect(chord.projectilePressed, isTrue);

    harness.adapter.handlePointerUp(
      const Offset(300, 100),
      kSecondaryMouseButton,
    );
    expect(harness.advance().pressedMask, 0);
    harness.adapter.handlePointerUp(const Offset(300, 100), 0);
    expect(harness.advance().pressedMask, 0);
  });

  test('pointer cancel releases mouse hold without committing', () {
    final harness = _DesktopHarness(
      modes: const <RunnerGameplayAction, AbilityInputMode>{
        RunnerGameplayAction.projectile: AbilityInputMode.holdAimRelease,
      },
    );

    harness.adapter.handlePointerDown(
      const Offset(300, 100),
      kSecondaryMouseButton,
    );
    harness.advance();
    harness.adapter.handlePointerCancel();
    final canceled = harness.advance();

    expect(canceled.projectilePressed, isFalse);
    expect(
      canceled.abilitySlotHeldChangedMask,
      1 << AbilitySlot.projectile.index,
    );
    expect(canceled.abilitySlotHeldValueMask, 0);
  });

  test('keyboard release uses current pointer aim only inside viewport', () {
    final harness = _DesktopHarness(
      modes: const <RunnerGameplayAction, AbilityInputMode>{
        RunnerGameplayAction.projectile: AbilityInputMode.holdAimRelease,
      },
    );

    harness.adapter.handlePointerPosition(const Offset(200, 20));
    harness.keyDown(PhysicalKeyboardKey.keyK);
    harness.advance();
    harness.keyUp(PhysicalKeyboardKey.keyK);
    final aimed = harness.advance();
    expect(aimed.projectilePressed, isTrue);
    expect(aimed.aimDirX, 0);
    expect(aimed.aimDirY, -1);

    harness.keyDown(PhysicalKeyboardKey.keyK);
    harness.advance();
    harness.keyUp(PhysicalKeyboardKey.keyK);
    final repeatedAim = harness.advance();
    expect(repeatedAim.projectilePressed, isTrue);
    expect(repeatedAim.aimDirX, 0);
    expect(repeatedAim.aimDirY, -1);

    harness.adapter.handlePointerPosition(const Offset(401, 100));
    harness.keyDown(PhysicalKeyboardKey.keyK);
    harness.advance();
    harness.keyUp(PhysicalKeyboardKey.keyK);
    final defaultAim = harness.advance();
    expect(defaultAim.projectilePressed, isTrue);
    expect(defaultAim.aimDirX, isNull);
    expect(defaultAim.aimDirY, isNull);

    harness.adapter.handlePointerPosition(const Offset(100, 100));
    harness.keyDown(PhysicalKeyboardKey.keyK);
    harness.advance();
    harness.keyUp(PhysicalKeyboardKey.keyK);
    final reentered = harness.advance();
    expect(reentered.projectilePressed, isTrue);
    expect(reentered.aimDirX, -1);
    expect(reentered.aimDirY, 0);

    harness.adapter.handlePointerExit();
    harness.keyDown(PhysicalKeyboardKey.keyK);
    harness.advance();
    harness.keyUp(PhysicalKeyboardKey.keyK);
    final exited = harness.advance();
    expect(exited.projectilePressed, isTrue);
    expect(exited.aimDirX, isNull);
    expect(exited.aimDirY, isNull);
  });

  testWidgets('focus loss cancels held input before notifying the host', (
    tester,
  ) async {
    final order = <String>[];
    late final _DesktopHarness harness;
    harness = _DesktopHarness(
      modes: const <RunnerGameplayAction, AbilityInputMode>{
        RunnerGameplayAction.primary: AbilityInputMode.holdMaintain,
      },
      onFocusLost: () => order.add('focus-lost'),
      onCancelPresentation: () => order.add('presentation-canceled'),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RunnerDesktopInputAdapter(
          controller: harness.adapter,
          child: const SizedBox(width: 400, height: 200),
        ),
      ),
    );

    harness.adapter.requestFocus();
    await tester.pump();
    expect(harness.adapter.focusNode.hasFocus, isTrue);
    order.clear();

    harness.keyDown(PhysicalKeyboardKey.keyJ);
    harness.advance();
    harness.adapter.releaseFocus();
    await tester.pump();
    final canceled = harness.advance();

    expect(canceled.abilitySlotHeldChangedMask, 1 << AbilitySlot.primary.index);
    expect(canceled.abilitySlotHeldValueMask, 0);
    expect(order.first, 'presentation-canceled');
    expect(order, contains('focus-lost'));
    expect(harness.adapter.focusNode.hasFocus, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    harness.adapter.dispose();
  });

  testWidgets('only a mouse click inside the game viewport acquires focus', (
    tester,
  ) async {
    const surfaceKey = Key('desktop-input-surface');
    final harness = _DesktopHarness();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            key: surfaceKey,
            width: 400,
            height: 200,
            child: RunnerDesktopInputAdapter(
              controller: harness.adapter,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    final surfaceCenter = tester.getCenter(find.byKey(surfaceKey));

    await tester.tapAt(surfaceCenter);
    await tester.pump();
    expect(harness.adapter.focusNode.hasFocus, isFalse);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: surfaceCenter);
    await mouse.down(surfaceCenter);
    await tester.pump();
    expect(harness.adapter.focusNode.hasFocus, isTrue);
    await mouse.up();

    await tester.pumpWidget(const SizedBox.shrink());
    harness.adapter.dispose();
  });

  testWidgets('pause and disposal are repeatable neutralization paths', (
    tester,
  ) async {
    final harness = _DesktopHarness(
      modes: const <RunnerGameplayAction, AbilityInputMode>{
        RunnerGameplayAction.secondary: AbilityInputMode.holdMaintain,
      },
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RunnerDesktopInputAdapter(
          controller: harness.adapter,
          child: const SizedBox(width: 400, height: 200),
        ),
      ),
    );
    harness.adapter.requestFocus();
    await tester.pump();

    harness.keyDown(PhysicalKeyboardKey.keyQ);
    harness.advance();
    harness.adapter.cancelForPause();
    harness.adapter.cancelForPause();
    final paused = harness.advance();
    expect(paused.abilitySlotHeldChangedMask, 1 << AbilitySlot.secondary.index);
    expect(paused.abilitySlotHeldValueMask, 0);
    expect(harness.adapter.focusNode.hasFocus, isTrue);

    harness.keyDown(PhysicalKeyboardKey.keyQ);
    harness.advance();
    await tester.pumpWidget(const SizedBox.shrink());
    harness.adapter.dispose();
    final disposed = harness.advance();
    expect(
      disposed.abilitySlotHeldChangedMask,
      1 << AbilitySlot.secondary.index,
    );
    expect(disposed.abilitySlotHeldValueMask, 0);
    harness.adapter.dispose();
  });
}

final class _DesktopHarness {
  _DesktopHarness({
    Map<RunnerGameplayAction, AbilityInputMode>? modes,
    VoidCallback? onFocusLost,
    VoidCallback? onCancelPresentation,
  }) : modes = modes ?? <RunnerGameplayAction, AbilityInputMode>{} {
    final core = GameCore(
      levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
      playerCharacter: testPlayerCharacter,
      seed: 1,
      tickHz: 60,
    );
    controller = GameController(core: core);
    dispatcher = RunnerSemanticActionDispatcher(
      input: RunnerInputRouter(controller: controller),
      resolveInputMode: (action) => this.modes[action] ?? AbilityInputMode.tap,
    );
    adapter = RunnerDesktopInputController(
      dispatcher: dispatcher,
      resolveAimGeometry: () => const RunnerDesktopAimGeometry(
        viewportRect: Rect.fromLTWH(0, 0, 400, 200),
        playerPosition: Offset(200, 100),
      ),
      onFocusLost: onFocusLost,
      onCancelPresentation: onCancelPresentation,
    );
    controller.addAppliedCommandFrameListener(frames.add);
  }

  final Map<RunnerGameplayAction, AbilityInputMode> modes;
  late final GameController controller;
  late final RunnerSemanticActionDispatcher dispatcher;
  late final RunnerDesktopInputController adapter;
  final List<ReplayCommandFrameV1> frames = <ReplayCommandFrameV1>[];

  KeyEventResult keyDown(PhysicalKeyboardKey key) {
    return adapter.handleKeyEvent(
      KeyDownEvent(
        physicalKey: key,
        logicalKey: LogicalKeyboardKey.keyA,
        timeStamp: Duration.zero,
      ),
    );
  }

  KeyEventResult keyRepeat(PhysicalKeyboardKey key) {
    return adapter.handleKeyEvent(
      KeyRepeatEvent(
        physicalKey: key,
        logicalKey: LogicalKeyboardKey.keyA,
        timeStamp: Duration.zero,
      ),
    );
  }

  KeyEventResult keyUp(PhysicalKeyboardKey key) {
    return adapter.handleKeyEvent(
      KeyUpEvent(
        physicalKey: key,
        logicalKey: LogicalKeyboardKey.keyA,
        timeStamp: Duration.zero,
      ),
    );
  }

  ReplayCommandFrameV1 advance() {
    dispatcher.pumpHeldInputs();
    controller.advanceFrame(1 / controller.tickHz);
    return frames.last;
  }
}
