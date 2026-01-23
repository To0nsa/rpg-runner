# Phase 3: Equip-Time Validation — **Locked Spec**

## Goal

Implement **equip-time validation** that enforces:
1. **Ability-weapon gating** — abilities can only equip if weapon provides required capabilities.
2. **Two-handed weapon enforcement** — two-handed weapons occupy both primary and secondary slots.
3. **Slot-ability compatibility** — abilities can only equip to allowed slots.
4. **Category consistency** — equipment must match the slot's intended category.

**Hard constraint:** Phase 3 validation runs at menu/loadout time. Runtime systems remain unchanged.

---

## Design Pillars

### P1 — Derived Offhand Model
When a **Two-Handed** weapon is equipped in the Primary slot:
- The Secondary (Off-hand) slot is **derived** from the Primary.
- The stored `offhandWeaponId` is largely ignored or treated as "none" during validation.
- The menu UI prevents equipping a separate off-hand item.
- Validation ensures `offhandWeaponId` is not set to a conflicting item.

### P2 — Explicit "None" Semantics
- `WeaponId.none` / `RangedWeaponId.none` represent "Nothing Equipped".
- `weaponNotFound` (catalog miss) is distinct from `none`.
- Validation treats `none` as a valid "empty" state (unless a slot strictly requires an item).

### P3 — Capabilities Everywhere
- **All** equipment (Melee Weapons, Ranged Weapons, and potentially Spells) provides `grantedAbilityTags`.
- **All** abilities declare `requiredTags`.
- Rule: `ability.requiredTags ⊆ equippedItem.grantedAbilityTags`.

---

## Validation Logic

### 1. Data Structures

#### `LoadoutIssue`
Actionable diagnostic object.

```dart
enum IssueKind {
  slotNotAllowed,           // Ability not allowed in this slot
  weaponCategoryMismatch,   // Weapon in slot is wrong category (e.g. shield in primary)
  missingRequiredTags,      // Weapon lacks tags required by ability
  requiresEquippedWeapon,   // Ability needs *some* weapon, but slot is empty
  twoHandedConflict,        // Separate offhand equipped while using 2H primary
  catalogMissing,           // ID not found in catalog (corruption)
}

class LoadoutIssue {
  const LoadoutIssue({
    required this.slot,
    required this.kind,
    this.abilityId,
    this.weaponId,
    this.missingTags = const {},
    this.message = '',
  });

  final AbilitySlot slot;
  final IssueKind kind;
  final String? abilityId;
  final String? weaponId;
  final Set<AbilityTag> missingTags;
  final String message;
}
```

#### `LoadoutValidationResult`

```dart
class LoadoutValidationResult {
  const LoadoutValidationResult({
    required this.isValid,
    this.issues = const [],
  });

  final bool isValid;
  final List<LoadoutIssue> issues;
}
```

### 2. Validation Hierarchy

For each slot `(AbilitySlot, WeaponSlot, ExpectedCategory)`:

1.  **Catalog Check**: Do the Ability and Weapon IDs exist?
    *   If missing -> `catalogMissing`.
2.  **Category Check**: Does the equipped Weapon match `ExpectedCategory`?
    *   e.g., `offHand` slot must have `WeaponCategory.offHand`.
    *   If mismatch -> `weaponCategoryMismatch`.
3.  **Slot Legality**: Is `AbilitySlot` in `ability.allowedSlots`?
    *   If no -> `slotNotAllowed`.
4.  **Two-Handed Rule** (Secondary Slot only):
    *   If Primary is 2H:
        *   If `offhandWeaponId != none` -> `twoHandedConflict`.
        *   Effective Weapon = Primary Weapon.
    *   Else:
        *   Effective Weapon = Equipped Offhand Weapon.
5.  **Weapon Presence**:
    *   If `ability.requiresEquippedWeapon` is true AND `Effective Weapon == none` -> `requiresEquippedWeapon`.
6.  **Tag Gating**:
    *   Check `ability.requiredTags ⊆ effectiveWeapon.grantedAbilityTags`.
    *   If missing tags -> `missingRequiredTags` (populate `missingTags`).

---

## Schema Changes

### `RangedWeaponDef` (Upgrade)
Add `grantedAbilityTags` to unify gating logic.

```dart
class RangedWeaponDef {
  // ... existing fields ...
  
  /// Capabilities provided by this ranged weapon (e.g. [projectile, physical]).
  final Set<AbilityTag> grantedAbilityTags;
}
```
*Note: This allows "Projectile" slot to support both Thrown Weapons (granting `projectile`) and potentially Spell Focuses (granting `magic` or `fire`).*

### `AbilityDef` (Refinement)
Add explicit weapon requirement flag.

```dart
class AbilityDef {
  // ...
  
  /// If true, this ability requires *some* weapon to be equipped in its slot,
  /// even if requiredTags is empty.
  final bool requiresEquippedWeapon;
}
```

---

## Slot Mapping

| Ability Slot | Backing Equipment | Expected Category | Notes |
| :--- | :--- | :--- | :--- |
| **Primary** | `mainWeaponId` | `primary` | Checks `grantedAbilityTags` |
| **Secondary** | `offhandWeaponId` | `offHand` | Inherits Primary if 2H |
| **Projectile** | `rangedWeaponId` | `projectile` | Checks `grantedAbilityTags`. Covers Throws & Spells. |
| **Mobility** | *None* | *None* | No weapon check |
| **Bonus** | *None* | *None* | No weapon inheritance (per feedback) |

---

## Action Items

### New Files
- `lib/core/loadout/loadout_issue.dart`
- `lib/core/loadout/loadout_validation_result.dart`
- `lib/core/loadout/loadout_validator.dart`

### Modified Files
- `lib/core/weapons/ranged_weapon_def.dart` — Add `grantedAbilityTags`.
- `lib/core/weapons/ranged_weapon_catalog.dart` — Populate tags (e.g. `projectile, physical`).
- `lib/core/weapons/weapon_catalog.dart` — Ensure categories are correct.
- `lib/core/abilities/ability_def.dart` — Add `requiresEquippedWeapon`.

### Tests
- `test/core/loadout/loadout_validator_test.dart`
  - Test valid loadouts.
  - Test 2H derivation (valid 2H+EmptyOffhand, invalid 2H+Shield).
  - Test category mismatches.
  - Test tag gating (missing tags).
  - Test explicit "none" handling.
