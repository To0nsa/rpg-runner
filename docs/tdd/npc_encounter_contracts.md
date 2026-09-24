# NPC encounter data contracts

Core owns immutable `EncounterDefinition` records, stable `NpcId` identities and
`AiTargetPolicy` preferences. They are independent of player input and enemy
score IDs. Core contracts, shared AI targeting and the warrior encounter
lifecycle, shared authored compilation and editor source preservation are delivered
slices of the [rescue implementation plan](../building/npc_rescue_encounters.md).
The encounter editing UI and score presentation
remain in progress. Gameplay currently runs through typed and captured-source
fixtures; production rescue content is not yet authored.

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

## Occurrence lifecycle

`EncounterSystem` owns a bounded run-local state table keyed by streamed chunk
index and authored encounter ID. `EncounterOccurrence` freezes sorted participant
publication order and the actual chunk bounds. A dormant group creates no actors;
the activation API tests the inclusive sweep between player-center samples and
requires a complete, typed spawn result. A rejected/partial roster fails without
an award. Opening suppression skips the entire group.

Membership is separate from actor type. The ECS captures removal evidence before
component teardown and ID recycling. Health defeat counts toward the objective;
unexpected disappearance fails it. Fatal world loss counts as an NPC death but
invalidates a required enemy rather than treating a terrain cull as a combat win.

Resolution priority is run termination, camera expiry, invalid membership, all
NPCs dead, then required-enemy completion. Completion rescues living NPCs only
after recorded player HP damage; otherwise survivors become safe without points.
Terminal outcomes are immutable. Enemies lose only their encounter target policy,
retaining resources, statuses and committed attacks. Awards accumulate once from
each occurrence's resolved points override, including explicit zero.

The coordinator checks expiry before streaming and after the camera update,
records participation during damage, and resolves after fatal enemy culling but
before death cleanup. Unresolved member enemies bypass ordinary behind-camera
culling; falling out of the world still removes them. Run exit finalizes groups
before statistics or player-death freeze. The controller's terrain-retention and
retirement APIs enforce expiry before cleanup and retain only a monotonic retired
chunk index. Streamed chunk snapshots carry typed encounter definitions. Each new
index registers once after terrain publication, opening suppression skips the
complete roster, and the streamer retains unresolved owning chunks. Retirement
releases membership metadata before removed terrain is observed. Terminal
outcomes drain into `EncounterResolvedEvent`; consumers cannot issue awards.

`EncounterSpawnAdapter` resolves every member against the current terrain before
allocating any entity. It shares actor placement with ordinary enemies and checks
NPC full-body containment for both facings. Hashash uses its authored placement
and normal intro/teleport state, bypassing the ambient edge scheduler. Required
Grojib, Hashash, Unoco and Derf placements retain their catalog-specific support
rules. One rejected placement fails the complete group. NPC camera/fatal culling
shares the enemy cleanup pass and records the member's removal before teardown.

Core activation runs after world publication and before motion preparation,
using the preceding player collider-center sweep. A real warrior/player rescue,
repeated chunk instances, suppression, atomic failure and run exit are covered by
streamed Core fixtures and captured authored Play.

## Authored source and readiness

Chunk-v2 accepts an optional `encounters` array. Absence means empty; explicit
null fails decoding. Empty arrays are omitted on editor export so existing chunk
source does not acquire an empty field. No schema migration or marker conversion
is implicit. [The source example](../examples/rescue_encounter_chunk.json) shows
one complete warrior/Hashash group on ordinary ground.

Each encounter requires `id`, `name`, `trigger`, `targetPolicy`, `npcs`, and
`enemies`. The optional `pointsPerNpc` override remains absent in default mode;
zero and an explicitly entered 250 retain their meaning. Members require `id`,
the typed `npcId` or `enemyId`, whole-pixel `x`, `facing`, and `placement`. Only
enemy members may override `targetPolicy`. IDs are sorted independently in each
collection, with uniqueness across the two member roles. Trigger coordinates are
whole pixels and its complete rectangle must fit the chunk. Unknown fields,
null overrides, invalid enums, fractional values, bounds and capacity errors
fail strict shared decoding. Export canonicalizes copies without mutating author
order or discarding explicit overrides.

`resolveEncounterPlacement` owns the pure complete-roster preflight. Runtime,
shared content materialization and typed Play admission call it against their
actual terrain publication. The authored boundary supplies the owning Level's
ground height, rather than inventing fallback spawn support. Grounded members
use their catalog capsule and terrain policy; flying placement uses the same
hover reference as the default runtime tuning. One invalid member prevents a
runtime product. Readiness diagnostics carry an encounter `elementId` and a
participant placement `fieldKey`, separate from polygon lineage fields.

Structurally valid empty roles and unplaceable groups can be saved. Editor
validation blocks Play/Build for these readiness findings, without blocking
Save. Generation requires readiness for active chunks in included levels;
excluded/deprecated content still receives strict source/geometry validation.
Captured Chunk Play checks its selected active pool and Level Play checks all
active chunks in the captured level. An unfinished unselected or deprecated
group cannot prevent playing an unrelated valid selection.

Editor immutable source, composition snapshots, semantic equality, stale-command
guards, metadata/copy operations, canonical pending diffs and source fingerprints
all retain encounters. Typed Play snapshots freeze the collection and revalidate
complete rosters before admitting Core. Whole-chunk copies retain local IDs;
runtime occurrence identity still includes the new streamed chunk index.

Encounter edit helpers preserve group/member identity through moves and renames,
allocate fresh IDs for local duplication, and retain nullable policy/reward
inheritance explicitly. A composition operation replaces or deletes one complete
owned group under the existing owner/revision/before-snapshot guard. Removing its
last required member remains a saveable incomplete draft. Scene controls are
still the next authoring milestone.

