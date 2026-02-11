import 'package:flutter_test/flutter_test.dart';

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
          abilityPrimaryId: 'eloise.sword_parry',
          abilitySecondaryId: 'eloise.shield_block',
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
}
