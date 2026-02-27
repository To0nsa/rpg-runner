# Eloise Abilities

Canonical snapshot of currently shipped Eloise ability defs (`lib/core/abilities/catalog/eloise_ability_defs.dart`).

Core units:

- fixed-point values: `100 = 1.0`
- basis points: `100 = 1%`
- authored ticks: 60 Hz

## Slot Inventory

| Slot | Ability IDs |
|---|---|
| `primary` | `eloise.bloodletter_slash`, `eloise.bloodletter_cleave`, `eloise.seeker_slash`, `eloise.riposte_guard` |
| `secondary` | `eloise.concussive_bash`, `eloise.concussive_breaker`, `eloise.seeker_bash`, `eloise.aegis_riposte`, `eloise.shield_block` |
| `projectile` | `eloise.snap_shot`, `eloise.quick_shot`, `eloise.skewer_shot`, `eloise.overcharge_shot` |
| `mobility` | `eloise.dash`, `eloise.roll` |
| `jump` | `eloise.jump`, `eloise.double_jump` |
| `spell` | `eloise.arcane_haste`, `eloise.arcane_ward`, `eloise.vital_surge`, `eloise.mana_infusion`, `eloise.second_wind` |

## Full Ability Table

| Ability ID | Slot | Lifecycle | Targeting | W/A/R | Cost | Cooldown |
|---|---|---|---|---|---|---:|
| `eloise.bloodletter_slash` | `primary` | `holdRelease` | `directional` | `8/6/8` | stamina `500` | `18` |
| `eloise.bloodletter_cleave` | `primary` | `holdRelease` | `aimedCharge` | `10/6/10` | stamina `550` | `24` |
| `eloise.seeker_slash` | `primary` | `tap` | `homing` | `8/6/8` | stamina `550` | `24` |
| `eloise.riposte_guard` | `primary` | `holdMaintain` | `none` | `2/180/2` | hold drain `700/s` | `30` |
| `eloise.concussive_bash` | `secondary` | `tap` | `directional` | `8/6/8` | stamina `500` | `18` |
| `eloise.concussive_breaker` | `secondary` | `holdRelease` | `aimedCharge` | `10/6/10` | stamina `550` | `24` |
| `eloise.seeker_bash` | `secondary` | `tap` | `homing` | `8/6/8` | stamina `550` | `24` |
| `eloise.aegis_riposte` | `secondary` | `holdMaintain` | `none` | `2/180/2` | hold drain `700/s` | `30` |
| `eloise.shield_block` | `secondary` | `holdMaintain` | `none` | `2/180/2` | hold drain `700/s` | `30` |
| `eloise.snap_shot` | `projectile` | `tap` | `homing` | `10/2/12` | mana `800` (throwing: stamina `800`) | `40` |
| `eloise.quick_shot` | `projectile` | `holdRelease` | `aimed` | `10/2/12` | mana `600` (throwing: stamina `600`) | `14` |
| `eloise.skewer_shot` | `projectile` | `holdRelease` | `aimedLine` | `10/2/12` | mana `1000` (throwing: stamina `1000`) | `32` |
| `eloise.overcharge_shot` | `projectile` | `holdRelease` | `aimedCharge` | `10/2/12` | mana `1300` (throwing: stamina `1300`) | `40` |
| `eloise.arcane_haste` | `spell` | `tap` | `none` | `0/0/10` | mana `1000` | `300` |
| `eloise.arcane_ward` | `spell` | `tap` | `none` | `0/0/10` | mana `1200` | `420` |
| `eloise.vital_surge` | `spell` | `tap` | `none` | `0/0/10` | mana `1500` | `420` |
| `eloise.mana_infusion` | `spell` | `tap` | `none` | `0/0/10` | stamina `1500` | `420` |
| `eloise.second_wind` | `spell` | `tap` | `none` | `0/0/10` | mana `1500` | `420` |
| `eloise.jump` | `jump` | `tap` | `none` | `0/0/0` | stamina `200` | `0` |
| `eloise.double_jump` | `jump` | `tap` | `none` | `0/0/0` | first jump stamina `200`, air jump mana `200` | `0` |
| `eloise.dash` | `mobility` | `tap` | `directional` | `0/15/0` | stamina `200` | `120` |
| `eloise.roll` | `mobility` | `tap` | `directional` | `0/10/0` | stamina `200` | `120` |

## Runtime Notes

1. Charged variants (`bloodletter_cleave`, `concussive_breaker`, `overcharge_shot`) opt into forced interrupt on `damageTaken`.
2. Projectile-slot abilities resolve payload from projectile source selection at commit time.
3. `riposte_guard` and `aegis_riposte` both mitigate `50%` incoming hit damage while active and grant riposte on guarded hit.
4. `shield_block` mitigates `100%` incoming hit damage while active and does not grant riposte.
5. `arcane_ward` applies `StatusProfileId.arcaneWard` (`40%` direct-hit mitigation, DoT canceled while active).
6. `roll` has mobility contact status (`stunOnHit`) via `MobilityImpactDef`.
