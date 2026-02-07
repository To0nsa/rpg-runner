# Eloise Abilities

## Overview

This document defines the Eloise ability catalog as implemented in Core. Costs and damage are shown in human units (Core uses fixed-point where 100 = 1.0).
Jump is now a fixed ability slot (`AbilitySlot.jump`) committed through the ability pipeline and executed by `PlayerMovementSystem` (buffer/coyote-aware).

Based on the slot table from `ability_system_design.md`:

| Slot | Abilities |
|------|-----------|
| **Primary** | Sword Strike, Sword Parry |
| **Secondary** | Shield Bash, Shield Block |
| **Projectile** | Quick Throw, Heavy Throw |
| **Mobility** | Dash, Roll |
| **Jump** | Jump (fixed slot) |
| **Bonus** | Any Primary/Secondary/Projectile + Arcane Haste |

Projectile payload resolution is now slot-driven:
- `quick_throw` / `heavy_throw` can be equipped in `projectile` or `bonus`.
- Each slot has an optional selected spell (`projectileSlotSpellId`, `bonusSlotSpellId`).
- If a selected spell is valid for the equipped spellbook, that spell is launched.
- Otherwise, the equipped projectile item fallback (typically throwing weapon) is used.
- Cooldowns are also slot-driven by default (`projectile` lane for projectile slot, `bonus` lane for bonus slot).
- `arcane_haste` remains bonus-only.

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

**Design Intent:** Pure defense with a deterministic reward. Strict parry window that blocks all hits during active, and grants a one-shot riposte bonus on the first blocked hit.

| Property | Value |
|----------|-------|
| Category | Defense |
| Targeting | None (Self) |
| Hit Delivery | `SelfHitDelivery` |
| Effect | Strict parry (negates hits, grants riposte buff) |

#### Timing

Total duration: **22 ticks** -- matches Parry animation (**6 frames x 0.06s = 360ms**)

| Phase | Ticks | Duration |
|-------|--------|----------|
| Windup | 2 | ~33ms |
| Active | 18 | ~300ms (parry window) |
| Recovery | 2 | ~33ms |
| **Total** | **22** | **~366ms** |

#### Core behavior

If a hit is received during Active (melee hitbox or projectile damage request):

- **Negate 100%** of the incoming `DamageRequest`
- **Block** all on-hit status effects and on-hit procs (because the damage request is canceled before `DamageSystem`)
- **Grant Riposte only once** per activation (first blocked hit), but continue blocking subsequent hits during the same activation

Notes:
- Tick damage from already-applied statuses (`DeathSourceKind.statusEffect`) is currently **not** blocked by parry.

#### Riposte (first blocked hit only)

- Grants a **one-shot offensive buff** that applies to your **next landed melee hit**
- The buff is **consumed on hit** (not on swing), so misses do not waste it
- The bonus is **deterministic** and does **not** depend on incoming enemy damage
- The buff **expires** after a short window (tuned in middleware)
- Implementation: `SwordParryMiddleware` grants `RiposteStore`, and `HitboxDamageSystem` consumes it on the first landed melee hit.

#### Costs & cooldown

| Property | Value |
|----------|-------|
| Stamina Cost | 7.0 |
| Cooldown | 0.5s (**30 ticks @ 60Hz**) |

#### Edge cases (locked rules)

- **Multi-hit / everyTick attacks:** riposte is granted on the **first** blocked hit; all hits are still blocked during active
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
  windupTicks: 2,
  activeTicks: 18,
  recoveryTicks: 2,
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

**Design Intent:** Same swing profile as **Sword Strike** (tempo + DPS neutrality). The *only* differentiator is the **weapon status proc** coming from the equipped **shield** (e.g. stun). This keeps balancing centralized in weapon/status tuning, not ability tuning.

| Property     | Value                                                                                 |
| ------------ | ------------------------------------------------------------------------------------- |
| Category     | Defense                                                                               |
| Targeting    | Directional (commit on press)                                                         |
| Hit Delivery | `MeleeHitDelivery`                                                                    |
| Damage Type  | From weapon (physical default)                                                        |
| Effect       | Damage + **weapon status proc** (e.g. `stunOnHit` if the equipped shield provides it) |

