

---

## Guiding strategy (don’t skip this)

**Do not rewrite all systems into one “AbilitySystem” immediately.**
Instead, add an **Ability front-end** that outputs the *same intent stores you already have* (MeleeIntent/CastIntent/RangedWeaponIntent/Dash), then migrate execution later.

Why: your current pipelines are already deterministic and battle-tested enough (they gate via `EquippedLoadoutStore.mask`, they block while stunned, they stamp anim ticks, etc.). Example: `PlayerMeleeSystem` and `PlayerCastSystem` already read `EquippedLoadoutStore` and block on `controlLock.isStunned`.

---

## Phase 0 — Lock the design contract (1 short doc page)

Before coding, freeze these as **non-negotiable contracts** (because they drive code shape):

* Slot set + “slots never empty” rule. 
* Targeting models + commit points (tap vs hold-release vs committed-hold). 
* Mobility preemption + buffering rules.
* Modifier order: ability → weapon → passive.

Deliverable: 1 “contracts” section at top of `ability_system_design.md` + any clarifications you already decided.

---

## Phase 1 — Data model foundation (no behavior changes yet)

### 1) Add Ability IDs + defs + catalog

Create minimal “authoritative” types matching your design docs:

* `AbilityId`, `AbilityDef`, `AbilityCategory`, `AbilityTag`
* `TargetingModel`, `AbilityTiming(windup/active/recovery ticks)`, `AbilityCost`, `cooldownTicks`, `animKey`
  This aligns with your Eloise spec.

### 2) Add slot model

Introduce `AbilitySlot { primary, secondary, projectile, mobility, bonus }` (and keep Jump separate if you want it “fixed”). This mirrors your slot rules. 

### 3) Extend EquippedLoadoutStore (still backwards compatible)

Today, `PlayerArchetype` equips `weaponId/offhand/rangedWeaponId/spellId` and a `LoadoutSlotMask`. 
Add new fields in `EquippedLoadoutStore` for:

* `abilityPrimaryId`, `abilitySecondaryId`, `abilityProjectileId`, `abilityMobilityId`, `abilityBonusId`
  Keep the old ones temporarily to avoid breaking everything.

**Acceptance criteria**

* Player spawns with these ability ids populated (hardcoded defaults for Eloise using your table: Sword Strike/Parry, Dash/Roll, etc.).
* Nothing in gameplay changes yet.

---

## Phase 2 — Weapon payload refactor (still no behavior changes)

Your weapon doc explicitly says **RangedWeaponDef.damage must move to abilities**.

### 4) Update weapon defs toward “payload provider”

* Expand `WeaponDef` and `RangedWeaponDef` to carry: `enabledAbilityTags`, `damageType default`, `procs`, `stats`, `isTwoHanded`. 
* Transitional approach: keep `statusProfileId` during migration, but design toward a list of `WeaponProc`. 

**Acceptance criteria**

* Catalogs compile and still return same current items.
* No gameplay change.

---

## Phase 3 — Ability “front-end” that drives existing intent stores (the key migration step)

### 5) Add an AbilityActivationSystem (Core)

Create one new system whose only job is:

* Read input
* Resolve the equipped ability for the pressed “button/slot”
* Apply commit rules (tap vs hold-release vs committed-hold) 
* Enforce locks (stun etc.) like your current systems do
* Optionally do input buffering (1-slot buffer) 
* Emit **AbilityRequest** into a small store (or directly write intents)

### 6) Add a thin “adapter layer”: AbilityRequest → existing intents

Instead of rewriting `MeleeStrikeSystem`, `SpellCastSystem`, `RangedWeaponSystem`, you do:

* If ability is “melee”: write `MeleeIntentDef`
* If ability is “spell projectile”: write `CastIntentDef`
* If ability is “throw weapon”: write `RangedWeaponIntentDef`
* If ability is mobility: call into movement dash/roll start logic (or a MobilityIntent)

This preserves your current execution logic (cost/cooldown checks, spawning, hitboxes). Example: right now `PlayerCastSystem` writes `CastIntentDef` and `SpellCastSystem` owns mana/cooldown/spawn. Keep that separation. 

**Result:** you can delete `PlayerMeleeSystem / PlayerCastSystem / PlayerRangedWeaponSystem` later, but not yet.

**Acceptance criteria**

* Pressing the same buttons still triggers the same actions, but now the ability id decides “what happens”.
* Determinism preserved (no wall-clock, no per-frame logic).

---

## Phase 4 — Move damage/cost/cooldown ownership to abilities (actual design shift)

### 7) Refactor ranged thrown weapons first (cleanest)

Currently ranged weapons define `damage` and `staminaCost`.
Change to:

* Ability defines: baseDamage, cost, cooldown, targeting, hit delivery template
* Weapon defines: projectileId + ballistic params + payload modifiers (damage type, procs, stats)

So `RangedWeaponIntentDef` should carry:

* `baseDamage from ability`
* `projectile template params` (from weapon)
* `damageType/procs` merged from weapon payload
* final cooldown/cost from ability (possibly modified by weapon stats later)

### 8) Do the same for spells

Your current `PlayerCastSystem` picks `spellId` from loadout and uses global cast cooldown ticks. 
Shift to:

* Ability defines spell behavior and cooldown (firebolt vs icebolt are abilities, not “the cast button”)
* Equipped projectile gear (spell focus? projectile slot?) gates which spell abilities are valid (per your rules).

**Acceptance criteria**

* `RangedWeaponDef.damage` removed (or unused) and damage comes from ability.
* Spells and throws still spawn identical projectiles with same determinism.

---

## Phase 5 — Unified “hit payload” + proc hooks (ability→weapon→passive)

### 9) Implement a single “HitPayload” struct used by hitbox/projectile damage

Right now hitboxes carry `damage`, `damageType`, `statusProfileId`. 
Evolve to:

* payload includes: baseDamage, damageType, procList, crit data (future), source tags
* procs trigger from hook points (`onHit`, later `onBlock/onKill/onCrit`) 

Hard rule: apply modifiers in fixed order.

**Acceptance criteria**

* One place in code is responsible for final damage calculation and proc application.
* Weapon procs can be swapped without duplicating abilities.

---

## Phase 6 — Animation state becomes ability-driven (stop stamping “cast/melee/ranged”)

Today you stamp `lastCastTick/lastMeleeTick/...` in various player systems.
Replace with:

* `ActiveAbilityStateStore { abilityId, slot, phase (windup/active/recovery), startTick }`
  Then AnimResolver chooses `animKey` from the active ability.

**Acceptance criteria**

* Animation selection is purely derived from active ability state, not from “which system ran”.

---

## Phase 7 — Input/router + UI alignment (later, but you’ll need it)

Your router already has:

* separate aim channels (projectile/melee/ranged)
* commit methods that enqueue aim + pressed command then clear aim safely (clear blocking).

To support your targeting models cleanly:

* For **hold-release** abilities: keep current pattern (commit on release).
* For **committed aim hold**: enqueue “pressed” on hold start, keep updating aim while held, and ignore cancel unless forced interruption (your design doc supports this model).

Also: add new button events eventually (secondary / mobility / bonus) or map your existing buttons to slots.

---

## Phase 8 — Tests + migration cleanup

### 10) Determinism + regression

* Snapshot test: same seed + same input stream => identical snapshots/events.
* Combat test: ability modifiers + weapon procs order.

### 11) Delete old code paths

Once AbilityActivationSystem fully drives intents:

* remove `PlayerMeleeSystem`, `PlayerCastSystem`, `PlayerRangedWeaponSystem`
* remove legacy loadout mask paths if replaced by slot/ability validation

---
