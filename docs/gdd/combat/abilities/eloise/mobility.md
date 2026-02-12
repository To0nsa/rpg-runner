# Eloise Mobility

## Scope

This document defines Eloise mobility kit abilities:

- `AbilitySlot.mobility` lane (dash/roll variants)
- `AbilitySlot.jump` fixed action

Core units:

- Damage/cost: fixed-point (`100 = 1.0`)
- Percent/buffs: basis points (`100 = 1%`)
- Ticks authored at 60 Hz

## Ability Matrix (Current Core)

| Ability ID | Slot | Lifecycle | Targeting | Timing (W/A/R) | Stamina | Cooldown |
|---|---|---|---|---|---:|---:|
| `eloise.jump` | `jump` | `tap` | `none` | `0 / 0 / 0` | `200` | `0` |
| `eloise.dash` | `mobility` | `tap` | `directional` | `0 / 12 / 0` | `200` | `120` |
| `eloise.charged_aim_dash` | `mobility` | `holdRelease` | `aimedCharge` | `0 / 12 / 0` | `225` | `120` |
| `eloise.charged_auto_dash` | `mobility` | `holdRelease` | `homing` | `0 / 12 / 0` | `240` | `120` |
| `eloise.hold_auto_dash` | `mobility` | `holdMaintain` | `homing` | `0 / 60 / 0` | `240` + hold drain `120/s` | `120` |
| `eloise.roll` | `mobility` | `tap` | `directional` | `3 / 24 / 3` | `200` | `120` |

## Mobility Design Notes

### Directional mobility

- `dash` and `roll` commit on press.
- `roll` has longer action duration (`30` total ticks) than `dash` (`12`).

### Charged mobility

Both charged dash variants are tiered by hold duration (`minHoldTicks60`):

- `charged_aim_dash` speed scales: `0.90x`, `1.10x`, `1.28x`
- `charged_auto_dash` speed scales: `0.88x`, `1.06x`, `1.23x`
- `chargeMaxHoldTicks60: 150` for both

### Maintain mobility

`hold_auto_dash`:

- uses `holdMaintain` + `holdToMaintain`
- max maintain window authored as `activeTicks: 60`
- drains stamina at `120` per second while held
- still uses tier profile for speed tuning

### Jump

- Jump remains an authored ability (`eloise.jump`) in fixed jump slot.
- Execution remains movement-system driven after commit (buffer/coyote rules).

## Contract Notes

1. Mobility abilities use `payloadSource: none` and `SelfHitDelivery`.
2. Mobility lane supports full lifecycle combinations now: `tap`, `holdRelease`, `holdMaintain`.
3. Homing mobility variants are non-directional at input level by design.
