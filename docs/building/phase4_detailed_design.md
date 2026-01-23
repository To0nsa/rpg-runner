# Phase 4: Runtime Data Model Shift — **Locked Spec**

## Goal

Transition the **runtime source of truth** for damage, costs, and cooldowns from **Weapons** to **Abilities**.
This realizes the "Ability Owns Structure, Weapon Owns Payload" design pillar.

**Hard constraint:** Phase 4 changes **runtime behavior** to read from new fields. This is a breaking change for internal logic, but must preserve external gameplay behavior (determinism).

---

## Design Pillars

### P1 — Ability Owns Structure
The **AbilityDef** becomes the authoritative source for:
- **Base Damage**: The core damage value of the action (new field).
- **Costs**: Stamina, Mana, etc. required to commit (existing fields).
- **Cooldown**: Time before the ability can be used again (existing field).
- **Targeting**: Range, shape, and window (existing).

### P2 — Weapon Owns Payload
The **WeaponDef** (and `RangedWeaponDef`) provides:
- **Projectile Identity (Thrown only)**: The physical object being thrown (e.g., specific knife).
- **Physical Properties**: Gravity, ballistics.
- **Payload Modifiers**: Damage type, generic procs (bleed, burn), and stats.

### P3 — Projectile Ownership Rule
- **Thrown Weapons**: Projectile identity comes from the **equipped weapon** (`RangedWeaponDef.projectileId`).
- **Spells**: Projectile identity comes from the **ability itself** (`ProjectileHitDelivery.projectileId`).

### P4 — Numeric Consistency
All new fields must use the existing fixed-point domain (e.g., `int` where 100 = 1.0) or `clicks` to match current determinism standards. **No floating point base damage.**

---

## Schema Changes

### 1. `AbilityDef` (Additions)
Add `baseDamage` to carry the structural damage value.

```dart
class AbilityDef {
  // ... existing fields ...

  /// Base damage for this ability.
  /// Fixed-point: 100 = 1.0 damage.
  /// - Melee: Base damage of the swing.
  /// - Thrown: Base damage of the throw.
  /// - Spell: Base damage of the spell projectile.
  final int baseDamage; 

  // Existing fields used in Phase 4:
  // final int staminaCost;
  // final int manaCost;
  // final int cooldownTicks;
}
```

### 2. `RangedWeaponDef` (Deprecation)
Runtime systems must **stop reading** these fields.

```dart
class RangedWeaponDef {
  // ...
  
  // IGNORED IN PHASE 4 (Runtime reads AbilityDef instead)
  @Deprecated('Use AbilityDef.baseDamage')
  final double legacyDamage; 
  
  @Deprecated('Use AbilityDef.staminaCost')
  final double legacyStaminaCost;
  
  @Deprecated('Use AbilityDef.cooldownTicks')
  final double legacyCooldownSeconds;
}
```

---

## Runtime Integration

### 1. Unified Payload Builder
Introduce a helper (or system logic) to merge Ability structure with Weapon payload.

```dart
HitPayload buildHitPayload(AbilityDef ability, WeaponDef? weapon) {
  // 1. Start with Ability Structure
  var payload = HitPayload(
    baseDamage: ability.baseDamage,
    // ...
  );
  
  // 2. Apply Weapon Payload (if equipped)
  if (weapon != null) {
    payload.damageType = weapon.damageType;
    payload.procs.addAll(effectiveWeaponProcs(weapon));
    // NOTE: Stat scaling (powerBonus) is PHASE 5. 
    // Do NOT apply it here yet.
  }
  
  return payload;
}
```

### 2. `RangedWeaponIntent` Refactor
Update `AbilityActivationSystem` (or legacy `PlayerRangedSystem`) to use the new source of truth.

**Legacy (Delete):**
```dart
// OLD
intent.damage = rangedWeapon.legacyDamage;
intent.staminaCost = rangedWeapon.legacyStaminaCost;
intent.rechargeTicks = rangedWeapon.legacyCooldownSeconds * 60;
intent.projectileId = rangedWeapon.projectileId; // CORRECT for Thrown, WRONG for Spells
```

**Phase 4 (New):**
```dart
// NEW
intent.damage = ability.baseDamage;
intent.staminaCost = ability.staminaCost;
intent.rechargeTicks = ability.cooldownTicks;

// Projectile Identity Logic
if (ability.category == AbilityCategory.projectile && ability.tags.contains(AbilityTag.spell)) {
   // Spells own their projectile
   intent.projectileId = (ability.hitDelivery as ProjectileHitDelivery).projectileId;
} else {
   // Thrown weapons use the weapon's projectile
   intent.projectileId = equippedRangedWeapon.projectileId;
}
```

### 3. Derived Helpers
**Action**: Clean up `RangedWeaponCatalogDerived`.
- Remove `cooldownTicks` getter (which wraps `legacyCooldownSeconds`).
- Direct consumers to use `ability.cooldownTicks`.

---

## Migration Steps

1.  **Populate Ability Data**: Update `AbilityCatalog` to include correct `baseDamage` values.
    *   *Critical*: Must exactly match `oldWeapon.damage` to pass regression tests.
    *   Ensure `cooldownTicks` in catalog matches `ceil(oldSeconds * 60)`.
2.  **Refactor Systems**: Update `PlayerRangedWeaponSystem` and `PlayerCastSystem` to read from `AbilityDef`.
3.  **Strict Equivalence Verification**: Run deterministic replay tests.
4.  **Deprecate**: Mark legacy fields as `@Deprecated`.

---

## Validation Plan

### Automated
1.  **Catalog Consistency Test**:
    *   Iterate all `RangedWeaponDef`s.
    *   Find corresponding `AbilityDef` (e.g., via name convention or lookup).
    *   Assert `ability.baseDamage == weapon.legacyDamage` (allowing for type conversion if legacy was double).
    *   Assert `ability.cooldownTicks == ceil(weapon.legacyCooldownSeconds * 60)`.

2.  **Gameplay Regression**:
    *   Run strict deterministic replay.
    *   Verify `DamageEvent` values are bit-identical to Phase 3.

### Manual
- **Smoke Test**: Equip generic "Throwing Dagger". Verify damage numbers are visible and match expected values. Note any stamina drain.

---

## Out of Scope (Phase 5+)
- **Stat Scaling**: `weapon.stats.powerBonus` scaling `baseDamage` is **forbidden** in Phase 4.
- **Complex Procs**: New proc logic beyond `effectiveWeaponProcs` bridge.
