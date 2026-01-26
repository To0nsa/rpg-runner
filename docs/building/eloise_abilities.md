# Eloise Abilities

## Overview

This document defines the Eloise ability catalog as implemented in Core. Costs and damage are shown in human units (Core uses fixed-point where 100 = 1.0).
Jump is now a fixed ability slot (`AbilitySlot.jump`) committed through the ability pipeline and executed by `PlayerMovementSystem` (buffer/coyote-aware).

Based on the slot table from `ability_system_design.md`:

| Slot | Abilities |
|------|-----------|
| **Primary** | Sword Strike, Sword Parry |
| **Secondary** | Shield Bash, Shield Block |
| **Projectile** | Throwing Knife, Ice Bolt, Fire Bolt, Thunder Bolt |
| **Mobility** | Dash, Roll |
| **Jump** | Jump (fixed slot) |
| **Bonus** | Any Primary/Secondary/Projectile (not wired yet) |

---

## Animation Reference (from eloise.dart)

All timing values are derived from the animation data in `eloise.dart`.

| Animation | Frames | Step (s) | Total (ms) | Notes |
|-----------|--------|----------|------------|-------|
| Strike | 6 | 0.06 | 360 | Melee attack |
| Back Strike | 5 | 0.08 | 400 | Backward melee |
| Parry | 6 | 0.06 | 360 | Defensive |
| Cast | 5 | 0.08 | 400 | Spell casting |
| Ranged | 5 | 0.08 | 400 | Throwing (uses cast) |
| Dash | 4 | 0.05 | 200 | Blocks on last frame |
| Roll | 10 | 0.05 | 500 | Not looping |
| Jump | 6 | 0.10 | 600 | Airborne up movement |

---

## Data Structures (Core)

### AbilityDef (Implemented)

```dart
class AbilityDef {
  const AbilityDef({
    required this.id,
    required this.category,
    required this.allowedSlots,
    required this.targetingModel,
    required this.hitDelivery,
    required this.windupTicks,
    required this.activeTicks,
    required this.recoveryTicks,
    required this.staminaCost,
    required this.manaCost,
    required this.cooldownTicks,
    required this.interruptPriority,
    this.canBeInterruptedBy = const {},
    required this.animKey,
    this.tags = const {},
    this.requiredTags = const {},
    this.requiredWeaponTypes = const {},
    this.requiresEquippedWeapon = false,
    required this.baseDamage,
    this.baseDamageType = DamageType.physical,
  });

  final AbilityKey id;
  final AbilityCategory category;
  final Set<AbilitySlot> allowedSlots;
  final TargetingModel targetingModel;
  final HitDeliveryDef hitDelivery;
  final int windupTicks;
  final int activeTicks;
  final int recoveryTicks;
  final int staminaCost; // fixed-point (100 = 1.0)
  final int manaCost;    // fixed-point (100 = 1.0)
  final int cooldownTicks;
  final InterruptPriority interruptPriority;
  final Set<InterruptPriority> canBeInterruptedBy;
  final AnimKey animKey;
  final Set<AbilityTag> tags;
  final Set<AbilityTag> requiredTags;
  final Set<WeaponType> requiredWeaponTypes;
  final bool requiresEquippedWeapon;
  final int baseDamage; // fixed-point (100 = 1.0)
  final DamageType baseDamageType;
}
```

### Supporting Types (Summary)

- `AbilitySlot`: primary, secondary, projectile, mobility, bonus, **jump** (fixed).
- `AbilityCategory`: melee, ranged, magic, mobility, defense, utility.
- `TargetingModel`: none, directional, aimed, homing, groundTarget.
- `HitDeliveryDef`: `MeleeHitDelivery`, `ProjectileHitDelivery`, `SelfHitDelivery`.

---

## Primary Slot Abilities

### Sword Strike

**Design Intent:** Fast, reliable melee attack. The bread-and-butter offensive option.

| Property | Value |
|----------|-------|
| Category | Melee |
| Targeting | Directional (commit on press) |
| Hit Delivery | `MeleeHitDelivery` |
| Damage Type | From weapon (physical default) |

**Timing (60Hz ticks):**

| Phase | Ticks | Duration |
|-------|--------|----------|
| Windup | 8 | ~133ms |
| Active | 6 | ~100ms |
| Recovery | 8 | ~133ms |
| **Total** | **22** | **~366ms** |

**Cost & Cooldown:**

| Property | Value |
|----------|-------|
| Stamina Cost | 5.0 |
| Mana Cost | 0 |
| Cooldown | 18 ticks (~300ms) |

