# Eloise Primary: Sword

Abilities requiring `WeaponType.oneHandedSword` and equipable in `AbilitySlot.primary`.

## Ability Matrix

| Ability ID | Lifecycle | Targeting | W/A/R | Cost | Cooldown | Payload Source |
|---|---|---|---|---|---:|---|
| `eloise.bloodletter_slash` | `holdRelease` | `directional` | `8/6/8` | stamina `500` | `18` | `primaryWeapon` |
| `eloise.bloodletter_cleave` | `holdRelease` | `aimedCharge` | `10/6/10` | stamina `550` | `24` | `primaryWeapon` |
| `eloise.seeker_slash` | `tap` | `homing` | `8/6/8` | stamina `550` | `24` | `primaryWeapon` |

## Ability Notes

### Sword Slash (`eloise.bloodletter_slash`)

- base damage: `1500`
- no innate on-hit status proc
- melee delivery: active-pose blade capsules, about 37 world units forward reach, `oncePerTarget`
- front/back variants and aimed pose rotation share animation and collision timing

### `eloise.seeker_slash`

Homing variant of slash with reliability tax:

- damage `1400` (vs `1500`)
- stamina `550` (vs `500`)
- cooldown `24` (vs `18`)
- no innate on-hit status proc

### `eloise.bloodletter_cleave`

- base damage: `1600`
- on-hit proc: guaranteed `StatusProfileId.meleeBleed` only at full charge
- tap/partial charge have no innate bleed; weapon procs still apply normally
- forced interrupt causes: `stun`, `death`, `damageTaken`
- charge tiers (`minHoldTicks60`):
  - `0`: damage `0.90x`
  - `8`: damage `1.08x`, crit `+5%`
  - `20`: damage `1.30x`, crit `+10%`, guaranteed bleed (3 DPS for 5s before modifiers)
- max hold: `150` ticks

## Constraints

- All abilities in this file require `WeaponType.oneHandedSword`.
- Payload/procs resolve from `AbilityPayloadSource.primaryWeapon`.

Charge-tier innate procs replace the base ability list before merging item procs.
With Waspfang, uncharged hits retain its 20% bleed chance; full-charge Cleave
uses its own guaranteed bleed without duplicating the same hook/profile.
