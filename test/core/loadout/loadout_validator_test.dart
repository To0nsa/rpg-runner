import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/loadout/loadout_issue.dart';
import 'package:rpg_runner/core/loadout/loadout_validator.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/spellBook/spell_book_catalog.dart';
import 'package:rpg_runner/core/spellBook/spell_book_id.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_category.dart';
import 'package:rpg_runner/core/weapons/weapon_def.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';

void main() {
  group('LoadoutValidator', () {
    const abilityCatalog = AbilityCatalog();
    const weaponCatalog = WeaponCatalog();
    const projectileCatalog = ProjectileCatalog();

    final validator = LoadoutValidator(
      abilityCatalog: abilityCatalog,
      weaponCatalog: weaponCatalog,
      projectileCatalog: projectileCatalog,
      spellBookCatalog: const SpellBookCatalog(),
    );

    test('valid standard loadout should pass', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.plainsteel,
        offhandWeaponId: WeaponId.woodenShield,
        projectileId: ProjectileId.throwingKnife,
        abilityPrimaryId: 'eloise.bloodletter_slash',
        abilitySecondaryId: 'eloise.aegis_riposte',
        abilityProjectileId: 'eloise.quick_shot',
        abilityMobilityId: 'eloise.dash',
        abilitySpellId: 'eloise.arcane_haste',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isTrue, reason: 'Issues: ${result.issues}');
      expect(result.issues, isEmpty);
    });

    test('auto-aim melee variants are valid in their authored slots', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.plainsteel,
        offhandWeaponId: WeaponId.woodenShield,
        abilityPrimaryId: 'eloise.seeker_slash',
        abilitySecondaryId: 'eloise.seeker_bash',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isTrue, reason: 'Issues: ${result.issues}');
      expect(result.issues, isEmpty);
    });

    test('tiered melee and dash mobility are valid in authored slots', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.plainsteel,
        offhandWeaponId: WeaponId.woodenShield,
        abilityPrimaryId: 'eloise.bloodletter_cleave',
        abilityMobilityId: 'eloise.dash',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isTrue, reason: 'Issues: ${result.issues}');
      expect(result.issues, isEmpty);
    });

    test('roll mobility is valid in authored mobility slot', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.plainsteel,
        offhandWeaponId: WeaponId.woodenShield,
        abilityMobilityId: 'eloise.roll',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isTrue, reason: 'Issues: ${result.issues}');
      expect(result.issues, isEmpty);
    });

    test('quick throw is valid when projectile slot spell is selected', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.plainsteel,
        offhandWeaponId: WeaponId.woodenShield,
        projectileId: ProjectileId.throwingKnife,
        projectileSlotSpellId: ProjectileId.fireBolt,
        abilityProjectileId: 'eloise.quick_shot',
        abilitySpellId: 'eloise.arcane_haste',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isTrue, reason: 'Issues: ${result.issues}');
      expect(result.issues, isEmpty);
    });

    test('non-spell ability cannot be equipped in spell slot', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.plainsteel,
        offhandWeaponId: WeaponId.woodenShield,
        projectileId: ProjectileId.throwingKnife,
        abilityProjectileId: 'eloise.overcharge_shot',
        abilitySpellId: 'eloise.quick_shot',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isFalse);
      expect(
        result.issues.any(
          (issue) =>
              issue.slot == AbilitySlot.spell &&
              issue.kind == IssueKind.slotNotAllowed,
        ),
        isTrue,
      );
    });

    test('spell-slot self spell is valid', () {
      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.plainsteel,
        offhandWeaponId: WeaponId.woodenShield,
        projectileId: ProjectileId.throwingKnife,
        spellBookId: SpellBookId.epicSpellBook,
        abilitySpellId: 'eloise.vital_surge',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isTrue, reason: 'Issues: ${result.issues}');
      expect(result.issues, isEmpty);
    });

    test('spell-slot self spell is not gated by spellbook grants', () {
      const loadout = EquippedLoadoutDef(
        spellBookId: SpellBookId.basicSpellBook,
        abilitySpellId: 'eloise.vital_surge',
      );

      final result = validator.validate(loadout);
      expect(result.isValid, isTrue, reason: 'Issues: ${result.issues}');
      expect(result.issues, isEmpty);
    });

    test('selected slot spell must be a projectile spell item', () {
      const loadout = EquippedLoadoutDef(
        projectileSlotSpellId: ProjectileId.throwingAxe,
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

    test('spell-slot-only spell cannot be equipped in projectile slot', () {
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
        mainWeaponId: WeaponId.plainsteel,
        abilityPrimaryId: 'eloise.concussive_bash', // Requires Secondary slot
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
        abilityPrimaryId: 'eloise.bloodletter_slash',
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
        mainWeaponId: WeaponId.plainsteel,
        offhandWeaponId: WeaponId
            .plainsteel, // Invalid for other reasons, but let's test gating
        abilitySecondaryId:
            'eloise.aegis_riposte', // Requires shield weapon type.
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
          projectileCatalog: projectileCatalog,
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
      // Use mock catalog that defines graveglass as Two-Handed.
      final mockValidator = LoadoutValidator(
        abilityCatalog: abilityCatalog,
        weaponCatalog: const MockWeaponCatalog(),
        projectileCatalog: projectileCatalog,
        spellBookCatalog: const SpellBookCatalog(),
      );

      const loadout = EquippedLoadoutDef(
        mainWeaponId: WeaponId.graveglass, // Mocked as 2H
        offhandWeaponId: WeaponId.basicShield, // Conflict!
        abilityPrimaryId: 'eloise.bloodletter_slash',
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
    if (id == WeaponId.graveglass) {
      return const WeaponDef(
        id: WeaponId.graveglass,
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

  static final AbilityDef _testAbility = AbilityDef(
    id: testAbilityId,
    category: AbilityCategory.defense,
    allowedSlots: {AbilitySlot.secondary},
    targetingModel: TargetingModel.directional,
    inputLifecycle: AbilityInputLifecycle.tap,
    hitDelivery: SelfHitDelivery(),
    windupTicks: 0,
    activeTicks: 0,
    recoveryTicks: 0,
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
