# Allied rescue NPCs

Allied NPCs fight the required enemies in their encounter. Their bodies stay
inside the chunk where the encounter was placed; detached arrows and spears
keep their normal range. The trigger starts the fight and does not define their
movement boundary. Repeated placements of a chunk create independent groups.

Ground melee enemies stop and face their opponent once they reach fighting
range on reachable ground, holding position between attacks instead of running
through the NPC. They chase again when the opponent moves out of range. Hashash
can still change sides with its evade-and-ambush teleport.

| NPC | Health | Attack | Damage | Attack range |
| --- | ---: | --- | ---: | ---: |
| Warrior | 32 | Sword slash | 4 | 52 |
| Huntress | 25 | Thrown spear | 4.5 | 260 |
| Huntress 2 | 21 | Bow | 3 | 320 |

Health and damage above are display units; distances are world pixels. These
are current catalog values. NPC attacks use stamina, cooldowns and the same
damage/status rules as other combat actors. NPC damage is allied damage and
does not count as player participation. NPC death does not add an enemy kill.

A rescue requires every required enemy to be health-defeated, at least one
living NPC, and positive applied player damage to an encounter enemy. The final
hit need not belong to the player. Player-owned projectiles and damage over time
retain participation credit after their owner or original attack disappears.
Unassisted survivors become safe but award no rescue points.

All NPCs dying fails the encounter. Unresolved encounters expire once the
camera's left edge reaches the owning chunk's end plus that chunk's full width.
Ending a run also abandons unresolved encounters without points. Surviving
enemies return to normal player targeting with their current combat state.

Protected survivors stop fighting, cannot be targeted or damaged, and remain
inside their chunk until ordinary cleanup. Live NPCs show a green allied health
bar with a cross; protected survivors show a check. Ghost NPCs use ghost visuals
without live health or reward feedback. All three have movement, attack, hit
and complete death animations.

Core resolves a default award of 250 points per survivor, with a per-encounter
override including zero. Chunk Creator exposes this value and targeting policy
on each rescue group; incomplete groups can be saved while being authored.
The end screen lists credited survivors and their combined rescue points in a
separate row, including zero-point rescues. Field's `field_roadside_rescue` chunk
places all three allies against a Grojib and a Hashash on a clear, flat route.
Its trigger starts at X 160; the group inherits the 250-point default, for up to
750 points. It enters the normal pool and obeys the first-three-chunks enemy
suppression. Repeated placements remain independent. Three seeded runs and a
30 Hz replay clear it with ordinary player movement/attacks and the normal camera.
See the
[technical contract](../tdd/npc_encounter_contracts.md) for ownership and ordering.
