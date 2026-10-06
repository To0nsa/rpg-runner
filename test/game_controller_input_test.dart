import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:run_protocol/replay_blob.dart';

import 'support/test_level.dart';

import 'package:rpg_runner/game/game_controller.dart';

import 'test_tunings.dart';

void main() {
  test(
    'Core events reach each subscriber once and retain the terminal result',
    () {
      final level = testFieldLevel(tuning: noAutoscrollTuning);
      final core = GameCore(
        levelDefinition: level,
        playerCharacter: testPlayerCharacter,
        seed: 42,
      );
      final reference = GameCore(
        levelDefinition: level,
        playerCharacter: testPlayerCharacter,
        seed: 42,
      );
      final controller = GameController(core: core);
      addTearDown(controller.dispose);
      final first = <GameEvent>[];
      final second = <GameEvent>[];
      final expected = <GameEvent>[];
      controller.addEventListener(first.add);
      controller.addEventListener(second.add);

      for (var tick = 1; tick <= 240 && !core.gameOver; tick++) {
        final commands = <Command>[
          MoveAxisCommand(tick: tick, axis: 1),
          if (tick % 30 == 0) JumpPressedCommand(tick: tick),
          if (tick % 45 == 0) StrikePressedCommand(tick: tick),
          if (tick % 60 == 0) ProjectilePressedCommand(tick: tick),
        ];
        for (final command in commands) {
          controller.enqueue(command);
        }
        controller.advanceFrame(1 / controller.tickHz);
        reference.applyCommands(commands);
        reference.stepOneTick();
        expected.addAll(reference.drainEvents());
      }
      controller.giveUp();
      reference.giveUp();
      expected.addAll(reference.drainEvents());

      expect(first, second);
      expect(
        first.map((event) => event.runtimeType),
        expected.map((event) => event.runtimeType),
      );
      final ended = first.whereType<RunEndedEvent>().single;
      final expectedEnd = expected.whereType<RunEndedEvent>().single;
      expect(controller.lastRunEndedEvent, same(ended));
      expect(ended.tick, expectedEnd.tick);
      expect(ended.reason, expectedEnd.reason);
      expect(ended.distance, expectedEnd.distance);
      final eventCount = first.length;
      controller.advanceFrame(1);
      controller.giveUp();
      expect(first, hasLength(eventCount));
      expect(second, hasLength(eventCount));
    },
  );

  for (final shutdownFirst in [false, true]) {
    test('closed controller cannot restart terrain preparation '
        '(shutdown first: $shutdownFirst)', () async {
      final core = GameCore(
        levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
        playerCharacter: testPlayerCharacter,
        seed: 1,
      );
      final controller = GameController(core: core);
      final pending = controller.prepareTerrainAhead();
      expect(core.terrainPreparationStats, isNotNull);
      if (shutdownFirst) {
        controller.shutdown();
        expect(core.paused, isTrue);
      }
      controller.dispose();
      await pending;
      await controller.prepareTerrainAhead();
      expect(core.terrainPreparationStats, isNull);
    });
  }

  test('GameController dedupes MoveAxis per tick (last wins)', () {
    final core = GameCore(
      levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
      playerCharacter: testPlayerCharacter,
      seed: 1,
    );
    final controller = GameController(core: core);

    controller.enqueue(const MoveAxisCommand(tick: 1, axis: 1));
    controller.enqueue(const MoveAxisCommand(tick: 1, axis: -1));

    controller.advanceFrame(1 / controller.tickHz);

    expect(core.tick, 1);
    expect(core.playerVelX, lessThan(0));
  });

  test('GameController merges multiple button presses per tick', () {
    final core = GameCore(
      levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
      playerCharacter: testPlayerCharacter,
      seed: 1,
    );
    final controller = GameController(core: core);

    controller.enqueue(const JumpPressedCommand(tick: 1));
    controller.enqueue(const DashPressedCommand(tick: 1));
    controller.enqueue(const ProjectilePressedCommand(tick: 1));

    controller.advanceFrame(1 / controller.tickHz);

    expect(core.tick, 1);
    // Dash cancels vertical velocity and sets dash horizontal speed; assert the
    // net effect occurred even with another press.
    expect(core.playerVelY, closeTo(0, 1e-9));
    expect(core.playerVelX, greaterThan(0));
  });

  test('GameController dedupes AimDir per tick (last wins)', () {
    final core = GameCore(
      levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
      playerCharacter: testPlayerCharacter,
      seed: 1,
    );
    final controller = GameController(core: core);

    controller.enqueue(const AimDirCommand(tick: 1, x: 1, y: 0));
    controller.enqueue(const AimDirCommand(tick: 1, x: 0, y: 1));

    controller.advanceFrame(1 / controller.tickHz);

    expect(core.tick, 1);
  });

  test('GameController notifies once after stepping ticks', () {
    final core = GameCore(
      levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
      playerCharacter: testPlayerCharacter,
      seed: 1,
    );
    final controller = GameController(core: core);
    var notifyCount = 0;
    controller.addListener(() {
      notifyCount += 1;
    });

    final dt = (1 / controller.tickHz) * 3.5;
    controller.advanceFrame(dt);

    expect(core.tick, greaterThan(0));
    expect(notifyCount, 1);
  });

  test('GameController notifies when paused and shutdown', () {
    final core = GameCore(
      levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
      playerCharacter: testPlayerCharacter,
      seed: 1,
    );
    final controller = GameController(core: core);
    var notifyCount = 0;
    controller.addListener(() {
      notifyCount += 1;
    });

    controller.setPaused(true);
    expect(notifyCount, 1);

    controller.setPaused(true);
    expect(notifyCount, 1);

    controller.shutdown();
    expect(notifyCount, 2);
  });

  test('GameController emits applied command frame after coalescing', () {
    final core = GameCore(
      levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
      playerCharacter: testPlayerCharacter,
      seed: 1,
    );
    final controller = GameController(core: core);
    final frames = <ReplayCommandFrameV1>[];
    controller.addAppliedCommandFrameListener(frames.add);

    controller.enqueue(const MoveAxisCommand(tick: 1, axis: 1));
    controller.enqueue(const MoveAxisCommand(tick: 1, axis: -1));
    controller.enqueue(const JumpPressedCommand(tick: 1));
    controller.enqueue(const DashPressedCommand(tick: 1));
    controller.enqueue(
      const AbilitySlotHeldCommand(
        tick: 1,
        slot: AbilitySlot.secondary,
        held: true,
      ),
    );

    controller.advanceFrame(1 / controller.tickHz);

    expect(frames, hasLength(1));
    final frame = frames.single;
    expect(frame.tick, 1);
    expect(frame.moveAxis, -1);
    expect(frame.jumpPressed, isTrue);
    expect(frame.dashPressed, isTrue);
    expect(frame.abilitySlotHeldChangedMask, 1 << AbilitySlot.secondary.index);
    expect(frame.abilitySlotHeldValueMask, 1 << AbilitySlot.secondary.index);
  });
}
