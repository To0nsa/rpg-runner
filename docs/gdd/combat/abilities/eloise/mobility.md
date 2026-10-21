# Eloise Mobility

This document tracks Eloise mobility/jump abilities from `eloise_ability_defs.dart`.

## Ability Matrix

| Ability ID | Slot | Lifecycle | Targeting | W/A/R | Cost | Cooldown |
|---|---|---|---|---|---|---:|
| `eloise.jump` | `jump` | `tap` | `none` | `0/0/0` | stamina `200` | `0` |
| `eloise.double_jump` | `jump` | `tap` | `none` | `0/0/0` | first jump stamina `200`, air jump mana `200` | `0` |
| `eloise.dash` | `mobility` | `tap` | `directional` | `0/12/0` | stamina `200` | `120` |
| `eloise.double_dash` | `mobility` | `tap` | `directional` | `0/8/0` per burst | stamina `200` per burst | `120`, from first burst |
| `eloise.roll` | `mobility` | `tap` | `directional` | `0/10/0` | stamina `200` | `120` |

## Current Behavior Notes

- Mobility input preempts combat: on dash/jump press, pending combat intents, buffered input, and active non-mobility ability are cleared.
- `dash` uses authored `mobilitySpeedX: 550`.
- `dash` covers 110 nominal units at 60 Hz, 20% less than its original
  137.5-unit range. Its speed is unchanged; its duration is shorter.
- `roll` uses authored `mobilitySpeedX: 400` and applies `StatusProfileId.stunOnHit` on mobility contact (`oncePerTarget`).
- Roll vulnerability and contact stun follow the low visible body pose; terrain support keeps its stable capsule. This does not grant roll invulnerability.
- Jump execution is handled in `JumpSystem` with coyote + jump-buffer rules.

## Double Jump Contract

`eloise.double_jump` adds one air jump:

- `maxAirJumps = 1`
- ground jump speed: `450`
- air jump speed: `450`
- ground jump cost from default cost
- air jump cost from `airJumpCost`

## Double Dash Contract

`eloise.double_dash` is a separate mobility-slot choice available through the
normal ability store/ownership flow. It is not a starter grant.

- Each burst uses speed `515.625` for eight authored ticks: 68.75 nominal units
  at 60 Hz. Two bursts total the original Dash's 137.5 units.
- Tap once, then tap again within 0.5 seconds after the first burst finishes.
  Early taps do not queue or interrupt a burst. The second tap can change direction.
- Each accepted burst costs 2 stamina. A failed resource check preserves the
  remaining window; it neither spends resources nor restarts cooldown.
- The two-second cooldown starts with the first burst. The second does not
  refresh it, and a third burst is unavailable until the next cooldown cycle.
- Unused follow-ups expire. Stun, swimming, changing the equipped mobility
  ability, and run end cancel them. Landing does not replenish them.
- The dash button shows `+1` while the follow-up is available; insufficient
  stamina still disables activation. After use/expiry the shared cooldown returns.
- These are active-burst travel budgets before speed modifiers, terrain
  quantization, collisions, or interruption. Movement between bursts and after
  them is ordinary locomotion; changing direction changes net displacement.
  Dash grants no additional invulnerability.

## Payload Notes

Mobility/jump abilities do not use weapon/spell payload sourcing for hit delivery.