**Data Structure:**

```dart
const swordStrike = AbilityDef(
  id: 'eloise.sword_strike',
  category: AbilityCategory.melee,
  allowedSlots: {AbilitySlot.primary},
  targetingModel: TargetingModel.directional,
  hitDelivery: MeleeHitDelivery(
    sizeX: 1.5, sizeY: 1.5, offsetX: 1.0, offsetY: 0.0,
    hitPolicy: HitPolicy.oncePerTarget,
  ),
  windupTicks: 8,
  activeTicks: 6,
  recoveryTicks: 8,
  staminaCost: 500,
  manaCost: 0,
  cooldownTicks: 18,
  interruptPriority: InterruptPriority.combat,
  animKey: AnimKey.strike,
  requiredWeaponTypes: {WeaponType.oneHandedSword},
  baseDamage: 1500,
);
```

---

### Sword Parry

**Design Intent:** Defensive timing-based counter. Strict parry window with a perfect timing bonus.

| Property | Value |
|----------|-------|
| Category | Defense |
| Targeting | None (Self) |
| Hit Delivery | `SelfHitDelivery` |
| Effect | Strict parry (negates hit, optional riposte) |

#### Timing

Total duration: **22 ticks** — matches Parry animation (**6 frames × 0.06s = 360ms**)

| Phase | Ticks | Duration |
|-------|--------|----------|
| Windup | 4 | ~66ms |
| Active | 14 | ~233ms (parry window) |
| Recovery | 4 | ~66ms |
| **Total** | **22** | **~366ms** |

**Active sub-windows:**

- **Perfect window:** Active ticks **0–7** (8 ticks)
- **Late parry:** Active ticks **8–13** (6 ticks)

#### Core behavior

If a hit is received during Active:

- **Negate 100%** of the incoming `DamageRequest`
- **Block** all status effects and on-hit procs
- **Consume** the parry (max **1 parried hit** per activation)

#### Perfect parry bonus (Active ticks 0–7)

- Trigger an **automatic riposte** (small instant melee hitbox)
- Riposte damage is a **deterministic percentage** of the incoming damage
  - Example: `reflectBp = 6000` → **60%**
  - **Hard cap** applies to prevent abuse

#### Costs & cooldown

| Property | Value |
|----------|-------|
| Stamina Cost | 7.0 |
| Cooldown | 0.5s (**30 ticks @ 60Hz**) |

#### Edge cases (locked rules)

- **Multi-hit / everyTick attacks:** parry consumes on the **first** parried hit
- **Projectiles:** parry **destroys** the projectile
- **Status / procs:** parry **blocks** them
- **Airborne:** parry is **allowed in the air**

**Data Structure:**

```dart
const swordParry = AbilityDef(
  id: 'eloise.sword_parry',
  category: AbilityCategory.defense,
  allowedSlots: {AbilitySlot.primary},
  targetingModel: TargetingModel.none,
  hitDelivery: SelfHitDelivery(),
  windupTicks: 4,
  activeTicks: 14,
  recoveryTicks: 4,
  staminaCost: 700,
  manaCost: 0,
  cooldownTicks: 30,
  interruptPriority: InterruptPriority.combat,
  animKey: AnimKey.parry,
  requiredWeaponTypes: {WeaponType.oneHandedSword},
  baseDamage: 0,
);
```

---

## Secondary Slot Abilities

### Shield Bash

**Design Intent:** Offensive shield attack. Stuns enemies briefly.

| Property | Value |
|----------|-------|
| Category | Defense |
| Targeting | Directional (commit on press) |
| Hit Delivery | `MeleeHitDelivery` |
| Effect | Damage + weapon procs |

**Timing (at 60 FPS):**

| Phase | Ticks | Duration |
|-------|-------|----------|
| Windup | 8 | ~133ms |
| Active | 4 | ~66ms |
| Recovery | 10 | ~166ms |
| **Total** | **22** | **~366ms** |

**Cost & Cooldown:**

| Property | Value |
|----------|-------|
| Stamina Cost | 12.0 |
| Cooldown | 15 ticks (~250ms) |

**Data Structure:**

