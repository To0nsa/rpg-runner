import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/commands/command.dart';
import 'package:walkscape_runner/core/contracts/render_contract.dart';
import 'package:walkscape_runner/core/game_core.dart';
import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/players/player_catalog.dart';
import 'package:walkscape_runner/core/tuning/movement_tuning.dart';
import 'package:walkscape_runner/core/tuning/resource_tuning.dart';

import '../test_tunings.dart';

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
    final core = GameCore.withTunings(
      seed: 1,
      tickHz: defaultTickHz,
      cameraTuning: noAutoscrollCameraTuning,
    );

    _tick(core, axis: 1);
    expect(core.playerVelX, greaterThan(0));
    expect(
      core.playerVelX,
      lessThanOrEqualTo(const MovementTuning().maxSpeedX),
    );

    // After a few ticks, velocity should keep increasing up to max speed.
    final v1 = core.playerVelX;
    for (var i = 0; i < 5; i += 1) {
      _tick(core, axis: 1);
    }
    expect(core.playerVelX, greaterThan(v1));
  });

  test('jump from ground sets upward velocity', () {
    final core = GameCore.withTunings(
      seed: 1,
      tickHz: defaultTickHz,
      cameraTuning: noAutoscrollCameraTuning,
    );
    final floorY =
        groundTopY.toDouble() - const MovementTuning().playerRadius;

    expect(core.playerPosY, closeTo(floorY, 1e-9));
    expect(core.playerGrounded, isTrue);

    _tick(core, jumpPressed: true);

    // Jump is applied before gravity, but gravity still affects the final vY.
    expect(core.playerVelY, lessThan(0));
    expect(core.playerPosY, lessThan(floorY));
    expect(core.playerGrounded, isFalse);
  });

  test('jump buffer triggers on the tick after landing', () {
    final core = GameCore.withTunings(
      seed: 1,
      tickHz: defaultTickHz,
      cameraTuning: noAutoscrollCameraTuning,
    );
    final tuning = const MovementTuning();
    final floorY = groundTopY.toDouble() - tuning.playerRadius;

    // Put the player high above the floor so coyote time expires before landing.
    core.setPlayerPosXY(core.playerPosX, floorY - 200);
    core.setPlayerVelXY(0, 0);

    // Burn coyote time (default is 0.10s => 6 ticks at 60 Hz).
    for (var i = 0; i < 7; i += 1) {
      _tick(core);
      expect(core.playerPosY, lessThan(floorY));
      expect(core.playerGrounded, isFalse);
    }

    // Snap close to the ground while staying airborne (keeps coyote expired).
    core.setPlayerPosXY(core.playerPosX, floorY - 5);
    core.setPlayerVelXY(0, 0);

    // Press jump while still in the air (buffer should be stored, not executed).
    _tick(core, jumpPressed: true);
    expect(core.playerPosY, lessThan(floorY));
    expect(core.playerVelY, greaterThan(0)); // still falling after gravity
    expect(core.playerGrounded, isFalse);

    // Simulate until landing.
    var safety = 60;
    while (core.playerPosY < floorY && safety > 0) {
      _tick(core);
      safety -= 1;
    }
    expect(safety, greaterThan(0));
    expect(core.playerPosY, closeTo(floorY, 1e-9));
    expect(core.playerVelY, closeTo(0, 1e-9));
    expect(core.playerGrounded, isTrue);

    // Next tick: buffered jump should fire due to grounded state from previous tick.
    _tick(core);
    expect(core.playerVelY, lessThan(0));
    expect(core.playerGrounded, isFalse);
  });

  test('dash sets constant horizontal speed and cancels vertical velocity', () {
    final core = GameCore.withTunings(
      seed: 1,
      tickHz: defaultTickHz,
      cameraTuning: noAutoscrollCameraTuning,
    );
    final tuning = const MovementTuning();
    final floorY = groundTopY.toDouble() - tuning.playerRadius;

    // Start dashing from the ground.
    _tick(core, dashPressed: true);

    expect(core.playerVelX, closeTo(tuning.dashSpeedX, 1e-9));
    expect(core.playerVelY, closeTo(0, 1e-9));
    expect(core.playerPosY, closeTo(floorY, 1e-9));
  });

  test('jump spends stamina (2) when executed', () {
    final core = GameCore.withTunings(
      seed: 1,
      tickHz: defaultTickHz,
      cameraTuning: noAutoscrollCameraTuning,
      resourceTuning: const ResourceTuning(
        playerStaminaMax: 10,
        playerStaminaRegenPerSecond: 0,
        jumpStaminaCost: 2,
      ),
    );

    _tick(core, jumpPressed: true);

    final hud = core.buildSnapshot().hud;
    expect(hud.stamina, closeTo(8.0, 1e-9));
  });

  test('dash spends stamina (2) when started', () {
    final core = GameCore.withTunings(
      seed: 1,
      tickHz: defaultTickHz,
      cameraTuning: noAutoscrollCameraTuning,
      resourceTuning: const ResourceTuning(
        playerStaminaMax: 10,
        playerStaminaRegenPerSecond: 0,
        dashStaminaCost: 2,
      ),
    );

    _tick(core, dashPressed: true);

    final hud = core.buildSnapshot().hud;
    expect(hud.stamina, closeTo(8.0, 1e-9));
  });

  test('insufficient stamina blocks dash and jump', () {
    final core = GameCore.withTunings(
      seed: 1,
      tickHz: defaultTickHz,
      cameraTuning: noAutoscrollCameraTuning,
      resourceTuning: const ResourceTuning(
        playerStaminaMax: 1,
        playerStaminaRegenPerSecond: 0,
        jumpStaminaCost: 2,
        dashStaminaCost: 2,
      ),
    );

    final floorY =
        groundTopY.toDouble() - const MovementTuning().playerRadius;
    expect(core.playerPosY, closeTo(floorY, 1e-9));
    expect(core.playerGrounded, isTrue);

    _tick(core, jumpPressed: true, dashPressed: true);

    // Without stamina, the buffered jump won't execute and dash won't start.
    expect(core.playerVelY, greaterThanOrEqualTo(0));
    expect(
      core.playerVelX.abs(),
      lessThan(const MovementTuning().dashSpeedX),
    );

    final hud = core.buildSnapshot().hud;
    expect(hud.stamina, closeTo(1.0, 1e-9));
  });

  test('Body.gravityScale=0 disables gravity integration', () {
    final core = GameCore.withTunings(
      seed: 1,
      tickHz: defaultTickHz,
      cameraTuning: noAutoscrollCameraTuning,
      playerCatalog: const PlayerCatalog(
        bodyTemplate: BodyDef(gravityScale: 0),
      ),
    );
    final tuning = const MovementTuning();
    final floorY = groundTopY.toDouble() - tuning.playerRadius;

    core.setPlayerPosXY(core.playerPosX, floorY - 120);
    core.setPlayerVelXY(0, 0);

    _tick(core);

    expect(core.playerVelY, closeTo(0, 1e-9));
    expect(core.playerPosY, closeTo(floorY - 120, 1e-9));
  });

  test('Body.isKinematic skips physics integration', () {
    final core = GameCore.withTunings(
      seed: 1,
      tickHz: defaultTickHz,
      cameraTuning: noAutoscrollCameraTuning,
      playerCatalog: const PlayerCatalog(
        bodyTemplate: BodyDef(isKinematic: true),
      ),
    );
    final tuning = const MovementTuning();
    final floorY = groundTopY.toDouble() - tuning.playerRadius;

    core.setPlayerPosXY(core.playerPosX, floorY - 120);
    core.setPlayerVelXY(0, 0);

    _tick(core, axis: 1, jumpPressed: true, dashPressed: true);

    expect(core.playerVelX, closeTo(0, 1e-9));
    expect(core.playerVelY, closeTo(0, 1e-9));
    expect(core.playerPosY, closeTo(floorY - 120, 1e-9));
  });

  test('Body.maxVelY clamps jump velocity', () {
    final core = GameCore.withTunings(
      seed: 1,
      tickHz: defaultTickHz,
      cameraTuning: noAutoscrollCameraTuning,
      movementTuning: const MovementTuning(maxVelY: 100),
    );

    _tick(core, jumpPressed: true);

    expect(core.playerVelY, closeTo(-100, 1e-9));
  });
}
