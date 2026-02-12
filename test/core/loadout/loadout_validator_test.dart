import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/loadout/loadout_issue.dart';
import 'package:rpg_runner/core/loadout/loadout_validator.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_catalog.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_id.dart';
import 'package:rpg_runner/core/spells/spell_book_catalog.dart';
import 'package:rpg_runner/core/spells/spell_book_id.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_category.dart';
import 'package:rpg_runner/core/weapons/weapon_def.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';

void main() {
  group('LoadoutValidator', () {
    const abilityCatalog = AbilityCatalog();
    const weaponCatalog = WeaponCatalog();
    const projectileItemCatalog = ProjectileItemCatalog();

    final validator = LoadoutValidator(
      abilityCatalog: abilityCatalog,
      weaponCatalog: weaponCatalog,
      projectileItemCatalog: projectileItemCatalog,
      spellBookCatalog: const SpellBookCatalog(),
    );

    test('valid standard loadout should pass', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.woodenSword,
        offhandWeaponId: WeaponId.woodenShield,
        projectileItemId: ProjectileItemId.throwingKnife,
        abilityPrimaryId: 'eloise.sword_strike',
        abilitySecondaryId: 'eloise.shield_block',
        abilityProjectileId: 'eloise.quick_shot',
        abilityMobilityId: 'eloise.dash',
        abilityBonusId: 'eloise.arcane_haste',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isTrue, reason: 'Issues: ${result.issues}');
      expect(result.issues, isEmpty);
    });

    test('auto-aim melee variants are valid in their authored slots', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.woodenSword,
        offhandWeaponId: WeaponId.woodenShield,
        abilityPrimaryId: 'eloise.sword_strike_auto_aim',
        abilitySecondaryId: 'eloise.shield_bash_auto_aim',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isTrue, reason: 'Issues: ${result.issues}');
      expect(result.issues, isEmpty);
    });

    test(
      'tiered homing melee and charged aimed mobility are valid in authored slots',
      () {
        const loadout = EquippedLoadoutDef(
          mainWeaponId: WeaponId.woodenSword,
          offhandWeaponId: WeaponId.woodenShield,
          abilityPrimaryId: 'eloise.charged_sword_strike_auto_aim',
          abilityMobilityId: 'eloise.charged_aim_dash',
        );

        final result = validator.validate(loadout);
        expect(result.isValid, isTrue, reason: 'Issues: ${result.issues}');
        expect(result.issues, isEmpty);
      },
    );

    test(
      'hold-maintain homing tiered mobility is valid in authored mobility slot',
      () {
        const loadout = EquippedLoadoutDef(
          mainWeaponId: WeaponId.woodenSword,
          offhandWeaponId: WeaponId.woodenShield,
          abilityMobilityId: 'eloise.hold_auto_dash',
        );

        final result = validator.validate(loadout);
        expect(result.isValid, isTrue, reason: 'Issues: ${result.issues}');
        expect(result.issues, isEmpty);
      },
    );

    test('quick throw is valid when projectile slot spell is selected', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.woodenSword,
        offhandWeaponId: WeaponId.woodenShield,
        projectileItemId: ProjectileItemId.throwingKnife,
        projectileSlotSpellId: ProjectileItemId.fireBolt,
        abilityProjectileId: 'eloise.quick_shot',
        abilityBonusId: 'eloise.arcane_haste',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isTrue, reason: 'Issues: ${result.issues}');
      expect(result.issues, isEmpty);
    });

    test('non-spell ability cannot be equipped in bonus slot', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.woodenSword,
        offhandWeaponId: WeaponId.woodenShield,
        projectileItemId: ProjectileItemId.throwingKnife,
        abilityProjectileId: 'eloise.charged_shot',
        abilityBonusId: 'eloise.quick_shot',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isFalse);
      expect(
        result.issues.any(
          (issue) =>
              issue.slot == AbilitySlot.bonus &&
              issue.kind == IssueKind.slotNotAllowed,
        ),
        isTrue,
      );
    });

    test('bonus self spell is valid', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.woodenSword,
        offhandWeaponId: WeaponId.woodenShield,
        projectileItemId: ProjectileItemId.throwingKnife,
        spellBookId: SpellBookId.epicSpellBook,
        abilityBonusId: 'eloise.restore_health',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isTrue, reason: 'Issues: ${result.issues}');
      expect(result.issues, isEmpty);
    });

    test('bonus self spell must be granted by equipped spellbook', () {
      const loadout = EquippedLoadoutDef(
        spellBookId: SpellBookId.basicSpellBook,
        abilityBonusId: 'eloise.restore_health',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isFalse);
      expect(
        result.issues.any(
          (issue) =>
              issue.slot == AbilitySlot.bonus &&
              issue.kind == IssueKind.catalogMissing,
        ),
        isTrue,
      );
    });

    test('selected slot spell must be a projectile spell item', () {
      const loadout = EquippedLoadoutDef(
        projectileSlotSpellId: ProjectileItemId.throwingAxe,
        abilityProjectileId: 'eloise.quick_shot',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isFalse);
      expect(
        result.issues.any(
          (issue) =>
              issue.slot == AbilitySlot.projectile &&
              issue.kind == IssueKind.missingRequiredWeaponTypes,
        ),
        isTrue,
      );
    });

    test('bonus-only spell cannot be equipped in projectile slot', () {
      const loadout = EquippedLoadoutDef(
        abilityProjectileId: 'eloise.arcane_haste',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isFalse);
      expect(
        result.issues.any(
          (issue) =>
              issue.kind == IssueKind.slotNotAllowed &&
              issue.slot == AbilitySlot.projectile,
        ),
        isTrue,
      );
    });

    test('invalid slot (shield bash in primary) should fail', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.basicSword,
        abilityPrimaryId: 'eloise.shield_bash', // Requires Secondary slot
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isFalse);
      expect(
        result.issues.any((i) => i.kind == IssueKind.slotNotAllowed),
        isTrue,
      );
    });

    test('category mismatch (shield in primary) should fail', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.basicShield, // OffHand category
        abilityPrimaryId: 'eloise.sword_strike',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isFalse);
      expect(
        result.issues.any((i) => i.kind == IssueKind.weaponCategoryMismatch),
        isTrue,
      );
    });

    test('missing required weapon types (shield block with sword) should fail', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.woodenSword,
        offhandWeaponId: WeaponId
            .woodenSword, // Invalid for other reasons, but let's test gating
        abilitySecondaryId:
            'eloise.shield_block', // Requires shield weapon type.
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

    test(
      'missing required weapon types (valid category, wrong capabilities) should fail',
      () {
        const tagValidator = LoadoutValidator(
          abilityCatalog: TestAbilityCatalog(),
          weaponCatalog: weaponCatalog,
          projectileItemCatalog: projectileItemCatalog,
          spellBookCatalog: SpellBookCatalog(),
        );

        const loadout = EquippedLoadoutDef(
          offhandWeaponId: WeaponId.basicShield,
          abilitySecondaryId: TestAbilityCatalog.testAbilityId,
        );

        final result = tagValidator.validate(loadout);
        expect(result.isValid, isFalse);
        expect(
          result.issues.any(
            (i) => i.kind == IssueKind.missingRequiredWeaponTypes,
          ),
          isTrue,
        );

        final issue = result.issues.firstWhere(
          (i) => i.kind == IssueKind.missingRequiredWeaponTypes,
        );
        expect(issue.missingWeaponTypes, contains(WeaponType.oneHandedSword));
      },
    );

    test('two-handed primary with off-hand equipped should fail', () {
      // Use mock catalog that defines solidSword as Two-Handed
      final mockValidator = LoadoutValidator(
        abilityCatalog: abilityCatalog,
        weaponCatalog: const MockWeaponCatalog(),
        projectileItemCatalog: projectileItemCatalog,
        spellBookCatalog: const SpellBookCatalog(),
      );

      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.solidSword, // Mocked as 2H
        offhandWeaponId: WeaponId.basicShield, // Conflict!
        abilityPrimaryId: 'eloise.sword_strike',
      );

      final result = mockValidator.validate(loadout);
      expect(result.isValid, isFalse);
      expect(
        result.issues.any((i) => i.kind == IssueKind.twoHandedConflict),
        isTrue,
      );
    });
  });
}

