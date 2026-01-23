# Ability System Design (Design-First Overview)

## Purpose

Abilities are the player’s *equippable actions* (strike, parry, dash, roll, spells (firebolt, icebolt, etc), quick throw, heavy throw, etc.). A run is defined by a **loadout**: which abilities are mapped to which **button slots**.

This document defines **expected behavior and constraints** (game design contract). It intentionally avoids implementation details.

---

## Design Pillars

* **Clarity under pressure:** each button always triggers one predictable action.
* **Meaningful loadout choices:** abilities compete for limited slots; trade-offs are explicit.
* **Deterministic feel:** timing windows and outcomes must be consistent and learnable.
* **Scales with content:** adding new weapons/characters/abilities should not rewrite rules.

---

## Core Concepts

### Ability

An ability is a discrete action the player can equip to a slot.

**Abilities define gameplay behavior:**

* damage / effects
* costs (stamina/mana)
* cooldown
* timing windows (windup/active/recovery)
* targeting model (instant/directional/aim)
* animation key (presentation)

### Weapon

A weapon is equipment that:

* **enables** a set of abilities
* grants passive bonuses (stats, tags, resistances, damage types, effects)

**Weapons do not define amount of damage.** Damage are defined by the ability.

**Example:** equipping a one-hand sword enables *Sword Strike* and *Sword Parry*.

---

## Slot-Based Loadout

### Slots

A character has a set of named ability slots. Slots map to input buttons.

| Slot          | Role                              | Typical content                                          |
| ------------- | --------------------------------- | -------------------------------------------------------- |
| **Primary**   | Primary hand                      | strike, parry, combo                                     |
| **Secondary** | Secondary hand (or empty for two-handed) | shield bash, shield block, off-hand parry        |
| **Projectile**    | Projectile (spells/throwing weapons) | quick throw, heavy throw, firebolt, icebolt          |
| **Mobility**  | Mobility                          | dash, roll                                               |
| **Bonus**     | Flexible slot                     | any of Primary/Secondary/Projectile/Spell                |

### Slot Rules

Each slot has **restrictions** that define what can be equipped.
Restrictions are determined by:

* **Character** (what the character is allowed to use)
* **Role** (Primary/Secondary/Projectile/Spell)
* **Unlocks** (future meta progression)

**Design rule:** legality is determined *when equipping* the loadout (menu time). In-run behavior assumes the equipped loadout is valid.

---

## Ability Categories

Abilities are grouped into broad categories to support clear slot restrictions and consistent player expectations.

* **Primary hand**: ability linked to what is equipped in the primary gear slot
* **Secondary hand**: ability linked to what is equipped in the secondary gear slot; slot may be empty if Primary is a two-handed weapon
* **Projectile**: ability linked to what is equipped in the projectile gear slot (spells or throwing weapons)
* **Mobility**: mobility ability (dash, roll, etc)
* **Spell**: spell ability, special ability (AoE, buffs etc)
* **Combo** (Future): multi-tap ability that chains multiple attacks (double/triple tap sequences)

> Categories are about player intent and slot compatibility, not implementation.

---

## Ability Timing Model (Player-Facing Contract)

Every ability follows a common timing language so players can learn the system. All phases concerning the character must happen during the animation of the ability.

### Phases

* **Windup**: commitment begins; no effect yet (telegraph)
* **Active**: the ability “does its thing” (hitbox/effect window)
* **Recovery**: ending lag; player returns to normal control

### Windows & Rules

* **Cooldown** starts at the end of recovery; must be consistent per ability.
* **Costs** are paid at commit (default) unless explicitly designed otherwise.
* **Cancel behavior** (future): no canceling.

> The exact per-ability numbers are tuning. The model is the design contract.

---

## Costs, Cooldowns, and Resources

Abilities may consume:

* **Stamina** (physical actions)
* **Mana** (spells)
* **Health**
* **Stamina, Mana, Health**
* Optional future resources (ammo, charges)

### Design Rules

* If you don’t have enough resource, the ability **does not start**.
* Cooldown prevents re-activation until it completes.
* Abilities should not be **free** and always gated by cooldown even if short.

