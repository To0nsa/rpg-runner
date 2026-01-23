import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/loadout/loadout_issue.dart';
import 'package:rpg_runner/core/loadout/loadout_validator.dart';
import 'package:rpg_runner/core/weapons/ranged_weapon_catalog.dart';
import 'package:rpg_runner/core/weapons/ranged_weapon_id.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_category.dart';
import 'package:rpg_runner/core/weapons/weapon_def.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';

void main() {
  group('LoadoutValidator', () {
    const abilityCatalog = AbilityCatalog();
    const weaponCatalog = WeaponCatalog();
    const rangedWeaponCatalog = RangedWeaponCatalog();
    
    final validator = LoadoutValidator(
      abilityCatalog: abilityCatalog,
      weaponCatalog: weaponCatalog,
      rangedWeaponCatalog: rangedWeaponCatalog,
    );

    test('valid standard loadout should pass', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.basicSword,
        offhandWeaponId: WeaponId.basicShield,
        rangedWeaponId: RangedWeaponId.throwingKnife,
        abilityPrimaryId: 'eloise.sword_strike',
        abilitySecondaryId: 'eloise.shield_block',
        abilityProjectileId: 'eloise.throwing_knife',
        abilityMobilityId: 'eloise.dash',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isTrue, reason: 'Issues: ${result.issues}');
      expect(result.issues, isEmpty);
    });

    test('invalid slot (shield bash in primary) should fail', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.basicSword,
        abilityPrimaryId: 'eloise.shield_bash', // Requires Secondary slot
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.kind == IssueKind.slotNotAllowed), isTrue);
    });

    test('category mismatch (shield in primary) should fail', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.basicShield, // OffHand category
        abilityPrimaryId: 'eloise.sword_strike',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.kind == IssueKind.weaponCategoryMismatch), isTrue);
    });

    test('missing required tags (shield block with sword) should fail', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.basicSword,
        offhandWeaponId: WeaponId.basicSword, // Invalid for other reasons, but let's test gating
        abilitySecondaryId: 'eloise.shield_block', // Needs 'buff' tag, Sword has 'melee'
      );

      // Note: This layout also triggers CategoryMismatch because Sword is not OffHand.
      // But we want to ensure tag checking logic works if reached (or if we fix category).
      // Since our validator fails fast on category (returns null weapon), we expect CategoryMismatch here.
      // To strictly test Tag Gating, we rely on the next test case ("valid category, wrong capabilities").
      // So this test case essentially duplicates "category mismatch" but checks for offhand slot.
      // Let's check for ANY failure for now or expect CategoryMismatch.
      
      final result = validator.validate(loadout);
      expect(result.isValid, isFalse);
      expect(result.issues.isNotEmpty, isTrue);
    });
    
    test('missing required tags (valid category, wrong capabilities) should fail', () {
       // Using 'eloise.shield_bash' (Secondary, needs Melee) with 'basicShield' (OffHand, grants Buff).
       // Wait, Shield Bash needs {Melee, Physical, Heavy}.
       // Basic Shield grants {Buff, Physical}.
       // So missing Melee and Heavy.
       // This setup is valid slots/categories, so should hit tag check.
       
       const loadout = EquippedLoadoutDef(
         offhandWeaponId: WeaponId.basicShield,
         abilitySecondaryId: 'eloise.shield_bash',
       );
       
       final result = validator.validate(loadout);
       expect(result.isValid, isFalse);
       expect(result.issues.any((i) => i.kind == IssueKind.missingRequiredTags), isTrue);
       
       final issue = result.issues.firstWhere((i) => i.kind == IssueKind.missingRequiredTags);
       expect(issue.missingTags, contains(AbilityTag.melee));
    });

    test('two-handed primary with off-hand equipped should fail', () {
      // Use mock catalog that defines goldenSword as Two-Handed
      final mockValidator = LoadoutValidator(
        abilityCatalog: abilityCatalog,
        weaponCatalog: const MockWeaponCatalog(),
        rangedWeaponCatalog: rangedWeaponCatalog,
      );

      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.goldenSword, // Mocked as 2H
        offhandWeaponId: WeaponId.basicShield, // Conflict!
        abilityPrimaryId: 'eloise.sword_strike',
      );

      final result = mockValidator.validate(loadout);
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.kind == IssueKind.twoHandedConflict), isTrue);
    });
  });
}

class MockWeaponCatalog implements WeaponCatalog {
  const MockWeaponCatalog();
  
  @override
  WeaponDef? tryGet(WeaponId id) {
    if (id == WeaponId.goldenSword) {
      return const WeaponDef(
        id: WeaponId.goldenSword,
        category: WeaponCategory.primary,
        isTwoHanded: true,
      );
    }
    return const WeaponCatalog().tryGet(id);
  }
  
  @override
  WeaponDef get(WeaponId id) => tryGet(id)!;
}
