import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/game_core.dart';
import 'package:walkscape_runner/core/players/player_catalog.dart';
import 'package:walkscape_runner/core/snapshots/enums.dart';
import 'package:walkscape_runner/core/tuning/movement_tuning.dart';
import 'package:walkscape_runner/core/tuning/resource_tuning.dart';
import 'package:walkscape_runner/game/game_controller.dart';
import 'package:walkscape_runner/game/input/runner_input_router.dart';

import 'test_tunings.dart';

void main() {
  test('move axis release overwrites buffered future ticks', () {
    final core = GameCore.withTunings(
      seed: 1,
      tickHz: 60,
      playerCatalog: const PlayerCatalog(
        bodyTemplate: BodyDef(useGravity: false),
      ),
      cameraTuning: noAutoscrollCameraTuning,
      movementTuning: const MovementTuning(
        maxSpeedX: 100,
        accelerationX: 100000,
        decelerationX: 100000,
        minMoveSpeed: 0,
      ),
    );
    final controller = GameController(core: core);
    final input = RunnerInputRouter(controller: controller);

    final dt = 1.0 / controller.tickHz;

    input.setMoveAxis(1);
    input.pumpHeldInputs();
    controller.advanceFrame(dt);
    expect(core.tick, 1);
    expect(core.playerVelX, greaterThan(0));

    input.setMoveAxis(0);
    input.pumpHeldInputs();
    controller.advanceFrame(dt);
    expect(core.tick, 2);

    // With a huge deceleration, releasing move input should stop immediately.
    expect(core.playerVelX, closeTo(0.0, 1e-9));
  });

  test(
    'projectile aim clear overwrites buffered future ticks (affects cast direction)',
    () {
      final core = GameCore.withTunings(
        seed: 1,
        tickHz: 60,
        playerCatalog: const PlayerCatalog(
          bodyTemplate: BodyDef(useGravity: false),
        ),
        cameraTuning: noAutoscrollCameraTuning,
        resourceTuning: const ResourceTuning(
          playerManaMax: 20,
          playerManaRegenPerSecond: 0,
        ),
      );
      final controller = GameController(core: core);
      final input = RunnerInputRouter(controller: controller);

      final dt = 1.0 / controller.tickHz;

      // Hold aim straight down for a frame; this will pre-buffer projectile aim
      // direction for upcoming ticks.
      input.setProjectileAimDir(0, 1);
      input.pumpHeldInputs();
      controller.advanceFrame(dt);
      expect(core.tick, 1);

      // Release aim and cast without setting a new aim direction. Cast should
      // fall back to facing (right), not the previously buffered aim.
      input.clearProjectileAimDir();
      input.pressCast();
      input.pumpHeldInputs();
      controller.advanceFrame(dt); // tick 2 (spawns projectile)
      controller.advanceFrame(dt); // tick 3 (projectile gets velocity)

      final snapshot = core.buildSnapshot();
      final projectiles = snapshot.entities
          .where((e) => e.kind == EntityKind.projectile)
          .toList();
      expect(projectiles.length, 1);
      final projectile = projectiles.single;

      expect(projectile.vel, isNotNull);
      expect(projectile.vel!.x, greaterThan(0));
      expect(projectile.vel!.y.abs(), lessThan(1e-9));
    },
  );

  test('release-to-cast keeps aimed dir for the cast tick', () {
    final core = GameCore.withTunings(
      seed: 1,
      tickHz: 60,
      playerCatalog: const PlayerCatalog(
        bodyTemplate: BodyDef(useGravity: false),
      ),
      cameraTuning: noAutoscrollCameraTuning,
      resourceTuning: const ResourceTuning(
        playerManaMax: 20,
        playerManaRegenPerSecond: 0,
      ),
    );
    final controller = GameController(core: core);
    final input = RunnerInputRouter(controller: controller);

    final dt = 1.0 / controller.tickHz;

    input.setProjectileAimDir(0, -1);
    input.commitCastWithAim(clearAim: true);

    input.pumpHeldInputs();
    controller.advanceFrame(dt); // tick 1: cast spawns
    input.pumpHeldInputs();
    controller.advanceFrame(dt); // tick 2: projectile moves

    final snapshot = core.buildSnapshot();
    final projectiles = snapshot.entities
        .where((e) => e.kind == EntityKind.projectile)
        .toList();
    expect(projectiles.length, 1);
    final projectile = projectiles.single;

    expect(projectile.vel, isNotNull);
    expect(projectile.vel!.y, lessThan(0));
    expect(projectile.vel!.x.abs(), lessThan(1e-6));
  });
}
