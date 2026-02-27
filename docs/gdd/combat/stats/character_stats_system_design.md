# Character Stats (Current Core)

This document reflects the implemented stat model as of **2026-02-27**.

## Goals

- Keep buildcraft readable in runner pacing
- Preserve deterministic, multiplayer-safe resolution
- Keep tuning surface small and explicit

## V1 Stat Set

Core gameplay stats:

- Health
- Mana
- Stamina
- Defense
- Power
- Move Speed
- Cooldown Reduction
- Crit Chance

Runtime also supports typed resistance fields for all current `DamageType` values.

## Implementation Status

| Stat | Current behavior |
|---|---|
| Health/Mana/Stamina | Max-pool scaling from resolved loadout stats at spawn. |
| Defense | Global incoming reduction before typed resistance. |
| Power | Hybrid: global power + payload-source power. |
| Move Speed | Gear multiplier composed with status modifier multiplier. |
| Cooldown Reduction | Applied at ability commit. |
| Crit Chance | Hybrid: global crit chance + payload-source crit chance, final clamp. |
| Typed Resistance | Applied from store + gear incoming mod for all 10 damage types. |

## Numeric Units

- basis points: `100 = 1%`
- fixed-point resources/damage: `100 = 1.0`

## Key Formulas

### Resource max scaling

`scaledMax = applyBp(baseMax100, resourceBonusBp)`

### Move speed

`finalMoveSpeed = gearMoveSpeedMultiplier * statusMoveSpeedMultiplier`

### Cooldown reduction

`scaledCooldownTicks = ceil(baseCooldownTicks * (10000 - cooldownReductionBp) / 10000)`

### Outgoing damage

1. apply global power
2. apply payload-source power
3. clamp `>= 0`

### Crit chance

`finalCritChanceBp = clamp(globalCritChanceBonusBp + payloadSourceCritChanceBp, 0, 10000)`

Crit bonus is currently fixed at `+5000 bp` (`+50%`).

### Incoming damage order

1. source `weaken` penalty
2. crit
3. defense
4. typed modifier (`store + gearIncomingMod`)
5. target `vulnerable` bonus
6. clamp `>= 0`

## Resolved Stats Cache Lifecycle

- Resolved via `ResolvedStatsCache`
- Recomputed only when equipped loadout snapshot changes
- Neutral stats returned when no loadout exists
- Status effects apply through status/modifier stores, not by mutating resolved gear bundle

## Stat Caps (Current)

| Stat | Min | Max |
|---|---:|---:|
| Health bonus bp | `-9000` | `20000` |
| Mana bonus bp | `-9000` | `20000` |
| Stamina bonus bp | `-9000` | `20000` |
| Defense bp | `-9000` | `7500` |
| Global power bp | `-9000` | `10000` |
| Payload power bp | `-9000` | `10000` |
| Move speed bp | `-9000` | `5000` |
| Cooldown reduction bp | `-5000` | `5000` |
| Global crit chance bp | `0` | `6000` |
| Payload crit chance bp | `0` | `6000` |
| Typed resistance bp (each type) | `-9000` | `7500` |

## Current Catalog Highlights

- Weapons power: wooden `-1%`, basic `+1%`, solid `+2%`
- Spellbooks power: basic `-1%`, solid `+1%`, epic `+2%`
- Accessories:
  - speed boots: `+5%` move speed
  - golden ring: `+2%` max health
  - teeth necklace: `+2%` max stamina
- Projectile items currently contribute via payload/procs, not direct stat bonuses

## Eloise Baseline (Pre-Gear)

- HP max: `100`
- Mana max: `100`
- Stamina max: `100`
- HP regen: `0.5/s`
- Mana regen: `2.0/s`
- Stamina regen: `1.0/s`

## Notes

- Default shipped content currently does not grant global offensive stats.
- Default shipped content currently does not grant typed gear resistance bonuses.
