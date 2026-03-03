import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/accessories/accessory_catalog.dart';
import 'package:rpg_runner/core/accessories/accessory_id.dart';
import 'package:rpg_runner/core/combat/status/status.dart';
import 'package:rpg_runner/core/weapons/reactive_proc.dart';

void main() {
  group('accessory catalog roster values', () {
    const catalog = AccessoryCatalog();

    test('speed boots tempo baseline values', () {
      final def = catalog.get(AccessoryId.speedBoots);
      expect(def.stats.moveSpeedBonusBp, 1000);
      expect(def.stats.staminaBonusBp, 1000);
      expect(def.stats.manaBonusBp, -500);
      expect(def.reactiveProcs, isEmpty);
    });

    test('golden ring survivability values', () {
      final def = catalog.get(AccessoryId.goldenRing);
      expect(def.stats.healthBonusBp, 1500);
      expect(def.stats.healthRegenBonusBp, 500);
      expect(def.stats.defenseBonusBp, 1000);
      expect(def.stats.manaBonusBp, -500);
      expect(def.reactiveProcs, hasLength(1));
      expect(def.reactiveProcs.single.hook, ReactiveProcHook.onLowHealth);
      expect(def.reactiveProcs.single.statusProfileId, StatusProfileId.restoreHealth);
      expect(def.reactiveProcs.single.target, ReactiveProcTarget.self);
      expect(def.reactiveProcs.single.chanceBp, 10000);
      expect(def.reactiveProcs.single.lowHealthThresholdBp, 3000);
      expect(def.reactiveProcs.single.internalCooldownTicks, 1800);
    });

    test('teeth necklace stamina sustain values', () {
      final def = catalog.get(AccessoryId.teethNecklace);
      expect(def.stats.staminaBonusBp, 2000);
      expect(def.stats.staminaRegenBonusBp, 1000);
      expect(def.stats.manaBonusBp, -500);
      expect(def.reactiveProcs, hasLength(1));
      expect(def.reactiveProcs.single.hook, ReactiveProcHook.onLowHealth);
      expect(
        def.reactiveProcs.single.statusProfileId,
        StatusProfileId.restoreStamina,
      );
    });

    test('diamond ring caster sustain values', () {
      final def = catalog.get(AccessoryId.diamondRing);
      expect(def.stats.manaBonusBp, 2000);
      expect(def.stats.manaRegenBonusBp, 1000);
      expect(def.stats.cooldownReductionBp, 800);
      expect(def.reactiveProcs, hasLength(1));
      expect(def.reactiveProcs.single.hook, ReactiveProcHook.onLowHealth);
      expect(def.reactiveProcs.single.statusProfileId, StatusProfileId.restoreMana);
    });

    test('iron boots mitigation anchor values', () {
      final def = catalog.get(AccessoryId.ironBoots);
      expect(def.stats.defenseBonusBp, 1200);
      expect(def.stats.globalPowerBonusBp, 1000);
      expect(def.stats.moveSpeedBonusBp, 500);
    });

    test('oath beads rotation consistency values', () {
      final def = catalog.get(AccessoryId.oathBeads);
      expect(def.stats.cooldownReductionBp, 800);
      expect(def.stats.globalPowerBonusBp, 500);
      expect(def.stats.globalCritChanceBonusBp, 500);
      expect(def.stats.manaBonusBp, -500);
    });

    test('resilience cape counterpick values', () {
      final def = catalog.get(AccessoryId.resilienceCape);
      expect(def.stats.bleedResistanceBp, 1200);
      expect(def.stats.darkResistanceBp, 800);
      expect(def.stats.healthBonusBp, 500);
      expect(def.stats.manaBonusBp, -500);
    });

    test('strength belt offense values', () {
      final def = catalog.get(AccessoryId.strengthBelt);
      expect(def.stats.globalPowerBonusBp, 1000);
      expect(def.stats.globalCritChanceBonusBp, 1000);
      expect(def.stats.staminaBonusBp, 1000);
      expect(def.stats.manaBonusBp, -500);
    });
  });
}
