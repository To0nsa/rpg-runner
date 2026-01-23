# Phase 2: Weapon Payload Refactor — Detailed Design

## Goal

Extend `WeaponDef` and `RangedWeaponDef` so that **weapons provide the payload** (damage type, procs, stats) while **abilities own the structure** (timing, targeting, base damage, costs).

This phase **does not change runtime behavior** yet — it prepares the data model so Phase 3+ can consume it.

---

## Current State Analysis

### WeaponDef (Melee)
```dart
class WeaponDef {
  final WeaponId id;
  final DamageType damageType;          // ✓ Keep
  final StatusProfileId statusProfileId; // → Replace with procs[]
}
```

**Issues:**
- No `category` (primary vs offHand).
- No `enabledAbilityTags` to gate which abilities can use this weapon.
- `statusProfileId` is a single enum — not extensible for multiple procs.

### RangedWeaponDef (Projectile Weapons)
```dart
class RangedWeaponDef {
  final RangedWeaponId id;
  final ProjectileId projectileId;       // ✓ Keep (weapon owns projectile type)
  final double damage;                   // ❌ Should move to AbilityDef
  final DamageType damageType;           // ✓ Keep
  final StatusProfileId statusProfileId; // → Replace with procs[]
  final double staminaCost;              // ❌ Should move to AbilityDef
  final double originOffset;             // ✓ Keep (physics)
  final double cooldownSeconds;          // ❌ Should move to AbilityDef
  final bool ballistic;                  // ✓ Keep (physics)
  final double gravityScale;             // ✓ Keep (physics)
}
```

**Issues:**
- `damage`, `staminaCost`, `cooldownSeconds` belong in the ability, not the weapon.
- These fields are currently read by `PlayerRangedWeaponSystem`. They need to remain for backward compat until Phase 4.

---

## Target State

### WeaponDef (Phase 2)

```dart
class WeaponDef {
  const WeaponDef({
    required this.id,
    required this.category,
    this.enabledAbilityTags = const {},
    this.damageType = DamageType.physical,
    this.statusProfileId = StatusProfileId.none, // DEPRECATED
    this.procs = const [],
    this.stats = const WeaponStats(),
    this.isTwoHanded = false,
  });

  final WeaponId id;
  
  /// Equipment slot category.
  final WeaponCategory category;
  
  /// Ability tags this weapon enables.
  /// Empty = no restrictions (all abilities allowed).
  final Set<AbilityTag> enabledAbilityTags;
  
  /// Default damage type applied to hits.
  final DamageType damageType;
  
  /// DEPRECATED: Use `procs` instead. Kept for backward compat.
  final StatusProfileId statusProfileId;
  
  /// Data-driven proc effects (on-hit, on-block, etc.).
  final List<WeaponProc> procs;
  
  /// Passive stat modifiers.
  final WeaponStats stats;
  
  /// If true, occupies both Primary and Secondary slots.
  final bool isTwoHanded;
}
```

### RangedWeaponDef (Phase 2)

```dart
class RangedWeaponDef {
  const RangedWeaponDef({
    required this.id,
    required this.projectileId,
    this.damageType = DamageType.physical,
    this.statusProfileId = StatusProfileId.none, // DEPRECATED
    this.procs = const [],
    this.stats = const WeaponStats(),
    // Physics (weapon-owned)
    this.originOffset = 0.0,
    this.ballistic = true,
    this.gravityScale = 1.0,
    // DEPRECATED: Ability should own these
    @Deprecated('Use AbilityDef.staminaCost') this.damage = 0.0,
    @Deprecated('Use AbilityDef.staminaCost') this.staminaCost = 0.0,
    @Deprecated('Use AbilityDef.cooldownTicks') this.cooldownSeconds = 0.25,
  });

  final RangedWeaponId id;
  final ProjectileId projectileId;
  
  final DamageType damageType;
  final StatusProfileId statusProfileId; // DEPRECATED
  final List<WeaponProc> procs;
  final WeaponStats stats;
  
  // Physics (weapon-owned)
  final double originOffset;
  final bool ballistic;
  final double gravityScale;
  
  // DEPRECATED fields (kept for backward compat until Phase 4)
  @Deprecated('Ability owns damage')
  final double damage;
  @Deprecated('Ability owns cost')
  final double staminaCost;
  @Deprecated('Ability owns cooldown')
  final double cooldownSeconds;
}
```

---

## New Types

### WeaponCategory
```dart
enum WeaponCategory {
  primary,    // Swords, axes, spears
  offHand,    // Shields, daggers, torches
  projectile, // Throwing weapons
}
```

### WeaponStats
```dart
class WeaponStats {
  const WeaponStats({
    this.powerBonus = 0,      // Fixed-point (100 = 1.0)
    this.critChanceBonus = 0, // Fixed-point (100 = 1%)
    this.critDamageBonus = 0, // Fixed-point (100 = 1.0x)
    this.rangeScalar = 100,   // Fixed-point (100 = 1.0x)
  });

  final int powerBonus;
  final int critChanceBonus;
  final int critDamageBonus;
  final int rangeScalar;
}
```

