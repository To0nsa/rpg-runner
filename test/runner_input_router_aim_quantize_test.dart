import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/game_core.dart';
import 'package:walkscape_runner/core/players/player_catalog.dart';
import 'package:walkscape_runner/core/projectiles/projectile_catalog.dart';
import 'package:walkscape_runner/core/projectiles/projectile_id.dart';
import 'package:walkscape_runner/core/snapshots/enums.dart';
import 'package:walkscape_runner/core/tuning/resource_tuning.dart';
import 'package:walkscape_runner/game/game_controller.dart';
import 'package:walkscape_runner/game/input/runner_input_router.dart';

import 'test_tunings.dart';

void main() {
  test('projectile aim dir is quantized (stable payload) before casting', () {
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

    const rawX = 0.123456;
    const rawY = 0.234567;
    input.setProjectileAimDir(rawX, rawY);
    input.pressCastWithAim();

    input.pumpHeldInputs();
    controller.advanceFrame(1.0 / controller.tickHz); // tick 1: cast spawns
    input.pumpHeldInputs();
    controller.advanceFrame(
      1.0 / controller.tickHz,
    ); // tick 2: projectile moves

    final snapshot = core.buildSnapshot();
    final projectiles = snapshot.entities
        .where((e) => e.kind == EntityKind.projectile)
        .toList();
    expect(projectiles.length, 1);
    final p = projectiles.single;
    expect(p.vel, isNotNull);

    const quantizeScale = 256.0;
    final qx = (rawX * quantizeScale).roundToDouble() / quantizeScale;
    final qy = (rawY * quantizeScale).roundToDouble() / quantizeScale;
    final len = sqrt(qx * qx + qy * qy);
    final nx = qx / len;
    final ny = qy / len;

    final speed = ProjectileCatalog()
        .get(ProjectileId.iceBolt)
        .speedUnitsPerSecond;
    expect(p.vel!.x / speed, closeTo(nx, 1e-9));
    expect(p.vel!.y / speed, closeTo(ny, 1e-9));
  });
}