```dart
const shieldBash = AbilityDef(
  id: 'eloise.shield_bash',
  category: AbilityCategory.defense,
  allowedSlots: {AbilitySlot.secondary},
  targetingModel: TargetingModel.directional,
  hitDelivery: MeleeHitDelivery(
    sizeX: 1.2, sizeY: 1.2, offsetX: 0.8, offsetY: 0.0,
    hitPolicy: HitPolicy.oncePerTarget,
  ),
  windupTicks: 8,
  activeTicks: 4,
  recoveryTicks: 10,
  staminaCost: 1200,
  manaCost: 0,
  cooldownTicks: 15,
  interruptPriority: InterruptPriority.combat,
  animKey: AnimKey.shieldBash,
  requiredWeaponTypes: {WeaponType.shield},
  baseDamage: 1500,
);
```

---

### Shield Block

**Design Intent:** Sustained defensive stance. Reduces incoming damage while held.

| Property | Value |
|----------|-------|
| Category | Defense |
| Targeting | None (Self) |
| Hit Delivery | `SelfHitDelivery` |
| Effect | Defensive stance (effect pending in Core) |

**Timing (at 60 FPS):**

| Phase | Ticks | Duration |
|-------|-------|----------|
| Windup | 3 | ~50ms |
| Active | 0 | 0ms |
| Recovery | 6 | ~100ms |

**Cost & Cooldown:**

| Property | Value |
|----------|-------|
| Stamina Cost | 5.0 |
| Cooldown | 12 ticks (~200ms) |

**Data Structure:**

```dart
const shieldBlock = AbilityDef(
  id: 'eloise.shield_block',
  category: AbilityCategory.defense,
  allowedSlots: {AbilitySlot.secondary},
  targetingModel: TargetingModel.none,
  hitDelivery: SelfHitDelivery(),
  windupTicks: 3,
  activeTicks: 0,
  recoveryTicks: 6,
  staminaCost: 500,
  manaCost: 0,
  cooldownTicks: 12,
  interruptPriority: InterruptPriority.combat,
  animKey: AnimKey.shieldBlock,
  requiredWeaponTypes: {WeaponType.shield},
  baseDamage: 0,
);
```

---

## Projectile Slot Abilities

### Throwing Knife

**Design Intent:** Fast, low-damage ranged option. Good for poking.

| Property | Value |
|----------|-------|
| Category | Ranged |
| Targeting | Aimed |
| Hit Delivery | `ProjectileHitDelivery` |
| Projectile | Stops on first hit |

**Timing (at 60 FPS):**

| Phase | Ticks | Duration |
|-------|-------|----------|
| Windup | 4 | ~66ms |
| Active | 2 | ~33ms |
| Recovery | 6 | ~100ms |
| **Total** | **12** | **~200ms** |

**Cost & Cooldown:**

| Property | Value |
|----------|-------|
| Stamina Cost | 5.0 |
| Cooldown | 18 ticks (~300ms) |

**Data Structure:**

```dart
const throwingKnife = AbilityDef(
  id: 'eloise.throwing_knife',
  category: AbilityCategory.ranged,
  allowedSlots: {AbilitySlot.projectile},
  targetingModel: TargetingModel.aimed,
  hitDelivery: ProjectileHitDelivery(
    projectileId: ProjectileId.throwingKnife,
    hitPolicy: HitPolicy.oncePerTarget,
  ),
  windupTicks: 4,
  activeTicks: 2,
  recoveryTicks: 6,
  staminaCost: 500,
  manaCost: 0,
  cooldownTicks: 18,
  interruptPriority: InterruptPriority.combat,
  animKey: AnimKey.throwItem,
  requiredWeaponTypes: {WeaponType.throwingWeapon},
  baseDamage: 1000,
);
```

---

### Ice Bolt

**Design Intent:** Slowing projectile spell. Controls enemy movement.

| Property | Value |
|----------|-------|
| Category | Magic |
| Targeting | Aimed |
| Hit Delivery | `ProjectileHitDelivery` |
| Effect | Applies slow on hit |
| Damage Type | Ice |

**Timing (at 60 FPS):**

| Phase | Ticks | Duration |
|-------|-------|----------|
| Windup | 6 | ~100ms |
| Active | 2 | ~33ms |
| Recovery | 8 | ~133ms |
| **Total** | **16** | **~266ms** |

**Cost & Cooldown:**

| Property | Value |
|----------|-------|
| Mana Cost | 10.0 |
| Cooldown | 24 ticks (~400ms) |

**Implementation (AbilityDef):**

