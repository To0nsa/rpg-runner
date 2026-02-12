# Eloise Abilities

## Purpose

Canonical overview of Eloise authored abilities as currently implemented in
Core (`lib/core/abilities/ability_catalog.dart`).

Core units:

- Damage/resource values use fixed-point (`100 = 1.0`)
- Percent values use basis points (`100 = 1%`)
- Timings are authored in 60 Hz ticks

## Related Docs

- System contract: `docs/gdd/combat/abilities/abilities_system_design.md`
- Primary lane: `docs/gdd/combat/abilities/eloise/primary_sword.md`
- Secondary lane: `docs/gdd/combat/abilities/eloise/secondary_shield.md`
- Projectile lane: `docs/gdd/combat/abilities/eloise/ranged.md`
- Mobility lane: `docs/gdd/combat/abilities/eloise/mobility.md`
- Bonus self-spells: `docs/gdd/combat/abilities/eloise/spells.md`

## Slot Inventory

| Slot | Ability IDs |
|---|---|
| `primary` | `eloise.sword_strike`, `eloise.charged_sword_strike`, `eloise.charged_sword_strike_auto_aim`, `eloise.sword_strike_auto_aim`, `eloise.sword_parry` |
| `secondary` | `eloise.shield_bash`, `eloise.charged_shield_bash`, `eloise.shield_bash_auto_aim`, `eloise.shield_block` |
| `projectile` | `eloise.auto_aim_shot`, `eloise.quick_shot`, `eloise.piercing_shot`, `eloise.charged_shot` |
| `mobility` | `eloise.dash`, `eloise.charged_aim_dash`, `eloise.charged_auto_dash`, `eloise.hold_auto_dash`, `eloise.roll` |
| `jump` | `eloise.jump` |
| `bonus` | `eloise.arcane_haste`, `eloise.restore_health`, `eloise.restore_mana`, `eloise.restore_stamina` |

## Full Ability Table (Current Core)

| Ability ID | Slot | Lifecycle | Targeting | Timing (W/A/R) | Stamina | Mana | Cooldown | Base Damage |
|---|---|---|---|---|---:|---:|---:|---:|
| `eloise.sword_strike` | `primary` | `holdRelease` | `directional` | `8/6/8` | `500` | `0` | `18` | `1500` |
| `eloise.charged_sword_strike` | `primary` | `holdRelease` | `aimedCharge` | `10/6/10` | `550` | `0` | `24` | `1600` |
| `eloise.charged_sword_strike_auto_aim` | `primary` | `holdRelease` | `homing` | `10/6/10` | `600` | `0` | `24` | `1550` |
| `eloise.sword_strike_auto_aim` | `primary` | `tap` | `homing` | `8/6/8` | `550` | `0` | `24` | `1400` |
| `eloise.sword_parry` | `primary` | `holdMaintain` | `none` | `2/180/2` | `0` | `0` | `30` | `0` |
| `eloise.shield_bash` | `secondary` | `tap` | `directional` | `8/6/8` | `500` | `0` | `18` | `1500` |
| `eloise.charged_shield_bash` | `secondary` | `holdRelease` | `aimedCharge` | `10/6/10` | `550` | `0` | `24` | `1600` |
| `eloise.shield_bash_auto_aim` | `secondary` | `tap` | `homing` | `8/6/8` | `550` | `0` | `24` | `1400` |
| `eloise.shield_block` | `secondary` | `holdMaintain` | `none` | `2/180/2` | `0` | `0` | `30` | `0` |
| `eloise.auto_aim_shot` | `projectile` | `tap` | `homing` | `10/2/12` | `0` | `800` | `40` | `1300` |
| `eloise.quick_shot` | `projectile` | `holdRelease` | `aimed` | `10/2/12` | `0` | `600` | `14` | `900` |
| `eloise.piercing_shot` | `projectile` | `holdRelease` | `aimedLine` | `10/2/12` | `0` | `1000` | `32` | `1800` |
| `eloise.charged_shot` | `projectile` | `holdRelease` | `aimedCharge` | `10/2/12` | `0` | `1300` | `40` | `2300` |
| `eloise.arcane_haste` | `bonus` | `tap` | `none` | `0/0/10` | `0` | `1000` | `300` | `0` |
| `eloise.restore_health` | `bonus` | `tap` | `none` | `0/0/10` | `0` | `1500` | `420` | `0` |
| `eloise.restore_mana` | `bonus` | `tap` | `none` | `0/0/10` | `1500` | `0` | `420` | `0` |
| `eloise.restore_stamina` | `bonus` | `tap` | `none` | `0/0/10` | `0` | `1500` | `420` | `0` |
| `eloise.jump` | `jump` | `tap` | `none` | `0/0/0` | `200` | `0` | `0` | `0` |
| `eloise.dash` | `mobility` | `tap` | `directional` | `0/12/0` | `200` | `0` | `120` | `0` |
| `eloise.charged_aim_dash` | `mobility` | `holdRelease` | `aimedCharge` | `0/12/0` | `225` | `0` | `120` | `0` |
| `eloise.charged_auto_dash` | `mobility` | `holdRelease` | `homing` | `0/12/0` | `240` | `0` | `120` | `0` |
| `eloise.hold_auto_dash` | `mobility` | `holdMaintain` | `homing` | `0/60/0` | `240` | `0` | `120` | `0` |
| `eloise.roll` | `mobility` | `tap` | `directional` | `3/24/3` | `200` | `0` | `120` | `0` |

## Key Runtime Notes

1. Charged sword/shield/projectile abilities opt into forced interruption on
   `damageTaken` in addition to `stun` and `death`.
2. Projectile lane payload comes from equipped projectile-item path at commit.
3. `holdMaintain` abilities use stamina drain:
   - `eloise.sword_parry`: `233` per second
   - `eloise.shield_block`: `700` per second
   - `eloise.hold_auto_dash`: `120` per second
4. Bonus slot is currently self-spell utility only.

