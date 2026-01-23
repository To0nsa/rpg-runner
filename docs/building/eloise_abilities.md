# Eloise Abilities

## Overview

This document defines all abilities available to Eloise, the starter character. Each ability includes its design intent, timing windows, data structure, and tuning parameters.

Based on the slot table from `ability_system_design.md`:

| Slot | Abilities |
|------|-----------|
| **Primary** | Sword Strike, Sword Parry |
| **Secondary** | Shield Bash, Shield Block |
| **Projectile** | Throwing Knife, Quick Throw, Ice Bolt, Fire Bolt, Thunder Bolt |
| **Mobility** | Dash, Roll |
| **Bonus** | Any of the above (except Mobility) |

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

---

## Data Structures

### AbilityDef (Proposed)

```dart
class AbilityDef {
  const AbilityDef({
    required this.id,
    required this.category,
    required this.targetingModel,
    required this.timing,
    required this.cost,
    required this.cooldownTicks,
    required this.hitType,
    this.baseDamage = 0.0,
    this.tags = const {},
  });

  final AbilityId id;
  final AbilityCategory category;
  final TargetingModel targetingModel;
  final AbilityTiming timing;
  final AbilityCost cost;
  final int cooldownTicks;
  final HitType hitType;
  final double baseDamage;
  final Set<AbilityTag> tags;
}
```

### Supporting Types

```dart
enum AbilityCategory {
  primaryHand,
  secondaryHand,
  projectile,
  mobility,
  spell,
}

enum TargetingModel {
  tapDirectional,
  holdDirectional,
  committedAimHold,
  selfCentered,
  autoTarget,
}

enum HitType {
  singleHit,
  multiHit,
  cleave,
}

class AbilityTiming {
  const AbilityTiming({
    required this.windupTicks,
    required this.activeTicks,
    required this.recoveryTicks,
  });

  final int windupTicks;
  final int activeTicks;
  final int recoveryTicks;
}

class AbilityCost {
  const AbilityCost({
    this.stamina = 0.0,
    this.mana = 0.0,
    this.health = 0.0,
  });

  final double stamina;
  final double mana;
  final double health;
}
```

---

## Primary Slot Abilities

### Sword Strike

**Design Intent:** Fast, reliable melee attack. The bread-and-butter offensive option.

| Property | Value |
|----------|-------|
| Category | Primary Hand |
| Targeting | Tap Directional |
| Hit Type | Single-hit |
| Damage Type | From weapon (slashing) |

**Timing (synced with animation: 6 frames × 0.06s = 360ms):**

| Phase | Frames | Duration |
|-------|--------|----------|
| Windup | 2 | 120ms |
| Active | 2 | 120ms |
| Recovery | 2 | 120ms |
| **Total** | **6** | **360ms** |

**Cost & Cooldown:**

| Property | Value |
|----------|-------|
| Stamina Cost | 8 |
| Mana Cost | 0 |
| Cooldown | 6 ticks (~100ms) |

**Data Structure:**

```dart
const swordStrike = AbilityDef(
  id: AbilityId.swordStrike,
  category: AbilityCategory.primaryHand,
  targetingModel: TargetingModel.tapDirectional,
  animKey: AnimKey.strike,
  timing: AbilityTiming(windupFrames: 2, activeFrames: 2, recoveryFrames: 2),
  cost: AbilityCost(stamina: 5),
  cooldownSeconds: 0.30,
  hitType: HitType.singleHit,
  baseDamage: 15.0,
  tags: {AbilityTag.melee, AbilityTag.strike},
);
```

---

### Sword Parry

**Design Intent:** Defensive timing-based counter. Rewards precise timing with damage reflection.

| Property | Value |
|----------|-------|
| Category | Primary Hand |
| Targeting | Self-Centered |
| Hit Type | N/A (defensive) |
| Effect | Block incoming attack; on perfect timing, counter-attack |

**Timing (synced with animation: 6 frames × 0.06s = 360ms):**

| Phase | Frames | Duration |
|-------|--------|----------|
| Windup | 1 | 60ms |
| Active | 3 | 180ms (parry window) |
| Recovery | 2 | 120ms |
| **Total** | **6** | **360ms** |

**Cost & Cooldown:**

| Property | Value |
|----------|-------|
| Stamina Cost | 10 |
| Cooldown | 18 ticks (~300ms) |

**Data Structure:**

```dart
const swordParry = AbilityDef(
  id: AbilityId.swordParry,
  category: AbilityCategory.primaryHand,
  targetingModel: TargetingModel.selfCentered,
  animKey: AnimKey.parry,
  timing: AbilityTiming(windupFrames: 1, activeFrames: 3, recoveryFrames: 2),
  cost: AbilityCost(stamina: 10),
  cooldownSeconds: 0.50,
  hitType: HitType.singleHit,
  baseDamage: 0.0,
  tags: {AbilityTag.melee, AbilityTag.defensive, AbilityTag.parry},
);
```

---

## Secondary Slot Abilities

### Shield Bash

