import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/combat/hit_payload_builder.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';

final AbilityDef _testAbility = AbilityDef(
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
  cooldownTicks: 1,
  animKey: AnimKey.strike,
  baseDamage: 1000,
);

void main() {
  test('HitPayloadBuilder applies global offensive stats', () {
    final payload = HitPayloadBuilder.build(
      ability: _testAbility,
      source: 1,
      globalPowerBonusBp: 2000,
      globalCritChanceBonusBp: 700,
    );

    // 1000 * 1.20 = 1200
    expect(payload.damage100, equals(1200));
    expect(payload.critChanceBp, equals(700));
  });

  test('HitPayloadBuilder clamps crit chance to 100%', () {
    final payload = HitPayloadBuilder.build(
      ability: _testAbility,
      source: 1,
      globalCritChanceBonusBp: 12000,
    );

    expect(payload.critChanceBp, equals(10000));
  });
}
