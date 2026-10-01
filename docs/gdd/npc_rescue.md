# Allied rescue NPCs

Allied NPCs fight the required enemies in their encounter. During that fight,
their bodies stay inside the owning chunk. After every required enemy is defeated,
living survivors guard the containing Flow section occurrence. They can cross
its chunk seams and fight nearby enemies, while their complete bodies stay within
the section's horizontal boundaries. Automatic levels and standalone Chunk Play
use the original chunk instead. Detached arrows and spears keep their normal
range. The trigger starts the fight and does not define movement boundaries.
Repeated placements create independent groups and section territories.

Ground melee enemies stop and face their opponent once they reach fighting
range on reachable ground, holding position between attacks instead of running
through the NPC. They chase again when the opponent moves out of range. Hashash
can still change sides with its evade-and-ambush teleport.

| NPC | Health | Attack | Damage | Attack range |
| --- | ---: | --- | ---: | ---: |
| Warrior | 20 | Sword slash | 4 | 52 |
| Huntress | 13 | Thrown spear | 4.5 | 260 |
| Huntress 2 | 9 | Bow | 3 | 320 |

Health and damage above are display units; distances are world pixels. These
are current catalog values. NPC attacks use stamina, cooldowns and the same
damage/status rules as other combat actors. NPC damage is allied damage and
does not count as player participation. NPC death does not add an enemy kill.

A rescue requires every required enemy to be health-defeated, at least one
living NPC, and positive applied player damage to an encounter enemy. The final
hit need not belong to the player. Player-owned projectiles and damage over time
retain participation credit after their owner or original attack disappears.
Unassisted clears also produce section guards, but award no rescue points.

All NPCs dying fails the encounter. Unresolved encounters expire once the
camera's left edge reaches the owning chunk's end plus that chunk's full width.
Ending a run also abandons unresolved encounters without points. Surviving
enemies return to normal player targeting with their current combat state.

Section guards remain vulnerable and use their existing health, resources,
statuses and cooldowns. They pursue eligible enemies within 800 world pixels,
retain an eligible opponent, and hold position when none can be reached. Ordinary
enemies entering their territory may target a guard or the player; active
encounters retain their authored targeting policies. Guards do not follow the
player or earn additional rescue credit. Later guard deaths leave the already
awarded rescue count and points unchanged.

Failed or abandoned groups' survivors become protected: they stop fighting and
cannot be targeted or damaged. Run end also stops remaining guards. Normal terrain
streaming and actor cleanup continue; an original encounter record can retire
while its guard remains in later loaded terrain, without retaining a full section
indefinitely. Live NPCs show a green allied health bar with a cross; protected
survivors show a check. Ghost NPCs use ghost visuals without live health or reward
feedback. All three have movement, attack, hit and complete death animations.

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