**Design Intent:** Offensive shield attack. Stuns enemies briefly.

| Property | Value |
|----------|-------|
| Category | Secondary Hand |
| Targeting | Tap Directional |
| Hit Type | Single-hit |
| Effect | Stun on hit (from weapon) |

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
| Stamina Cost | 12 |
| Cooldown | 24 ticks (~400ms) |

**Data Structure:**

```dart
const shieldBash = AbilityDef(
  id: AbilityId.shieldBash,
  category: AbilityCategory.secondaryHand,
  targetingModel: TargetingModel.tapDirectional,
  timing: AbilityTiming(windupTicks: 8, activeTicks: 4, recoveryTicks: 10),
  cost: AbilityCost(stamina: 12),
  cooldownTicks: 24,
  hitType: HitType.singleHit,
  baseDamage: 8.0,
  tags: {AbilityTag.melee, AbilityTag.strike, AbilityTag.stun},
);
```

---

### Shield Block

**Design Intent:** Sustained defensive stance. Reduces incoming damage while held.

| Property | Value |
|----------|-------|
| Category | Secondary Hand |
| Targeting | Self-Centered (hold) |
| Hit Type | N/A (defensive) |
| Effect | Damage reduction while active |

**Timing (at 60 FPS):**

| Phase | Ticks | Duration |
|-------|-------|----------|
| Windup | 3 | ~50ms |
| Active | Variable (hold) | Up to max |
| Recovery | 6 | ~100ms |

**Cost & Cooldown:**

| Property | Value |
|----------|-------|
| Stamina Cost | 5 (on start) + 2/tick while held |
| Cooldown | 12 ticks (~200ms) |

**Data Structure:**

```dart
const shieldBlock = AbilityDef(
  id: AbilityId.shieldBlock,
  category: AbilityCategory.secondaryHand,
  targetingModel: TargetingModel.selfCentered,
  timing: AbilityTiming(windupTicks: 3, activeTicks: 0, recoveryTicks: 6),
  cost: AbilityCost(stamina: 5),
  cooldownTicks: 12,
  hitType: HitType.singleHit,
  baseDamage: 0.0,
  tags: {AbilityTag.defensive, AbilityTag.block, AbilityTag.sustained},
);
```

---

## Projectile Slot Abilities

### Throwing Knife

**Design Intent:** Fast, low-damage ranged option. Good for poking.

| Property | Value |
|----------|-------|
| Category | Projectile |
| Targeting | Hold Directional |
| Hit Type | Single-hit |
| Projectile | Stop on first hit |

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
| Stamina Cost | 5 |
| Cooldown | 18 ticks (~300ms) |

**Data Structure:**

```dart
const throwingKnife = AbilityDef(
  id: AbilityId.throwingKnife,
  category: AbilityCategory.projectile,
  targetingModel: TargetingModel.holdDirectional,
  timing: AbilityTiming(windupTicks: 4, activeTicks: 2, recoveryTicks: 6),
  cost: AbilityCost(stamina: 5),
  cooldownTicks: 18,
  hitType: HitType.singleHit,
  baseDamage: 10.0,
  tags: {AbilityTag.ranged, AbilityTag.throw},
);
```

---

### Ice Bolt

**Design Intent:** Slowing projectile spell. Controls enemy movement.

| Property | Value |
|----------|-------|
| Category | Projectile (Spell) |
| Targeting | Hold Directional |
| Hit Type | Single-hit |
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
| Mana Cost | 10 |
| Cooldown | 24 ticks (~400ms) |

**Existing Implementation:**

```dart
// From spell_catalog.dart
case SpellId.iceBolt:
  return const SpellDef(
    stats: ProjectileSpellStats(
      manaCost: 10.0,
      damage: 15.0,
      damageType: DamageType.ice,
      statusProfileId: StatusProfileId.iceBolt,
    ),
    projectileId: ProjectileId.iceBolt,
  );
```

---

### Fire Bolt

**Design Intent:** Burning projectile spell. Applies burn DoT.

| Property | Value |
|----------|-------|
| Category | Projectile (Spell) |
| Targeting | Hold Directional |
| Hit Type | Single-hit |
| Effect | Applies burn on hit |
| Damage Type | Fire |

**Cost & Cooldown:**

| Property | Value |
|----------|-------|
| Mana Cost | 12 |
| Damage | 18 |
| Cooldown | 30 ticks (~500ms) |

**Existing Implementation:**

```dart
// From spell_catalog.dart
case SpellId.fireBolt:
  return const SpellDef(
    stats: ProjectileSpellStats(
      manaCost: 12.0,
      damage: 18.0,
      damageType: DamageType.fire,
      statusProfileId: StatusProfileId.fireBolt,
    ),
    projectileId: ProjectileId.fireBolt,
  );
```

---

### Thunder Bolt

**Design Intent:** Stunning projectile spell. Applies stun on hit.

| Property | Value |
|----------|-------|
| Category | Projectile (Spell) |
| Targeting | Hold Directional |
| Hit Type | Single-hit |
| Effect | Apply stun on hit |
| Damage Type | Thunder |