```dart
const iceBolt = AbilityDef(
  id: 'eloise.ice_bolt',
  category: AbilityCategory.magic,
  allowedSlots: {AbilitySlot.projectile},
  targetingModel: TargetingModel.aimed,
  hitDelivery: ProjectileHitDelivery(
    projectileId: ProjectileId.iceBolt,
    hitPolicy: HitPolicy.oncePerTarget,
  ),
  windupTicks: 6,
  activeTicks: 2,
  recoveryTicks: 8,
  staminaCost: 0,
  manaCost: 1000,
  cooldownTicks: 24,
  interruptPriority: InterruptPriority.combat,
  animKey: AnimKey.cast,
  requiredWeaponTypes: {WeaponType.projectileSpell},
  baseDamage: 1500,
  baseDamageType: DamageType.ice,
);
```

---

### Fire Bolt

**Design Intent:** Burning projectile spell. Applies burn DoT.

| Property | Value |
|----------|-------|
| Category | Magic |
| Targeting | Aimed |
| Hit Delivery | `ProjectileHitDelivery` |
| Effect | Applies burn on hit |
| Damage Type | Fire |

**Cost & Cooldown:**

| Property | Value |
|----------|-------|
| Mana Cost | 12.0 |
| Damage | 18.0 |
| Cooldown | 15 ticks (~250ms) |

**Implementation (AbilityDef):**

```dart
const fireBolt = AbilityDef(
  id: 'eloise.fire_bolt',
  category: AbilityCategory.magic,
  allowedSlots: {AbilitySlot.projectile},
  targetingModel: TargetingModel.aimed,
  hitDelivery: ProjectileHitDelivery(
    projectileId: ProjectileId.fireBolt,
  ),
  windupTicks: 6,
  activeTicks: 2,
  recoveryTicks: 8,
  staminaCost: 0,
  manaCost: 1200,
  cooldownTicks: 15,
  interruptPriority: InterruptPriority.combat,
  animKey: AnimKey.cast,
  requiredWeaponTypes: {WeaponType.projectileSpell},
  baseDamage: 1800,
  baseDamageType: DamageType.fire,
);
```

---

### Thunder Bolt

**Design Intent:** Stunning projectile spell. Applies stun on hit.

| Property | Value |
|----------|-------|
| Category | Magic |
| Targeting | Aimed |
| Hit Delivery | `ProjectileHitDelivery` |
| Effect | Apply stun on hit (if status profile configured) |
| Damage Type | Thunder |

**Cost & Cooldown:**

| Property | Value |
|----------|-------|
| Mana Cost | 10.0 |
| Damage | 5.0 |
| Cooldown | 15 ticks (~250ms) |

**Implementation (AbilityDef):**

```dart
const thunderBolt = AbilityDef(
  id: 'eloise.thunder_bolt',
  category: AbilityCategory.magic,
  allowedSlots: {AbilitySlot.projectile},
  targetingModel: TargetingModel.aimed,
  hitDelivery: ProjectileHitDelivery(
    projectileId: ProjectileId.thunderBolt,
  ),
  windupTicks: 6,
  activeTicks: 2,
  recoveryTicks: 8,
  staminaCost: 0,
  manaCost: 1000,
  cooldownTicks: 15,
  interruptPriority: InterruptPriority.combat,
  animKey: AnimKey.cast,
  requiredWeaponTypes: {WeaponType.projectileSpell},
  baseDamage: 500,
  baseDamageType: DamageType.thunder,
);
```

---

## Mobility Slot Abilities

### Dash

**Design Intent:** Fast forward movement with i-frames. Aggressive repositioning.

| Property | Value |
|----------|-------|
| Category | Mobility |
| Targeting | Directional (commit on press) |
| Effect | Horizontal burst (i-frames not yet implemented) |
| Movement | Forward dash |

**Timing (60Hz ticks):**

| Phase | Ticks | Duration |
|-------|--------|----------|
| Windup | 0 | 0ms |
| Active | 12 | ~200ms |
| Recovery | 0 | 0ms |
| **Total** | **12** | **~200ms** |

**Cost & Cooldown:**

| Property | Value |
|----------|-------|
| Stamina Cost | 2.0 |
| Cooldown | 120 ticks (~2.0s) |

**Data Structure:**

```dart
const dash = AbilityDef(
  id: 'eloise.dash',
  category: AbilityCategory.mobility,
  allowedSlots: {AbilitySlot.mobility},
  targetingModel: TargetingModel.directional,
  hitDelivery: SelfHitDelivery(),
  windupTicks: 0,
  activeTicks: 12,
  recoveryTicks: 0,
  staminaCost: 200,
  manaCost: 0,
  cooldownTicks: 120,
  interruptPriority: InterruptPriority.mobility,
  animKey: AnimKey.dash,
  baseDamage: 0,
);
```

