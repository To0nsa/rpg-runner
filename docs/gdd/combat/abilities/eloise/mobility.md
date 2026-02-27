# Eloise Mobility

This document tracks Eloise mobility/jump abilities from `eloise_ability_defs.dart`.

## Ability Matrix

| Ability ID | Slot | Lifecycle | Targeting | W/A/R | Cost | Cooldown |
|---|---|---|---|---|---|---:|
| `eloise.jump` | `jump` | `tap` | `none` | `0/0/0` | stamina `200` | `0` |
| `eloise.double_jump` | `jump` | `tap` | `none` | `0/0/0` | first jump stamina `200`, air jump mana `200` | `0` |
| `eloise.dash` | `mobility` | `tap` | `directional` | `0/15/0` | stamina `200` | `120` |
| `eloise.roll` | `mobility` | `tap` | `directional` | `0/10/0` | stamina `200` | `120` |

## Current Behavior Notes

- Mobility input preempts combat: on dash/jump press, pending combat intents, buffered input, and active non-mobility ability are cleared.
- `dash` uses authored `mobilitySpeedX: 550`.
- `roll` uses authored `mobilitySpeedX: 400` and applies `StatusProfileId.stunOnHit` on mobility contact (`oncePerTarget`).
- Jump execution is handled in `JumpSystem` with coyote + jump-buffer rules.

## Double Jump Contract

`eloise.double_jump` adds one air jump:

- `maxAirJumps = 1`
- ground jump speed: `450`
- air jump speed: `450`
- ground jump cost from default cost
- air jump cost from `airJumpCost`

## Payload Notes

Mobility/jump abilities do not use weapon/spell payload sourcing for hit delivery.