**Cost & Cooldown:**

| Property | Value |
|----------|-------|
| Mana Cost | 10 |
| Damage | 10 (per target) |
| Cooldown | 36 ticks (~600ms) |

**Existing Implementation:**

```dart
// From spell_catalog.dart
case SpellId.thunderBolt:
  return const SpellDef(
    stats: ProjectileSpellStats(
      manaCost: 10.0,
      damage: 10.0,
      damageType: DamageType.thunder,
      statusProfileId: StatusProfileId.thunderBolt,
    ),
    projectileId: ProjectileId.thunderBolt,
  );
```

---

## Mobility Slot Abilities

### Dash

**Design Intent:** Fast forward movement with i-frames. Aggressive repositioning.

| Property | Value |
|----------|-------|
| Category | Mobility |
| Targeting | Tap Directional |
| Effect | I-frames during Active phase |
| Movement | Forward dash (fixed distance) |

**Timing (synced with animation: 4 frames × 0.05s = 200ms, blocks on last frame):**

| Phase | Frames | Duration |
|-------|--------|----------|
| Windup | 0 | 0ms |
| Active | 4 | 200ms (i-frames, blocks on last frame) |
| Recovery | 0 | 0ms |
| **Total** | **4** | **200ms** |

**Cost & Cooldown:**

| Property | Value |
|----------|-------|
| Stamina Cost | 15 |
| Cooldown | 30 ticks (~500ms) |

**Data Structure:**

```dart
const dash = AbilityDef(
  id: AbilityId.dash,
  category: AbilityCategory.mobility,
  targetingModel: TargetingModel.tapDirectional,
  animKey: AnimKey.dash,
  timing: AbilityTiming(windupFrames: 0, activeFrames: 4, recoveryFrames: 0),
  cost: AbilityCost(stamina: 2),
  cooldownSeconds: 2.0,
  hitType: HitType.singleHit,
  baseDamage: 0.0,
  tags: {AbilityTag.mobility, AbilityTag.iframes},
);
```

---

### Roll

**Design Intent:** Evasive maneuver with longer i-frames. Defensive repositioning.

| Property | Value |
|----------|-------|
| Category | Mobility |
| Targeting | Tap Directional |
| Effect | I-frames during Active phase |
| Movement | Roll (shorter distance than dash) |

**Timing (synced with animation: 10 frames × 0.05s = 500ms, not looping):**

| Phase | Frames | Duration |
|-------|--------|----------|
| Windup | 1 | 50ms |
| Active | 8 | 400ms (i-frames) |
| Recovery | 1 | 50ms |
| **Total** | **10** | **500ms** |

**Cost & Cooldown:**

| Property | Value |
|----------|-------|
| Stamina Cost | 12 |
| Cooldown | 36 ticks (~600ms) |

**Data Structure:**

```dart
const roll = AbilityDef(
  id: AbilityId.roll,
  category: AbilityCategory.mobility,
  targetingModel: TargetingModel.tapDirectional,
  animKey: AnimKey.roll,
  timing: AbilityTiming(windupFrames: 1, activeFrames: 8, recoveryFrames: 1),
  cost: AbilityCost(stamina: 8),
  cooldownSeconds: 2.5,
  hitType: HitType.singleHit,
  baseDamage: 0.0,
  tags: {AbilityTag.mobility, AbilityTag.iframes},
);
```

---

## Ability Summary Table

| Ability | Category | Targeting | Stamina | Mana | Damage | Cooldown |
|---------|----------|-----------|---------|------|--------|----------|
| Sword Strike | Primary | Tap Dir | 8 | - | 20 | 100ms |
| Sword Parry | Primary | Self | 10 | - | - | 300ms |
| Shield Bash | Secondary | Tap Dir | 12 | - | 8 | 400ms |
| Shield Block | Secondary | Self | 5+ | - | - | 200ms |
| Throwing Knife | Projectile | Hold Dir | 5 | - | 10 | 300ms |
| Ice Bolt | Projectile | Hold Dir | - | 10 | 15 | 400ms |
| Fire Bolt | Projectile | Hold Dir | - | 12 | 18 | 500ms |
| Thunder Bolt | Projectile | Hold Dir | - | 10 | 5 | 600ms |
| Dash | Mobility | Tap Dir | 15 | - | - | 500ms |
| Roll | Mobility | Tap Dir | 12 | - | - | 600ms |

---

## Design Notes

1. **Stamina vs Mana:** Physical abilities use stamina; spells use mana. This creates resource management decisions.

2. **Cooldown balance:** More powerful abilities have longer cooldowns. Dash is faster but shorter; Roll has longer i-frames but longer cooldown.

3. **Timing trade-offs:** Sword Strike is fast but has short active window. Sword Parry requires precise timing but rewards with counter-attack.

4. **Weapon synergy:** Damage type and procs come from equipped weapon, not the ability. Sword Strike with a fire sword applies burn.
