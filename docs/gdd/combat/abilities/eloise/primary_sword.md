# Eloise Primary: Sword

## Scope

This document defines Eloise abilities that require `WeaponType.oneHandedSword`
and are equipped in `AbilitySlot.primary`.

Core units:

- Damage/cost: fixed-point (`100 = 1.0`)
- Percent/buffs: basis points (`100 = 1%`)
- Ticks authored at 60 Hz

## Ability Matrix (Current Core)

| Ability ID | Lifecycle | Targeting | Timing (W/A/R) | Cost | Cooldown | Payload Source |
|---|---|---|---|---:|---:|---|
| `eloise.sword_strike` | `holdRelease` | `directional` | `8 / 6 / 8` | stamina `500` | `18` | `primaryWeapon` |
| `eloise.charged_sword_strike` | `holdRelease` | `aimedCharge` | `10 / 6 / 10` | stamina `550` | `24` | `primaryWeapon` |
| `eloise.charged_sword_strike_auto_aim` | `holdRelease` | `homing` | `10 / 6 / 10` | stamina `600` | `24` | `primaryWeapon` |
| `eloise.sword_strike_auto_aim` | `tap` | `homing` | `8 / 6 / 8` | stamina `550` | `24` | `primaryWeapon` |
| `eloise.sword_riposte_guard` | `holdMaintain` | `none` | `2 / 180 / 2` | hold drain `233/s` | `30` | `primaryWeapon` |

## Offensive Sword Abilities

### `eloise.sword_strike`

- Base damage: `1500`
- Ability proc: guaranteed `StatusProfileId.meleeBleed` on hit
- Hit delivery: melee box `32x32`, offset `(12, 0)`, `oncePerTarget`

### `eloise.sword_strike_auto_aim`

- Same structure as `sword_strike` but `homing` + `tap` lifecycle.
- Reliability tax is explicit in authored values:
  - damage `1500 -> 1400`
  - stamina `500 -> 550`
  - cooldown `18 -> 24`

### `eloise.charged_sword_strike`

- Base damage: `1600`
- Forced interrupts: `stun`, `death`, `damageTaken`
- Charge tiers (`minHoldTicks60`):
  - `0`: damage `0.90x`
  - `8`: damage `1.08x`, `+5%` crit
  - `16`: damage `1.30x`, `+10%` crit
- `chargeMaxHoldTicks60: 150`

### `eloise.charged_sword_strike_auto_aim`

- Same charged structure as above, with `homing` targeting.
- Costs slightly higher for lock-on reliability:
  - stamina `600`
  - top tier damage `1.325x` (vs `1.30x` on aimed variant)

## Defensive Sword Ability

### `eloise.sword_riposte_guard`

- `holdMaintain` contract (`holdMode: holdToMaintain`)
- Max active hold window authored as `180` ticks
- Stamina drain while held: `233` per second
- No direct damage payload (`baseDamage: 0`, `SelfHitDelivery`)
- Uses `AnimKey.parry`

## Design Constraints

1. All abilities in this file require `WeaponType.oneHandedSword`.
2. Payload/procs are sourced from primary weapon path (`AbilityPayloadSource.primaryWeapon`).
3. Charged variants are interruption-sensitive by design (`damageTaken` included).
