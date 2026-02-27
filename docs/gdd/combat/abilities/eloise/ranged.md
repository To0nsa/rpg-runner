# Eloise Projectile Slot: Ranged

Eloise projectile-slot abilities (`AbilitySlot.projectile`).

All abilities here:

- use `payloadSource: AbilityPayloadSource.projectile`
- require `WeaponType.throwingWeapon` or `WeaponType.projectileSpell`
- use `AnimKey.ranged`

## Ability Matrix

| Ability ID | Lifecycle | Targeting | W/A/R | Cost | Cooldown | Base Damage |
|---|---|---|---|---|---:|---:|
| `eloise.snap_shot` | `tap` | `homing` | `10/2/12` | mana `800` (throwing override: stamina `800`) | `40` | `1300` |
| `eloise.quick_shot` | `holdRelease` | `aimed` | `10/2/12` | mana `600` (throwing override: stamina `600`) | `14` | `900` |
| `eloise.skewer_shot` | `holdRelease` | `aimedLine` | `10/2/12` | mana `1000` (throwing override: stamina `1000`) | `32` | `1800` |
| `eloise.overcharge_shot` | `holdRelease` | `aimedCharge` | `10/2/12` | mana `1300` (throwing override: stamina `1300`) | `40` | `2300` |

## Ability Notes

### `eloise.snap_shot`

- deterministic lock-on (`TargetingModel.homing`)
- highest reliability, explicit cooldown/resource tax

### `eloise.quick_shot`

- fastest cadence in lane (`cooldown 14`)
- aimed single-target projectile

### `eloise.skewer_shot`

- line-aim variant for aligned targets
- authored delivery: `pierce: true`, `chainCount: 3`

### `eloise.overcharge_shot`

- forced interrupt causes: `stun`, `death`, `damageTaken`
- charge tiers (`minHoldTicks60`):
  - `0`: damage `0.82x`, speed `0.90x`
  - `5`: damage `1.00x`, speed `1.05x`, crit `+5%`
  - `10`: damage `1.225x`, speed `1.20x`, crit `+10%`, `pierce: true`, `maxPierceHits: 2`
- max hold: `150` ticks

## Payload Resolution

The projectile-slot source is resolved at commit:

- if `projectileSlotSpellId` is valid for the equipped spellbook, that spell projectile is used
- otherwise the equipped throwing weapon projectile is used

This keeps one ability structure reusable across spell and throwing builds.
