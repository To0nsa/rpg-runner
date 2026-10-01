# NPC encounter data contracts

Core owns immutable `EncounterDefinition` records, stable `NpcId` identities and
`AiTargetPolicy` preferences. They are independent of player input and enemy
score IDs. Core contracts, shared AI targeting, all three NPC archetypes, encounter
lifecycle, shared authored compilation and Chunk Creator authoring are delivered
slices of the [rescue implementation plan](../building/npc_rescue_encounters.md).
Rescue statistics and score presentation are implemented. The generated Field
pool includes `field_roadside_rescue`, authored with all three NPCs and required
Grojib/Hashash participants. Normal Core and the replay worker use that same
source-generated content; editor Play uses the shared captured-source pipeline.

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

`RunEndStats` publishes `rescuedNpcs` and accumulated `rescuePoints` after unresolved
encounters are finalized. The shared `buildRunScoreBreakdown` checks rescue counts,
per-survivor limits and total addition, appending one rescue row only when credited
survivors exist. Zero-point rescues retain that row. UI feed, local `RunResult`, and
validator use this same calculation with the actual simulation tick rate. Older
local result JSON defaults missing rescue fields to zero.

The replay's optional `clientSummary` includes the two fields only as provisional
display evidence. The validator ignores these claims and writes both statistics
from replayed Core to `ValidatedRun.stats`; gold and settlement idempotency remain
unchanged. Existing open JSON maps support these additive keys without changing
replay/command format 1. Gameplay compatibility is `2026.10.1`, ranked scoring is
`score-v2`, and rules/ghost remain `rules-v2`/`ghost-v1`. The worker accepts only the
new gameplay/score pair. See the [pre-live release checklist](../building/rescue_release_operations.md).

The ordinary-combat regression uses an explicit marker roster on the generated
`field_flat` terrain, with no encounter definitions. Its current camera-paced
trace covers 1068 ticks and Grojib, Hashash and Unoco behavior, including
motion, attack animation, projectiles, resources and terminal state. Derf
placement/casting is covered separately; it does not appear in this trace.
The contract probe is also compiled and executed to verify admission errors
survive AOT assertion removal.

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
after recorded player HP damage; otherwise it resolves unassisted without points.
Both cleared outcomes admit living survivors to vulnerable section guarding.
Failure and abandonment protect survivors instead. Terminal outcomes and awarded
statistics are immutable even if a guard subsequently dies. Enemies lose only their encounter target policy,
retaining resources, statuses and committed attacks. Awards accumulate once from
each occurrence's resolved points override, including explicit zero.

The coordinator checks expiry before streaming and after the camera update,
records participation during damage, and resolves after fatal enemy culling but
before death cleanup. Unresolved member enemies bypass ordinary behind-camera
culling; falling out of the world still removes them. Run exit finalizes groups and stops all remaining guards, including those whose
origin records have retired, before statistics or player-death freeze. The controller's terrain-retention and
retirement APIs enforce expiry before cleanup and retain only a monotonic retired
chunk index. Streamed chunk snapshots carry typed encounter definitions and the exact selected
`ChunkAssemblySelection` in both live and speculative selections. Its start
chunk/count identify one Flow occurrence independently of repeated source IDs.
`EncounterOccurrence.guardRegion` derives the section interval using the owning
chunk width; automatic and standalone chunks derive a one-chunk region. Active
encounter placement and objectives still use the original chunk bounds. Each new
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
last required member remains a saveable incomplete draft.

Chunk Creator exposes Encounters in its existing scene selector. The contextual
sidebar reuses section/list cards and visual catalogs. Group inspectors own
display name, activation rectangle, enemy policy and point inheritance; member
inspectors own catalog identity, X, facing, terrain support and enemy policy
overrides. Relevant shared readiness diagnostics appear beside the selected
group/member. The inspector describes chunk confinement during an active encounter and
section guarding after completion, separately from the blue activation rectangle.

