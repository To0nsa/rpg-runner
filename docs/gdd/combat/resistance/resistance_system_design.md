# Damage Resistance

## Purpose

Damage resistance defines per-damage-type mitigation or vulnerability at the
entity level. It exists to support:

- enemy identity (elemental strengths/weaknesses),
- readable counterplay in loadouts,
- deterministic balancing knobs for content expansion.

---

## Scope

This document covers typed damage resistance (`DamageResistanceStore`) only.

It does not replace:

- global defense (`defenseBonusBp` in resolved stats),
- invulnerability frames,
- status immunity.

---

## Current Runtime Model

### Damage types

`DamageType` currently includes:

- `physical`
- `fire`
- `ice`
- `thunder`
- `bleed`

### Storage contract

Per entity, resistance is stored in `DamageResistanceStore` as basis points:

- `physicalBp`
- `fireBp`
- `iceBp`
- `thunderBp`
- `bleedBp`

Unit:

- `100 bp = 1%`
- `+5000 bp = +50% damage taken` (vulnerability)
- `-5000 bp = -50% damage taken` (resistance)
- `-10000 bp = 0 damage after typed resistance step`

If an entity has no `DamageResistanceStore` entry, typed modifier defaults to `0`.

---

## Authoritative Damage Formula Order

In `DamageSystem.step`, incoming damage is resolved in this order:

1. Crit resolution (`critChanceBp` with deterministic RNG, +50% crit bonus)
2. Global defense (`ResolvedCharacterStats.applyDefense`)
3. Typed resistance/vulnerability from `DamageResistanceStore`
4. Final clamp `>= 0`

Typed resistance application:

`appliedAmount = applyBp(amountAfterDefense, resistanceBpForDamageType)`

Where:

- positive bp increases incoming damage,
- negative bp decreases incoming damage.

---

## Relationship with Defense

Defense and typed resistance are separate layers:

- Defense is global and comes from resolved gear stats (`defenseBonusBp`).
- Typed resistance is per damage category and comes from entity archetype/store.

Current order is intentional:

`crit -> defense -> typed resistance`

This means typed vulnerabilities amplify damage after defense has already reduced the base.

---

## Relationship with Status Scaling

Status applications using `scaleByDamageType` read the same typed modifier via `DamageResistanceStore` using the request `damageType`.

Current behavior in `StatusSystem`:

- Positive modifier (`> 0`) scales status magnitude up.
- Negative modifier (`<= 0`) does not scale status magnitude down.

So typed resistance can fully reduce damage but still allow a status proc toapply at base magnitude.

---

## Current Content Examples

- Player (Eloise default): all typed resistance values are `0`.
- `EnemyId.unocoDemon`: `fireBp = -5000`, `iceBp = +5000`.
- `EnemyId.grojib`: all typed resistance values are `0`.

---

## Determinism Contract

1. Resistance values are integer basis points.
2. Lookup is direct by enum switch (`modBpForIndex`), no hashing/randomness.
3. Same command stream and seed yields identical damage outcomes.
4. Missing store entries deterministically resolve to neutral (`0`).

---

## Current Constraints and Gaps

1. No explicit clamp in `DamageResistanceStore` today.
2. Authoring can technically exceed `[-10000, +10000]`, which can create
   extreme outcomes.
3. No dedicated UI/snapshot exposure for per-type resistance values yet.
4. No resistance-penetration mechanic yet (flat or percent shred).

Recommended authoring guardrail until clamps are introduced:

- keep per-type values in `[-10000, +10000]`.

---

## Extension Template

### Add a new damage type

1. Add enum value in `DamageType`.
2. Add field in `DamageResistanceDef` and `DamageResistanceStore`.
3. Update `modBpFor` and `modBpForIndex` switches.
4. Ensure damage producers can emit the new `DamageType`.
5. Add tests for neutral, resistance, and vulnerability cases.

### Add per-type resistance on gear

1. Extend `GearStatBonuses` with typed resistance fields (for example:
   `physicalResistBp`, `fireResistBp`, `iceResistBp`, `thunderResistBp`,
   `bleedResistBp`).
2. Add clamp limits for typed resistance in `CharacterStatCaps`.
3. Aggregate typed resistance in `CharacterStatsResolver` and expose it on
   `ResolvedCharacterStats`.
4. Define and enforce one authority path for runtime application:
   - either write resolved typed resistance into `DamageResistanceStore`, or
   - resolve gear typed resistance in `DamageSystem` and combine with store data.
5. Freeze stacking order explicitly (recommended):
   `archetype/base resistance + gear resistance + temporary runtime modifiers`.
6. Add tests for:
   - neutral vs resistant vs vulnerable outcomes from gear,
   - interaction with global defense (`defenseBonusBp`) and formula order,
   - deterministic outcomes for repeated runs.
7. Update related docs (`docs\gdd\combat\gears\gear_system_design.md`, `docs\gdd\combat\stats\character_stats_system_design.md`, and this file) after implementation.

### Add penetration / shred later

Prefer explicit pipeline stage after defense and before typed resistance, with
deterministic clamping and test coverage for stacking order.
