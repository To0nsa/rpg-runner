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

Goddess uses **1.0x sprite scale** and **240 HP**; Shoggoth and Voidcaller have
120 HP and share Bringer of Death's **1.5x scale**. All three have no passive
health regeneration and have Stun immunity. Prepared compatibility `2026.10.11` also
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
| Claw combo | Four visible swipes that follow and turn toward the player between hits, each able to deal 8.4 physical damage per target; 0.4-second windup |
| Reactive dodge | Evades one eligible direct player attack every 4–6 attacks, with a newly randomized interval after each dodge. Vanishes for about 0.13 seconds, teleports 35 units from the player, then counters with her four-swipe claw combo |
| Void orb | Flies straight toward the target position captured when casting starts; 7.2 dark damage; 0.45-second cast and 480 world units/second flight. The orb follows its aim line, and its explosion is centered over the struck body, expanding across the player silhouette. |
| Hand barrage | Casts once at each 75%, 50% and 25% HP threshold. Teleports to an upper arena corner away from the captured target, then sends six hands across fixed floor marks at 0.35-second intervals after a 1-second preparation. Each hand warns for about 0.6 seconds (ten effect frames) and slaps once for 12 dark damage. She animates and remains invincible through the final hand, then casts one orb and teleports to medium range; at least six seconds between commits |

Released orbs and hands remain active and dangerous after her death until they
hit or finish their normal lifetime. Dying cancels casts she has not released.

Prepared compatibility `2026.10.11` makes her a mostly stationary caster:

- Within 45 horizontal units and 50 vertical units, she chooses a claw combo
  70% of the time and a retreat teleport 30% of the time when teleport is ready.
  Otherwise she uses claws. A blocked retreat also falls back to claws.
- During the combo's windup and attack, she follows on directly walkable ground
  at half normal speed, stopping about 35 units away. She can turn during windup,
  harmless gaps and at each new swipe; a live swipe keeps its direction. This
  applies to dodge counters too. Recovery stops pursuit and leaves an opening.
- Just outside claw range (45–70 units), she may approach on directly walkable
  ground, at half normal speed, for at most 25 units or 0.5 seconds. Her endpoint
  stays fixed even if the player retreats; she then attacks instead of chasing.
- At medium range she stands and casts a seeded sequence of one or two orbs
  before considering relocation. If teleport is still cooling down, she keeps
  casting. Beyond 240 units she prefers to teleport nearer when ready.
- Voluntary teleports select a supported destination 140, 180 or 220 units from
  the player, on either legal side, at least 64 units from her current position.
  A purple destination mark accompanies her 0.3-second disappearance. The mark
  stays fixed; reappearance takes 0.2 seconds followed by 0.3 seconds of recovery.
- Voluntary teleports have a randomized 4–6-second minimum interval, including
  an initial delay. A successful reactive dodge restarts that timer. Normal
  ability recovery and cooldown must also finish, preserving the combo opening.
  The scripted exit from Slapping Hands can bypass the voluntary timer.

Slapping Hands is reserved for reaching or falling below **180, 120 and 60 HP**
at her 240 HP maximum. Each threshold grants one barrage, prioritized over normal
choices after the current action, scripted exit and cooldown finish. Large damage
can queue multiple crossed thresholds; healing does not reset them. Failed cast
admission retains the pending barrage, while an interrupted accepted cast still
consumes it. She cannot earn more than three barrages per life.

The barrage sweeps from her corner to the other end across six fixed floor marks,
without tracking later player movement. Marks over holes without support are
skipped. Move between marks or jump to avoid the slaps. Her corner is 64 units
inside the arena and 150 units above the level floor. Six preparation frames lead
into all thirty casting frames through the final hand's full effect. During each
slap, the entire visible palm and fingers can hit the player; warning frames,
detached particles and impact streaks remain harmless.

When the final hand finishes she becomes vulnerable, holds her casting position
for one normal orb, then teleports to medium range with the same destination cue
and recovery as a voluntary teleport. If both upper corners are obstructed she
casts from her current safe position. If the exit has no legal landing, or is
interrupted, hovering ends and ordinary gravity resumes. She gains no additional
invulnerability from the exit spell or voluntary teleports.

The dodge counts melee, projectile and direct spell attacks that would hit her;
a multi-hit combo counts once, and evading it also evades its remaining strikes.
Misses, damage over time, NPC attacks and protected hits do not count. She cannot
dodge during the hand barrage, its scripted exit, a voluntary teleport, while
stunned, or during another vanish. These intervals do not count new attacks.
At 45 units or less of horizontal separation she crosses to the opposite side. Beyond that range either side has an equal chance when both are legal;
if only one side is legal, she uses it. The distant side is chosen when the dodge
starts and stays fixed through the vanish. The landing follows the player's
position when she reappears and must have clear supported ground inside the
arena. If no legal landing exists when attacked, that hit lands and the dodge
stays ready without rerolling the interval. The counter uses
the normal claw windup and damage and can be escaped. Dodging evades the selected
attack; it does not make her invincible against other attacks.

## Shoggoth

| Action | Default behavior |
| --- | --- |
| Tentacle sweep | Two visible sweeps, each able to deal 7 physical damage per target; 0.4-second windup |
| Spinning charge | 0.5-second warning followed by a 0.6-second charge at 180 world units/second in the committed direction; two arc passes, each able to deal 6 physical damage per target |
| Void orb | A straight projectile at the captured target center; 6 dark damage; 0.7-second cast |
| Invoke minion | Summons one damageable, mobile minion; maximum three living minions per owner |
| Vanish and return | After three actions, relocates to a legal point 150 units from the captured target, preferring the opposite side; at least eight seconds between commits, with a six-frame disappearance and nine-frame return |

Its sequence favors a summon every fourth action, a spin within 150 units, a
sweep within 85, and an orb at distance. Teleports take priority when due.
Walking uses a 65-unit stand-off and 0.8 of shared ground speed. The spin obeys
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
and damage. Spells capture their targets once and never home onto later player
movement. Goddess claws can retarget between distinct swipes while each live
swipe retains its direction and hit ledger. Utility actions deal no direct damage.
Consecutive poses of one swing share its hit ledger. In prepared source
compatibility `2026.10.11`, claws, sweeps, spin passes and beam pulses are explicit
combos: after a damaging hit, later strikes from that same boss and activation
can hit through its post-hit protection. Other attackers and separate attacks
from that boss remain blocked for 0.25 seconds after each accepted hit. Overlapping
bright frames never create damage every simulation tick. This uses the
[shared combat rule](combat/combat_system_design.md#resolution-stage-damagesystem)
and is not a boss-only exception; the source change is not yet deployed.
When both Shoggoth teleport destinations are invalid, it reappears at its original
safe position and the cooldown still applies.

Each required boss awards 1000 points once. Arena survival time is excluded
from score, and summon kills cannot farm points. Summons and their attacks are
removed when their owner dies, the arena releases or the run ends. A simultaneous
player defeat takes precedence. See [technical ownership](../tdd/ancient_god_bosses.md).
