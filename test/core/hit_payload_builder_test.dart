import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/combat/hit_payload_builder.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/stats/gear_stat_bonuses.dart';

const AbilityDef _testAbility = AbilityDef(
  id: 'test.payload',
  category: AbilityCategory.melee,
  allowedSlots: {AbilitySlot.primary},
  targetingModel: TargetingModel.directional,
  hitDelivery: MeleeHitDelivery(
    sizeX: 20,
    sizeY: 20,
    offsetX: 0,
    offsetY: 0,
    hitPolicy: HitPolicy.oncePerTarget,
  ),
  payloadSource: AbilityPayloadSource.primaryWeapon,
  inputLifecycle: AbilityInputLifecycle.tap,
  windupTicks: 1,
  activeTicks: 1,
  recoveryTicks: 1,
  defaultCost: AbilityResourceCost(staminaCost100: 0, manaCost100: 0),
  cooldownTicks: 1,
  animKey: AnimKey.strike,
  baseDamage: 1000,
);

void main() {
  test(
    'HitPayloadBuilder applies global and payload-source offensive stats',
    () {
      final payload = HitPayloadBuilder.build(
        ability: _testAbility,
        source: 1,
        globalPowerBonusBp: 2000,
        globalCritChanceBonusBp: 700,
        weaponStats: const GearStatBonuses(
          powerBonusBp: 1000,
          critChanceBonusBp: 500,
        ),
      );

      // 1000 * 1.20 * 1.10 = 1320
      expect(payload.damage100, equals(1320));
      expect(payload.critChanceBp, equals(1200));
    },
  );

  test('HitPayloadBuilder clamps crit chance to 100%', () {
    final payload = HitPayloadBuilder.build(
      ability: _testAbility,
      source: 1,
      globalCritChanceBonusBp: 9000,
      weaponStats: const GearStatBonuses(critChanceBonusBp: 3000),
    );

    expect(payload.critChanceBp, equals(10000));
  });
}
