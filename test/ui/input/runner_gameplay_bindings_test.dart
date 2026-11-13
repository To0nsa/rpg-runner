import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/training/authored_training_field.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/game/input/aim_preview.dart';
import 'package:rpg_runner/game/input/runner_gameplay_action.dart';
import 'package:rpg_runner/game/input/runner_input_router.dart';
import 'package:rpg_runner/ui/haptics/haptics_cue.dart';
import 'package:rpg_runner/ui/haptics/haptics_service.dart';
import 'package:rpg_runner/ui/input/runner_gameplay_bindings.dart';

import '../../support/test_level.dart';
import '../../support/test_player.dart';
import '../../test_tunings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('damage cancels a charge without canceling movement or allowing late release', () {
    final h = _Harness(
      core: GameCore.trainingField(
        definition: trainingFieldDefinition,
        playerCharacter: PlayerCharacterRegistry.eloise,
        equippedLoadout: const EquippedLoadoutDef(
          abilityProjectileId: 'eloise.overcharge_shot',
        ),
      ),
    );
    addTearDown(h.dispose);
    h.controller.selectTrainingEnemy(EnemyId.grojib);
    h.binding.actions.setMoveAxis(1);
    for (
      var i = 0;
      i < 300 && h.controller.snapshot.playerEntity!.pos.x < 700;
      i++
    ) {
      h.advance();
    }
    h.binding.actions.setAimDir(1, 0);
    h.binding.actions.beginAction(RunnerGameplayAction.projectile);
    h.advance();
    expect(h.controller.snapshot.hud.chargeActive, isTrue);
    final damage = h.controller.snapshot.hud.lastDamageTick;
    final epoch = h.binding.movementEpoch;
    final cancel = h.binding.forceAimCancelSignal.value;
    for (
      var i = 0;
      i < 180 && h.controller.snapshot.hud.lastDamageTick == damage;
      i++
    ) {
      h.advance();
    }
    expect(h.controller.snapshot.hud.lastDamageTick, greaterThan(damage));
    expect(h.binding.forceAimCancelSignal.value, greaterThan(cancel));
    expect(h.binding.movementEpoch, epoch);
    expect(h.frames.last.moveAxis, 1);
    h.binding.actions.endAction(RunnerGameplayAction.projectile);
    h.binding.actions.commitAction(RunnerGameplayAction.projectile);
    expect(h.advance().projectilePressed, isFalse);
  });

  for (final desktop in [false, true]) {
    test(
      'charge timeout preserves movement and rejects late release (desktop: $desktop)',
      () {
        final h = _Harness(desktop: desktop);
        addTearDown(h.dispose);
        final binding = h.binding;
        binding.actions.setAimDir(1, 0);
        if (desktop) {
          binding.desktop!.handleKeyEvent(
            const KeyDownEvent(
              physicalKey: PhysicalKeyboardKey.keyD,
              logicalKey: LogicalKeyboardKey.keyD,
              timeStamp: Duration.zero,
            ),
          );
          binding.desktop!.handleKeyEvent(
            const KeyDownEvent(
              physicalKey: PhysicalKeyboardKey.keyK,
              logicalKey: LogicalKeyboardKey.keyK,
              timeStamp: Duration.zero,
            ),
          );
        } else {
          binding.actions.setMoveAxis(1);
          binding.actions.beginAction(RunnerGameplayAction.projectile);
        }
        h.advance();
        expect(h.controller.snapshot.hud.chargeActive, isTrue);
        final epoch = binding.movementEpoch;
        final cancel = binding.forceAimCancelSignal.value;
        for (var tick = 0; tick < 185; tick++) {
          h.advance();
        }
        expect(binding.forceAimCancelSignal.value, cancel + 1);
        expect(binding.movementEpoch, epoch);
        expect(h.frames.last.moveAxis, 1);
        expect(
          h.haptics.cues.where(
            (cue) => cue == UiHapticsCue.holdAbilityTimedOut,
          ),
          hasLength(1),
        );
        if (desktop) {
          binding.desktop!.handleKeyEvent(
            const KeyUpEvent(
              physicalKey: PhysicalKeyboardKey.keyK,
              logicalKey: LogicalKeyboardKey.keyK,
              timeStamp: Duration(seconds: 4),
            ),
          );
        } else {
          binding.actions.endAction(RunnerGameplayAction.projectile);
          binding.actions.commitAction(RunnerGameplayAction.projectile);
        }
        expect(h.advance().projectilePressed, isFalse);
        expect(h.frames.last.moveAxis, 1);
        expect(h.frames.where((frame) => frame.projectilePressed), isEmpty);
      },
    );
  }

  test(
    'full cancellation clears queued input and invalidates touch pointers',
    () {
      final h = _Harness(desktop: true);
      addTearDown(h.dispose);
      final binding = h.binding;
      binding.actions.setMoveAxis(1);
      binding.actions.beginAction(RunnerGameplayAction.projectile);
      h.advance();
      binding.actions.triggerAction(RunnerGameplayAction.jump);
      final epoch = binding.movementEpoch;
      binding.cancelAll();
      expect(binding.movementEpoch, epoch + 1);
      final frame = h.advance();
      // Neutral movement is omitted from the canonical applied frame.
      expect(frame.moveAxis, isNull);
      expect(frame.pressedMask, 0);
      expect(frame.abilitySlotHeldValueMask, 0);
    },
  );

  test('retired bindings ignore later controller ticks and charge events', () {
    final h = _Harness();
    addTearDown(h.dispose);
    h.binding.stop();
    final cancel = h.binding.forceAimCancelSignal.value;
    h.binding.actions.setAimDir(1, 0);
    h.binding.actions.beginAction(RunnerGameplayAction.projectile);
    for (var tick = 0; tick < 185; tick++) {
      h.advance();
    }
    expect(h.binding.forceAimCancelSignal.value, cancel);
    expect(h.haptics.cues, isEmpty);
  });
}

final class _Harness {
  _Harness({bool desktop = false, GameCore? core}) {
    controller = GameController(
      core:
          core ??
          GameCore(
            seed: 1,
            levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
            playerCharacter: PlayerCharacterRegistry.eloise.copyWith(
              catalog: testPlayerCatalog(
                bodyTemplate: const BodyDef(useGravity: false),
              ),
            ),
          ),
    );
    input = RunnerInputRouter(controller: controller);
    binding = RunnerGameplayBindings(
      controller: controller,
      input: input,
      projectilePreview: projectile,
      meleePreview: melee,
      haptics: haptics,
    );
    if (desktop) {
      binding.attachDesktop(resolveAimGeometry: () => null, onFocusLost: () {});
      binding.desktop!.setEnabled(true);
    }
    controller.addAppliedCommandFrameListener(frames.add);
  }

  final projectile = AimPreviewModel();
  final melee = AimPreviewModel();
  final haptics = _Haptics();
  final frames = <ReplayCommandFrameV1>[];
  late final GameController controller;
  late final RunnerInputRouter input;
  late final RunnerGameplayBindings binding;

  ReplayCommandFrameV1 advance() {
    input.pumpHeldInputs();
    controller.advanceFrame(1 / controller.tickHz);
    return frames.last;
  }

  void dispose() {
    binding.dispose();
    controller.dispose();
    projectile.dispose();
    melee.dispose();
  }
}

final class _Haptics implements UiHaptics {
  final cues = <UiHapticsCue>[];
  @override
  void trigger(UiHapticsCue cue, {UiHapticsIntensity? intensityOverride}) =>
      cues.add(cue);
}