#### Timing (60Hz ticks)

Matches Sword Strike exactly (6 frames × 0.06s = 360ms total, ~22 ticks).

| Phase     | Ticks  | Duration   |
| --------- | ------ | ---------- |
| Windup    | 8      | ~133ms     |
| Active    | 6      | ~100ms     |
| Recovery  | 8      | ~133ms     |
| **Total** | **22** | **~366ms** |

#### Cost & cooldown

Matches Sword Strike exactly. 

| Property     | Value             |
| ------------ | ----------------- |
| Stamina Cost | 5.0               |
| Mana Cost    | 0                 |
| Cooldown     | 18 ticks (~300ms) |

#### Stun status profile (weapon proc)

`StatusProfileId.stunOnHit` is tuned to **0.5s = 30 ticks @ 60Hz** (Core currently stores duration as seconds, so this corresponds to `durationSeconds: 0.5`).

**No chain-stun rule (locked):**

* On re-apply, stun duration becomes: `newRemaining = max(currentRemaining, newDuration)`
* i.e. **refreshes to max(current, new)** and **never extends beyond the base duration**.

#### Animation rule (frame speed)

Goal: Shield Bash must visually match Sword Strike tempo.

* If you keep a dedicated `AnimKey.shieldBash`, its authored strip must be tuned to the same pacing as Strike (**6 frames × 0.06s**).
* If no dedicated strip exists yet, render-side should **fallback `shieldBash → strike`** so timing stays correct. (Eloise currently has a dedicated `shield_bash.png` wired to `AnimKey.shieldBash`.)

**Data Structure (AbilityDef):**

```dart
const shieldBash = AbilityDef(
  id: 'eloise.shield_bash',
  category: AbilityCategory.defense,
  allowedSlots: {AbilitySlot.secondary},
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
  animKey: AnimKey.shieldBash,
  requiredWeaponTypes: {WeaponType.shield},
  baseDamage: 1500,
);
```

---

### Shield Block

**Design Intent:** **Parry-equivalent** defensive action for the shield slot. Same rules and reward as Sword Parry, only the animation and required weapon differ.

| Property | Value |
|----------|-------|
| Category | Defense |
| Targeting | None (Self) |
| Hit Delivery | `SelfHitDelivery` |
| Effect | Strict parry (negates hits, grants riposte buff) |

#### Timing

Total duration: **22 ticks** -- matches Shield Block animation (**7 frames ~ 0.052s = ~364ms**)

| Phase | Ticks | Duration |
|-------|--------|----------|
| Windup | 2 | ~33ms |
| Active | 18 | ~300ms (parry window) |
| Recovery | 2 | ~33ms |
| **Total** | **22** | **~366ms** |

#### Core behavior

If a hit is received during Active:

- **Negate 100%** of the incoming `DamageRequest`
- **Block** all status effects and on-hit procs
- **Grant Riposte only once** per activation (first blocked hit), but continue blocking subsequent hits during the same activation

Notes:
- Tick damage from already-applied statuses (`DeathSourceKind.statusEffect`) is currently **not** blocked by parry/block.

#### Riposte (first blocked hit only)

- Grants a **one-shot offensive buff** that applies to your **next landed melee hit**
- The buff is **consumed on hit** (not on swing), so misses do not waste it
- The bonus is **deterministic** and does **not** depend on incoming enemy damage
- The buff **expires** after a short window (tuned in middleware)

#### Costs & cooldown

| Property | Value |
|----------|-------|
| Stamina Cost | 7.0 |
| Cooldown | 0.5s (**30 ticks @ 60Hz**) |

#### Edge cases (locked rules)

- **Multi-hit / everyTick attacks:** riposte is granted on the **first** blocked hit; all hits are still blocked during active
- **Projectiles:** block **destroys** the projectile
- **Status / procs:** block **blocks** them
- **Airborne:** block is **allowed in the air**

**Data Structure:**

