# Eloise Projectile Slot: Ranged

## Scope

This document defines Eloise abilities equipped in `AbilitySlot.projectile`.

All abilities here use:

- `payloadSource: AbilityPayloadSource.projectileItem`
- `requiredWeaponTypes: {throwingWeapon, projectileSpell}`
- `AnimKey.ranged`

Core units:

- Damage/cost: fixed-point (`100 = 1.0`)
- Percent/buffs: basis points (`100 = 1%`)
- Ticks authored at 60 Hz

## Ability Matrix (Current Core)

| Ability ID | Lifecycle | Targeting | Timing (W/A/R) | Cost | Cooldown | Base Damage |
|---|---|---|---|---:|---:|---:|
| `eloise.auto_aim_shot` | `tap` | `homing` | `10 / 2 / 12` | mana `800` | `40` | `1300` |
| `eloise.quick_shot` | `holdRelease` | `aimed` | `10 / 2 / 12` | mana `600` | `14` | `900` |
| `eloise.piercing_shot` | `holdRelease` | `aimedLine` | `10 / 2 / 12` | mana `1000` | `32` | `1800` |
| `eloise.charged_shot` | `holdRelease` | `aimedCharge` | `10 / 2 / 12` | mana `1300` | `40` | `2300` |

## Ability Notes

### `eloise.auto_aim_shot`

- Deterministic lock-on (`TargetingModel.homing`)
- Simplest fire-and-forget projectile lane entry

### `eloise.quick_shot`

- Fast low-cost aimed projectile
- Best cadence in projectile lane via low cooldown (`14`)

### `eloise.piercing_shot`

- Line-aim variant for alignment scenarios
- Projectile delivery includes `pierce: true` and `chainCount: 3`

### `eloise.charged_shot`

- Forced interrupts: `stun`, `death`, `damageTaken`
- Tiered charge profile (`minHoldTicks60`):
  - `0`: damage `0.82x`, speed `0.90x`
  - `5`: damage `1.00x`, speed `1.05x`, `+5%` crit
  - `10`: damage `1.225x`, speed `1.20x`, `+10%` crit, pierce `true`, max pierce hits `2`
- `chargeMaxHoldTicks60: 150`

## Payload Behavior

Authored projectile IDs in these ability defs are defaults/fallbacks. Runtime
payload (projectile type, procs, damage type, stats) is resolved from equipped
projectile item path at commit time.

This keeps one ranged ability structure reusable across spell and throwing
weapon builds.
