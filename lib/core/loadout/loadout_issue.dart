import '../abilities/ability_def.dart';

/// The kind of issue found during loadout validation.
enum IssueKind {
  /// Ability is not allowed in this slot (checked against `allowedSlots`).
  slotNotAllowed,

  /// Equipped weapon definition does not match the slot's expected category.
  weaponCategoryMismatch,

  /// Equipped weapon (or effective weapon) lacks tags required by the ability.
  missingRequiredTags,

  /// Equipped weapon (or effective weapon) lacks required weapon types.
  missingRequiredWeaponTypes,

  /// Ability requires an equipped weapon, but none is present.
  requiresEquippedWeapon,

  /// Two-handed primary weapon conflicts with a separately equipped off-hand item.
  twoHandedConflict,

  /// References a definition that does not exist in the catalog.
  catalogMissing,
}

/// A single validation error or warning for a loadout.
class LoadoutIssue {
  const LoadoutIssue({
    required this.slot,
    required this.kind,
    this.abilityId,
    this.weaponId,
    this.missingTags = const {},
    this.missingWeaponTypes = const {},
    this.message = '',
  });

  /// The slot where the issue occurred.
  final AbilitySlot slot;

  /// The specific kind of validation failure.
  final IssueKind kind;

  /// The ID of the ability involved, if known.
  final String? abilityId;

  /// The ID of the weapon involved, if known.
  final String? weaponId;

  /// If [kind] is [missingRequiredTags], this set contains the missing tags.
  final Set<AbilityTag> missingTags;

  /// If [kind] is [missingRequiredWeaponTypes], this set contains the missing types.
  final Set<WeaponType> missingWeaponTypes;

  /// A human-readable message describing the issue.
  final String message;

  @override
  String toString() {
    return 'LoadoutIssue($slot, $kind, ability:$abilityId, weapon:$weaponId, missingTags:$missingTags, missingWeaponTypes:$missingWeaponTypes)';
  }
}
