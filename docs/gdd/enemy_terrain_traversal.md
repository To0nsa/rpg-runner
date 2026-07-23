# Enemy Terrain Traversal

## Status

Grojib and Hashash slope traversal, Hashash terrain-safe ambush placement, and
deferred Hashash slope spawning are implemented in the isolated Phase 3
polygon-terrain harness. Repository-backed production levels and replay
validation still use the legacy flat/rectangle authority until the later
terrain cutover phases.

## Grounded Enemy Rules

Grojib and Hashash remain upright grounded enemies. Slopes change the path they
follow, not their combat size, facing rules, attack origins, or melee spacing.

| Enemy | Maximum walkable slope | Step up | Ground snap | Speed on slopes |
| --- | ---: | ---: | ---: | --- |
| Grojib | `45°` inclusive | `4 px` | `4 px` | constant distance along terrain |
| Hashash | `60°` inclusive | `4 px` | `4 px` | constant distance along terrain |

Enemy speed does not use Éloïse's uphill slowdown or downhill boost. A
Grojib or Hashash configured for `120` world units per second requests `120`
units per second along a flat floor, uphill slope, or downhill slope. The
horizontal screen-space component naturally becomes smaller on a steep slope
because part of that distance is vertical.

The following existing modifiers still apply before terrain direction is
chosen:

- engagement approach and recovery speed
- arrival slowing near a chase or stand-off target
- status-effect movement multipliers
- acceleration, deceleration, stopping, and reversal
- navigation, movement, and stun locks

Chase targets, deterministic chase offsets, and melee stand-off distances stay
in world-X space. This keeps combat spacing recognizable while the actual
motion follows the eligible support tangent.

## Terrain Interaction

Ordinary pursuit can follow connected flat/slope seams, peaks, and valleys. It
can automatically step onto or snap down to terrain within the accepted
4-pixel helper range. A 5-pixel discontinuity is not silently accepted.

Grojib and Hashash:

- collide with solid terrain from the sides
- ignore ceilings as they did before slope work
- pass upward through one-way platforms and may land/traverse on the top side
- do not receive a terrain bounce or launch impulse
- remain grounded only when the final capsule solve finds eligible support

An accepted jump always launches world-up. Its existing horizontal graph-edge
commit and recovery rules remain in force while airborne; ground snap cannot
pull the enemy back onto the takeoff slope. A drop likewise keeps its committed
horizontal direction until landing or deterministic fallback.

## Presentation And Death

Walk/run playback advances from distance actually traveled along eligible
support. Step, snap, and overlap-recovery corrections do not make the animation
run faster, and exact seams do not create a one-frame airborne animation.
Sprites stay upright rather than rotating with the terrain.

Enemies using ground-impact death continue falling after a lethal airborne hit.
Their death animation begins when the final terrain solve reports eligible
support, or when the existing deterministic maximum-fall timeout expires.
Culling rules are unchanged.

## Unchanged Combat Behavior

Slope locomotion does not retune attacks. Grojib and Hashash retain their
existing engage/strike/recover timing, face-player behavior during melee,
world-space melee and cast origins, hitboxes, and cooldowns. Hashash teleport
uses the same predicted-player lead and authored timing, with one terrain-safe
failure rule:

- try `36 px` right and `36 px` above the predicted player
- if the complete upright capsule is blocked, try the mirrored left/above point
- the ambush may remain airborne; it does not need a support beneath it
- queue the strike only when one point is clear
- if neither point is clear, stay at the last safe position, perform no strike,
  and wait the normal cooldown before another teleport evade

This fallback is fixed and consumes no RNG. Deferred Hashash edge spawning also
requires a full capsule-width foothold and complete clearance at its requested
X. Invalid terrain skips that spawn instead of moving Hashash elsewhere or
rolling a replacement.
