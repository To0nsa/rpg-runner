import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/commands/command.dart';
import 'package:walkscape_runner/core/game_core.dart';
import 'package:walkscape_runner/game/game_controller.dart';

void main() {
  test('GameController dedupes MoveAxis per tick (last wins)', () {
    final core = GameCore(seed: 1);
    final controller = GameController(core: core);

    controller.enqueue(const MoveAxisCommand(tick: 1, axis: 1));
    controller.enqueue(const MoveAxisCommand(tick: 1, axis: -1));

    controller.advanceFrame(1 / controller.tickHz);

    expect(core.tick, 1);
    expect(core.playerVel.x, lessThan(0));
  });

  test('GameController merges multiple button presses per tick', () {
    final core = GameCore(seed: 1);
    final controller = GameController(core: core);

    controller.enqueue(const JumpPressedCommand(tick: 1));
    controller.enqueue(const DashPressedCommand(tick: 1));

    controller.advanceFrame(1 / controller.tickHz);

    expect(core.tick, 1);
    // Dash cancels vertical velocity and sets dash horizontal speed; assert the
    // net effect occurred even with another press.
    expect(core.playerVel.y, closeTo(0, 1e-9));
    expect(core.playerVel.x, greaterThan(0));
  });
}

