import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/commands/command.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/game_core.dart';
import 'package:rpg_runner/core/players/player_character_registry.dart';
import 'package:rpg_runner/core/players/player_catalog.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';

import '../test_tunings.dart';

void main() {
  test(
    'resource regen refills after spending and clamps at max (via snapshot HUD)',
    () {
      final base = PlayerCharacterRegistry.eloise;
      final core = GameCore(
        seed: 1,
        tickHz: 10,
        tuning: noAutoscrollTuning,
        playerCharacter: base.copyWith(
          catalog: const PlayerCatalog(bodyTemplate: BodyDef(useGravity: false)),
          tuning: base.tuning.copyWith(
            resource: const ResourceTuning(
              playerHpMax: 100,
              playerHpRegenPerSecond: 10,
              playerManaMax: 10,
              playerManaRegenPerSecond: 1,
              playerStaminaMax: 20,
              playerStaminaRegenPerSecond: 2,
            ),
          ),
        ),
      );

      // Player spawns at max resources.
      var hud = core.buildSnapshot().hud;
      expect(hud.hp, closeTo(100.0, 1e-9));
      expect(hud.mana, closeTo(10.0, 1e-9));
      expect(hud.stamina, closeTo(20.0, 1e-9));

      // Spend mana and stamina on separate ticks (dash preempts combat).
      core.applyCommands(const [ProjectilePressedCommand(tick: 1)]);
      core.stepOneTick(); // tick 1: spend mana and apply regen (dt=0.1)
      core.applyCommands(const [DashPressedCommand(tick: 2)]);
      core.stepOneTick(); // tick 2: spend stamina and apply regen
      hud = core.buildSnapshot().hud;
      expect(hud.hp, closeTo(100.0, 1e-9));
      expect(hud.mana, lessThan(10.0));
      expect(hud.stamina, lessThan(20.0));

      // Run long enough to exceed maxima; values should clamp exactly to max.
      for (var i = 0; i < 200; i += 1) {
        // Clear latched inputs (e.g. dashPressed) so spending does not repeat.
        core.applyCommands(<Command>[]);
        core.stepOneTick();
      }
      hud = core.buildSnapshot().hud;
      expect(hud.hp, closeTo(100.0, 1e-9));
      expect(hud.mana, closeTo(10.0, 1e-9));
      expect(hud.stamina, closeTo(20.0, 1e-9));
    },
  );
}
