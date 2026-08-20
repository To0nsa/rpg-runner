# Enemy Terrain Traversal

## Status

Grojib and Hashash slope traversal, Hashash terrain-safe ambush placement,
Unoco flying-terrain traversal, Derf terrain-safe obstacle-top placement, and
shared terrain-safe enemy/item spawning are implemented on the polygon-terrain
authority used by repository-backed Field and Forest runs. Replay validation
constructs the same Core path. The currently authored production ground is
flat; these rules also govern later slope/platform content without another
authority switch.

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

## Unoco Flying Terrain Rules

Unoco remains a flying enemy and never joins the grounded surface graph. Its
existing random target height stays between `60` and `180 px`, but that height
is now measured above the highest local solid terrain beneath its capsule
footprint. This lets it follow hills and raised terrain without snapping to
them. When it crosses a pit, it keeps the last valid terrain reference so its
flight does not suddenly dive. The level's explicit flight plane is used only
when no local solid reference has been observed yet.

Its complete capsule is blocked by solid floors, walls, slopes, ceilings,
undersides, and concave boundaries. It ignores one-way platforms completely
and can never become grounded, step, or snap. Contact immediately slides away
the entering part of its velocity instead of bouncing or teleporting it.

If direct hover/combat movement remains blocked, Unoco tries a small fixed set
of deterministic directions around the contact and briefly commits to the best
one. The choice favors movement toward its existing combat/hover target, then
clear travel, with a stable final tie-break. It uses no extra randomness and
cannot phase or relocate through terrain. After the short detour it returns to
ordinary hover/combat steering; its attack ranges, projectile/melee timing,
aiming policy, attack origins, cooldowns, and facing behavior are unchanged.

## Derf Placement Rules

Derf remains stationary after spawning; slope support does not turn it into a
walking or falling enemy. An obstacle-top marker may place Derf only when its
intended solid support:

- is no steeper than `15°`, inclusive
- provides at least `32 px` of total horizontal span
- has room for Derf's complete upright capsule

If a marker lies too close to an edge, it moves to the nearest valid point on
that same support. It never moves to another ledge, a lower surface, the
highest unrelated terrain, or ordinary ground. An absent, one-way, steep,
narrow, or obstructed intended perch skips the spawn.

The support does not rotate Derf, its art, aim, or cast origin. It continues to
face the player, target the predicted player center, cast from its existing
world-space origin, and die instantly when killed.

No current production Chunk requests a Derf encounter. Forest retains only its
flat early Chunk with no enemy markers. The obstacle-top rule remains the
authoring contract for a future Chunk that reintroduces a Derf perch.

## Enemy Spawn Rules

Terrain-backed enemy markers keep their authored meaning instead of choosing
whichever nearby surface happens to fit:

- a Grojib or ordinary Hashash marker needs a complete capsule-width foothold,
  room for the whole capsule, and a slope within that enemy's limit
- an ordinary marker near an edge may move only to the nearest valid point on
  that same support
- deferred Hashash edge spawning stays at its exact requested X; invalid
  support skips the spawn
- Unoco must fit at its exact intended flying point; solid blockage skips the
  spawn, while one-way terrain is ignored
- Derf keeps the stricter obstacle-top rules above

Missing or invalid intended terrain never relocates an enemy to a lower or
unrelated ledge. Skipping one marker does not reroll or reorder later markers.

## Collectible And Restoration Placement

Coins and restoration gems may rest on solid terrain or the top of a one-way
platform that Éloïse can traverse, including slopes through `60°`. A candidate
needs at least `20 px` of horizontal support and enough room for the complete
upright pickup, including its existing visual/collision margin and vertical
gap above the surface.

Pickups remain upright; they do not rotate to match a ramp. Consequently, a
very steep but walkable ramp can reject a candidate if the uphill side of the
pickup would clip the terrain. The game then consumes that normal placement
attempt. It does not hide the pickup on a lower overlapping surface or grant an
extra random attempt beyond the existing limit; exhausted placement creates no
pickup.

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
