import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/game_core.dart';
import 'package:rpg_runner/core/players/player_character_registry.dart';
import 'package:rpg_runner/core/players/player_catalog.dart';
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_id.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';
import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/util/tick_math.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/game/input/runner_input_router.dart';

import 'test_tunings.dart';

void main() {
  test('projectile aim dir is quantized (stable payload) before casting', () {
    final base = PlayerCharacterRegistry.eloise;
    final core = GameCore(
      seed: 1,
      tickHz: 60,
      tuning: noAutoscrollTuning,
      playerCharacter: base.copyWith(
        catalog: const PlayerCatalog(
          bodyTemplate: BodyDef(useGravity: false),
          projectileItemId: ProjectileItemId.iceBolt,
          abilityProjectileId: 'eloise.ice_bolt',
        ),
        tuning: base.tuning.copyWith(
          resource: const ResourceTuning(
            playerManaMax: 20,
            playerManaRegenPerSecond: 0,
          ),
        ),
      ),
    );
    final controller = GameController(core: core);
    final input = RunnerInputRouter(controller: controller);

    const rawX = 0.123456;
    const rawY = 0.234567;
    input.setProjectileAimDir(rawX, rawY);
    input.pressProjectileWithAim();

    final dt = 1.0 / controller.tickHz;
    final windupTicks = ticksFromSecondsCeil(
      AbilityCatalog.tryGet('eloise.ice_bolt')!.windupTicks / 60.0,
      controller.tickHz,
    );

    // Advance to spawn tick, then one more for movement.
    for (var i = 0; i < windupTicks + 2; i += 1) {
      input.pumpHeldInputs();
      controller.advanceFrame(dt);
    }

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
