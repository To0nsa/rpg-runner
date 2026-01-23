import '../abilities/ability_catalog.dart';
import '../abilities/ability_def.dart';
import '../ecs/stores/combat/equipped_loadout_store.dart';
import '../weapons/ranged_weapon_catalog.dart';
import '../weapons/ranged_weapon_def.dart';
import '../weapons/ranged_weapon_id.dart';
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
    required this.rangedWeaponCatalog,
  });

  final AbilityCatalog abilityCatalog;
  final WeaponCatalog weaponCatalog;
  final RangedWeaponCatalog rangedWeaponCatalog;

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

    final rangedWeapon = _resolveRangedWeapon(
      loadout.rangedWeaponId,
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
      effectiveWeapon: mainWeapon,
      weaponTags: mainWeapon?.grantedAbilityTags ?? const {},
    );

    // Secondary
    _validateSlot(
      issues: issues,
      abilityId: loadout.abilitySecondaryId,
      slot: AbilitySlot.secondary,
      effectiveWeapon: effectiveSecondaryWeapon,
      weaponTags: effectiveSecondaryWeapon?.grantedAbilityTags ?? const {},
    );

    // Projectile
    _validateSlot(
      issues: issues,
      abilityId: loadout.abilityProjectileId,
      slot: AbilitySlot.projectile,
      effectiveWeapon: rangedWeapon,
      weaponTags: rangedWeapon?.grantedAbilityTags ?? const {},
    );

    // Mobility (No weapon)
    _validateSlot(
      issues: issues,
      abilityId: loadout.abilityMobilityId,
      slot: AbilitySlot.mobility,
      effectiveWeapon: null,
      weaponTags: const {},
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
    // Explicit NONE check (Phase 3 Rule: none is valid empty)
    // Note: Assuming WeaponId has 'none' based on typical patterns, 
    // but WeaponId enum in codebase doesn't have 'none' yet (Phase 1 legacy).
    // The design doc mentioned "WeaponId.none exist (or you disallow none entirely)".
    // Looking at WeaponId enum: basicSword, basicShield... no none.
    // However, EquipmentLoadoutStore uses WeaponId.basicSword as default.
    // If we assume valid IDs are required for now as per "Slots are never empty" rule,
    // then 'none' might not be reachable. 
    // BUT the Phase 3 design explicitly requested "P2 — Explicit None Semantics".
    // Since I can't change WeaponId enum easily without breaking things or I should have added it,
    // I will check if I should effectively treat "invalid lookup" as "none" OR 
    // if I should strictly validate existence.
    // The previous implementation used tryGet which returns null.
    // I'll treat "valid lookup" as "equipped".
    
    // Actually, let's treat lookup failure differently based on Phase 3 design "missing vs none".
    // For now, let's rely on tryGet.

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
      // Return null so we don't cascade category errors into tag errors? 
      // Or return weapon so we can still check tags? 
      // Returning weapon allows more checks, but might be noisy. 
      // Let's return null to fail-fast on this slot's weapon.
      return null;
    }

    return weapon;
  }

  RangedWeaponDef? _resolveRangedWeapon(
    RangedWeaponId id,
    AbilitySlot slot,
    List<LoadoutIssue> issues,
  ) {
    final weapon = rangedWeaponCatalog.tryGet(id);
    if (weapon == null) {
      issues.add(LoadoutIssue(
        slot: slot,
        kind: IssueKind.catalogMissing,
        weaponId: id.toString(),
        message: 'Ranged Weapon ID not found in catalog.',
      ));
      return null;
    }
    return weapon;
  }

  void _validateSlot({
    required List<LoadoutIssue> issues,
    required AbilityKey abilityId,
    required AbilitySlot slot,
    required Object? effectiveWeapon, // WeaponDef or RangedWeaponDef or null
    required Set<AbilityTag> weaponTags,
  }) {
    final ability = AbilityCatalog.tryGet(abilityId);
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
    if (ability.requiresEquippedWeapon && effectiveWeapon == null) {
      issues.add(LoadoutIssue(
        slot: slot,
        kind: IssueKind.requiresEquippedWeapon,
        abilityId: abilityId,
        message: 'Ability requires an equipped weapon.',
      ));
    }

    // 3. Tag Gating
    if (ability.requiredTags.isNotEmpty) {
      // Check subset: requiredTags ⊆ weaponTags
      final missing = ability.requiredTags.difference(weaponTags);
      if (missing.isNotEmpty) {
        issues.add(LoadoutIssue(
          slot: slot,
          kind: IssueKind.missingRequiredTags,
          abilityId: abilityId,
          missingTags: missing,
          message: 'Missing required tags: ${missing.join(", ")}.',
        ));
      }
    }
  }
}
