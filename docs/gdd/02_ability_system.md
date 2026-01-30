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

## Design Contracts (Non-Negotiable)

These rules drive the implementation shape and must not be violated:

1.  **Slots are never empty:** Every slot (Primary, Secondary, etc.) must have a valid ability equipped.
2.  **Targeting determines commit:** 
    *   Tap → Commit on press.
    *   Hold → Commit on release.
    *   Committed-Hold → Commit on start (locked until release).
3.  **Mobility Preemption:** Mobility actions (Dash/Jump) explicitly preempt combat actions. Input buffer handles concurrency.
4.  **Modifier Order:** Evaluation order is always **Ability → Weapon → Passive**.
5.  **Data Ownership:** Ability defines *structure* (timing/targeting/base damage). Weapon/Projectile Item defines *payload* (damage type/procs).

---

## Core Concepts

### Ability

An ability is a discrete action the player can equip to a slot.

**Abilities define gameplay behavior:**

* base damage model + ability-specific effects; weapon/passives may add modifiers/procs
* costs (stamina/mana)
* cooldown
* timing windows (windup/active/recovery)
* targeting model (instant/directional/aim)
* animation key (presentation)

### Weapon / Projectile Item

A weapon (or projectile item) is equipment that provides the **payload** for actions and constrains what the player can equip.

A weapon/projectile item:

* **enables / gates** a compatible set of abilities (by weapon type requirements)
* provides **damage-type defaults** (slashing / piercing / bludgeoning, etc.)
* grants **passive stats + traits** (e.g., power, crit, range scalar, resistances)
* provides **effect modifiers** as **data-driven procs** applied at defined hook points (e.g., *onHit*: bleed/burn/slow)

Weapons and projectile items do **not** define the ability’s structure (targeting, timing windows, hitbox/projectile shape).  
They **parameterize** the outcome via modifiers, so one ability (e.g., *Strike* or *Ice Bolt*) can behave consistently while producing different payloads depending on the equipped item.

**Example:** equipping a one-hand sword enables *Sword Strike* and *Sword Parry*, sets damage type to *slashing*, and may add an on-hit *bleed* proc.


### Weapon vs Ability: Damage & Effects Relationship

Weapons and abilities both contribute to the final outcome, but they own **different layers** of the model.

**Abilities define the action (structure):**

* Targeting model (tap / hold-aim / self-centered)
* Timing windows (windup / active / recovery)
* Hit delivery (melee hitbox shape, projectile template)
* Costs + cooldown rules
* Base damage model (the "core" of the move)

**Weapons define the payload (modifiers):**

* Damage type defaults (slashing / piercing / bludgeoning)
* Passive stats and traits
* **Effect modifiers** (burn, bleed, slow, etc.) expressed as **data-driven procs** applied at defined hook points (e.g., *on hit*, *on block*, *on kill*)

> Design intent: the player should not need "Sword Strike (Bleed)" vs "Sword Strike (Burn)" as separate abilities.
> The **same ability** can produce different effects depending on the equipped weapon's modifiers.

**Final outcome** = ability structure + weapon/projectile payload.
Abilities decide *how the action is executed*; weapons/projectile items shape *what the hit carries*.

---

## Slot-Based Loadout

### Slots

A character has a set of named ability slots. Slots map to input buttons.

| Slot          | Role                              | Typical content                                          |
| ------------- | --------------------------------- | -------------------------------------------------------- |
| **Primary**   | Primary hand                      | strike, parry                                     |
| **Secondary** | Secondary hand (used by two-handed) | shield bash, shield block       |
| **Projectile**    | Projectile (projectile spells/throwing weapons) | quick throw, heavy throw, firebolt, icebolt, thunderbolt          |
| **Mobility**  | Mobility                          | dash, roll                                               |
| **Jump**      | Fixed Mobility                    | jump (fixed slot, always available)                      |
| **Bonus**     | Flexible slot                     | any of Primary/Secondary/Projectile                |

### Slot Rules

Each slot has **restrictions** that define what can be equipped.
Restrictions are determined by:

* **Slot role** (Primary/Secondary/Projectile/Mobility/Bonus)
* **Ability categories/types** (Melee/Defensive/Projectile/Magic/etc.)
* **Unlocks** (future meta progression)

**Design rules:**

* Legality is determined *when equipping* the loadout (menu time). In-run behavior assumes the equipped loadout is valid.
* **Slots are never empty.** Each slot must have a default ability equipped at all times.
* **Two-handed weapons occupy both Primary and Secondary.** When a two-handed weapon is equipped, it provides abilities for both slots.

---

## Ability Categories

Abilities are grouped into broad categories to support clear slot restrictions and consistent player expectations.

* **Primary hand**: ability linked to what is equipped in the primary gear slot
* **Secondary hand**: ability linked to what is equipped in the secondary gear slot; occupied by two-handed weapon if equipped
* **Projectile**: ability linked to what is equipped in the projectile gear slot (spells or throwing weapons)
* **Mobility**: special action (dash, roll, etc) — not a combat ability
* **Magic**: spell ability, special ability (AoE, buffs etc)
* **Combo** (Future): multi-tap ability that chains multiple attacks (double/triple tap sequences)

> Categories are about player intent and slot compatibility, not implementation.

### Mobility Abilities

Mobility is a **special action**, not a combat ability. It follows unique rules:

