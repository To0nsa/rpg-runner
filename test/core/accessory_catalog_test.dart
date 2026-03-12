import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/accessories/accessory_catalog.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/combat/status/status.dart';
import 'package:runner_core/weapons/reactive_proc.dart';

void main() {
  group('accessory catalog roster values', () {
    const catalog = AccessoryCatalog();

    test('speed boots tempo baseline values', () {
      final def = catalog.get(AccessoryId.speedBoots);
      expect(def.stats.moveSpeedBonusBp, 1000);
      expect(def.stats.staminaRegenBonusBp, 1000);
      expect(def.stats.cooldownReductionBp, 500);
      expect(def.stats.manaBonusBp, -1000);
      expect(def.reactiveProcs, isEmpty);
    });

    test('golden ring survivability values', () {
      final def = catalog.get(AccessoryId.goldenRing);
      expect(def.stats.healthBonusBp, 1500);
      expect(def.stats.cooldownReductionBp, -500);
      expect(def.reactiveProcs, hasLength(1));
      expect(def.reactiveProcs.single.hook, ReactiveProcHook.onLowHealth);
      expect(
        def.reactiveProcs.single.statusProfileId,
        StatusProfileId.restoreHealth,
      );
      expect(def.reactiveProcs.single.target, ReactiveProcTarget.self);
      expect(def.reactiveProcs.single.chanceBp, 10000);
      expect(def.reactiveProcs.single.lowHealthThresholdBp, 3000);
      expect(def.reactiveProcs.single.internalCooldownTicks, 1800);
    });

    test('teeth necklace stamina sustain values', () {
      final def = catalog.get(AccessoryId.teethNecklace);
      expect(def.stats.staminaBonusBp, 1500);
      expect(def.stats.healthBonusBp, -500);
      expect(def.reactiveProcs, hasLength(1));
      expect(def.reactiveProcs.single.hook, ReactiveProcHook.onLowHealth);
      expect(
        def.reactiveProcs.single.statusProfileId,
        StatusProfileId.restoreStamina,
      );
      expect(def.reactiveProcs.single.target, ReactiveProcTarget.self);
      expect(def.reactiveProcs.single.chanceBp, 10000);
      expect(def.reactiveProcs.single.lowHealthThresholdBp, 3000);
      expect(def.reactiveProcs.single.internalCooldownTicks, 1800);
    });

    test('diamond ring caster sustain values', () {
      final def = catalog.get(AccessoryId.diamondRing);
      expect(def.stats.manaBonusBp, 1500);
      expect(def.stats.staminaBonusBp, -500);
      expect(def.reactiveProcs, hasLength(1));
      expect(def.reactiveProcs.single.hook, ReactiveProcHook.onLowHealth);
      expect(
        def.reactiveProcs.single.statusProfileId,
        StatusProfileId.restoreMana,
      );
      expect(def.reactiveProcs.single.target, ReactiveProcTarget.self);
      expect(def.reactiveProcs.single.chanceBp, 10000);
      expect(def.reactiveProcs.single.lowHealthThresholdBp, 3000);
      expect(def.reactiveProcs.single.internalCooldownTicks, 1800);
    });

    test('iron boots mitigation anchor values', () {
      final def = catalog.get(AccessoryId.ironBoots);
      expect(def.stats.healthBonusBp, 500);
      expect(def.stats.defenseBonusBp, 1500);
      expect(def.stats.physicalResistanceBp, 1500);
      expect(def.stats.globalPowerBonusBp, -500);
    });

    test('oath beads rotation consistency values', () {
      final def = catalog.get(AccessoryId.oathBeads);
      expect(def.stats.cooldownReductionBp, 500);
      expect(def.stats.globalPowerBonusBp, 1000);
      expect(def.stats.manaRegenBonusBp, 1000);
      expect(def.stats.defenseBonusBp, -500);
    });

    test('resilience cape counterpick values', () {
      final def = catalog.get(AccessoryId.resilienceCape);
      expect(def.stats.fireResistanceBp, 2500);
      expect(def.stats.darkResistanceBp, 2000);
      expect(def.stats.defenseBonusBp, 1000);
      expect(def.stats.manaBonusBp, -500);
    });

    test('strength belt offense values', () {
      final def = catalog.get(AccessoryId.strengthBelt);
      expect(def.stats.globalPowerBonusBp, 1500);
      expect(def.stats.globalCritChanceBonusBp, 1000);
      expect(def.stats.staminaBonusBp, 1000);
      expect(def.stats.cooldownReductionBp, -500);
    });
  });
}
