# Weapon System Design

## Purpose

Weapons are **equipment that provides the payload for abilities**. They constrain what the player can equip, define damage types and effect modifiers, but do NOT define the ability's structure (timing, targeting, hitbox shape).

This document defines what weapons are, what they own, and their data structure.

---

## Core Concept

> Weapons shape **what the hit carries**; abilities decide **how the action is executed**.

A weapon:

* **Enables / gates** a compatible set of abilities (by tags / requirements)
* Provides **damage-type defaults** (slashing / piercing / bludgeoning, etc.)
* Grants **passive stats + tags** (power, crit, range scalar, resistances)
* Provides **effect modifiers** as **data-driven procs** applied at defined hook points

Weapons do **not** define:

* Targeting model (tap / hold-aim / self-centered)
* Timing windows (windup / active / recovery)
* Hitbox / projectile shape
* Base damage amount (that's the ability's job)

---

## Weapon Categories

| Category | Slot | Examples |
|----------|------|----------|
| **Primary Weapon** | Primary | Sword, Axe, Spear, Two-Handed Sword |
| **Off-Hand Weapon** | Secondary | Shield, Dagger, Torch |
| **Projectile Weapon** | Projectile | Throwing Knife, Throwing Axe |

> **Two-handed weapons** occupy both Primary and Secondary slots.

---

## Data Structures

### WeaponDef (Melee Weapons)

Current implementation in `lib/core/weapons/weapon_def.dart`:

```dart
class WeaponDef {
  const WeaponDef({
    required this.id,
    this.damageType = DamageType.physical,
    this.statusProfileId = StatusProfileId.none,
  });

  final WeaponId id;
  final DamageType damageType;
  final StatusProfileId statusProfileId;
}
```

**Proposed additions** based on ability_system_design.md:

```dart
class WeaponDef {
  const WeaponDef({
    required this.id,
    required this.category,
    required this.enabledAbilityTags,
    this.damageType = DamageType.physical,
    this.statusProfileId = StatusProfileId.none,
    this.isTwoHanded = false,
    this.stats = const WeaponStats(),
    this.procs = const [],
  });

  /// Unique identifier.
  final WeaponId id;

  /// Weapon category (primary / offHand / projectile).
  final WeaponCategory category;

  /// Ability tags this weapon enables (e.g., [strike, parry]).
  final Set<AbilityTag> enabledAbilityTags;

  /// Default damage type applied to abilities.
  final DamageType damageType;

  /// Status effect profile (on-hit procs).
  final StatusProfileId statusProfileId;

  /// If true, occupies both Primary and Secondary slots.
  final bool isTwoHanded;

  /// Passive stat modifiers.
  final WeaponStats stats;

  /// Data-driven procs applied at hook points.
  final List<WeaponProc> procs;
}
```

---

### RangedWeaponDef (Projectile Weapons)

Current implementation in `lib/core/weapons/ranged_weapon_def.dart`:

```dart
class RangedWeaponDef {
  const RangedWeaponDef({
    required this.id,
    required this.projectileId,
    required this.damage,
    this.damageType = DamageType.physical,
    this.statusProfileId = StatusProfileId.none,
    this.staminaCost = 0.0,
    this.originOffset = 0.0,
    this.cooldownSeconds = 0.25,
    this.ballistic = true,
    this.gravityScale = 1.0,
  });

  final RangedWeaponId id;
  final ProjectileId projectileId;
  final double damage;
  final DamageType damageType;
  final StatusProfileId statusProfileId;
  final double staminaCost;
  final double originOffset;
  final double cooldownSeconds;
  final bool ballistic;
  final double gravityScale;
}
```

> **Note:** `RangedWeaponDef` currently defines `damage`, which conflicts with the ability system design (abilities should define base damage). This should be refactored so the ability defines damage and the weapon provides modifiers.

---

### WeaponStats (future) (Passive Modifiers)

```dart
class WeaponStats {
  const WeaponStats({
    this.powerBonus = 0.0,
    this.critChanceBonus = 0.0,
    this.critDamageMultiplier = 1.0,
    this.rangeScalar = 1.0,
  });

  final double powerBonus;
  final double critChanceBonus;
  final double critDamageMultiplier;
  final double rangeScalar;
}
```

---

### WeaponProc (Effect Modifiers)

```dart
class WeaponProc {
  const WeaponProc({
    required this.hook,
    required this.statusId,
    this.chance = 1.0,
  });

  /// Hook point: onHit, onBlock, onKill, etc.
  final ProcHook hook;

  /// Status effect to apply.
  final StatusId statusId;

  /// Probability (0.0 - 1.0).
  final double chance;
}

enum ProcHook {
  onHit,
  onBlock,
  onKill,
  onCrit,
}
```

---

### WeaponCategory

```dart
enum WeaponCategory {
  primary,    // Swords, axes, spears
  offHand,    // Shields, daggers, torches
  projectile, // Throwing weapons
}
```

---

## Weapon Catalog

Weapons are registered in catalogs for lookup by ID:

| Catalog | Contains |
|---------|----------|
| `WeaponCatalog` | Melee weapons (swords, shields) |
| `RangedWeaponCatalog` | Throwing weapons |

**Current weapons:**

| ID | Category | Damage Type | On-Hit Effect |
|----|----------|-------------|---------------|
| `basicSword` | Primary | Physical | Bleed |
| `goldenSword` | Primary | Physical | Bleed |
| `basicShield` | Off-Hand | Physical | Stun |
| `goldenShield` | Off-Hand | Physical | Stun |
| `throwingAxe` | Projectile | Physical | None |
| `throwingKnife` | Projectile | Physical | None |

---

## Weapon → Ability Relationship

```
┌─────────────┐     enables      ┌─────────────┐
│   Weapon    │ ───────────────▶ │   Ability   │
│             │                  │             │
│ damageType  │     provides     │ baseDamage  │
│ procs       │ ───────────────▶ │ timing      │
│ stats       │    modifiers     │ targeting   │
└─────────────┘                  └─────────────┘
           │                            │
           │      Final Outcome         │
           └──────────────┬─────────────┘
                          ▼
              ability structure + weapon payload
```

---

## Design Rules

1. **Weapons gate abilities.** A weapon defines which abilities can be used (by tags/requirements).
2. **Weapons provide payload.** Damage type, procs, and stats come from the weapon.
3. **Abilities define structure.** Timing, targeting, and base damage come from the ability.
4. **Modifier order is fixed.** On hit: ability modifiers → weapon modifiers → passive modifiers.
5. **Same ability, different weapons = different effects.** "Sword Strike" with a fire sword applies burn; with a frost sword applies slow.

---

## Refactoring Notes

### Current vs Target State

| Aspect | Current | Target |
|--------|---------|--------|
| Damage definition | `RangedWeaponDef.damage` | Move to ability |
| Proc system | `StatusProfileId` enum | Data-driven `WeaponProc` list |
| Two-handed flag | Not implemented | Add `isTwoHanded` field |
| Ability gating | Implicit | Explicit `enabledAbilityTags` |
| Weapon stats | Not implemented | Add `WeaponStats` class |

---

## Acceptance Criteria

* Weapons can be looked up by ID from catalogs.
* Weapons define damage type defaults and effect modifiers.
* Weapons enable/gate abilities via tags.
* Abilities define base damage, timing, and targeting (not weapons).
* Modifier application order is deterministic (ability → weapon → passive).
