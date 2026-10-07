# Bringer of Death

Bringer of Death is Forest's first mandatory boss, fought in
`forest_boss_easy_001` between the easy rocky-grove and enchanted-forest sections.
The original encounter is deployed as gameplay `2026.10.8` with `score-v4`; see the
[production evidence](../verification/forest_boss_arena.md#production-release-2026108).
The tuning below is implemented in source for `2026.10.9` and awaits a coordinated
client, Functions and replay-worker release.

The 600-by-270 arena fills one gameplay viewport. Its flat floor and raised
one-way platform give the player room to reposition. Once the entire arena is
framed and the player is inside its combat bounds, the player stops while Bringer
reconstitutes from purple smoke. Both actors are protected during this entrance.
After the entrance, ordinary controls return and purple barriers contain the
fight. A named boss health bar shows introduction, combat and defeat feedback.

During the smoke entrance, three black edge pulses accompany three moderate
camera shakes and device haptic pulses where supported. The center stays clear
so the apparition remains visible. This reusable boss-entrance feedback follows
the entrance clock and does not extend the control hold.

Bringer and Death Pillar are 1.5x their original width and height, with matching
body and attack collision shapes. Bringer has 120 HP and no passive health
regeneration. His ground pursuit is 20% faster than the original encounter
(1.2 of shared ground speed on direct routes, with 0.72 fallback approach speed).
He pursues on the ground and keeps the shared melee stand-off distance so the
enlarged blade stays over its target between attacks. He cannot jump, swim upward
or climb the raised platform;
Death Pillar reaches a player who stays there. Walking, gravity and terrain
support still apply. This first fight has one phase and
two attacks:

| Attack | Readable threat | Response window |
| --- | --- | --- |
| Scythe Sweep | About 267 ms windup, committed facing and a 1.5x larger blade arc; 8 base damage | Reposition before the sweep, then punish its recovery |
| Death Pillar | 400 ms cast at the player's captured position, then six harmless ring frames at 40 ms per source frame; 7 base dark damage | Leave the larger marked position promptly; the spell also threatens the raised platform |

Those timings use 60 Hz authoring ticks and are scaled to the run's tick rate.
Scythe windup, active window, recovery and cooldown are all 1.5x faster.
The pillar's cast cycle is 1.5x faster and its warning/effect strip is 2x faster
before tick quantization. Commit-to-first-damage takes 600/600/667 ms at
30/60/90 Hz, at least 1.5x faster than the original at each rate. The same
effect clock drives its art and damage. Both attacks retain one hit per target.
Both attacks push a damaged, surviving player horizontally away from the attack's
caster origin. The shared effect targets 112 world units over about 0.28 seconds
(9 ticks at 30 Hz, 17 at 60 Hz, 26 at 90 Hz). The platform spans 96 units, so the
shove exceeds its half-width and clears it from the tested center and end positions.
Movement input and dash cannot cancel the shove; ordinary jumping and attacks
remain available. Walls and arena boundaries stop it. Fully prevented damage does
not push; Death Pillar retains its existing rule of bypassing ordinary guard.
Other bosses and attacks can opt into the same
[damage effect](../tdd/combat_knockback.md) with their own distance and duration.

The entrance lasts the complete ten-frame spawn strip, about 1.17 seconds at
60 Hz. Ordinary light hits cannot stun-lock the boss. Incoming damage and other
status rules continue normally; the boss has no special damage resistance.

Outside enemies and NPCs cannot interfere during the arena. Player health, mana,
stamina, equipment and cooldowns carry into and out of the fight. Regeneration
and the run clock continue; this is an encounter hold, not a whole-game pause.
The exit stays closed until Bringer is defeated and his death presentation
finishes. The Dames de la forêt then bless the surviving player, instantly
restoring 20% of maximum health, mana and stamina in easy chunks, capped at each
maximum. Other chunk difficulties retain the 60% restoration. For example, in
the easy Forest arena, 20 HP out of 100 becomes 40 HP; 90 becomes 100.
The calculation uses the player's current equipment-adjusted maxima.

The golden Holy VFX 02 animation rises around the player's feet and follows
movement. “Bénédiction des Dames de la forêt” identifies the reward on the HUD.
The effect lasts sixteen frames, about 0.8 seconds at 60 Hz, without another
control hold: running resumes into the next Forest section while it plays.
Pause freezes the animation and message. This is a one-time victory restore,
separate from the shrine's persistent regeneration bonus; existing bonuses
remain active. A dead player receives no blessing.

Defeating Bringer awards 1000 points once. Arena time earns no survival-time
points, so delaying the fight cannot farm score. Distance remains furthest
horizontal progress, and backtracking in the arena adds no repeated distance.
The complete elapsed duration still appears in run results. Dying simultaneously
with Bringer grants no boss defeat credit. Quitting or losing a required boss
through invalid cleanup cannot count as victory.

The Chunk Creator owner form controls encounter placement and bounds. Enemy
stats, attack geometry, animation and rewards remain catalog-authored. Detailed
ownership and replay rules are in [boss arena contracts](../tdd/boss_arenas.md).
