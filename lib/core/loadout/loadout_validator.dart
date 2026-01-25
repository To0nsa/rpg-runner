import '../abilities/ability_catalog.dart';
import '../abilities/ability_def.dart';
import '../ecs/stores/combat/equipped_loadout_store.dart';
import '../projectiles/projectile_item_catalog.dart';
import '../projectiles/projectile_item_def.dart';
import '../projectiles/projectile_item_id.dart';
import '../weapons/weapon_catalog.dart';
import '../weapons/weapon_category.dart';
import '../weapons/weapon_def.dart';
import '../weapons/weapon_id.dart';
import 'loadout_issue.dart';
import 'loadout_validation_result.dart';

/// Stateless validator for checking loadout legality.
class LoadoutValidator {
  const LoadoutValidator({
    required this.abilityCatalog,
    required this.weaponCatalog,
    required this.projectileItemCatalog,
  });

  final AbilityCatalog abilityCatalog;
  final WeaponCatalog weaponCatalog;
  final ProjectileItemCatalog projectileItemCatalog;

  /// Validates an entire loadout definition.
  LoadoutValidationResult validate(EquippedLoadoutDef loadout) {
    final issues = <LoadoutIssue>[];

    // 1. Resolve Weapons
    final mainWeapon = _resolveWeapon(
      loadout.mainWeaponId,
      WeaponCategory.primary,
      AbilitySlot.primary,
      issues,
    );

    final offhandWeapon = _resolveWeapon(
      loadout.offhandWeaponId,
      WeaponCategory.offHand,
      AbilitySlot.secondary,
      issues,
    );

    final projectileItem = _resolveProjectileItem(
      loadout.projectileItemId,
      AbilitySlot.projectile,
      issues,
    );

    // 2. Derive Effective Weapons (Two-Handed Logic)
    final isTwoHanded = mainWeapon?.isTwoHanded ?? false;

    // Rule: Two-Handed weapon blocks separate secondary weapon
    if (isTwoHanded && offhandWeapon != null) {
      issues.add(LoadoutIssue(
        slot: AbilitySlot.secondary,
        kind: IssueKind.twoHandedConflict,
        weaponId: loadout.offhandWeaponId.toString(),
        message: 'Cannot equip off-hand weapon with two-handed primary.',
      ));
    }

    // Effective weapons for gating
    final effectiveSecondaryWeapon = isTwoHanded ? mainWeapon : offhandWeapon;

    // 3. Validate Slots

    // Primary
    _validateSlot(
      issues: issues,
      abilityId: loadout.abilityPrimaryId,
      slot: AbilitySlot.primary,
      hasWeapon: mainWeapon != null,
      weaponType: mainWeapon?.weaponType,
    );

    // Secondary
    _validateSlot(
      issues: issues,
      abilityId: loadout.abilitySecondaryId,
      slot: AbilitySlot.secondary,
      hasWeapon: effectiveSecondaryWeapon != null,
      weaponType: effectiveSecondaryWeapon?.weaponType,
    );

    // Projectile
    _validateSlot(
      issues: issues,
      abilityId: loadout.abilityProjectileId,
      slot: AbilitySlot.projectile,
      hasWeapon: projectileItem != null,
      weaponType: projectileItem?.weaponType,
    );

    // Mobility (No weapon)
    _validateSlot(
      issues: issues,
      abilityId: loadout.abilityMobilityId,
      slot: AbilitySlot.mobility,
      hasWeapon: false,
      weaponType: null,
    );

    // Jump (Fixed slot, no weapon)
    _validateSlot(
      issues: issues,
      abilityId: loadout.abilityJumpId,
      slot: AbilitySlot.jump,
      hasWeapon: false,
      weaponType: null,
    );

    return LoadoutValidationResult(
      isValid: issues.isEmpty,
      issues: issues,
    );
  }

  WeaponDef? _resolveWeapon(
    WeaponId id,
    WeaponCategory expectedCategory,
    AbilitySlot slot,
    List<LoadoutIssue> issues,
  ) {
    final weapon = weaponCatalog.tryGet(id);
    if (weapon == null) {
      // If we assume LoadoutStore always has valid defaults, this is a corruption/catalogMissing.
      // If we want to support "none", we'd need a specific ID for it or nullable field.
      // LoadoutDefs are non-nullable IDs.
      // So if tryGet fails, it's catalogMissing.
      issues.add(LoadoutIssue(
        slot: slot,
        kind: IssueKind.catalogMissing,
        weaponId: id.toString(),
        message: 'Weapon ID not found in catalog.',
      ));
      return null;
    }

    if (weapon.category != expectedCategory) {
      issues.add(LoadoutIssue(
        slot: slot,
        kind: IssueKind.weaponCategoryMismatch,
        weaponId: id.toString(),
        message: 'Expected $expectedCategory, found ${weapon.category}.',
      ));
      // Return null so we don't cascade category errors into type errors?
      // Or return weapon so we can still check types?
      // Returning weapon allows more checks, but might be noisy. 
      // Let's return null to fail-fast on this slot's weapon.
      return null;
    }

    return weapon;
  }

  ProjectileItemDef? _resolveProjectileItem(
    ProjectileItemId id,
    AbilitySlot slot,
    List<LoadoutIssue> issues,
  ) {
    final item = projectileItemCatalog.tryGet(id);
    if (item == null) {
      issues.add(LoadoutIssue(
        slot: slot,
        kind: IssueKind.catalogMissing,
        weaponId: id.toString(),
        message: 'Projectile item ID not found in catalog.',
      ));
      return null;
    }
    return item;
  }

  void _validateSlot({
    required List<LoadoutIssue> issues,
    required AbilityKey abilityId,
    required AbilitySlot slot,
    required bool hasWeapon,
    required WeaponType? weaponType,
  }) {
    final ability = abilityCatalog.resolve(abilityId);
    if (ability == null) {
      issues.add(LoadoutIssue(
        slot: slot,
        kind: IssueKind.catalogMissing,
        abilityId: abilityId,
        message: 'Ability ID not found in catalog.',
      ));
      return;
    }

    // 1. Slot Compatibility
    if (!ability.allowedSlots.contains(slot)) {
      issues.add(LoadoutIssue(
        slot: slot,
        kind: IssueKind.slotNotAllowed,
        abilityId: abilityId,
        message: 'Ability not allowed in $slot slot.',
      ));
    }

    // 2. Weapon Presence
    if (ability.requiresEquippedWeapon && !hasWeapon) {
      issues.add(LoadoutIssue(
        slot: slot,
        kind: IssueKind.requiresEquippedWeapon,
        abilityId: abilityId,
        message: 'Ability requires an equipped weapon.',
      ));
    }

    // 3. Weapon Type Gating
    if (ability.requiredWeaponTypes.isNotEmpty) {
      if (weaponType == null ||
          !ability.requiredWeaponTypes.contains(weaponType)) {
        issues.add(LoadoutIssue(
          slot: slot,
          kind: IssueKind.missingRequiredWeaponTypes,
          abilityId: abilityId,
          missingWeaponTypes: ability.requiredWeaponTypes,
          message: 'Missing required weapon types: ${ability.requiredWeaponTypes.join(", ")}.',
        ));
      }
    }
  }
}
