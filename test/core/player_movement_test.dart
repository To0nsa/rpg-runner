import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/commands/command.dart';
import 'package:walkscape_runner/core/contracts/v0_render_contract.dart';
import 'package:walkscape_runner/core/game_core.dart';
import 'package:walkscape_runner/core/math/vec2.dart';
import 'package:walkscape_runner/core/tuning/v0_movement_tuning.dart';

void _tick(
  GameCore core, {
  double axis = 0,
  bool jumpPressed = false,
  bool dashPressed = false,
}) {
  final targetTick = core.tick + 1;
  final commands = <Command>[
    if (axis != 0) MoveAxisCommand(tick: targetTick, axis: axis),
    if (jumpPressed) JumpPressedCommand(tick: targetTick),
    if (dashPressed) DashPressedCommand(tick: targetTick),
  ];

  core.applyCommands(commands);
  core.stepOneTick();
}

void main() {
  test('accelerates toward desired horizontal speed', () {
    final core = GameCore(seed: 1, tickHz: v0DefaultTickHz);

    _tick(core, axis: 1);
    expect(core.playerVel.x, greaterThan(0));
    expect(
      core.playerVel.x,
      lessThanOrEqualTo(const V0MovementTuning().maxSpeedX),
    );

    // After a few ticks, velocity should keep increasing up to max speed.
    final v1 = core.playerVel.x;
    for (var i = 0; i < 5; i += 1) {
      _tick(core, axis: 1);
    }
    expect(core.playerVel.x, greaterThan(v1));
  });

  test('jump from ground sets upward velocity', () {
    final core = GameCore(seed: 1, tickHz: v0DefaultTickHz);
    final floorY =
        v0GroundTopY.toDouble() - const V0MovementTuning().playerRadius;

    expect(core.playerPos.y, closeTo(floorY, 1e-9));

    _tick(core, jumpPressed: true);

    // Jump is applied before gravity, but gravity still affects the final vY.
    expect(core.playerVel.y, lessThan(0));
    expect(core.playerPos.y, lessThan(floorY));
  });

  test('jump buffer triggers on the tick after landing', () {
    final core = GameCore(seed: 1, tickHz: v0DefaultTickHz);
    final tuning = const V0MovementTuning();
    final floorY = v0GroundTopY.toDouble() - tuning.playerRadius;

    // Put the player high above the floor so coyote time expires before landing.
    core.playerPos = core.playerPos.withY(floorY - 200);
    core.playerVel = const Vec2(0, 0);

    // Burn coyote time (default is 0.10s => 6 ticks at 60 Hz).
    for (var i = 0; i < 7; i += 1) {
      _tick(core);
      expect(core.playerPos.y, lessThan(floorY));
    }

    // Snap close to the ground while staying airborne (keeps coyote expired).
    core.playerPos = core.playerPos.withY(floorY - 5);
    core.playerVel = const Vec2(0, 0);

    // Press jump while still in the air (buffer should be stored, not executed).
    _tick(core, jumpPressed: true);
    expect(core.playerPos.y, lessThan(floorY));
    expect(core.playerVel.y, greaterThan(0)); // still falling after gravity

    // Simulate until landing.
    var safety = 60;
    while (core.playerPos.y < floorY && safety > 0) {
      _tick(core);
      safety -= 1;
    }
    expect(safety, greaterThan(0));
    expect(core.playerPos.y, closeTo(floorY, 1e-9));
    expect(core.playerVel.y, closeTo(0, 1e-9));

    // Next tick: buffered jump should fire due to grounded state from previous tick.
    _tick(core);
    expect(core.playerVel.y, lessThan(0));
  });

  test('dash sets constant horizontal speed and cancels vertical velocity', () {
    final core = GameCore(seed: 1, tickHz: v0DefaultTickHz);
    final tuning = const V0MovementTuning();
    final floorY = v0GroundTopY.toDouble() - tuning.playerRadius;

    // Start dashing from the ground.
    _tick(core, dashPressed: true);

    expect(core.playerVel.x, closeTo(tuning.dashSpeedX, 1e-9));
    expect(core.playerVel.y, closeTo(0, 1e-9));
    expect(core.playerPos.y, closeTo(floorY, 1e-9));
  });
}