* **I-frames:** Dash/Roll grant invincibility frames during the Active phase.
* **Preemption:** Mobility can **preempt** any in-progress combat ability. When preempted, the combat ability is canceled under **forced interruption rules**.
* **Concurrency:** Mobility **is allowed** while in aiming state. Doing so cancels the aim/shot (Survival Priority).
* **Concurrency:** Mobility does not block combat abilities — after mobility completes, the player may immediately use a combat ability.

> **Jump** is a special case: it has its own dedicated button and slot. It follows the same "special action" rules as Mobility (not a combat ability).
> Jump input cancels any in-progress combat ability immediately, but once the jump executes it should not block other abilities.
---

## Ability Timing Model (Player-Facing Contract)

Every ability follows a common timing language so players can learn the system. All phases concerning the character must happen during the animation of the ability.

### Phases

* **Windup**: commitment begins; no effect yet (telegraph)
* **Active**: the ability “does its thing” (hitbox/effect window)
* **Recovery**: ending lag; player returns to normal control

### Windows & Rules

* **Cooldown** starts on **commit** (when costs are paid); must be consistent per ability.
* **Costs** are paid at commit (default) unless explicitly designed otherwise.

> The exact per-ability numbers are tuning. The model is the design contract.

### Concurrency Rule

**One action at a time:** The player may have at most one **combat ability** executing (Windup/Active/Recovery).

Movement and jumping remain available unless explicitly locked by the ability.

### Interruptions (Forced)

Some events (stun, death) can forcibly end an ability mid-execution.

**Design contract:**

* Pre-commit aiming (Hold Directional before release): cancel allowed (no cost/cd).
* Post-commit ability execution (Windup/Active/Recovery): no voluntary cancel (only forced interruption).
* No voluntary cancel after commit.
* Forced interruptions can occur in **any phase**.
* If interrupted **before Active**, effects do not occur.
* **Cost refund policy:** No refund (simple, punishing, consistent).
* **Cooldown policy:** Cooldown starts on commit (same as normal flow); interruption does not reset or cancel cooldown.
* **Queued inputs do not survive** interruption.

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
* **Cooldown feedback** must be readable by the player at all times.

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

**Aiming state rules:**

* While holding to aim, the character **continues to move**; aiming does not pause time.
* If the player releases while in an invalid state (stunned/dead), the ability **does not commit** and no cost is paid.

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

### Commit Timing (Per Targeting Model)

| Targeting Model | Commit Point |
|-----------------|--------------|
| Tap Directional | on press |
| Hold Directional | on release |
| Committed Aim Hold | on hold start |
| Self-Centered | on press |
| Auto-Target | on press (after target resolution) |

---

## Hit Rules

Each ability declares how it interacts with targets during the Active phase.

**Hit types:**

* **Single-hit:** affects the first valid target only.
* **Multi-hit / Cleave:** affects all valid targets in the hitbox.

**Design rule:** A target can be hit **at most once per Active window** unless the ability explicitly declares multi-tick hits.

**Projectile behaviors** (defined per ability):

* Pierce (continues through targets)
* Chain (jumps to nearby targets)
* Stop on first hit (default)

---

## Modifier Order (Determinism)

On hit, modifiers are applied in a fixed order to ensure deterministic outcomes:

1. **Ability modifiers** (base damage, ability-specific effects)
2. **Weapon modifiers** (damage type, procs, stats)
3. **Passive modifiers** (character passives, buffs)

**Status stacking rules** (refresh vs stack vs max stacks) are defined per status effect.

---

## Input Buffering

If the player presses a slot button while another ability is in **Recovery**, the input is buffered and will trigger on the first valid frame.

**Buffer duration** is configurable. Recommended default: **8-10 ticks (~130-165ms at 60 FPS)** — forgiving for mobile without feeling sluggish.

**Rules:**

* Only **one buffered input** is stored at a time (latest press wins).
* Buffered inputs are **cleared on forced interruption** (stun/hit) to prevent accidental actions.

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

**Bonus slot has no special priority or cooldown behavior** — it follows the same rules as other slots.

Optional stricter rule (future): Bonus can only equip abilities from a *subset* of other slots (Primary/Secondary/Projectile), to prevent weird loadouts.

### Ability Chaining

For now, **abilities do not chain** into each other. Each ability is independent and must complete (or be interrupted) before another can start.

> Future: Combo abilities may enable multi-tap chaining.

### Gear-Gated Slots

All slots must have a default gear equipped at all times.

Examples for Eloise:

* Primary requires a **weapon** (or two-handed weapon).
* Secondary requires an **off-hand weapon** (acts as Primary if two-handed weapon equipped).
* Projectile requires a **projectile item**, either a spell or a throwing weapon.
* Bonus has no dedicated gear slot, but the equipped ability may require a payload source (primary / secondary / projectile).

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

> Non-goal refers to **run-randomized modifiers** (roguelike affixes); **equipment/ability-defined modifiers** are allowed.

---

## Acceptance Criteria (Design-Level)

* A player can equip a valid loadout that maps abilities to slots.
* In a run, each button triggers exactly one equipped ability.
* Abilities follow a shared timing language (windup/active/recovery) and feel consistent.
* Weapons enable abilities and provide damage-type defaults + effect modifiers; abilities define the action structure (timing/targeting/hit delivery) and base damage model.
* Slot restrictions are clear, learnable, and enforced before the run starts.
