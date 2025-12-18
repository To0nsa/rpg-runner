import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/game_core.dart';
import 'package:walkscape_runner/core/tuning/v0_resource_tuning.dart';

void main() {
  test('resource regen increases toward max and clamps (via snapshot HUD)', () {
    final core = GameCore(
      seed: 1,
      tickHz: 10,
      playerBody: const BodyDef(isKinematic: true, useGravity: false),
      resourceTuning: const V0ResourceTuning(
        playerHpMax: 100,
        playerHpRegenPerSecond: 10,
        playerHpStart: 50,
        playerManaMax: 10,
        playerManaRegenPerSecond: 1,
        playerManaStart: 0,
        playerStaminaMax: 20,
        playerStaminaRegenPerSecond: 2,
        playerStaminaStart: 0,
      ),
    );

    // dt=0.1s per tick at 10Hz.
    core.stepOneTick();
    var hud = core.buildSnapshot().hud;
    expect(hud.hp, closeTo(51.0, 1e-9));
    expect(hud.mana, closeTo(0.1, 1e-9));
    expect(hud.stamina, closeTo(0.2, 1e-9));

    // Run long enough to exceed maxima; values should clamp exactly to max.
    for (var i = 0; i < 200; i += 1) {
      core.stepOneTick();
    }
    hud = core.buildSnapshot().hud;
    expect(hud.hp, closeTo(100.0, 1e-9));
    expect(hud.mana, closeTo(10.0, 1e-9));
    expect(hud.stamina, closeTo(20.0, 1e-9));
  });
}