### WeaponProc
```dart
class WeaponProc {
  const WeaponProc({
    required this.hook,
    required this.statusId,
    this.chance = 100, // Fixed-point (100 = 100%)
  });

  final ProcHook hook;
  final StatusId statusId;
  final int chance;
}

enum ProcHook {
  onHit,
  onBlock,
  onKill,
  onCrit,
}
```

---

## Migration Strategy

### Phase 2 Scope (This Phase)
1. **Add new fields** to `WeaponDef` and `RangedWeaponDef`.
2. **Create** `WeaponCategory`, `WeaponStats`, `WeaponProc`, `ProcHook`.
3. **Mark deprecated fields** with `@Deprecated` annotation.
4. **Update catalogs** to populate new fields with sensible defaults.
5. **Do NOT change system logic** — existing systems continue reading deprecated fields.

### Phase 4 Scope (Future)
- Refactor `PlayerRangedWeaponSystem` to read damage/cost from `AbilityDef`.
- Remove deprecated fields from `RangedWeaponDef`.

---

## Catalog Updates

### WeaponCatalog (Melee)

| ID | Category | Enabled Tags | Damage Type | Procs |
|----|----------|--------------|-------------|-------|
| `basicSword` | primary | `{melee, strike}` | physical | `[onHit: bleed]` |
| `goldenSword` | primary | `{melee, strike}` | physical | `[onHit: bleed]` |
| `basicShield` | offHand | `{melee, block}` | physical | `[onBlock: stun]` |
| `goldenShield` | offHand | `{melee, block}` | physical | `[onBlock: stun]` |

### RangedWeaponCatalog

| ID | Projectile | Damage Type | Procs | Physics |
|----|------------|-------------|-------|---------|
| `throwingKnife` | `throwingKnife` | physical | `[]` | ballistic, 0.9g |
| `throwingAxe` | `throwingAxe` | physical | `[]` | ballistic, 1.0g |

---

## Ability ↔ Weapon Contract

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ON ABILITY COMMIT                           │
├─────────────────────────────────────────────────────────────────────┤
│ 1. Read AbilityDef from AbilityCatalog                              │
│    - staminaCost, manaCost, cooldownTicks (ability owns)           │
│    - hitDelivery (melee box / projectileId)                        │
│                                                                     │
│ 2. Read WeaponDef from WeaponCatalog (via loadout)                 │
│    - damageType (weapon provides)                                   │
│    - procs[] (weapon provides)                                      │
│    - stats (weapon provides)                                        │
│                                                                     │
│ 3. Build HitPayload                                                 │
│    - baseDamage = from AbilityDef (future Phase 5)                 │
│    - damageType = from WeaponDef                                    │
│    - procs = from WeaponDef                                         │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Validation Rules (Asserts)

```dart
// WeaponDef
assert(category != null, 'Weapon must have a category');
assert(damageType != null, 'Weapon must have a damage type');

// WeaponProc
assert(chance >= 0 && chance <= 100, 'Proc chance must be 0-100');

// WeaponStats
assert(rangeScalar > 0, 'Range scalar must be positive');
```

---

## Phase 2 Action Items

1. **Create Enums:**
   - `WeaponCategory` in `weapon_category.dart`
   - `ProcHook` in `weapon_proc.dart`

2. **Create Structs:**
   - `WeaponStats` in `weapon_stats.dart`
   - `WeaponProc` in `weapon_proc.dart`

3. **Update WeaponDef:**
   - Add `category`, `enabledAbilityTags`, `procs`, `stats`, `isTwoHanded`
   - Mark `statusProfileId` as deprecated

4. **Update RangedWeaponDef:**
   - Add `procs`, `stats`
   - Mark `damage`, `staminaCost`, `cooldownSeconds` as deprecated

5. **Update Catalogs:**
   - Populate new fields with correct values
   - Ensure builds pass

6. **Verify:**
   - Run `dart analyze` — no errors
   - Run tests — all pass (no behavior change)

---

## Files to Create/Modify

### New Files
- `lib/core/weapons/weapon_category.dart`
- `lib/core/weapons/weapon_stats.dart`
- `lib/core/weapons/weapon_proc.dart`

### Modified Files
- `lib/core/weapons/weapon_def.dart`
- `lib/core/weapons/ranged_weapon_def.dart`
- `lib/core/weapons/weapon_catalog.dart`
- `lib/core/weapons/ranged_weapon_catalog.dart`

---

## Success Criteria

- [ ] `WeaponDef` has `category`, `enabledAbilityTags`, `procs`, `stats`
- [ ] `RangedWeaponDef` has `procs`, `stats`, deprecated fields annotated
- [ ] Catalogs compile with new fields populated
- [ ] `dart analyze` passes
- [ ] All tests pass (no runtime behavior change)
- [ ] Design doc approved before implementation
