# Eloise Primary: Sword

Abilities requiring `WeaponType.oneHandedSword` and equipable in `AbilitySlot.primary`.

## Ability Matrix

| Ability ID | Lifecycle | Targeting | W/A/R | Cost | Cooldown | Payload Source |
|---|---|---|---|---|---:|---|
| `eloise.bloodletter_slash` | `holdRelease` | `directional` | `8/6/8` | stamina `500` | `18` | `primaryWeapon` |
| `eloise.bloodletter_cleave` | `holdRelease` | `aimedCharge` | `10/6/10` | stamina `550` | `24` | `primaryWeapon` |
| `eloise.seeker_slash` | `tap` | `homing` | `8/6/8` | stamina `550` | `24` | `primaryWeapon` |

## Ability Notes

### `eloise.bloodletter_slash`

- base damage: `1500`
- no innate on-hit status proc
- melee delivery: `32x32`, offset `(12, 0)`, `oncePerTarget`

### `eloise.seeker_slash`

Homing variant of slash with reliability tax:

- damage `1400` (vs `1500`)
- stamina `550` (vs `500`)
- cooldown `24` (vs `18`)
- no innate on-hit status proc

### `eloise.bloodletter_cleave`

- base damage: `1600`
- on-hit proc: guaranteed `StatusProfileId.meleeBleed`
- forced interrupt causes: `stun`, `death`, `damageTaken`
- charge tiers (`minHoldTicks60`):
  - `0`: damage `0.90x`
  - `8`: damage `1.08x`, crit `+5%`
  - `16`: damage `1.30x`, crit `+10%`
- max hold: `150` ticks

## Constraints

- All abilities in this file require `WeaponType.oneHandedSword`.
- Payload/procs resolve from `AbilityPayloadSource.primaryWeapon`.
