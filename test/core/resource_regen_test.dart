import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/accessories/accessory_catalog.dart';
import 'package:runner_core/accessories/accessory_def.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/game_core.dart';
import '../support/test_level.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/stats/gear_stat_bonuses.dart';

import '../support/test_player.dart';
import '../test_tunings.dart';

void main() {
  test('loadout regen bonuses scale runtime regen ticks', () {
    final base = PlayerCharacterRegistry.eloise;
    GameCore buildCore(AccessoryCatalog accessories) {
      return GameCore(
        levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
        seed: 7,
        tickHz: 10,
        accessoryCatalog: accessories,
        playerCharacter: base.copyWith(
          catalog: testPlayerCatalog(
            bodyTemplate: BodyDef(useGravity: false),
            projectileId: ProjectileId.iceBolt,
            abilityProjectileId: 'eloise.overcharge_shot',
          ),
          tuning: base.tuning.copyWith(
            resource: const ResourceTuning(
              playerHpMax: 100,
              playerHpRegenPerSecond: 0,
              playerManaMax: 20,
              playerManaRegenPerSecond: 1,
              playerStaminaMax: 20,
              playerStaminaRegenPerSecond: 0,
            ),
          ),
        ),
      );
    }

    final baseCore = buildCore(const _ZeroRegenAccessoryCatalog());
    final boostedCore = buildCore(const _BoostedRegenAccessoryCatalog());

    baseCore.applyCommands(const [ProjectilePressedCommand(tick: 1)]);
    boostedCore.applyCommands(const [ProjectilePressedCommand(tick: 1)]);
    baseCore.stepOneTick();
    boostedCore.stepOneTick();

    for (var i = 0; i < 20; i += 1) {
      baseCore.applyCommands(const <Command>[]);
      boostedCore.applyCommands(const <Command>[]);
      baseCore.stepOneTick();
      boostedCore.stepOneTick();
    }

    final baseMana = baseCore.buildSnapshot().hud.mana;
    final boostedMana = boostedCore.buildSnapshot().hud.mana;
    expect(boostedMana, greaterThan(baseMana));
  });

  test(
    'resource regen refills after spending and clamps at max (via snapshot HUD)',
    () {
      final base = PlayerCharacterRegistry.eloise;
      final core = GameCore(
        levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
        seed: 1,
        tickHz: 10,
        playerCharacter: base.copyWith(
          catalog: testPlayerCatalog(
            bodyTemplate: BodyDef(useGravity: false),
            projectileId: ProjectileId.iceBolt,
            abilityProjectileId: 'eloise.overcharge_shot',
          ),
          tuning: base.tuning.copyWith(
            resource: const ResourceTuning(
              playerHpMax: 100,
              playerHpRegenPerSecond: 10,
              playerManaMax: 20,
              playerManaRegenPerSecond: 1,
              playerStaminaMax: 20,
              playerStaminaRegenPerSecond: 2,
            ),
          ),
        ),
      );

      // Player spawns at max resources.
      var hud = core.buildSnapshot().hud;
      final initialHp = hud.hp;
      final initialMana = hud.mana;
      final initialStamina = hud.stamina;
      expect(hud.hp, closeTo(initialHp, 1e-9));
      expect(hud.mana, closeTo(initialMana, 1e-9));
      expect(hud.stamina, closeTo(initialStamina, 1e-9));

      // Spend mana and stamina on separate ticks (dash preempts combat).
      core.applyCommands(const [ProjectilePressedCommand(tick: 1)]);
      core.stepOneTick(); // tick 1: spend mana and apply regen (dt=0.1)
      core.applyCommands(const [DashPressedCommand(tick: 2)]);
      core.stepOneTick(); // tick 2: spend stamina and apply regen
      hud = core.buildSnapshot().hud;
      expect(hud.hp, closeTo(initialHp, 1e-9));
      expect(hud.mana, lessThan(initialMana));
      expect(hud.stamina, lessThan(initialStamina));

      // Run long enough to exceed maxima; values should clamp exactly to max.
      for (var i = 0; i < 200; i += 1) {
        // Clear latched inputs (e.g. dashPressed) so spending does not repeat.
        core.applyCommands(<Command>[]);
        core.stepOneTick();
      }
      hud = core.buildSnapshot().hud;
      expect(hud.hp, closeTo(initialHp, 1e-9));
      expect(hud.mana, closeTo(initialMana, 1e-9));
      expect(hud.stamina, closeTo(initialStamina, 1e-9));
    },
  );
}

class _ZeroRegenAccessoryCatalog extends AccessoryCatalog {
  const _ZeroRegenAccessoryCatalog();

  @override
  AccessoryDef get(AccessoryId id) {
    return AccessoryDef(id: id);
  }
}

class _BoostedRegenAccessoryCatalog extends AccessoryCatalog {
  const _BoostedRegenAccessoryCatalog();

  @override
  AccessoryDef get(AccessoryId id) {
    return AccessoryDef(
      id: id,
      stats: const GearStatBonuses(manaRegenBonusBp: 10000),
    );
  }
}
