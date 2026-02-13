import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/combat/status/status.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/weapons/weapon_proc.dart';

void main() {
  test('AbilityChargeProfile requires strictly increasing tier thresholds', () {
    expect(
      () => AbilityChargeProfile(
        tiers: <AbilityChargeTierDef>[
          const AbilityChargeTierDef(minHoldTicks60: 8, damageScaleBp: 10000),
          const AbilityChargeTierDef(minHoldTicks60: 8, damageScaleBp: 11000),
        ],
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('AbilityDef copies mutable collections defensively', () {
    final allowedSlots = <AbilitySlot>{AbilitySlot.spell};
    final requiredWeaponTypes = <WeaponType>{WeaponType.projectileSpell};
    final procs = <WeaponProc>[];
    final forcedInterruptCauses = <ForcedInterruptCause>{
      ForcedInterruptCause.stun,
      ForcedInterruptCause.death,
    };
    final costProfileByWeaponType = <WeaponType, AbilityResourceCost>{
      WeaponType.projectileSpell: const AbilityResourceCost(manaCost100: 100),
    };

    final ability = AbilityDef(
      id: 'test.immutable',
      category: AbilityCategory.utility,
      allowedSlots: allowedSlots,
      inputLifecycle: AbilityInputLifecycle.tap,
      windupTicks: 0,
      activeTicks: 0,
      recoveryTicks: 0,
      cooldownTicks: 0,
      animKey: AnimKey.cast,
      requiredWeaponTypes: requiredWeaponTypes,
      procs: procs,
      forcedInterruptCauses: forcedInterruptCauses,
      costProfileByWeaponType: costProfileByWeaponType,
      baseDamage: 0,
    );

    allowedSlots.add(AbilitySlot.primary);
    requiredWeaponTypes.clear();
    procs.add(
      const WeaponProc(
        hook: ProcHook.onHit,
        statusProfileId: StatusProfileId.stunOnHit,
        chanceBp: 10000,
      ),
    );
    forcedInterruptCauses.add(ForcedInterruptCause.damageTaken);
    costProfileByWeaponType[WeaponType.throwingWeapon] =
        const AbilityResourceCost(staminaCost100: 100);

    expect(ability.allowedSlots, equals(<AbilitySlot>{AbilitySlot.spell}));
    expect(
      ability.requiredWeaponTypes,
      equals(<WeaponType>{WeaponType.projectileSpell}),
    );
    expect(ability.procs, isEmpty);
    expect(
      ability.forcedInterruptCauses,
      equals(<ForcedInterruptCause>{
        ForcedInterruptCause.stun,
        ForcedInterruptCause.death,
      }),
    );
    expect(
      ability.costProfileByWeaponType.keys,
      equals(<WeaponType>[WeaponType.projectileSpell]),
    );
  });
}
