# Eloise Secondary: Shield

## Scope

This document defines Eloise abilities that require `WeaponType.shield` and
are equipped in `AbilitySlot.secondary`.

Core units:

- Damage/cost: fixed-point (`100 = 1.0`)
- Percent/buffs: basis points (`100 = 1%`)
- Ticks authored at 60 Hz

## Ability Matrix (Current Core)

| Ability ID | Lifecycle | Targeting | Timing (W/A/R) | Cost | Cooldown | Payload Source |
|---|---|---|---|---:|---:|---|
| `eloise.shield_bash` | `tap` | `directional` | `8 / 6 / 8` | stamina `500` | `18` | `secondaryWeapon` |
| `eloise.charged_shield_bash` | `holdRelease` | `aimedCharge` | `10 / 6 / 10` | stamina `550` | `24` | `secondaryWeapon` |
| `eloise.shield_bash_auto_aim` | `tap` | `homing` | `8 / 6 / 8` | stamina `550` | `24` | `secondaryWeapon` |
| `eloise.shield_riposte_guard` | `holdMaintain` | `none` | `2 / 180 / 2` | hold drain `700/s` | `30` | `secondaryWeapon` |

## Offensive Shield Abilities

### `eloise.shield_bash`

- Base damage: `1500`
- Ability proc: guaranteed `StatusProfileId.stunOnHit` on hit
- Hit delivery: melee box `32x32`, offset `(12, 0)`, `oncePerTarget`

### `eloise.shield_bash_auto_aim`

- Same structure as `shield_bash` but `homing` targeting.
- Reliability tax is explicit in authored values:
  - damage `1500 -> 1400`
  - stamina `500 -> 550`
  - cooldown `18 -> 24`

### `eloise.charged_shield_bash`

- Base damage: `1600`
- Forced interrupts: `stun`, `death`, `damageTaken`
- Charge tiers (`minHoldTicks60`):
  - `0`: damage `0.90x`
  - `8`: damage `1.08x`, `+5%` crit
  - `16`: damage `1.30x`, `+10%` crit
- `chargeMaxHoldTicks60: 150`

## Defensive Shield Ability

### `eloise.shield_riposte_guard`

- `holdMaintain` contract (`holdMode: holdToMaintain`)
- Max active hold window authored as `180` ticks
- Stamina drain while held: `700` per second
- No direct damage payload (`baseDamage: 0`, `SelfHitDelivery`)
- Uses `AnimKey.shieldBlock`

## Design Constraints

1. All abilities in this file require `WeaponType.shield`.
2. Payload/procs are sourced from secondary weapon path (`AbilityPayloadSource.secondaryWeapon`).
3. Charged shield bash is interruption-sensitive by design (`damageTaken` included).
