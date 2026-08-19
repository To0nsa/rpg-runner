import 'package:flutter_test/flutter_test.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/game/input/runner_gameplay_action.dart';
import 'package:rpg_runner/game/input/runner_input_router.dart';
import 'package:rpg_runner/game/input/runner_semantic_action_dispatcher.dart';

import '../../support/test_level.dart';
import '../../test_tunings.dart';

void main() {
  test('tap actions emit every one-shot command without pressed state', () {
    final harness = _InputHarness();

    for (final action in const <RunnerGameplayAction>[
      RunnerGameplayAction.jump,
      RunnerGameplayAction.primary,
      RunnerGameplayAction.secondary,
      RunnerGameplayAction.projectile,
      RunnerGameplayAction.spell,
      RunnerGameplayAction.mobility,
    ]) {
      harness.dispatcher.triggerAction(action);
    }
    final frame = harness.advance();

    expect(frame.jumpPressed, isTrue);
    expect(frame.strikePressed, isTrue);
    expect(frame.secondaryPressed, isTrue);
    expect(frame.projectilePressed, isTrue);
    expect(frame.spellPressed, isTrue);
    expect(frame.dashPressed, isTrue);
    expect(frame.abilitySlotHeldChangedMask, 0);
  });

  test('duplicate desktop tap begins emit one action edge', () {
    final harness = _InputHarness();

    harness.dispatcher.beginAction(RunnerGameplayAction.jump);
    harness.dispatcher.beginAction(RunnerGameplayAction.jump);
    final frame = harness.advance();
    harness.dispatcher.releaseAction(RunnerGameplayAction.jump);

    expect(frame.pressedMask, ReplayCommandFrameV1.pressedJumpBit);
  });

  for (final action in const <RunnerGameplayAction>[
    RunnerGameplayAction.primary,
    RunnerGameplayAction.secondary,
    RunnerGameplayAction.projectile,
    RunnerGameplayAction.mobility,
  ]) {
    for (final mode in const <AbilityInputMode>[
      AbilityInputMode.holdAimRelease,
      AbilityInputMode.holdRelease,
    ]) {
      test('${action.name} ${mode.name} commits and releases in one frame', () {
        final harness = _InputHarness(
          modes: <RunnerGameplayAction, AbilityInputMode>{action: mode},
        );
        final bit = 1 << _slotFor(action).index;

        harness.dispatcher.beginAction(action);
        expect(
          harness.advance().abilitySlotHeldValueMask,
          bit,
          reason: '${action.name} begins held',
        );

        harness.dispatcher.setAimDir(0, -1);
        harness.dispatcher.releaseAction(action);
        final release = harness.advance();

        expect(release.abilitySlotHeldChangedMask & bit, bit);
        expect(release.abilitySlotHeldValueMask & bit, 0);
        expect(release.aimDirX, 0);
        expect(release.aimDirY, -1);
        expect(
          release.pressedMask & _pressedBitFor(action),
          _pressedBitFor(action),
        );
      });
    }
  }

  for (final action in const <RunnerGameplayAction>[
    RunnerGameplayAction.primary,
    RunnerGameplayAction.secondary,
    RunnerGameplayAction.mobility,
  ]) {
    test('${action.name} hold-maintain commits on begin and ends once', () {
      final harness = _InputHarness(
        modes: <RunnerGameplayAction, AbilityInputMode>{
          action: AbilityInputMode.holdMaintain,
        },
      );
      final bit = 1 << _slotFor(action).index;

      harness.dispatcher.beginAction(action);
      harness.dispatcher.beginAction(action);
      final begin = harness.advance();
      expect(begin.abilitySlotHeldValueMask & bit, bit);
      expect(
        begin.pressedMask & _pressedBitFor(action),
        _pressedBitFor(action),
      );

      harness.dispatcher.releaseAction(action);
      harness.dispatcher.releaseAction(action);
      final end = harness.advance();
      expect(end.abilitySlotHeldChangedMask & bit, bit);
      expect(end.abilitySlotHeldValueMask & bit, 0);
      expect(end.pressedMask & _pressedBitFor(action), 0);
    });
  }

  test('directional touch commit before end preserves one release edge', () {
    final harness = _InputHarness(
      modes: const <RunnerGameplayAction, AbilityInputMode>{
        RunnerGameplayAction.primary: AbilityInputMode.holdAimRelease,
      },
    );

    harness.dispatcher.beginAction(RunnerGameplayAction.primary);
    harness.advance();
    harness.dispatcher.setAimDir(1, 0);
    harness.dispatcher.commitAction(RunnerGameplayAction.primary);
    harness.dispatcher.endAction(RunnerGameplayAction.primary);
    final release = harness.advance();

    expect(release.strikePressed, isTrue);
    expect(release.abilitySlotHeldChangedMask, 1 << AbilitySlot.primary.index);
    expect(release.abilitySlotHeldValueMask, 0);
  });

  test('hold touch end before commit preserves one release edge', () {
    final harness = _InputHarness(
      modes: const <RunnerGameplayAction, AbilityInputMode>{
        RunnerGameplayAction.secondary: AbilityInputMode.holdRelease,
      },
    );

    harness.dispatcher.beginAction(RunnerGameplayAction.secondary);
    harness.advance();
    harness.dispatcher.endAction(RunnerGameplayAction.secondary);
    harness.dispatcher.commitAction(RunnerGameplayAction.secondary);
    final release = harness.advance();

    expect(release.secondaryPressed, isTrue);
    expect(
      release.abilitySlotHeldChangedMask,
      1 << AbilitySlot.secondary.index,
    );
    expect(release.abilitySlotHeldValueMask, 0);
  });

  test('cancel ends a release mode without committing', () {
    final harness = _InputHarness(
      modes: const <RunnerGameplayAction, AbilityInputMode>{
        RunnerGameplayAction.projectile: AbilityInputMode.holdAimRelease,
      },
    );

    harness.dispatcher.beginAction(RunnerGameplayAction.projectile);
    harness.advance();
    harness.dispatcher.cancelAction(RunnerGameplayAction.projectile);
    final canceled = harness.advance();

    expect(canceled.projectilePressed, isFalse);
    expect(
      canceled.abilitySlotHeldChangedMask,
      1 << AbilitySlot.projectile.index,
    );
    expect(canceled.abilitySlotHeldValueMask, 0);
  });

  test('mode is retained from begin through release', () {
    final modes = <RunnerGameplayAction, AbilityInputMode>{
      RunnerGameplayAction.mobility: AbilityInputMode.holdRelease,
    };
    final harness = _InputHarness(modes: modes);

    harness.dispatcher.beginAction(RunnerGameplayAction.mobility);
    harness.advance();
    modes[RunnerGameplayAction.mobility] = AbilityInputMode.tap;
    harness.dispatcher.releaseAction(RunnerGameplayAction.mobility);
    final release = harness.advance();

    expect(release.dashPressed, isTrue);
    expect(release.abilitySlotHeldChangedMask, 1 << AbilitySlot.mobility.index);
    expect(release.abilitySlotHeldValueMask, 0);
  });

  test('opposing digital movement is neutral and release recomputes', () {
    final harness = _InputHarness();

    harness.dispatcher.beginAction(RunnerGameplayAction.moveLeft);
    harness.dispatcher.pumpHeldInputs();
    expect(harness.advance().moveAxis, -1);

    harness.dispatcher.beginAction(RunnerGameplayAction.moveRight);
    harness.dispatcher.pumpHeldInputs();
    expect(harness.advance().moveAxis, isNull);

    harness.dispatcher.endAction(RunnerGameplayAction.moveLeft);
    harness.dispatcher.pumpHeldInputs();
    expect(harness.advance().moveAxis, 1);

    harness.dispatcher.endAction(RunnerGameplayAction.moveRight);
    harness.dispatcher.pumpHeldInputs();
    expect(harness.advance().moveAxis, isNull);
  });

  test('cancelAll neutralizes held state and is idempotent', () {
    final harness = _InputHarness(
      modes: const <RunnerGameplayAction, AbilityInputMode>{
        RunnerGameplayAction.primary: AbilityInputMode.holdMaintain,
      },
    );

    harness.dispatcher.beginAction(RunnerGameplayAction.moveRight);
    harness.dispatcher.beginAction(RunnerGameplayAction.primary);
    harness.dispatcher.setAimDir(0, 1);
    harness.dispatcher.pumpHeldInputs();
    harness.advance();

    harness.dispatcher.cancelAll();
    harness.dispatcher.cancelAll();
    final neutral = harness.advance();

    expect(neutral.moveAxis, isNull);
    expect(neutral.aimDirX, isNull);
    expect(neutral.aimDirY, isNull);
    expect(neutral.abilitySlotHeldChangedMask, 1 << AbilitySlot.primary.index);
    expect(neutral.abilitySlotHeldValueMask, 0);
    expect(neutral.pressedMask, 0);
  });

  test('unsupported action and mode pairs fail explicitly', () {
    final projectile = _InputHarness(
      modes: const <RunnerGameplayAction, AbilityInputMode>{
        RunnerGameplayAction.projectile: AbilityInputMode.holdMaintain,
      },
    );
    expect(
      () => projectile.dispatcher.beginAction(RunnerGameplayAction.projectile),
      throwsA(
        isA<UnsupportedError>().having(
          (error) => error.message,
          'message',
          contains('runner_input_unsupported_mode'),
        ),
      ),
    );

    final spell = _InputHarness(
      modes: const <RunnerGameplayAction, AbilityInputMode>{
        RunnerGameplayAction.spell: AbilityInputMode.holdRelease,
      },
    );
    expect(
      () => spell.dispatcher.beginAction(RunnerGameplayAction.spell),
      throwsA(isA<UnsupportedError>()),
    );

    final jump = _InputHarness(
      modes: const <RunnerGameplayAction, AbilityInputMode>{
        RunnerGameplayAction.jump: AbilityInputMode.holdMaintain,
      },
    );
    expect(
      () => jump.dispatcher.beginAction(RunnerGameplayAction.jump),
      throwsA(isA<UnsupportedError>()),
    );
  });
}

