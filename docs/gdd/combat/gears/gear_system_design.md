# Gear

## Purpose

Gear is **equipment** that modifies and constrains the player's loadout.  
It exists to make the build matter without rewriting abilities.

For tuning workflow and parity checks, see:

- `docs/gdd/combat/balance/README.md`
- `docs/gdd/combat/balance/balance_invariants.md`
- `docs/gdd/combat/balance/scenario_matrix.md`

**Rule of thumb**

- **Abilities** define *how the action happens* (timing, targeting, hitbox, base damage model, costs, cooldown).
- **Gear** defines *what the action carries* (damage flavor, proc payload, passive stats, restrictions).
- **Passives** (talents, rings, passive bonuses) are the final layer that can further modify both.

This separation is mandatory for scale: adding new gear must not require rewriting ability logic.

---

## Gear slots

The character has these **gear slots**:

| Slot | What it is | Owns |
|---|---|---|
| **Primary** | Main-hand weapon | weapon category/type, damage flavor payload, weapon stats, procs, compatibility gates |
| **Secondary** | Off-hand item | off-hand stats/procs/traits, compatibility gates |
| **Projectile** | Spell focus / throwable / ranged item | projectile payload (damage flavor + procs), compatibility gates |
| **Utility** | Pure passive item (ring/charm/etc.) | passive stats, passive modifiers, compatibility gates |

### Two-handed rule (visible Secondary, occupied)
A **two-handed** Primary occupies **both Primary + Secondary**.

**Intent:** the Secondary slot remains **visible** in UI and loadout, but is shown as **occupied by the two-handed weapon** (not empty and not a separate item).  
While a two-handed Primary is equipped, you cannot equip a separate Secondary item.

---

## Design contracts

### 1. Gear does not own ability structure
Gear must **never** define:
- targeting model (tap vs aim+commit vs self)
- windup/active/recovery timings
- hitbox / projectile shape
- input rules, buffering, preemption
- the ability's base damage numbers (gear can *modify* numbers but does not *own* them)

### 2. Deterministic resolution order
All modifiers resolve in this strict order:

**Ability → Gear → Passive**

This guarantees consistent balancing and prevents “hidden power” in later layers.

### 3. Slots are never empty (ever)
The loadout is **always complete**:

- On first load, **default gear** is automatically equipped in every gear slot.
- Gear slots cannot be emptied; they can only be **swapped**.
- **Utility is mandatory** (no empty utility).

Any illegal combination must be blocked at **equip-time** (setup UI / meta validation), never discovered mid-run.

### 4. Gear ↔ Ability pool mapping (hard contract)
Gear gates **which abilities can be equipped** by defining the available pool for each ability slot.

| Ability slot | Comes from | Intent |
|---|---|---|
| **Primary ability** | Primary gear | Primary weapon determines eligible Primary abilities. |
| **Secondary ability** | Secondary gear (or the two-handed Primary occupying Secondary) | Off-hand determines eligible Secondary abilities; if two-handed, the two-handed weapon provides the Secondary-eligible set (or a constrained subset). |
| **Projectile ability** | Projectile gear | Projectile item determines eligible Projectile abilities. |
| **Mobility ability** | Player kit | Mobility is a character kit slot, not gear-gated by default (unless a future Utility explicitly gates it). |
| **Jump** | Player kit | Jump is part of core kit; not gear-gated by default. |
| **Bonus ability** | Spellbook grants + global/meta unlocks | Current Core bonus self-spells are spellbook-gated; keep utility ownership optional unless explicitly designed. |

**Important:** gating is eligibility only. Gear should not rewrite ability mechanics; it only constrains *which* mechanics you can choose.

---

## What gear owns

### A. Stats
Gear can provide additive/multiplicative stats such as:

- power / damage scalar
- crit chance / crit multiplier
- range scalar (melee reach, projectile speed)
- defenses / resistances (physical/elemental)
- resource modifiers (stamina/mana max, regen, cost reduction)

**Intent:** stats must be predictable and communicateable; never “surprise” the player mid-run.

Current Core wiring model:

- **Global offensive stats** (`globalPowerBonusBp`, `globalCritChanceBonusBp`) apply to all outgoing payloads.
- **Payload-source offensive stats** (`powerBonusBp`, `critChanceBonusBp`) apply only from the selected payload source item (weapon/projectile/spellbook).
- **Global incoming defense** (`defenseBonusBp`) applies before typed resistance.
- **Typed gear resistance** (`physical/fire/ice/thunder/bleedResistanceBp`) combines with base typed resistance at incoming-damage resolution.
- **Resource/cooldown/move speed stats** are resolved from full loadout and applied in their dedicated runtime stages.

### B. Damage flavor (stacks, no overwrite)
Gear contributes a **damage flavor payload** when an ability requests “use equipped payload”.

Examples:
- Sword → slashing physical payload
- Spear → piercing physical payload
- Mace → bludgeoning physical payload
- Fire focus → fire elemental payload
- Throwing knife bundle → physical piercing payload