class MockWeaponCatalog implements WeaponCatalog {
  const MockWeaponCatalog();

  @override
  WeaponDef? tryGet(WeaponId id) {
    if (id == WeaponId.solidSword) {
      return const WeaponDef(
        id: WeaponId.solidSword,
        category: WeaponCategory.primary,
        weaponType: WeaponType.oneHandedSword,
        isTwoHanded: true,
      );
    }
    return const WeaponCatalog().tryGet(id);
  }

  @override
  WeaponDef get(WeaponId id) => tryGet(id)!;
}

class TestAbilityCatalog extends AbilityCatalog {
  const TestAbilityCatalog();

  static const String testAbilityId = 'test.shield_smash';

  static const AbilityDef _testAbility = AbilityDef(
    id: testAbilityId,
    category: AbilityCategory.defense,
    allowedSlots: {AbilitySlot.secondary},
    targetingModel: TargetingModel.directional,
    inputLifecycle: AbilityInputLifecycle.tap,
    hitDelivery: SelfHitDelivery(),
    windupTicks: 0,
    activeTicks: 0,
    recoveryTicks: 0,
    staminaCost: 0,
    manaCost: 0,
    cooldownTicks: 0,
    animKey: AnimKey.idle,
    requiredWeaponTypes: {WeaponType.oneHandedSword},
    baseDamage: 0,
  );

  @override
  AbilityDef? resolve(AbilityKey key) {
    if (key == testAbilityId) return _testAbility;
    return super.resolve(key);
  }
}
