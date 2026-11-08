# Eloise Abilities

Canonical snapshot of current authored Eloise ability defs (`packages/runner_core/lib/abilities/catalog/eloise_ability_defs.dart`).

Core units:

- fixed-point values: `100 = 1.0`
- basis points: `100 = 1%`
- authored ticks: 60 Hz

## Slot Inventory

| Slot | Ability IDs |
|---|---|
| `primary` | `eloise.bloodletter_slash`, `eloise.bloodletter_cleave`, `eloise.seeker_slash` |
| `secondary` | `eloise.aegis_riposte`, `eloise.shield_block` |
| `projectile` | `eloise.snap_shot`, `eloise.quick_shot`, `eloise.skewer_shot`, `eloise.overcharge_shot` |
| `mobility` | `eloise.dash`, `eloise.double_dash`, `eloise.roll` |
| `jump` | `eloise.jump`, `eloise.double_jump` |
| `spell` | `eloise.arcane_haste`, `eloise.focus`, `eloise.arcane_ward`, `eloise.cleanse`, `eloise.vital_surge`, `eloise.mana_infusion`, `eloise.second_wind` |

## Full Ability Table

| Ability ID | Slot | Lifecycle | Targeting | W/A/R | Cost | Cooldown |
|---|---|---|---|---|---|---:|
| `eloise.bloodletter_slash` | `primary` | `holdRelease` | `directional` | `8/6/8` | stamina `500` | `18` |
| `eloise.bloodletter_cleave` | `primary` | `holdRelease` | `aimedCharge` | `10/6/10` | stamina `550` | `24` |
| `eloise.seeker_slash` | `primary` | `tap` | `homing` | `8/6/8` | stamina `550` | `24` |
| `eloise.aegis_riposte` | `secondary` | `holdMaintain` | `none` | `2/180/2` | hold drain `700/s` | `30` |
| `eloise.shield_block` | `secondary` | `holdMaintain` | `none` | `2/180/2` | hold drain `700/s` | `30` |
| `eloise.snap_shot` | `projectile` | `tap` | `homing` | `10/2/12` | mana `800` | `40` |
| `eloise.quick_shot` | `projectile` | `holdRelease` | `aimed` | `6/2/6` | mana `600` | `14` |
| `eloise.skewer_shot` | `projectile` | `holdRelease` | `aimedLine` | `10/2/12` | mana `1000` | `32` |
| `eloise.overcharge_shot` | `projectile` | `holdRelease` | `aimedCharge` | `10/2/12` | mana `1300` | `40` |
| `eloise.arcane_haste` | `spell` | `tap` | `none` | `0/0/10` | mana `1200` | `480` |
| `eloise.focus` | `spell` | `tap` | `none` | `0/0/10` | mana `1200` | `480` |
| `eloise.arcane_ward` | `spell` | `tap` | `none` | `0/0/10` | mana `1400` | `540` |
| `eloise.cleanse` | `spell` | `tap` | `none` | `0/0/10` | mana `1200` | `480` |
| `eloise.vital_surge` | `spell` | `tap` | `none` | `0/0/10` | mana `2000` | `720` |
| `eloise.mana_infusion` | `spell` | `tap` | `none` | `0/0/10` | stamina `1500` | `420` |
| `eloise.second_wind` | `spell` | `tap` | `none` | `0/0/10` | mana `1800` | `600` |
| `eloise.jump` | `jump` | `tap` | `none` | `0/0/0` | stamina `200` | `0` |
| `eloise.double_jump` | `jump` | `tap` | `none` | `0/0/0` | first jump stamina `200`, air jump mana `200` | `0` |
| `eloise.dash` | `mobility` | `tap` | `directional` | `0/12/0` | stamina `200` | `120` |
| `eloise.double_dash` | `mobility` | `tap` | `directional` | `0/8/0` per burst | stamina `200` per burst | `120` from first burst |
| `eloise.roll` | `mobility` | `tap` | `directional` | `0/10/0` | stamina `200` | `120` |

## Runtime Notes

1. Charged variants (`bloodletter_cleave`, `overcharge_shot`) opt into forced interrupt on `damageTaken`.
2. For sword primaries, guaranteed `StatusProfileId.meleeBleed` is on fully charged `bloodletter_cleave` only; `bloodletter_slash` and `seeker_slash` have no innate on-hit status proc.
3. Projectile-slot abilities resolve payload from projectile source selection at commit time.
4. `aegis_riposte` mitigates `50%` incoming hit damage while active and grants riposte on guarded hit.
5. `shield_block` mitigates `100%` incoming hit damage while active and does not grant riposte.
6. `focus` applies `StatusProfileId.focus` (`+25%` power, `+15%` crit chance for `4.0s`).
7. `arcane_ward` applies `StatusProfileId.arcaneWard` (`40%` direct-hit mitigation, DoT canceled for its three-second duration).
8. `cleanse` applies `PurgeProfileId.cleanse`, removes active debuffs including stun, and can commit while stunned.
9. `roll` has mobility contact status (`stunOnHit`) via `MobilityImpactDef`.

## Ability illustrations

All 21 abilities have distinct transparent 64×64 pixel-art icons in
`assets/images/icons/skills-icons/eloise/`. Single and double movement actions
use one or two impulses; Concussive Roll includes its contact-stun impact.
Riposte combines guard and counterattack, while Block shows incoming strikes
stopped by a shield. Only Cleave includes an innate bleed cue. Projectile
symbols describe targeting and charge independently of the selected payload.
See [ability-art verification](../../../../verification/ability-icon-art-2026-11-08.md).

Balance pass: [local evidence and decisions](../../../../verification/eloise-ability-balance-2026-11-08.md).
`eloise.bloodletter_slash` displays as **Sword Slash**; its ownership ID is stable.
