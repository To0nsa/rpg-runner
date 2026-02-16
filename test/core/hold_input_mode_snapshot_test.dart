import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/game_core.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';

void main() {
  test(
    'snapshot exposes hold-maintain input mode for parry/block abilities',
    () {
      final core = GameCore(
        seed: 1,
        equippedLoadoutOverride: const EquippedLoadoutDef(
          abilityPrimaryId: 'eloise.sword_riposte_guard',
          abilitySecondaryId: 'eloise.shield_riposte_guard',
        ),
      );

      final hud = core.buildSnapshot().hud;
      expect(hud.meleeInputMode, AbilityInputMode.holdMaintain);
      expect(hud.secondaryInputMode, AbilityInputMode.holdMaintain);
    },
  );

  test('snapshot exposes hold-aim-release for charged secondary melee', () {
    final core = GameCore(
      seed: 1,
      equippedLoadoutOverride: const EquippedLoadoutDef(
        abilitySecondaryId: 'eloise.charged_shield_bash',
      ),
    );

    final hud = core.buildSnapshot().hud;
    expect(hud.secondaryInputMode, AbilityInputMode.holdAimRelease);
  });

  test('snapshot exposes hold-release for charged homing primary melee', () {
    final core = GameCore(
      seed: 1,
      equippedLoadoutOverride: const EquippedLoadoutDef(
        abilityPrimaryId: 'eloise.charged_sword_strike_auto_aim',
      ),
    );

    final hud = core.buildSnapshot().hud;
    expect(hud.meleeInputMode, AbilityInputMode.holdRelease);
  });

  test('snapshot keeps non-charged secondary melee on tap mode', () {
    final core = GameCore(
      seed: 1,
      equippedLoadoutOverride: const EquippedLoadoutDef(
        abilitySecondaryId: 'eloise.shield_bash',
      ),
    );

    final hud = core.buildSnapshot().hud;
    expect(hud.secondaryInputMode, AbilityInputMode.tap);
  });

  test('snapshot exposes tap input mode for default mobility ability', () {
    final core = GameCore(seed: 1);
    final hud = core.buildSnapshot().hud;
    expect(hud.mobilityInputMode, AbilityInputMode.tap);
  });

  test('snapshot exposes hold-aim-release for charged aimed mobility', () {
    final core = GameCore(
      seed: 1,
      equippedLoadoutOverride: const EquippedLoadoutDef(
        abilityMobilityId: 'eloise.charged_aim_dash',
      ),
    );

    final hud = core.buildSnapshot().hud;
    expect(hud.mobilityInputMode, AbilityInputMode.holdAimRelease);
  });

  test('snapshot exposes hold-release for charged homing mobility', () {
    final core = GameCore(
      seed: 1,
      equippedLoadoutOverride: const EquippedLoadoutDef(
        abilityMobilityId: 'eloise.charged_auto_dash',
      ),
    );

    final hud = core.buildSnapshot().hud;
    expect(hud.mobilityInputMode, AbilityInputMode.holdRelease);
  });

  test('snapshot exposes hold-maintain mode for hold auto-aim mobility', () {
    final core = GameCore(
      seed: 1,
      equippedLoadoutOverride: const EquippedLoadoutDef(
        abilityMobilityId: 'eloise.hold_auto_dash',
      ),
    );

    final hud = core.buildSnapshot().hud;
    expect(hud.mobilityInputMode, AbilityInputMode.holdMaintain);
  });

  test(
    'all authored tiered homing hold-release abilities use non-directional hold-release mode',
    () {
      final authored = AbilityCatalog.abilities.values.where((ability) {
        return ability.chargeProfile != null &&
            ability.targetingModel == TargetingModel.homing &&
            ability.inputLifecycle == AbilityInputLifecycle.holdRelease;
      }).toList();

      expect(authored, isNotEmpty);

      for (final ability in authored) {
        for (final slot in ability.allowedSlots) {
          if (slot == AbilitySlot.jump || slot == AbilitySlot.spell) continue;

          final loadout = switch (slot) {
            AbilitySlot.primary => EquippedLoadoutDef(
              abilityPrimaryId: ability.id,
            ),
            AbilitySlot.secondary => EquippedLoadoutDef(
              abilitySecondaryId: ability.id,
            ),
            AbilitySlot.projectile => EquippedLoadoutDef(
              abilityProjectileId: ability.id,
            ),
            AbilitySlot.mobility => EquippedLoadoutDef(
              abilityMobilityId: ability.id,
            ),
            AbilitySlot.spell || AbilitySlot.jump => const EquippedLoadoutDef(),
          };

          final core = GameCore(seed: 1, equippedLoadoutOverride: loadout);
          final hud = core.buildSnapshot().hud;
          final mode = switch (slot) {
            AbilitySlot.primary => hud.meleeInputMode,
            AbilitySlot.secondary => hud.secondaryInputMode,
            AbilitySlot.projectile => hud.projectileInputMode,
            AbilitySlot.mobility => hud.mobilityInputMode,
            AbilitySlot.spell || AbilitySlot.jump => AbilityInputMode.tap,
          };
          expect(
            mode,
            AbilityInputMode.holdRelease,
            reason: '${ability.id} in $slot should not require directional aim',
          );
        }
      }
    },
  );
}