`ChunkEncounterGesture` wraps the shared rectangle/snapping interaction. Actor
drags change only X and resolve Y through Core's `createEncounterSpawnRequest`
and terrain placement resolver. Catalog choice does not create history. Release
emits one guarded composition command; wrong-pointer events and cancellation do
not publish source. Converting an ambient enemy removes that exact marker and
adds a required encounter member in one command, preserving X/support and
initializing catalog facing. Encounter activation replaces its ambient chance
and scheduler; no alias or ambient-marker reference remains.

Inspector buffers use the shared exact-edit controller and Save/Discard/Cancel
guard. Save and Play finalize valid visible fields before session export/capture.
Undo first cancels a gesture or unaccepted form edit. Composite selection IDs
survive canonical sorting and are retained as tombstones across deletion, so
Undo restores the selected participant. Owner changes clear selection, while
navigation snapshots retain group/member IDs for the same owner. All source
writes continue through the Chunk plugin's revision and before-snapshot guard.

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
supply quantized bounds to the motion authority. The bounds expand exactly once
on a cleared encounter from the original chunk to its frozen section interval;
failed or abandoned groups retain their current chunk bounds. Teleport placement
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

`NpcAiSystem` consumes the shared selected target and terrain navigation
intent, during both encounters and section guarding. The terrain publication includes allied graph profiles derived from
each registered NPC's actual capsule, speed, jump and gravity. Bounded graph
views retain the shared surface identities and remove traversals whose takeoff
or landing falls outside the NPC's current full-body range. Goals and safe fallback
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

## Combat ownership and survivor lifecycle

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

The NPC store retains identity, facing, current motion bounds, protection state
and an optional `NpcGuardRegion`. Guard state remains independent of retired
encounter membership. `beginNpcGuarding` cancels pending/attached encounter
attacks, expands motion bounds and configures a guard-owned hostile roster while
preserving health, statuses, resources and cooldowns.
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

`NpcGuardSystem` refreshes current membership before `AiTargetSystem` in phase 3.
It orders living guard and enemy IDs, admits enemies whose body-center X is in
`[minX, maxX)`, and uses nearest-opponent policy with no player fallback for
guards. Ordinary enemies in those territories receive guard candidates with
player fallback. `AiTargetOwner` prevents this system from replacing active
encounter policies or rosters. Leaving a territory or losing its final guard
removes an ordinary enemy's guard-owned component, restoring normal pursuit.
`refreshCandidates` preserves selected identity and navigation evidence for
retained IDs and avoids copying an unchanged roster. Normal perception and
unreachable-target filtering still apply; there is no section-wide path search.

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
profile for the current published bundle. Ground-mounted kinematic targets
such as Derf lack dynamic contact records; their actual pose is queried against
the same terrain placement/support contract and admitted only within collision
skin of resolved support. This supplies target support without moving the target
or adding a dynamic contact store. `SurfaceNavStateStore.targetEntity`
owns target-support cache identity, including transitions back to ordinary
pursuit. Target changes invalidate graph/support paths while existing airborne
scalar jump commitments retain their normal landing behavior. Confirmed no-path
evidence requires grounded resolved supports with movement/navigation unlocked;
water-entry fallback is considered first. It expires on support/profile changes,
target movement or terrain publication, without ranking candidates by all-pairs
path searches. Blocked evidence is local to each attacker.

Terrain navigation distinguishes a direct supported walk chain from a jump/drop
plan through `canWalkDirectlyToTarget`. Ground melee enemies on that chain stop
their pursuit velocity while engaged within melee X range and one attacker
collider half-height vertically, continuing to face the selected opponent. This
hold applies between attacks too; leaving range resumes pursuit. It does not
interrupt airborne motion, swimming or committed terrain transitions. The flag
is refreshed with navigation and cleared on target loss or water pursuit.
Hashash's explicit evade/ambush teleport retains its normal repositioning.

`EcsWorld.destroyEntity` removes inbound roster, selection and navigation-target
references before recycling entity IDs. Removing an encounter's target component
restores ordinary player pursuit without resetting the actor's combat state.
The shared target seam is exercised with fixture allies and complete streamed
encounters. Authored source, editor capture and normal runtime use the same rules.
