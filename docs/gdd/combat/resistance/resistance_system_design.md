# Damage Resistance

## Purpose

Typed resistance defines deterministic per-damage-type mitigation/vulnerability.

It supports:

- enemy identity and counters
- loadout tradeoffs
- predictable balance knobs

## Scope

Covers typed modifiers from:

- `DamageResistanceStore` (entity/archetype base)
- resolved gear typed resistance (`ResolvedCharacterStats`)

Does not replace:

- global defense
- invulnerability
- status immunity

## Current Runtime Model

### Damage types

`DamageType` currently includes:

- `physical`, `fire`, `ice`, `water`, `thunder`, `acid`, `dark`, `bleed`, `earth`, `holy`

### Store fields

`DamageResistanceStore` stores bp fields per entity:

- `physicalBp`, `fireBp`, `iceBp`, `waterBp`, `thunderBp`
- `acidBp`, `darkBp`, `bleedBp`, `earthBp`, `holyBp`

Units:

- `100 bp = 1%`
- positive bp = vulnerability (more damage taken)
- negative bp = resistance (less damage taken)

Missing store entry resolves to neutral (`0`).

## Damage Order in `DamageSystem`

Incoming damage resolves as:

1. Source-side `weaken` reduction (if present)
2. Crit
3. Global defense
4. Typed modifier
5. Target `vulnerable` bonus
6. Clamp `>= 0`

Typed step:

```text
combinedTypedModBp = baseTypedModBp + gearIncomingModBp
amountAfterTyped = applyBp(amountAfterDefense, combinedTypedModBp)
```

Where `gearIncomingModBp` is already sign-adjusted (`-resistanceBp`).

## Relation with Status Scaling

For status applications with `scaleByDamageType = true`:

- Status magnitude scales up only when combined typed modifier is positive.
- Negative combined modifier does not scale status down.

So resistance can reduce damage while status still applies at base magnitude.

## Current Content Examples

- Eloise default: neutral typed store values
- `EnemyId.unocoDemon`: `fireBp = -5000`, `iceBp = 5000`
- `EnemyId.grojib`: neutral typed store values

## Determinism Contract

1. Integer bp values only
2. Enum-switch lookup (no hash ordering)
3. Missing entries resolve to `0`
4. Same command stream + seed => same outcomes

## Constraints

- `DamageResistanceStore` itself has no clamp.
- Gear typed resistance is clamped in `CharacterStatsResolver` (`-9000..7500`).
- Authoring store values outside sane ranges can produce extreme outcomes.

Recommended store guardrail: keep authored values in `[-10000, 10000]` unless explicitly testing extremes.

## Extension Template

### Add a new damage type

1. Add enum in `DamageType`
2. Add fields/switch handling in:
   - `DamageResistanceDef`
   - `DamageResistanceStore`
   - `GearStatBonuses` / resolver accessors
3. Update producers and tests

### Add penetration/shred (future)

Prefer explicit stage between defense and typed resistance, with deterministic stacking tests.
