# NPC encounter data contracts

Core owns immutable `EncounterDefinition` records, stable `NpcId` identities and
`AiTargetPolicy` preferences. They are independent of player input and enemy
score IDs. Contracts and shared AI targeting are the delivered slices of the
[rescue implementation plan](../building/npc_rescue_encounters.md); runtime
encounters, NPC actors, authoring and rescue awards are not integrated yet.

An encounter owns separate NPC and enemy placement lists. Member IDs are unique
across both lists and local to the encounter. Coordinates use world units, with
X relative to the owning chunk. Vertical placement reuses `SpawnPlacementMode`.
The entry rectangle uses an inclusive swept-center intersection; it catches
crossing between samples, a stationary point inside, and boundary contact.

Constructors reject malformed identity, duplicate members, non-finite geometry,
capacity violations and invalid point values without relying on assertions.
Incomplete roles are valid drafts. `validateForChunk` requires a complete roster
by default and checks horizontal containment; full capsule/terrain admission is
the responsibility of the runtime placement boundary.

`EncounterLimits` is shared by source and runtime consumers: four encounters per
chunk, four NPCs and eight enemies per encounter, sixteen live encounters and
192 live participants. Points per NPC range from 0 to 100,000, with 250 as the
initial shared default. Missing override differs from explicit zero or an
explicit value equal to the default. Capacity is a first-release admission
budget, not a promise that every maximum-density layout meets performance goals.

Awards use checked addition against 9,007,199,254,740,991, the shared exact integer
ceiling for JavaScript score consumers. Even a deliberately loose six-hour,
240-Hz estimate that replaces all sixteen live encounters every tick yields
33,177,600,000,000 rescue points, below that ceiling. Checked accumulation remains
mandatory for other tick rates/durations and for combining other score rows;
overflow must fail before mutation, never wrap or silently clamp.

The ordinary-combat regression uses an explicit marker roster on the generated
`field_flat` terrain, with no encounter definitions. Its pre-refactor trace covers
785 ticks and Grojib, Hashash and Unoco behavior, including motion, attack
animation, projectiles, resources and terminal state. Derf placement/casting is
covered separately; it does not appear in this trace. The contract probe is also
compiled and executed to verify admission errors survive AOT assertion removal.

## Shared AI target selection

`AiTargetStore` holds an explicit bounded opponent roster, policy, perception
range and selected identity for each participating AI actor. Absence retains
ordinary player pursuit; an explicit null selection means no target. Roster
membership is supplied by the owner, never inferred from faction or proximity.
The actual player cannot be treated as an NPC roster member.

`AiTargetSystem` runs once before AI in `GameCore`. It filters living actors and
allied factions, then ranks policy tier, squared center distance and entity ID.
An eligible target is retained within its tier. A preferred NPC can preempt the
player; death, range loss or confirmed negative navigation evidence invalidates
retention. The default perception distance for roster members is 800 world units;
normal player fallback retains existing engagement/range rules. No RNG is used.

Ground navigation, engagement, locomotion and melee; flying locomotion and
contact melee; enemy casts; and Hashash teleport commits all read `combatTarget`.
They may read its updated position after movement but cannot select another
identity during the tick. Already committed aim, execute ticks, costs, cooldowns
and active ability phases remain owned by their existing execution systems.

Terrain prediction is cached per target for the current tick and per traversal
profile for the current published bundle. `SurfaceNavStateStore.targetEntity`
owns target-support cache identity, including transitions back to ordinary
pursuit. Target changes invalidate graph/support paths while existing airborne
scalar jump commitments retain their normal landing behavior. Confirmed no-path
evidence requires grounded resolved supports with movement/navigation unlocked;
water-entry fallback is considered first. It expires on support/profile changes,
target movement or terrain publication, without ranking candidates by all-pairs
path searches. Blocked evidence is local to each attacker.

`EcsWorld.destroyEntity` removes inbound roster, selection and navigation-target
references before recycling entity IDs. Removing an encounter's target component
restores ordinary player pursuit without resetting the actor's combat state.
The shared target seam is exercised with fixture allies; production encounter
membership and NPC lifecycle are the next implementation milestone.
