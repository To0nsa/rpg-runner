import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/game_core.dart';
import '../support/test_level.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/snapshots/enums.dart';

void main() {
  test(
    'snapshot exposes hold-maintain input mode for defensive secondary abilities',
    () {
      final core = GameCore(
        levelDefinition: LevelRegistry.byId(LevelId.field),
        playerCharacter: testPlayerCharacter,
        seed: 1,
        equippedLoadoutOverride: const EquippedLoadoutDef(
          abilitySecondaryId: 'eloise.aegis_riposte',
        ),
      );

      final hud = core.buildSnapshot().hud;
      expect(hud.meleeInputMode, AbilityInputMode.tap);
      expect(hud.secondaryInputMode, AbilityInputMode.holdMaintain);
    },
  );

  test('snapshot exposes hold-maintain for shield block secondary', () {
    final core = GameCore(
      levelDefinition: LevelRegistry.byId(LevelId.field),
      playerCharacter: testPlayerCharacter,
      seed: 1,
      equippedLoadoutOverride: const EquippedLoadoutDef(
        abilitySecondaryId: 'eloise.shield_block',
      ),
    );

    final hud = core.buildSnapshot().hud;
    expect(hud.secondaryInputMode, AbilityInputMode.holdMaintain);
  });

  test('snapshot exposes hold-aim-release for charged primary melee', () {
    final core = GameCore(
      levelDefinition: LevelRegistry.byId(LevelId.field),
      playerCharacter: testPlayerCharacter,
      seed: 1,
      equippedLoadoutOverride: const EquippedLoadoutDef(
        abilityPrimaryId: 'eloise.bloodletter_cleave',
      ),
    );

    final hud = core.buildSnapshot().hud;
    expect(hud.meleeInputMode, AbilityInputMode.holdAimRelease);
  });

  test('snapshot keeps default secondary guard on hold-maintain mode', () {
    final core = GameCore(
      levelDefinition: LevelRegistry.byId(LevelId.field),
      playerCharacter: testPlayerCharacter,
      seed: 1,
    );

    final hud = core.buildSnapshot().hud;
    expect(hud.secondaryInputMode, AbilityInputMode.holdMaintain);
  });

  test('snapshot exposes tap input mode for default mobility ability', () {
    final core = GameCore(
      levelDefinition: LevelRegistry.byId(LevelId.field),
      playerCharacter: testPlayerCharacter,
      seed: 1,
    );
    final hud = core.buildSnapshot().hud;
    expect(hud.mobilityInputMode, AbilityInputMode.tap);
  });

  test('no authored tiered homing hold-release abilities remain', () {
    final authored = AbilityCatalog.abilities.values.where((ability) {
      return ability.chargeProfile != null &&
          ability.targetingModel == TargetingModel.homing &&
          ability.inputLifecycle == AbilityInputLifecycle.holdRelease;
    }).toList();

    expect(authored, isEmpty);
  });
}
