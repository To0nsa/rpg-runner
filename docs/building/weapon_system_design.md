# Weapon System Design

## Purpose

Weapons are **equipment that provides the payload for abilities**. They constrain what the player can equip, define damage types and effect modifiers, but do NOT define the ability's structure (timing, targeting, hitbox shape).

This document defines what weapons are, what they own, and their data structure.

---

## Core Concept

> Weapons shape **what the hit carries**; abilities decide **how the action is executed**.

A weapon:

* **Enables / gates** a compatible set of abilities (by weapon type requirements)
* Provides **damage-type defaults** (slashing / piercing / bludgeoning, etc.)
* Grants **passive stats + traits** (power, crit, range scalar, resistances)
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
| **Projectile Item** | Projectile | Throwing Knife, Ice Bolt, Fire Bolt |

> **Two-handed weapons** occupy both Primary and Secondary slots.  
> The **Projectile slot** is equipped with a `ProjectileItemDef` (spells + throws).

---

## Data Structures

### WeaponDef (Melee Weapons)

Current implementation in `lib/core/weapons/weapon_def.dart`:

```dart
class WeaponDef {
  const WeaponDef({
    required this.id,
    required this.category,
    required this.weaponType,
    this.grantedAbilityTags = const {},
    this.damageType = DamageType.physical,
    this.procs = const [],
    this.stats = const WeaponStats(),
    this.isTwoHanded = false,
  });

  final WeaponId id;
  final WeaponCategory category;
  final WeaponType weaponType;
  final Set<AbilityTag> grantedAbilityTags;
  final DamageType damageType;
  final List<WeaponProc> procs;
  final WeaponStats stats;
  final bool isTwoHanded;
}
```

---

### ProjectileItemDef (Projectile Slot Items)

Current implementation in `lib/core/projectiles/projectile_item_def.dart`:

```dart
class ProjectileItemDef {
  const ProjectileItemDef({
    required this.id,
    required this.weaponType,
    required this.projectileId,
    this.originOffset = 0.0,
    this.ballistic = false,
    this.gravityScale = 1.0,
    this.damageType = DamageType.physical,
    this.procs = const <WeaponProc>[],
    this.stats = const WeaponStats(),
  });

  final ProjectileItemId id;
  final WeaponType weaponType;
  final ProjectileId projectileId;
  final double originOffset;
  final bool ballistic;
  final double gravityScale;
  final DamageType damageType;
  final List<WeaponProc> procs;
  final WeaponStats stats;
}
```

`ProjectileItemDef` unifies **spells and throwing weapons** under one payload
structure. Abilities define **base damage and timing**; projectile items provide
**damage type, procs, stats, and projectile identity**.

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
    required this.statusProfileId,
    this.chanceBp = 10000,
  });

  /// Hook point: onHit, onBlock, onKill, etc.
  final ProcHook hook;

  /// Status effect to apply.
  final StatusProfileId statusProfileId;

  /// Probability in basis points (10000 = 100%).
  final int chanceBp;
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
| `ProjectileItemCatalog` | Projectile slot items (spells + throws) |

**Current weapons:**

| ID | Category | Damage Type | On-Hit Effect |
|----|----------|-------------|---------------|
| `basicSword` | Primary | Physical | None (Sword Strike ability applies bleed) |
| `goldenSword` | Primary | Physical | None (Sword Strike ability applies bleed) |
| `basicShield` | Off-Hand | Physical | None (Shield Bash ability applies stun) |
| `goldenShield` | Off-Hand | Physical | None (Shield Bash ability applies stun) |
| `throwingAxe` | Projectile | Physical | None |
| `throwingKnife` | Projectile | Physical | None |
| `iceBolt` | Projectile | Ice | Slow |
| `fireBolt` | Projectile | Fire | Burn |
| `thunderBolt` | Projectile | Thunder | None |

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

1. **Weapons gate abilities.** A weapon defines which abilities can be used (by weapon type requirements).
2. **Weapons/items provide payload.** Damage type, item procs, and stats come from the equipped item.
3. **Abilities define structure.** Timing, targeting, and base damage come from the ability.
4. **Proc merge order is fixed.** ability → item → buffs → passives (dedupe by hook + status profile).
5. **Same ability, different items = different effects (if item procs exist).** Example: a weapon with burn procs adds burn on hit.

---

## Refactoring Notes

### Current vs Target State

| Aspect | Current | Target |
|--------|---------|--------|
| Projectile payload | `ProjectileItemDef` | Unified for spells + throws |
| Damage definition | Ability base damage | Ability remains source of base damage |
| Proc system | `WeaponProc` list (procs-only) | Done |
| Two-handed flag | Not implemented | Add `isTwoHanded` field |
| Ability gating | Explicit `weaponType` | Keep weaponType-based gating |
| Weapon stats | Not implemented | Add `WeaponStats` class |

---

## Acceptance Criteria

* Weapons can be looked up by ID from catalogs.
* Weapons define damage type defaults and effect modifiers.
* Weapons enable/gate abilities via weapon types.
* Abilities define base damage, timing, and targeting (not weapons).
* Modifier application order is deterministic (ability → weapon → passive).
