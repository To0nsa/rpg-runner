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
| `eloise.double_jump` | `jump` | `tap` | `none` | `0 / 0 / 0` | `200` | `0` |
| `eloise.dash` | `mobility` | `tap` | `directional` | `0 / 12 / 0` | `200` | `120` |
| `eloise.roll` | `mobility` | `tap` | `directional` | `3 / 24 / 3` | `200` | `120` |

## Mobility Design Notes

### Directional mobility

- `dash` and `roll` commit on press.
- `roll` has longer action duration (`30` total ticks) than `dash` (`12`).

### Jump

- Jump remains an authored ability (`eloise.jump`) in fixed jump slot.
- Execution remains system-driven after commit (buffer/coyote rules).
- `eloise.jump` stays single-jump only (ground/coyote jump).
- `eloise.double_jump` adds one air jump (`maxAirJumps = 1`).
- For `eloise.double_jump`:
  - first jump consumes stamina (`200`)
  - second jump consumes mana (`200`)
  - both taps use fixed vertical impulse and produce a two-arc path based on second-tap timing.

## Contract Notes

1. Mobility abilities use `payloadSource: none` and `SelfHitDelivery`.
2. Mobility lane currently uses `tap` lifecycle only.