---

## Targeting Models

Each ability declares a targeting model that defines **how direction/area is chosen and when the ability commits**.

### **Directional (Tap / Hold)**

Used by melee strikes, throws, and other directional abilities.

* **Tap:** commits immediately using the character’s **current facing direction**.
* **Hold:** enters an aiming state; the player can rotate the direction freely. No time limit, tension is created by the runner genre forcing frequent jumps.
* **Release:** commits the ability using the last aimed direction.
* **Preview:** while holding, a clear directional indicator is shown.
* **Commit point:**

  * tap → commit on press
  * hold → commit on release

Facing direction is the fallback when no aiming occurs.

---

### **Self-Centered**

Used by defensive or aura-style abilities.

* Commits immediately on tap.
* Effect is centered on the player.
* No directional input required.

Examples: parry, block, guard stance, self-buff.

---

### **Auto-Target** (Future)

Used by abilities that prioritize targets over direction.

* On commit, snaps to the nearest valid target within a defined cone or area.
* Target selection rules must be clear and predictable.
* Visual feedback indicates which target will be affected before commit.

---

### Design Requirements

* The player must always understand **what will happen before commit**.
* Commit timing must be consistent per targeting model.
* Costs and cooldowns are applied at commit.
* Default behavior must work without holding or aiming.

---

## Animation and Feedback

Abilities reference a presentation key (animation/VFX/SFX).

### Design Rules

* Animation must **match phase timing** (windup telegraph, active impact).
* Effects must be readable at mobile scale.
* Input should feel responsive without breaking the timing contract.

> Ability timing is authoritative for gameplay; animation is the representation.

---

## Slot/Ability Interaction Rules

### Bonus Slot

The Bonus slot increases expression without adding new buttons.

**Baseline rule:** Bonus can equip any ability category that is also allowed by the character (excluding Mobility).

> Mobility is excluded from Bonus because having two mobility abilities would let the player move forward too quickly, breaking intended pacing.

Optional stricter rule (future): Bonus can only equip abilities from a *subset* of other slots (Primary/Secondary/Projectile), to prevent weird loadouts.

### Gear-Gated Slots

All slots must have a default gear equipped at all times.

Examples for Eloise:

* Primary requires a **sword** (or two-handed weapon, which leaves Secondary empty).
* Secondary requires a **shield** or off-hand weapon (empty if Primary is two-handed).
* Projectile requires a **projectile**, either a spell or a throwing weapon.
* Bonus does not require gear.

**Design rule:** gear cannot be missing.

---

## Example: Eloise (Early Content)

### Expected Slots

* Primary: Sword Strike **or** Sword Parry
* Secondary: Shield Block **or** Shield Bash
* Mobility: Dash or Roll
* Projectile: Ice Bolt or Throwing Knife
* Bonus: flexible

### Example Loadouts

**Loadout A (Aggressive):**

* Primary: Sword Strike
* Secondary: Shield Bash
* Mobility: Dash
* Projectile: Fire Bolt
* Bonus: Throwing Knife

**Loadout B (Defensive):**

* Primary: Sword Parry
* Secondary: Shield Block
* Mobility: Roll
* Projectile: Ice Bolt
* Bonus: Sword Strike

---

## Unlocking and Progression (Future-Compatible)

Abilities can be gated by meta progression.

* **Unlocked Abilities**: list of abilities the player has access to
* Unlock sources: XP, quests, store purchase, achievements

**Design rule:** unlocking happens between runs; in-run loadout remains stable.

---

## Non-Goals (For Early Phases)

* No mid-run ability swapping.
* No complex stance systems.
* No multi-layer talent trees.
* No procedural ability modifiers (unless explicitly introduced later).

---

## Acceptance Criteria (Design-Level)

* A player can equip a valid loadout that maps abilities to slots.
* In a run, each button triggers exactly one equipped ability (or does nothing if empty).
* Abilities follow a shared timing language (windup/active/recovery) and feel consistent.
* Weapons enable abilities without defining damage/effects.
* Slot restrictions are clear, learnable, and enforced before the run starts.