final class _InputHarness {
  _InputHarness({Map<RunnerGameplayAction, AbilityInputMode>? modes})
    : modes = modes ?? <RunnerGameplayAction, AbilityInputMode>{} {
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
    controller.addAppliedCommandFrameListener(frames.add);
  }

  final Map<RunnerGameplayAction, AbilityInputMode> modes;
  late final GameController controller;
  late final RunnerSemanticActionDispatcher dispatcher;
  final List<ReplayCommandFrameV1> frames = <ReplayCommandFrameV1>[];

  ReplayCommandFrameV1 advance() {
    controller.advanceFrame(1 / controller.tickHz);
    return frames.last;
  }
}

AbilitySlot _slotFor(RunnerGameplayAction action) {
  return switch (action) {
    RunnerGameplayAction.primary => AbilitySlot.primary,
    RunnerGameplayAction.secondary => AbilitySlot.secondary,
    RunnerGameplayAction.projectile => AbilitySlot.projectile,
    RunnerGameplayAction.mobility => AbilitySlot.mobility,
    RunnerGameplayAction.jump ||
    RunnerGameplayAction.spell ||
    RunnerGameplayAction.moveLeft ||
    RunnerGameplayAction.moveRight => throw ArgumentError.value(action),
  };
}

int _pressedBitFor(RunnerGameplayAction action) {
  return switch (action) {
    RunnerGameplayAction.primary => ReplayCommandFrameV1.pressedStrikeBit,
    RunnerGameplayAction.secondary => ReplayCommandFrameV1.pressedSecondaryBit,
    RunnerGameplayAction.projectile =>
      ReplayCommandFrameV1.pressedProjectileBit,
    RunnerGameplayAction.mobility => ReplayCommandFrameV1.pressedDashBit,
    RunnerGameplayAction.jump => ReplayCommandFrameV1.pressedJumpBit,
    RunnerGameplayAction.spell => ReplayCommandFrameV1.pressedSpellBit,
    RunnerGameplayAction.moveLeft ||
    RunnerGameplayAction.moveRight => throw ArgumentError.value(action),
  };
}
