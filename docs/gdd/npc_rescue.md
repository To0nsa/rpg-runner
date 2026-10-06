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
| Warrior | 25 | Sword slash | 4 | 52 |
| Huntress | 25 | Thrown spear | 4.5 | 260 |
| Huntress | 25 | Opening stab + bleed | 3 + 3/sec for 5 sec | 52 |
| Huntress | 25 | Follow-up slash | 4 | 52 |
| Huntress 2 | 25 | Bow | 3 | 320 |

Health and damage above are display units; distances are world pixels. These
are current catalog values. NPC attacks use stamina, cooldowns and the same
damage/status rules as other combat actors. NPC damage is allied damage and
does not count as player participation. NPC death does not add an enemy kill.

Huntress throws spears at 420 world pixels/second along a low gravity arc, using
half of the level's gravity. Her aim leads moving enemies and compensates for
the drop. Spears end on a target or terrain impact; a six-second limit cleans
up throws into deep gaps. Huntress 2 arrows retain their straight flight.

Huntress throws at distant opponents and uses melee within 52 horizontal world
pixels when their vertical origins differ by at most 27 pixels. Her first
successful stab against each enemy applies the existing physical bleed; later
close attacks against that enemy use slash. A successful stab means positive
health damage: misses, interrupted attacks, blocks that prevent all damage and
invulnerability leave the opener available. Bleed immunity does not prevent a
damaging stab from counting. Bleed uses the shared physical DoT channel and its
normal refresh rules, rather than stacking a separate effect per Huntress.

Each Huntress remembers her own stabbed enemies through target switches, bleed
expiry and the transition to section guarding. Returning to range resumes spear
throws; closing again resumes slash for a previously stabbed enemy.
An opener aimed at a new enemy cannot re-hit a previously stabbed enemy caught
in the same attack area. She finishes the committed attack before choosing
another, subject to normal interrupts.
All three attacks share a cooldown: throws take 1.3 seconds between starts,
melee 0.8 seconds. Stab and slash each cost 4 stamina; throw costs 5.

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
indefinitely. Live NPCs show a green allied health bar with a cross; cleared
section guards also show a check above the bar. Protected survivors show a check
without a bar. Ghost NPCs use ghost visuals without live health or reward
feedback. All three have movement, attack, hit and complete death animations.

Core resolves a default award of 250 points per survivor, with a per-encounter
override including zero. Chunk Creator exposes this value and targeting policy
on each rescue group; incomplete groups can be saved while being authored.
The end screen lists credited survivors and their combined rescue points in a
separate row, including zero-point rescues. Field's `field_default_normal_002` chunk
places all three allies against a Grojib and a Hashash on a clear, flat route.
Its trigger starts at X 160; the group inherits the 250-point default, for up to
750 points. It enters the normal pool and obeys the first-three-chunks enemy
suppression. Repeated placements remain independent. Three seeded runs and a
30 Hz replay clear it with ordinary player movement/attacks and the normal camera.
See the
[technical contract](../tdd/npc_encounter_contracts.md) for ownership and ordering.