---

### Roll

**Design Intent:** Evasive maneuver with longer i-frames. Defensive repositioning.

| Property | Value |
|----------|-------|
| Category | Mobility |
| Targeting | Directional (commit on press) |
| Effect | Horizontal burst (no i-frames yet) |
| Movement | Roll (longer active window than dash) |

**Timing (60Hz ticks):**

| Phase | Ticks | Duration |
|-------|--------|----------|
| Windup | 3 | ~50ms |
| Active | 24 | ~400ms |
| Recovery | 3 | ~50ms |
| **Total** | **30** | **~500ms** |

**Cost & Cooldown:**

| Property | Value |
|----------|-------|
| Stamina Cost | 2.0 |
| Cooldown | 120 ticks (~2.0s) |

**Data Structure:**

```dart
const roll = AbilityDef(
  id: 'eloise.roll',
  category: AbilityCategory.mobility,
  allowedSlots: {AbilitySlot.mobility},
  targetingModel: TargetingModel.directional,
  hitDelivery: SelfHitDelivery(),
  windupTicks: 3,
  activeTicks: 24,
  recoveryTicks: 3,
  staminaCost: 200,
  manaCost: 0,
  cooldownTicks: 120,
  interruptPriority: InterruptPriority.mobility,
  animKey: AnimKey.roll,
  baseDamage: 0,
);
```

---

## Fixed Jump Slot

### Jump

**Design Intent:** Baseline jump action. Committed through the ability pipeline, executed by `PlayerMovementSystem` (buffer + coyote time).

| Property | Value |
|----------|-------|
| Category | Mobility |
| Targeting | None (Self) |
| Hit Delivery | `SelfHitDelivery` |
| Effect | Applies vertical jump velocity |

**Timing (60Hz ticks):**

| Phase | Ticks | Duration |
|-------|-------|----------|
| Windup | 0 | 0ms |
| Active | 0 | 0ms |
| Recovery | 0 | 0ms |

**Cost & Cooldown:**

| Property | Value |
|----------|-------|
| Stamina Cost | 2.0 |
| Cooldown | 0 |

**Data Structure:**

```dart
const jump = AbilityDef(
  id: 'eloise.jump',
  category: AbilityCategory.mobility,
  allowedSlots: {AbilitySlot.jump},
  targetingModel: TargetingModel.none,
  hitDelivery: SelfHitDelivery(),
  windupTicks: 0,
  activeTicks: 0,
  recoveryTicks: 0,
  staminaCost: 200,
  manaCost: 0,
  cooldownTicks: 0,
  interruptPriority: InterruptPriority.mobility,
  animKey: AnimKey.jump,
  baseDamage: 0,
);
```

---

## Ability Summary Table

| Ability | Category | Targeting | Stamina | Mana | Damage | Cooldown |
|---------|----------|-----------|---------|------|--------|----------|
| Sword Strike | Melee | Directional | 5.0 | - | 15.0 | 18 ticks (~300ms) |
| Sword Parry | Defense | None | 7.0 | - | - | 30 ticks (~500ms) |
| Shield Bash | Defense | Directional | 12.0 | - | 15.0 | 15 ticks (~250ms) |
| Shield Block | Defense | None | 5.0 | - | - | 12 ticks (~200ms) |
| Throwing Knife | Ranged | Aimed | 5.0 | - | 10.0 | 18 ticks (~300ms) |
| Ice Bolt | Magic | Aimed | - | 10.0 | 15.0 | 24 ticks (~400ms) |
| Fire Bolt | Magic | Aimed | - | 12.0 | 18.0 | 15 ticks (~250ms) |
| Thunder Bolt | Magic | Aimed | - | 10.0 | 5.0 | 15 ticks (~250ms) |
| Dash | Mobility | Directional | 2.0 | - | - | 120 ticks (~2.0s) |
| Roll | Mobility | Directional | 2.0 | - | - | 120 ticks (~2.0s) |
| Jump | Mobility | None | 2.0 | - | - | 0 |

---

## Design Notes

1. **Stamina vs Mana:** Physical abilities use stamina; spells use mana. This creates resource management decisions.

2. **Cooldown balance:** Dash and Roll currently share the same cooldown (2.0s). Separate tuning can be added once i-frames/defense effects exist.

3. **Timing trade-offs:** Sword Strike is fast but has short active window. Sword Parry is a defensive window (effect pending in Core).

4. **Weapon synergy:** Damage type and procs come from equipped weapon, not the ability. Sword Strike with a fire sword applies burn.
