# Eloise Secondary: Shield

Abilities requiring `WeaponType.shield` and equipable in `AbilitySlot.secondary`.

## Ability Matrix

| Ability ID | Lifecycle | Targeting | W/A/R | Cost | Cooldown | Payload Source |
|---|---|---|---|---|---:|---|
| `eloise.concussive_bash` | `tap` | `directional` | `8/6/8` | stamina `500` | `18` | `secondaryWeapon` |
| `eloise.concussive_breaker` | `holdRelease` | `aimedCharge` | `10/6/10` | stamina `550` | `24` | `secondaryWeapon` |
| `eloise.seeker_bash` | `tap` | `homing` | `8/6/8` | stamina `550` | `24` | `secondaryWeapon` |
| `eloise.aegis_riposte` | `holdMaintain` | `none` | `2/180/2` | hold drain `700/s` | `30` | `secondaryWeapon` |
| `eloise.shield_block` | `holdMaintain` | `none` | `2/180/2` | hold drain `700/s` | `30` | `secondaryWeapon` |

## Offensive Shield Abilities

### `eloise.concussive_bash`

- base damage: `1500`
- on-hit proc: guaranteed `StatusProfileId.stunOnHit`
- melee delivery: `32x32`, offset `(12, 0)`, `oncePerTarget`

### `eloise.seeker_bash`

Homing variant with reliability tax:

- damage `1400`
- stamina `550`
- cooldown `24`

### `eloise.concussive_breaker`

- base damage: `1600`
- forced interrupt causes: `stun`, `death`, `damageTaken`
- charge tiers (`minHoldTicks60`):
  - `0`: damage `0.90x`
  - `8`: damage `1.08x`, crit `+5%`
  - `16`: damage `1.30x`, crit `+10%`
- max hold: `150` ticks

## Defensive Shield Abilities

### `eloise.aegis_riposte`

- hold-maintain guard (`holdToMaintain`)
- max active window: `180` ticks
- hold drain: `700` stamina/sec
- hit mitigation: `5000 bp` (`50%`)
- grants one riposte bonus on first guarded hit per activation

### `eloise.shield_block`

- hold-maintain guard (`holdToMaintain`)
- max active window: `180` ticks
- hold drain: `700` stamina/sec
- hit mitigation: `10000 bp` (`100%`)
- no riposte bonus

## Constraints

- All abilities in this file require `WeaponType.shield`.
- Payload/procs resolve from `AbilityPayloadSource.secondaryWeapon`.