**Stacking intent:** abilities do not overwrite gear flavor, and gear does not overwrite ability flavor.  
Instead, they **stack** into the final hit payload (e.g., an ability can add a secondary component, while gear provides the default component).

If you ever introduce “conversion” (e.g., physical → fire), it must be explicit as a proc/trait with clear UI wording (conversion is not an implicit overwrite).

### C. Procs (data-driven hooks)
A **proc** is a data-defined modifier that can trigger at specific hook points, e.g.:

- **OnHit**: apply status, add bonus damage, lifesteal, knockback impulse
- **OnCrit**: bonus effect on crit
- **OnKill**: resource refund, stack buff
- **OnAbilityCommit**: consume charges, spawn auxiliary projectile, etc.

Proc design constraints:
- deterministic (no frame-time dependence)
- explicit stacking rules (see below)
- explicit trigger + optional internal cooldown (ICD)

#### Proc schema (intent + sane defaults)
Every proc should define (at minimum):

- `hook`: one of (OnCommit, OnHit, OnCrit, OnKill, OnTakenHit, …)
- `chance`: probability (default **100%** unless the proc is explicitly RNG-based)
- `icdTicks`: internal cooldown in ticks (default **0**)
- `magnitude`: numeric payload (damage bonus, heal amount, knockback impulse, etc.) (default **0**, meaning “pure status”)
- `durationTicks`: for timed statuses/buffs (default **0** for instantaneous)
- `stackingPolicy`: one of (Independent, RefreshToMax, Replace, BlockedByICD) (default **Independent**)
- `maxStacks`: (default **1**)
- `targetFilter`: (default **Enemy**; anything else must be explicit)

If a proc applies a **status effect**, it must declare its refresh policy (never implicit).

### D. Compatibility gates
Gear can gate **which abilities can be equipped** (and/or how they behave) via:

- **weapon type requirements** (e.g., “requires sword”, “requires shield”, “requires staff”)
- **tags**: gear can grant ability tags and abilities can require tags

This enables:
- one ability reused across multiple gear variants
- gear that unlocks *families* of abilities without hardcoding per-item checks

---

## Loadout compatibility rules

### Required weapon type
An ability may require:
- a specific weapon type (sword/shield/staff/etc.)
- a category (any primary weapon, any off-hand, any projectile item)

### Tag-based compatibility
- Gear may provide **granted tags**.
- Abilities may require **one or more tags** to be eligible.

Examples:
- “Parry” requires `hasShield` or `hasSwordParryGuard`
- “Firebolt” requires `spellFocus` + `fireAffinity`
- “Quick Shot” requires `throwable`

### Conflict resolution
If multiple equipped gear items grant overlapping tags or procs:
- tags **union** (simple set)
- procs follow explicit stacking rules (below)

---

## Stacking rules

### Stats stacking (defaults + caps)
Stats should declare their stacking mode:

- **Flat additive**: `+X` (e.g., +10 power, +15 max HP)
- **Percent scalar**: `×(1 + X%)` (e.g., +15% damage)
- **Override / Max**: strongest wins (used for mutually exclusive traits or caps)

**Sane default math:** apply all flat additions first, then apply percent scalars multiplicatively, then apply overrides/caps.

**Sane default caps (balance guardrails):**
- **Crit chance:** cap at **60%**
- **Cost reduction:** cap at **50%**
- **Resistances:** cap at **75%**
- **Attack speed scalar:** cap at **+75%** (i.e. max 1.75×)
- **Move speed scalar:** cap at **+50%** (i.e. max 1.5×)

If a stat needs a different cap, it must be specified in the stat definition and surfaced in UI.

### Proc stacking
Procs must define one of:

- **Independent**: multiple procs can trigger separately
- **RefreshToMax**: refresh duration to `max(currentRemaining, newDuration)` (prevents chain-extension)
- **Replace**: newest replaces old
- **BlockedByICD**: internal cooldown prevents rapid retrigger

**Important:** any status effect proc must declare its refresh policy (no implicit behavior).

---

## Progression and economy (gear)

### Unlocking
Gear is unlocked via meta progression (shop, drops, milestones, achievements).  
Unlocking should expand **build options**, not strictly power-creep.

If a “new mechanic” is introduced (new proc / trait), it should be a **new item**.

---

## UI implications (setup + lab)

### Setup Character Loadout
The loadout screen must:
- show gear slots and ability slots clearly
- prevent illegal equip combinations immediately
- surface why something is illegal (missing weapon type/tag, two-handed conflict, etc.)
- render two-handed as **occupying Secondary** (visible, not empty)

### Loadout Lab
The testing lab must:
- simulate the same input/commit model as runs
- allow quick swapping to test gear/ability synergy
- keep iteration friction minimal (fast restart, minimal navigation)

### UI text ownership (for localization readiness)
Gear display copy is owned by the UI text layer and keyed by stable IDs.

- Core gear definitions/catalogs must not store user-facing `displayName` or `description` text.
- UI resolves names/descriptions from ID mappings (and later localization keys) so gameplay data stays language-agnostic.

