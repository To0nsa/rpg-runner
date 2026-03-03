import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/accessories/accessory_catalog.dart';
import 'package:rpg_runner/core/accessories/accessory_id.dart';

void main() {
  group('accessory catalog roster values', () {
    const catalog = AccessoryCatalog();

    test('speed boots tempo baseline values', () {
      final def = catalog.get(AccessoryId.speedBoots);
      expect(def.stats.moveSpeedBonusBp, 1000);
      expect(def.stats.staminaBonusBp, 1000);
      expect(def.stats.healthBonusBp, -500);
    });

    test('golden ring survivability values', () {
      final def = catalog.get(AccessoryId.goldenRing);
      expect(def.stats.healthBonusBp, 1000);
      expect(def.stats.healthRegenBonusBp, 500);
      expect(def.stats.defenseBonusBp, 1000);
      expect(def.stats.staminaBonusBp, -500);
    });

    test('teeth necklace stamina sustain values', () {
      final def = catalog.get(AccessoryId.teethNecklace);
      expect(def.stats.staminaBonusBp, 2000);
      expect(def.stats.staminaRegenBonusBp, 1000);
      expect(def.stats.healthBonusBp, -500);
    });

    test('diamond ring caster sustain values', () {
      final def = catalog.get(AccessoryId.diamondRing);
      expect(def.stats.manaBonusBp, 2000);
      expect(def.stats.manaRegenBonusBp, 1000);
      expect(def.stats.staminaBonusBp, -500);
    });

    test('iron boots mitigation anchor values', () {
      final def = catalog.get(AccessoryId.ironBoots);
      expect(def.stats.defenseBonusBp, 1000);
      expect(def.stats.globalPowerBonusBp, 1000);
      expect(def.stats.moveSpeedBonusBp, -300);
    });

    test('oath beads rotation consistency values', () {
      final def = catalog.get(AccessoryId.oathBeads);
      expect(def.stats.cooldownReductionBp, 1000);
      expect(def.stats.globalPowerBonusBp, 500);
      expect(def.stats.healthBonusBp, -500);
    });

    test('resilience cape counterpick values', () {
      final def = catalog.get(AccessoryId.resilienceCape);
      expect(def.stats.bleedResistanceBp, 1200);
      expect(def.stats.darkResistanceBp, 800);
      expect(def.stats.healthBonusBp, -500);
    });

    test('strength belt offense values', () {
      final def = catalog.get(AccessoryId.strengthBelt);
      expect(def.stats.globalPowerBonusBp, 500);
      expect(def.stats.globalCritChanceBonusBp, 500);
      expect(def.stats.staminaBonusBp, -500);
    });
  });
}
