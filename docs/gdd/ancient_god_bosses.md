# Ancient God bosses

Voidborn Goddess, Shoggoth and Voidcaller are implemented as reusable mandatory
arena bosses. Their kits use the supplied sprite sheets and demonstration video
as visual references; the damage, timing and AI below are gameplay defaults.
The [video](https://www.youtube.com/watch?v=0rPsM1DjEuc) demonstrates all three
kits; its animation showcase does not specify damage or combat balance.
They are available in Chunk Creator's **Mandatory boss arena → Boss** selector.
Forest places one easy arena for each boss immediately after Bringer of Death:
**Bringer → Voidborn Goddess → Shoggoth → Voidcaller → enchanted forest**.
Each new room reuses the existing 600-by-270 Forest arena terrain and scenery,
with its own chunk, arena identity and mandatory assembly group. Each victory
restores 20% of maximum health, mana and stamina, capped at the resource maximum.
These encounters first deployed in gameplay compatibility `2026.10.9`; see the
[release evidence](../verification/ancient-god-bosses-2026-10-07.md#production-release).
The corrections below are deployed in `2026.10.10`: aligned native beam pieces,
Goddess's corner hand barrage and distinct damage windows per swing; see the
[October 8 evidence](../verification/boss-combat-corrections-2026-10-08.md#production-release).

All three share Bringer of Death's **1.5x sprite scale**, 120 HP, no passive
health regeneration and Stun immunity. Prepared compatibility `2026.10.11` also
gives them Silence immunity and halves the strength of other harmful statuses,
keeping duration unchanged, as described in [Bringer's defenses](bringer_of_death.md).
Beneficial effects retain their full strength, and summoned minions and tentacles
retain ordinary status susceptibility. Source frame dimensions differ, so their
visible silhouettes differ in size. Terrain and attack shapes fit the scaled
art. They walk under normal gravity and collision, without jumping or swimming
upward. The framed arena, entrance protection, player controls, health bar,
death presentation, exit and victory blessing reuse the
[existing boss rules](bringer_of_death.md).

## Voidborn Goddess

| Action | Default behavior |
| --- | --- |
| Claw combo | Four visible swipes in a committed direction, each able to deal 7 physical damage per target; 0.4-second windup |
| Void orb | A straight projectile aimed at the captured target center; 6 dark damage; 0.7-second cast |
| Hand barrage | Moves to an upper arena corner away from the captured target, then sends six hands across the floor at half-second intervals after a 1-second cast. Each hand warns for ten effect frames and slaps once for 7 dark damage. She hovers through the final hand, then returns to her prior position; six seconds between commits |
| Vanish and return | After at least three actions, relocates to a legal point 150 world units from the captured target, preferring the opposite side; at least eight seconds between teleport commits |

She alternates orbs and eruptions, using claws on every third sequence position
when the player is within 85 units and near her height. In prepared source
compatibility `2026.10.11`, an eligible claw turn takes priority over a due
teleport; she can teleport on the next action after the claw cooldown. This
prevents the six-second barrage cadence from repeatedly skipping her melee
attack. Out of claw range or height, a due teleport keeps priority. She approaches
toward a 65-unit stand-off at 0.8 of shared ground speed. The barrage sweeps from her corner
to the other end, with fixed marks rather than tracking later player movement.
Move between marks or jump to avoid the slaps. Her corner is 64 units inside the
arena and 150 units above the level floor; she remains vulnerable while hovering.
If both upper corners are obstructed she casts from her current safe position.
Return placement is checked again; if blocked, gravity lands her normally.

## Shoggoth

| Action | Default behavior |
| --- | --- |
| Tentacle sweep | Two visible sweeps, each able to deal 7 physical damage per target; 0.4-second windup |
| Spinning charge | 0.5-second warning followed by a 0.6-second charge at 180 world units/second in the committed direction; two arc passes, each able to deal 6 physical damage per target |
| Void orb | A straight projectile at the captured target center; 6 dark damage; 0.7-second cast |
| Invoke minion | Summons one damageable, mobile minion; maximum three living minions per owner |
| Vanish and return | Uses the same placement policy as Goddess, with a six-frame disappearance and nine-frame return |

Its sequence favors a summon every fourth action, a spin within 150 units, a
sweep within 85, and an orb at distance. Teleports take priority when due.
Walking uses the same 65-unit stand-off and speed as Goddess. The spin obeys
walls, arena boundaries, gravity and terrain rather than moving through them.
Its crescent sweeps are dangerous on either side as they rotate, with damage
following the visible arc, with one hit per target per arc pass.

Minions have 10 HP and bite for 2 physical damage. They live for up to 12 seconds,
can be killed through ordinary combat, and grant zero kill points.

## Voidcaller

| Action | Default behavior |
| --- | --- |
| Vertical beam | A portal opens above a captured ground/platform mark, then fires three bright pulses, each able to deal 7 dark damage; 0.8-second cast and five harmless effect frames |
| Diagonal beam | The alternate Cast 1 version creates the same three-pulse threat, sloping from the offset overhead portal into the ground mark; 7 dark damage per pulse |
| Fiery claw | Cast 2 launches a straight claw projectile at the captured target center; 6 fire damage; 0.6-second cast |
| Summon tentacle | Casts for 1 second to plant one damageable tentacle; maximum two living tentacles per owner |

The sequence cycles vertical beam, diagonal beam, claw, summon. At the summon
limit it substitutes a claw. Voidcaller keeps a 180-unit stand-off and walks at
0.45 of shared ground speed. It does not teleport. The pack lacks a dedicated
spawn strip, so its entrance uses the alternate 17-frame ritual.

Tentacles stay at their planted X, have 16 HP and lash for 3 physical damage.
They live for up to 12 seconds, can be killed normally, and grant zero kill
points. Summon admission requires supported, clear ground inside the arena,
with space from the player and other summons. A blocked summon creates nothing.

## Timing and rewards

Listed cast/windup times use 60 Hz authoring ticks. Core scales and quantizes
them at 30, 60 and 90 Hz. Effect frames use quantized 80 ms steps, shared by art
and damage. Targets and attack directions are committed once; attacks never
home onto subsequent player movement. Utility actions deal no direct damage.
Consecutive poses of one swing share its hit ledger. In prepared source
compatibility `2026.10.11`, claws, sweeps, spin passes and beam pulses are explicit
combos: after a damaging hit, later strikes from that same boss and activation
can hit through its post-hit protection. Other attackers and separate attacks
from that boss remain blocked for 0.25 seconds after each accepted hit. Overlapping
bright frames never create damage every simulation tick. This uses the
[shared combat rule](combat/combat_system_design.md#resolution-stage-damagesystem)
and is not a boss-only exception; the source change is not yet deployed.
When both teleport destinations are invalid, the boss reappears at its original
safe position and the cooldown still applies.

Each required boss awards 1000 points once. Arena survival time is excluded
from score, and summon kills cannot farm points. Summons and their attacks are
removed when their owner dies, the arena releases or the run ends. A simultaneous
player defeat takes precedence. See [technical ownership](../tdd/ancient_god_bosses.md).