Generation emits immutable typed encounter lists and uses validated non-const
constructors. Encounter-free pools retain the existing constant output. Encounter
data does not change terrain signatures, while generated patterns and captured
source fingerprints include it. Generated display names escape Dart interpolation
and line breaks. Tests execute the emitted registry in an isolated Core package
and compare source semantics across captured Chunk and Level Play.

## Actor movement bounds

The terrain controller accepts optional `TerrainHorizontalBounds` on its motion
request. These are actor-specific full-body X limits in physics ticks. It insets
the interval by capsule radius, rejects an invalid initial pose, and constrains
requested movement and terrain-contact continuation before solving each segment.
Steps cannot preview outside the interval. Airborne motion retains vertical
movement; supported motion stops along its support path. Final terrain contacts
are resolved normally, with no post-motion transform clamp.

Recovery also obeys the interval. At a sloped boundary, a vertical correction can
satisfy the same separating projection without moving through the boundary. A
blocked or over-budget recovery restores the last valid in-bounds pose. The
controller reports boundary contact separately from terrain wall contacts and
clears optional constraints before processing an unrestricted actor. NPC stores
supply immutable quantized bounds to the motion authority. Teleport placement
checks the complete mirrored capsule against the same interval.

## NPC actor lifecycle

`EntityFactory.createNpc` shares autonomous combatant component assembly with
enemies while retaining a separate `NpcId`, allied faction, facing and bounds.
It adds neither player input nor an enemy score identity. All three catalogs
define reviewed sprite anchors, torso capsules, terrain profiles and resources.
The warrior uses its four-frame sword attack; Huntress uses the seven-frame
spear throw and Huntress 2 the six-frame bow attack. At 60 Hz, their release
ticks are respectively 12, 36 and 12.

`SnapshotBuilder` emits `EntityKind.npc`, a separate `NpcId`, and immutable
health/protection metadata alongside the shared actor animation, facing, status
and motion fields. No NPC receives an enemy identity. Enemy and NPC registries
share `ActorRenderRegistry` and `DeterministicAnimView`; live and ghost pools
accept both identities and apply the same deterministic frame/anchor handling.
Live NPCs show allied health bars and a check when protected. Ghost NPCs retain
the existing ghost style, without live health or reward feedback.

All NPC animation and projectile images are in UI warmup, render preload and
immutable Play asset capture, including content beyond the starting chunk.
Build source fingerprints include NPC PNGs. Entities exposes all three packs
through its existing guarded source parser and transactional export path.

Motion preparation installs the catalog's capsule/traversal profile and support
state. NPCs use the normal terrain solver, gravity and status stores. Animation
uses the same actor signals and active-ability timing as enemies. Shared actor
death progression waits for ground impact or its finite fall deadline, plays
the death animation, and then uses normal death cleanup. NPC death cancels
pending/attached combat and never reports an enemy kill. Generic health cleanup
leaves NPC bodies to that lifecycle.

## NPC decisions and shared execution

`NpcAiSystem` consumes the encounter-selected target and terrain navigation
intent. The terrain publication includes allied graph profiles derived from
each registered NPC's actual capsule, speed, jump and gravity. Bounded graph
views retain the shared surface identities and remove traversals whose takeoff
or landing falls outside the chunk's full-body range. Goals and safe fallback
ranges are clipped to that range; motion authority remains the final constraint.

Allied and enemy ground movement share surface-speed projection, jump commitment
and swimming. NPC decisions stop while protected, dead, stunned or without a
selected opponent. Movement locks stop pursuit without forbidding valid attacks.
The shared melee committer enforces living/targetable state, control locks,
cooldowns, active phases and resources before publishing a timed intent. Shared
resource helpers also serve enemy casts. Costs are paid once at commit; existing
melee execution, hit detection and damage ownership handle the resulting strike.

`AiCastCommitter` shares enemy and NPC cast timing, predictive aim, resource and
control gates, cooldowns and intent creation. Huntress spear and Huntress 2 arrow
projectiles use the existing launch/hit systems with physical damage and allied
faction, without player participation credit. They are separate catalog IDs,
excluded from the explicit player-equippable list. A committed vertical origin
offset places each launch at its reviewed release height; ordinary casts retain
their zero-offset behavior. Rescue cancels an unreleased intent, while detached
projectiles retain ordinary collision and lifetime behavior.

## Combat ownership and survivor safety

`DamageCredit` is captured when attacks are created and carried through hitboxes,
projectiles, queued damage, accepted status applications and each DoT channel.
It identifies player participation independently of faction and live entity IDs.
NPC allies never inherit player credit. The damage system exposes actual positive
HP loss through a separate participation callback; existing feedback amounts and
enemy kill counting remain unchanged.

DoT ownership changes only when the incoming application replaces a weaker
channel or extends an equal-strength channel. Ignored applications retain the
current owner. Equal-strength extensions preserve pulse phase. DoT requests keep
their previous null live source, so ownership does not introduce outgoing weaken
modifiers or attacker-targeted procs.

The NPC store retains identity, facing, owning chunk bounds and protection state.
`protectNpc` ends attached attacks and pending abilities, clears harmful effects
and target references, and leaves detached effects and physical bodies intact.
Protected NPCs are excluded from combat broadphase (including trap occupancy),
AI selection, queued damage and harmful status applications. Terrain movement
is supplied through the motion authority and bounded encounter navigation.

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
The shared target seam is exercised with fixture allies and complete streamed
warrior encounters. Authored JSON/editor delivery remains in the active plan.
