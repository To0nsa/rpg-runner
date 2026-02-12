import '../abilities/ability_catalog.dart';
import '../abilities/ability_def.dart';
import '../ecs/stores/combat/equipped_loadout_store.dart';
import '../projectiles/projectile_item_catalog.dart';
import '../projectiles/projectile_item_def.dart';
import '../projectiles/projectile_item_id.dart';
import '../spells/spell_book_catalog.dart';
import '../spells/spell_book_def.dart';
import '../spells/spell_book_id.dart';
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
    required this.spellBookCatalog,
  });

  final AbilityResolver abilityCatalog;
  final WeaponCatalog weaponCatalog;
  final ProjectileItemCatalog projectileItemCatalog;
  final SpellBookCatalog spellBookCatalog;

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

    final spellBook = _resolveSpellBook(loadout.spellBookId, issues);

    // 2. Derive Effective Weapons (Two-Handed Logic)
    final isTwoHanded = mainWeapon?.isTwoHanded ?? false;

    // Rule: Two-Handed weapon blocks separate secondary weapon
    if (isTwoHanded && offhandWeapon != null) {
      issues.add(
        LoadoutIssue(
          slot: AbilitySlot.secondary,
          kind: IssueKind.twoHandedConflict,
          weaponId: loadout.offhandWeaponId.toString(),
          message: 'Cannot equip off-hand weapon with two-handed primary.',
        ),
      );
    }

    // Effective weapons for gating
    final effectiveSecondaryWeapon = isTwoHanded ? mainWeapon : offhandWeapon;

    // 3. Validate Slots

    // Primary
    _validateSlot(
      issues: issues,
      abilityId: loadout.abilityPrimaryId,
      slot: AbilitySlot.primary,
      mainWeapon: mainWeapon,
      effectiveSecondaryWeapon: effectiveSecondaryWeapon,
      projectileItem: projectileItem,
      spellBook: spellBook,
      projectileSlotSpellId: loadout.projectileSlotSpellId,
    );

    // Secondary
    _validateSlot(
      issues: issues,
      abilityId: loadout.abilitySecondaryId,
      slot: AbilitySlot.secondary,
      mainWeapon: mainWeapon,
      effectiveSecondaryWeapon: effectiveSecondaryWeapon,
      projectileItem: projectileItem,
      spellBook: spellBook,
      projectileSlotSpellId: loadout.projectileSlotSpellId,
    );

    // Projectile
    _validateSlot(
      issues: issues,
      abilityId: loadout.abilityProjectileId,
      slot: AbilitySlot.projectile,
      mainWeapon: mainWeapon,
      effectiveSecondaryWeapon: effectiveSecondaryWeapon,
      projectileItem: projectileItem,
      spellBook: spellBook,
      projectileSlotSpellId: loadout.projectileSlotSpellId,
    );

    // Mobility (No weapon)
    _validateSlot(
      issues: issues,
      abilityId: loadout.abilityMobilityId,
      slot: AbilitySlot.mobility,
      mainWeapon: mainWeapon,
      effectiveSecondaryWeapon: effectiveSecondaryWeapon,
      projectileItem: projectileItem,
      spellBook: spellBook,
      projectileSlotSpellId: loadout.projectileSlotSpellId,
    );

    // Spell slot: payload gating is now driven by AbilityDef.payloadSource.
    _validateSlot(
      issues: issues,
      abilityId: loadout.abilitySpellId,
      slot: AbilitySlot.spell,
      mainWeapon: mainWeapon,
      effectiveSecondaryWeapon: effectiveSecondaryWeapon,
      projectileItem: projectileItem,
      spellBook: spellBook,
      projectileSlotSpellId: loadout.projectileSlotSpellId,
    );

    // Jump (Fixed slot, no weapon)
    _validateSlot(
      issues: issues,
      abilityId: loadout.abilityJumpId,
      slot: AbilitySlot.jump,
      mainWeapon: mainWeapon,
      effectiveSecondaryWeapon: effectiveSecondaryWeapon,
      projectileItem: projectileItem,
      spellBook: spellBook,
      projectileSlotSpellId: loadout.projectileSlotSpellId,
    );

    return LoadoutValidationResult(isValid: issues.isEmpty, issues: issues);
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
      issues.add(
        LoadoutIssue(
          slot: slot,
          kind: IssueKind.catalogMissing,
          weaponId: id.toString(),
          message: 'Weapon ID not found in catalog.',
        ),
      );
      return null;
    }

    if (weapon.category != expectedCategory) {
      issues.add(
        LoadoutIssue(
          slot: slot,
          kind: IssueKind.weaponCategoryMismatch,
          weaponId: id.toString(),
          message: 'Expected $expectedCategory, found ${weapon.category}.',
        ),
      );
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
      issues.add(
        LoadoutIssue(
          slot: slot,
          kind: IssueKind.catalogMissing,
          weaponId: id.toString(),
          message: 'Projectile item ID not found in catalog.',
        ),
      );
      return null;
    }
    return item;
  }

  SpellBookDef? _resolveSpellBook(SpellBookId id, List<LoadoutIssue> issues) {
    final book = spellBookCatalog.tryGet(id);
    if (book == null) {
      issues.add(
        LoadoutIssue(
          slot: AbilitySlot.spell,
          kind: IssueKind.catalogMissing,
          weaponId: id.toString(),
          message: 'Spell book ID not found in catalog.',
        ),
      );
      return null;
    }
    return book;
  }

  void _validateSlot({
    required List<LoadoutIssue> issues,
    required AbilityKey abilityId,
    required AbilitySlot slot,
    required WeaponDef? mainWeapon,
    required WeaponDef? effectiveSecondaryWeapon,
    required ProjectileItemDef? projectileItem,
    required SpellBookDef? spellBook,
    required ProjectileItemId? projectileSlotSpellId,
  }) {
    final ability = abilityCatalog.resolve(abilityId);
    if (ability == null) {
      issues.add(
        LoadoutIssue(
          slot: slot,
          kind: IssueKind.catalogMissing,
          abilityId: abilityId,
          message: 'Ability ID not found in catalog.',
        ),
      );
      return;
    }

    final effectiveProjectileItem = _effectiveProjectilePayloadForSlot(
      issues: issues,
      slot: slot,
      fallbackProjectileItem: projectileItem,
      spellBook: spellBook,
      projectileSlotSpellId: projectileSlotSpellId,
    );

    final (hasWeapon, weaponType) = _payloadContextFor(
      ability,
      mainWeapon: mainWeapon,
      effectiveSecondaryWeapon: effectiveSecondaryWeapon,
      projectileItem: effectiveProjectileItem,
      spellBook: spellBook,
    );

    // 1. Slot Compatibility
    if (!ability.allowedSlots.contains(slot)) {
      issues.add(
        LoadoutIssue(
          slot: slot,
          kind: IssueKind.slotNotAllowed,
          abilityId: abilityId,
          message: 'Ability not allowed in $slot slot.',
        ),
      );
    }

    // 2. Weapon Presence
    if (ability.requiresEquippedWeapon && !hasWeapon) {
      issues.add(
        LoadoutIssue(
          slot: slot,
          kind: IssueKind.requiresEquippedWeapon,
          abilityId: abilityId,
          message: 'Ability requires an equipped weapon.',
        ),
      );
    }

    // 3. Weapon Type Gating
    if (ability.requiredWeaponTypes.isNotEmpty) {
      if (weaponType == null ||
          !ability.requiredWeaponTypes.contains(weaponType)) {
        issues.add(
          LoadoutIssue(
            slot: slot,
            kind: IssueKind.missingRequiredWeaponTypes,
            abilityId: abilityId,
            missingWeaponTypes: ability.requiredWeaponTypes,
            message:
                'Missing required weapon types: ${ability.requiredWeaponTypes.join(", ")}.',
          ),
        );
      }
    }

    // 4. Spellbook grant gating for spell-slot self-spells.
    if (slot == AbilitySlot.spell &&
        ability.payloadSource == AbilityPayloadSource.spellBook &&
        spellBook != null &&
        !spellBook.containsSpellAbility(ability.id)) {
      issues.add(
        LoadoutIssue(
          slot: slot,
          kind: IssueKind.catalogMissing,
          abilityId: ability.id,
          weaponId: spellBook.id.toString(),
          message: 'Selected spell is not granted by the spellbook.',
        ),
      );
    }
  }

  ProjectileItemDef? _effectiveProjectilePayloadForSlot({
    required List<LoadoutIssue> issues,
    required AbilitySlot slot,
    required ProjectileItemDef? fallbackProjectileItem,
    required SpellBookDef? spellBook,
    required ProjectileItemId? projectileSlotSpellId,
  }) {
    final selectedSpellId = switch (slot) {
      AbilitySlot.projectile => projectileSlotSpellId,
      AbilitySlot.primary ||
      AbilitySlot.secondary ||
      AbilitySlot.mobility ||
      AbilitySlot.spell ||
      AbilitySlot.jump => null,
    };
    if (selectedSpellId == null) {
      return fallbackProjectileItem;
    }

    final selectedSpell = projectileItemCatalog.tryGet(selectedSpellId);
    if (selectedSpell == null) {
      issues.add(
        LoadoutIssue(
          slot: slot,
          kind: IssueKind.catalogMissing,
          weaponId: selectedSpellId.toString(),
          message:
              'Selected projectile spell was not found in ProjectileItemCatalog.',
        ),
      );
      return fallbackProjectileItem;
    }

    if (selectedSpell.weaponType != WeaponType.projectileSpell) {
      issues.add(
        LoadoutIssue(
          slot: slot,
          kind: IssueKind.missingRequiredWeaponTypes,
          weaponId: selectedSpellId.toString(),
          missingWeaponTypes: const <WeaponType>{WeaponType.projectileSpell},
          message: 'Selected slot spell must be a projectile spell item.',
        ),
      );
      return fallbackProjectileItem;
    }

    if (spellBook == null ||
        !spellBook.containsProjectileSpell(selectedSpellId)) {
      issues.add(
        LoadoutIssue(
          slot: slot,
          kind: IssueKind.catalogMissing,
          weaponId: selectedSpellId.toString(),
          message:
              'Selected projectile spell is not granted by the equipped spellbook.',
        ),
      );
      return fallbackProjectileItem;
    }

    return selectedSpell;
  }

  (bool hasWeapon, WeaponType? weaponType) _payloadContextFor(
    AbilityDef ability, {
    required WeaponDef? mainWeapon,
    required WeaponDef? effectiveSecondaryWeapon,
    required ProjectileItemDef? projectileItem,
    required SpellBookDef? spellBook,
  }) {
    switch (ability.payloadSource) {
      case AbilityPayloadSource.none:
        return (false, null);
      case AbilityPayloadSource.primaryWeapon:
        return (mainWeapon != null, mainWeapon?.weaponType);
      case AbilityPayloadSource.secondaryWeapon:
        // effectiveSecondaryWeapon already applies two-handed mapping
        return (
          effectiveSecondaryWeapon != null,
          effectiveSecondaryWeapon?.weaponType,
        );
      case AbilityPayloadSource.projectileItem:
        return (projectileItem != null, projectileItem?.weaponType);
      case AbilityPayloadSource.spellBook:
        return (spellBook != null, spellBook?.weaponType);
    }
  }
}
