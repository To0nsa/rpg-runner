# Character Stats

## Goals

- Keep buildcraft readable in runner pacing
- Preserve deterministic, multiplayer-safe resolution
- Keep tuning surface small and explicit

## Current Stat Set

Core gameplay stats:

- Health
- Mana
- Stamina
- Health Regen
- Mana Regen
- Stamina Regen
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
| Health Regen/Mana Regen/Stamina Regen | Regen-per-second scaling from resolved loadout stats at spawn, clamped to `>= 0`. |
| Defense | Global incoming reduction before typed resistance. |
| Power | Global power only (resolved + offense-buff). |
| Move Speed | Gear multiplier composed with status modifier multiplier. |
| Cooldown Reduction | Applied at ability commit (then action-speed scaling on attack/cast slots). |
| Crit Chance | Global crit chance only (resolved + offense-buff), final clamp. |
| Typed Resistance | Applied from store + gear incoming mod for all 10 damage types. |

## Numeric Units

- basis points: `100 = 1%`
- fixed-point resources/damage: `100 = 1.0`

## Key Formulas

### Loadout stat aggregation

`total = mainWeapon`

`if (mask has offHand && mainWeapon is not two-handed) total += offhandWeapon`

`if (mask has projectile) total += spellBook`

`total += accessory`

`resolved = clampPerStat(total)`

### Resource max scaling

`scaledMax = applyBp(baseMax100, resourceBonusBp)`

### Resource regen scaling

`scaledRegenPerSecond100 = max(0, applyBp(baseRegenPerSecond100, resourceRegenBonusBp))`

### Move speed

`finalMoveSpeed = gearMoveSpeedMultiplier * statusMoveSpeedMultiplier`

### Cooldown reduction

`scaledCooldownTicks = ceil(baseCooldownTicks * (10000 - cooldownReductionBp) / 10000)`

### Outgoing payload build (stats-relevant)

1. start from `AbilityDef.baseDamage`, `baseDamageType`, and ability procs
2. apply global power (`resolvedGlobalPowerBp + offenseBuffPowerBp`)
3. if payload source provides a damage type and ability base type is physical, override damage type
4. merge procs in canonical builder order (ability -> item -> buffs -> passives) with deterministic dedupe; current runtime call sites wire ability + item proc sources
5. clamp damage to `>= 0`

### Crit chance

`resolvedGlobalCritChanceBp = clamp(globalCritChanceBonusBp, -9000, 6000)`

`finalCritChanceBp = clamp(resolvedGlobalCritChanceBp + offenseBuffCritChanceBp, 0, 10000)`

Crit bonus is currently fixed at `+5000 bp` (`+50%`).

### Incoming damage order

1. source `weaken` penalty
2. crit
3. defense
4. typed modifier (`store + gearIncomingMod`)
5. target `vulnerable` bonus
6. clamp `>= 0` after each stage that can go negative

## Resolved Stats Cache Lifecycle

- Resolved via `ResolvedStatsCache`
- Recomputed only when equipped loadout snapshot changes
- Snapshot key fields: `mask`, `mainWeaponId`, `offhandWeaponId`, `spellBookId`, `accessoryId`
- `projectileSlotSpellId` and ability IDs do not affect resolved stat cache invalidation
- Neutral stats returned when no loadout exists
- Status effects apply through status/modifier stores, not by mutating resolved gear bundle

## Stat Caps (Current)

| Stat | Min | Max |
|---|---:|---:|
| Health bonus bp | `-9000` | `20000` |
| Mana bonus bp | `-9000` | `20000` |
| Stamina bonus bp | `-9000` | `20000` |
| Health regen bonus bp | `-9000` | `20000` |
| Mana regen bonus bp | `-9000` | `20000` |
| Stamina regen bonus bp | `-9000` | `20000` |
| Defense bp | `-9000` | `7500` |
| Global power bp | `-9000` | `10000` |
| Move speed bp | `-9000` | `5000` |
| Cooldown reduction bp | `-5000` | `5000` |
| Global crit chance bp | `-9000` | `6000` |
| Final payload crit chance bp (post-merge clamp) | `0` | `10000` |
| Typed resistance bp (each type) | `-9000` | `7500` |

## Eloise Baseline (Pre-Gear)

- HP max: `100`
- Mana max: `100`
- Stamina max: `100`
- HP regen: `0.5/s`
- Mana regen: `2.0/s`
- Stamina regen: `1.0/s`
