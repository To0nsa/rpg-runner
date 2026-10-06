# Bringer of Death

Bringer of Death is Forest's first mandatory boss, fought in
`forest_boss_easy_001` between the easy rocky-grove and enchanted-forest sections.
This feature is prepared on `feature/forest-boss-arena`; production release is
separate.

The 600-by-270 arena fills one gameplay viewport. Its flat floor and raised
one-way platform give the player room to reposition. Once the entire arena is
framed and the player is inside its combat bounds, the player stops while Bringer
reconstitutes from purple smoke. Both actors are protected during this entrance.
After the entrance, ordinary controls return and purple barriers contain the
fight. A named boss health bar shows introduction, combat and defeat feedback.

Bringer has 120 HP and no passive health regeneration. He pursues on the ground
with the existing navigation capabilities. This first fight has one phase and
two attacks:

| Attack | Readable threat | Response window |
| --- | --- | --- |
| Scythe Sweep | 400 ms windup, committed facing and a broad blade arc; 8 base damage | Reposition before the sweep, then punish its recovery |
| Death Pillar | Cast at the player's captured position, then six harmless ring frames before the pillar; 7 base dark damage | Leave the marked position; the spell also threatens the raised platform |

Those timings use 60 Hz authoring ticks and are scaled to the run's tick rate.
The entrance lasts the complete ten-frame spawn strip, about 1.17 seconds at
60 Hz. Ordinary light hits cannot stun-lock the boss. Incoming damage and other
status rules continue normally; the boss has no special damage resistance.

Outside enemies and NPCs cannot interfere during the arena. Player health, mana,
stamina, equipment and cooldowns carry into and out of the fight. Regeneration
and the run clock continue; this is an encounter hold, not a whole-game pause.
The exit stays closed until Bringer is defeated and his death presentation
finishes. Running then continues into the next Forest section.

Defeating Bringer awards 1000 points once. Arena time earns no survival-time
points, so delaying the fight cannot farm score. Distance remains furthest
horizontal progress, and backtracking in the arena adds no repeated distance.
The complete elapsed duration still appears in run results. Dying simultaneously
with Bringer grants no boss defeat credit. Quitting or losing a required boss
through invalid cleanup cannot count as victory.

The Chunk Creator owner form controls encounter placement and bounds. Enemy
stats, attack geometry, animation and rewards remain catalog-authored. Detailed
ownership and replay rules are in [boss arena contracts](../tdd/boss_arenas.md).
