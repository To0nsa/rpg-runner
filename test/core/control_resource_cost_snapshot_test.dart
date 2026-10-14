import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/abilities/effective_ability_cost.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/spellBook/spell_book_catalog.dart';
import 'package:runner_core/weapons/weapon_catalog.dart';

import '../support/test_level.dart';

void main() {
  test('preview and runtime share every payload cost override', () {
    const loadout = EquippedLoadoutDef();
    final store = EquippedLoadoutStore()..add(1, loadout);
    const byWeapon = {
      WeaponType.oneHandedSword: AbilityResourceCost(staminaCost100: 100),
      WeaponType.shield: AbilityResourceCost(staminaCost100: 200),
      WeaponType.spell: AbilityResourceCost(manaCost100: 300),
    };
    for (final source in AbilityPayloadSource.values) {
      final ability = AbilityDef(
        id: 'test.resource_cost',
        category: AbilityCategory.utility,
        payloadSource: source,
        windupTicks: 0,
        activeTicks: 1,
        recoveryTicks: 0,
        cooldownTicks: 0,
        animKey: AnimKey.idle,
        defaultCost: const AbilityResourceCost(healthCost100: 50),
        costProfileByWeaponType: byWeapon,
      );
      for (final slot in AbilitySlot.values) {
        final preview = resolveEffectiveAbilityCostForLoadout(
          ability: ability,
          loadout: loadout,
          slot: slot,
        );
        final runtime = resolveEffectiveAbilityCostForSlot(
          ability: ability,
          loadout: store,
          loadoutIndex: 0,
          slot: slot,
          weapons: const WeaponCatalog(),
          projectiles: const ProjectileCatalog(),
          spellBooks: const SpellBookCatalog(),
        );
        expect(preview, same(runtime), reason: '$source / $slot');
        final expected = switch (source) {
          AbilityPayloadSource.none => ability.defaultCost,
          AbilityPayloadSource.primaryWeapon =>
            byWeapon[WeaponType.oneHandedSword],
          AbilityPayloadSource.secondaryWeapon => byWeapon[WeaponType.shield],
          AbilityPayloadSource.spellBook => byWeapon[WeaponType.spell],
          AbilityPayloadSource.projectile =>
            slot == AbilitySlot.projectile
                ? byWeapon[WeaponType.spell]
                : ability.defaultCost,
        };
        expect(preview, same(expected));
      }
    }
  });

  test(
    'HUD publishes immutable costs and switches to the available air jump',
    () {
      final core = GameCore(
        levelDefinition: testFieldLevel(),
        playerCharacter: testPlayerCharacter,
        seed: 1,
        equippedLoadoutOverride: const EquippedLoadoutDef(
          abilityJumpId: 'eloise.double_jump',
        ),
      );
      // Settle initial ground contact before exercising the two jump costs.
      for (var i = 0; i < 10; i++) {
        core.applyCommands(const []);
        core.stepOneTick();
      }
      final grounded = core.buildSnapshot().hud;
      expect(
        grounded.abilityCostsBySlot.keys.toSet(),
        AbilitySlot.values.toSet(),
      );
      expect(
        grounded.abilityCostsBySlot[AbilitySlot.jump]!.staminaCost100,
        200,
      );
      expect(
        grounded.abilityCostsBySlot[AbilitySlot.projectile]!.manaCost100,
        greaterThan(0),
      );
      expect(() => grounded.abilityCostsBySlot.clear(), throwsUnsupportedError);
      core.applyCommands([JumpPressedCommand(tick: core.tick + 1)]);
      core.stepOneTick();
      final airborne = core.buildSnapshot().hud;
      final jump = AbilityCatalog.shared.resolve('eloise.double_jump')!;
      expect(
        airborne.abilityCostsBySlot[AbilitySlot.jump],
        same(jump.airJumpCost),
      );
      expect(
        grounded.abilityCostsBySlot[AbilitySlot.jump]!.staminaCost100,
        200,
      );
    },
  );
}