```dart
const shieldBlock = AbilityDef(
  id: 'eloise.shield_block',
  category: AbilityCategory.defense,
  allowedSlots: {AbilitySlot.secondary},
  targetingModel: TargetingModel.none,
  hitDelivery: SelfHitDelivery(),
  windupTicks: 2,
  activeTicks: 18,
  recoveryTicks: 2,
  staminaCost: 700,
  manaCost: 0,
  cooldownTicks: 30,
  interruptPriority: InterruptPriority.combat,
  animKey: AnimKey.shieldBlock,
  requiredWeaponTypes: {WeaponType.shield},
  baseDamage: 0,
);
```

---

## Projectile Slot Abilities

Runtime note (current Core behavior): projectile abilities in this slot
resolve payload from the equipped `projectileItemId` path. Spell projectile
abilities and throwing weapons both use the same projectile-item payload path.

Current default Eloise loadout uses:
- `eloise.quick_throw` on the projectile slot button
- `eloise.heavy_throw` on the bonus slot button

Both are payload-driven by the equipped projectile item and can launch either
`WeaponType.throwingWeapon` or `WeaponType.projectileSpell`.

### Quick Throw

**Design Intent:** Fast projectile commit for poke/pressure. Uses stamina.

| Property | Value |
|----------|-------|
| Category | Ranged |
| Targeting | Aimed |
| Allowed Slots | Projectile, Bonus |
| Payload Source | Equipped `projectileItemId` |

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
| Mana Cost | 0 |
| Cooldown | 18 ticks (~300ms) |

```dart
const quickThrow = AbilityDef(
  id: 'eloise.quick_throw',
  category: AbilityCategory.ranged,
  allowedSlots: {AbilitySlot.projectile, AbilitySlot.bonus},
  targetingModel: TargetingModel.aimed,
  hitDelivery: ProjectileHitDelivery(projectileId: ProjectileId.throwingKnife),
  windupTicks: 4,
  activeTicks: 2,
  recoveryTicks: 6,
  staminaCost: 500,
  manaCost: 0,
  cooldownTicks: 18,
  interruptPriority: InterruptPriority.combat,
  animKey: AnimKey.ranged,
  requiredWeaponTypes: {
    WeaponType.throwingWeapon,
    WeaponType.projectileSpell,
  },
  payloadSource: AbilityPayloadSource.projectileItem,
  baseDamage: 1000,
);
```

---

### Heavy Throw

**Design Intent:** Slower projectile commit with higher baseline impact. Uses mana.

| Property | Value |
|----------|-------|
| Category | Magic |
| Targeting | Aimed |
| Allowed Slots | Projectile, Bonus |
| Payload Source | Equipped `projectileItemId` |

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
| Stamina Cost | 0 |
| Mana Cost | 10.0 |
| Cooldown | 24 ticks (~400ms) |

```dart
const heavyThrow = AbilityDef(
  id: 'eloise.heavy_throw',
  category: AbilityCategory.magic,
  allowedSlots: {AbilitySlot.projectile, AbilitySlot.bonus},
  targetingModel: TargetingModel.aimed,
  hitDelivery: ProjectileHitDelivery(projectileId: ProjectileId.iceBolt),
  windupTicks: 6,
  activeTicks: 2,
  recoveryTicks: 8,
  staminaCost: 0,
  manaCost: 1000,
  cooldownTicks: 24,
  interruptPriority: InterruptPriority.combat,
  animKey: AnimKey.cast,
  requiredWeaponTypes: {
    WeaponType.throwingWeapon,
    WeaponType.projectileSpell,
  },
  payloadSource: AbilityPayloadSource.projectileItem,
  baseDamage: 1500,
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
| Sword Parry | Defense | None | 7.0 | - | Next melee hit +100% (riposte) | 30 ticks (~500ms) |
| Shield Bash | Defense | Directional | 5.0 | - | 15.0 | 18 ticks (~300ms) |
| Shield Block | Defense | None | 7.0 | - | Next melee hit +100% (riposte) | 30 ticks (~500ms) |
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

3. **Timing trade-offs:** Sword Strike is fast but has short active window. Sword Parry has a large active window that blocks hits and grants a one-shot riposte bonus.

4. **Weapon synergy:** Damage type and procs come from equipped weapon, not the ability. Sword Strike with a fire sword applies burn.
