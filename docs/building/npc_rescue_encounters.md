# NPC rescue encounters

Status: gameplay, authoring, scoring and production content are implemented and
deployed as `2026.09.8`. M7 retains the signed-in production smoke follow-up in
[release operations](rescue_release_operations.md). The owner stopped further
benchmarks and requested deployment on September 25; performance sign-off is
not claimed.

Created: September 24, 2026.

Plan audited against the working tree: September 24, 2026. The gaps recorded
below are addressed in this plan; runtime implementation and verification are
tracked in section 6.

This is the implementation plan for allied NPCs who fight enemies, can die,
remain within their encounter's chunk, and award rescue points. It covers
deterministic Core behavior, content compilation, Chunk Creator, rendering,
scoring, and replay validation. D1–D7 are confirmed design choices; implementation
details and the initial point value below remain planned, not existing gameplay.

## 1. Requirements and scope

Confirmed requirements:

- Use the imported Huntress, Huntress 2, and Medieval Warrior assets as NPCs.
- NPCs fight enemies automatically and can be killed.
- Saving NPCs earns gameplay points.
- Each encounter belongs to one streamed chunk instance. Its NPCs may move and
  fight inside that chunk's horizontal boundaries but cannot cross into adjacent
  chunks. Terrain remains authoritative for vertical movement (confirmed D1).
- Encounters explicitly control participation and targeting; enemies must not
  globally switch to preferring every NPC.
- A rescue requires all required encounter enemies defeated, a surviving NPC,
  and positive applied player damage to an encounter enemy. Player-owned
  projectiles/status damage count; the final hit is not required.
- Unresolved encounters are abandoned one owning-chunk width behind the
  camera's left edge, measured from the chunk's right edge. Run end also
  terminates unresolved encounters without rescue points.
- Rescue points per surviving NPC are editable per encounter in Chunk Creator,
  with a shared default. Existing defeated-enemy counting remains unchanged.
- After enemy victory, surviving enemies resume their normal behavior targeting
  the player; failure does not despawn or reset them.
- Reuse existing combat, movement, authoring, and rendering code where its
  contracts fit. Preserve established Chunk Creator UX and repository writes.

Deliver one rescue objective with all three NPC types. Use one warrior encounter
as the first integration fixture, not as the final feature scope. Ordinary
enemy placement and combat must continue to work without encounters.

Out of scope: escorting NPCs into later sections, persistent companions,
dialogue/quests, new currency or ownership rewards, a general scripting or
behavior-tree editor, arbitrary encounter waves, and a new editor application.
NPC movement across chunks, custom movement-region authoring and encounters
spanning multiple chunks are outside this implementation scope. Level Creator
does not need new encounter ownership or movement-scope configuration.

## 2. Decision record and implementation defaults

The user has confirmed D1–D7 below. The requested enemy-victory transition is
recorded separately after the table. The audit supplies implementation defaults
for activation, target retention, unassisted survivors and same-tick precedence
in section 4. These fill previously unspecified details; they are not additional
user-confirmed decisions. Balance and capacity values have an explicit M0/M7
validation gate and do not reopen D1–D7.

| Decision | Confirmed first-release rule | Consequence |
| --- | --- | --- |
| D1: Meaning of section — confirmed | Each rescue encounter belongs to one streamed chunk instance. NPCs may move and fight within that chunk's horizontal boundaries but cannot enter adjacent chunks. Terrain controls vertical movement. | Derive bounds from the owning chunk; no movement-scope selector, custom boundary fields or Level Creator section binding. Works in automatic levels, authored assemblies, Chunk Play and Level Play. |
| D2: Encounter composition — confirmed | Author the complete rescue group as encounter-owned participants in the same chunk. Each repeated placement creates a new encounter. | All placement and membership editing stays in Chunk Creator. Required participants are known without assembling an objective across several chunks. |
| D3: Rescue and participation — confirmed | Rescue surviving NPCs when every required encounter enemy is defeated and the player has dealt positive applied damage to an encounter enemy. Credit player-owned projectiles/status damage; do not require the final hit. | Count damage actually applied after defenses, not attempted attacks, proximity or an NPC's damage. Participation belongs to that encounter instance. |
| D4: Failure and abandonment — confirmed | All NPCs dead means failure. Abandon an unresolved encounter when `cameraLeftX >= chunkEndX + chunkWidth`, using its owning chunk's actual width. Run end grants no rescue points to unresolved encounters. | The chunk is fully off-screen with one additional chunk-width behind the left edge. Coordinate lifecycle with terrain/entity culling; removal is never victory. Previously awarded points remain. |
| D5: After rescue — confirmed | Survivors stop fighting, become non-targetable and protected from further damage, and stay inside their movement bounds until normal cleanup. | Rescue is terminal. Pending attacks, projectiles, and damage-over-time must respect the resolved state. |
| D6: Points and kill credit — confirmed | Provide a shared points-per-survivor default, an editable per-encounter override in Chunk Creator, and a separate rescue score row. Preserve the current defeated-enemy counting rule. | Persist the override with encounter source and replay it through Core. Sum actual awarded points across encounters with different values; do not multiply the total saved count by the global default. |
| D7: Ambient combat — confirmed | Only encounter members inherit its targeting policy. Active NPCs use existing faction rules, so ambient hostile attacks can still damage them. | Encounter membership is not a new faction or automatic damage shield. Player/NPC friendly fire stays disabled by the allied faction. |

Requested enemy-victory behavior: when all NPCs die, the failed encounter releases
surviving enemies to their normal player-targeting AI. Keep their existing health,
cooldowns, status effects, position and committed ability phases. NPC chunk
confinement must never become a permanent movement restriction on these enemies.

Activation uses an authored player-entry trigger evaluated by Core. Dormant
encounters hold definitions only; the complete group spawns on activation.
Streaming content ahead of the camera cannot start combat or expose NPCs to
damage. Author the trigger early enough for the fight to remain playable at the
existing camera pace; pausing the camera is not assumed.

## 3. Current implementation and reuse boundaries

The following findings were checked against the working tree on the creation
date. Recheck these seams before editing and preserve the completed
[forest navigation repair](../archive/2026-09-24/building/forest_enemy_navigation.md)
and its compatibility changes. This plan builds on that work.

| Existing owner | Reuse | Necessary extension |
| --- | --- | --- |
| [Faction](../../packages/runner_core/lib/combat/faction.dart), ECS health, damage, status, cooldown and attack-intent stores | `Faction.player` already covers allies. Reuse hit resolution, friendly-fire filtering, melee/projectile execution, resource and status rules. | NPC identity, AI decisions and lifecycle; do not represent an NPC as a fake player or enemy merely to enter an existing loop. |
| [Enemy AI systems](../../packages/runner_core/lib/ecs/systems/) | Preserve existing enemy archetypes, engagement, movement and ability behavior. | Navigation, engagement, facing, melee, casts, flying AI and Hashash ambush currently have player-specific assumptions. All affected consumers need one selected target. |
| [Terrain navigator](../../packages/runner_core/lib/navigation/terrain_surface_navigator.dart) and `WorldMotionAuthority` | Actor-neutral terrain snapshots, real traversal limits, collision-safe movement and support bookkeeping. | Generalize the enemy adapter where needed and enforce NPC movement bounds across all motion paths. |
| [Entity factory](../../packages/runner_core/lib/ecs/entity_factory.dart), [death handling](../../packages/runner_core/lib/ecs/systems/enemy_death_state_system.dart), [health cleanup](../../packages/runner_core/lib/ecs/systems/health_despawn_system.dart) | Extract genuinely shared actor setup and lifecycle operations. | Enemy death reporting currently identifies enemy types; generic health cleanup removes dead non-enemies immediately. Encounter outcomes need participant identity and removal cause before destruction. |
| [Chunk patterns](../../packages/runner_core/lib/track/chunk_pattern.dart) and [streamer](../../packages/runner_core/lib/track/track_streamer.dart) | Existing seeded selection, chunk instance indexes, terrain spawn placement and streaming publication. `ActiveTrackChunkSnapshot` already exposes the instance index and world-space start/end X. | Carry owning chunk and encounter/participant identity through spawn requests and returned entities. Reuse the published chunk bounds; no section-occurrence metadata extension is needed. |
| [Shared content pipeline](../tdd/runner_content_pipeline.md) | One deterministic compile/materialize path for generator and authored Play. | Strict encounter decoding, semantic validation and typed Core data. Core must not depend back on the pipeline or editor. |
| [Chunk composition operations](../../tools/editor/lib/src/chunks/chunk_v2_composition_operation.dart) and [editor UI](../tdd/editor_ui_system.md) | Revision-aware commands, inline drafts, visual catalogs, gestures, scene coordinates, history and transactional Save. | Typed encounter selection and operations; all existing composition edits must preserve new data. |
| [Animation contracts](../tdd/animation_data_flow_and_timing.md) and [enemy render registry](../../lib/game/components/enemies/enemy_render_registry.dart) | Core animation timing, `RenderAnimSetDefinition`, strip loaders and `DeterministicAnimView`. | NPC catalog/render registration, snapshot identity, asset capture and preview support. Avoid a second animation player. |
| [Score breakdown](../../packages/runner_core/lib/scoring/run_score_breakdown.dart) and [validator](../../services/replay_validator/lib/src/validator_worker.dart) | Shared deterministic score calculation and server replay. | Rescue counters/points, UI rows, validated stats and compatibility coordination. |

### Approach selection

Three approaches were considered:

1. Give all enemies a global NPC preference. Rejected: no encounter ownership,
   unclear cleanup/reward rules, and changes to ordinary combat.
2. Build an independent NPC combat/navigation stack. Rejected: duplicates
   deterministic combat and terrain rules, with likely editor/Play divergence.
3. Add a focused encounter owner and shared target selection around the existing
   actor systems. Selected: explicit lifecycle and policies, with reusable combat
   execution and the current content/editor infrastructure.

Extract shared behavior when a concrete enemy and NPC consumer need it. Keep
enemy-specific abilities and player input/loadout orchestration in their existing
owners; do not generalize the whole ECS or authoring plugin framework.

### Audit findings and closure in this plan

These are implementation gaps found in the plan/code comparison, not claims that
the existing game already implements NPC behavior. Each closure is specified
below and assigned to the single milestone checklist.

| Gap found in current code | Required plan closure | Milestone |
| --- | --- | --- |
| [Damage application](../../packages/runner_core/lib/ecs/systems/damage_system.dart) exposes no owner in its applied-damage callback; [status application](../../packages/runner_core/lib/ecs/systems/status_system.dart) and DoT channels retain trap provenance but no actor credit. | Carry stable participation credit through hits/status channels separately from the source used for damage modifiers; define refresh ownership. | M2 |
| [Melee](../../packages/runner_core/lib/ecs/systems/melee_strike_system.dart) and [projectile](../../packages/runner_core/lib/ecs/systems/projectile_launch_system.dart) executors consume committed intents and do not charge costs or gate cooldowns. | NPC attack decisions must use shared commit checks before existing execution. | M2, M4 |
| [Terrain body dispatch](../../packages/runner_core/lib/ecs/systems/world_motion_authority.dart), [facing](../../packages/runner_core/lib/ecs/collider_aabb_utils.dart) and [animation iteration](../../packages/runner_core/lib/ecs/systems/anim/anim_system.dart) explicitly recognize current player/enemy roles. | Register NPC terrain/contact profiles, mirrored colliders, animation iteration and snapshots; render registry entries alone are insufficient. | M2, M4 |
| [Damageable targets](../../packages/runner_core/lib/ecs/hit/aabb_hit_utils.dart) and [trap activation](../../packages/runner_core/lib/ecs/systems/trap_system.dart) do not express rescued actor eligibility. | Share eligibility across target selection, hit queries, traps and queued damage/status application; retain terrain collision. | M2 |
| Ambient streaming probability-rolls markers, suppresses opening enemies and defers Hashash without participant identity. | Spawn the guaranteed encounter roster atomically at activation; define opening suppression and authored Hashash placement. | M2, M3 |
| [GameCore](../../packages/runner_core/lib/game_core.dart) has early run-end exits, a death-animation freeze, different camera samples for streaming/culling, and culling before death reporting. | Resolve once before evidence is lost; specify camera sampling and terminal priority across every exit. | M2 |
| Live rendering, ghost rendering, UI preload and captured Play each have explicit actor/asset dispatch. | Include all NPC animation, health feedback and projectile assets in every applicable dispatch/capture path. | M4, M5 |
| Source copies/history and score consumers need more than a new encounter field or score row. | Preserve identities through operations, include data in capture fingerprints, and replay mixed authored awards with compatible wire/version changes. | M3, M5, M6 |

## 4. Runtime contract

### Ownership and data flow

Proposed new Core code belongs under `runner_core/lib/encounters/` and
`runner_core/lib/npcs/`, with per-entity state in ECS stores and tick logic in
focused systems. Final names should follow the repository's nearby patterns.

The data path is:

```text
Chunk authored source with existing Level context
  -> shared strict compilation -> typed Core encounter definitions
  -> streamed occurrence + stable participants -> encounter lifecycle
  -> selected AI targets -> existing movement and attack execution
  -> damage/death outcomes -> rescue result and run statistics
  -> snapshots/events -> Flame, HUD and editor Play

The replay worker runs the same Core and score calculation.
```

Authoring definitions are immutable; runtime state is owned by Core. Game/UI
events announce outcomes but must never grant points or advance the encounter.

### Identity, spawning and streaming

- Assign stable local encounter and participant IDs. NPC/enemy **type** IDs are
  separate from placement identity. Moving, reordering or editing a participant
  must not change its identity or membership.
- Scope runtime identity to the run-local streamed chunk index plus authored
  encounter/participant IDs, not only `chunkKey` or group name. Repeated chunks,
  including those in looping sections, must not share health, participants,
  target state or reward guards.
- An NPC or enemy has at most one owning encounter. The player can interact
  with multiple encounters without becoming an owned participant. Overlapping
  triggers must not transfer members or leak targeting policies between groups.
- Register each participant once. Reuse terrain placement and spawn setup;
  preserve the registration throughout an enemy's intro sequence. An intro is
  a living required member, not a missing or already defeated enemy. Never spawn
  the same authored enemy through both ambient and encounter paths.
- Use complete encounter-owned participant records for D2. Reuse the existing
  enemy placement value semantics and editor controls; do not reference ambient
  markers by their list index, position-derived UI key, or type name.
- If converting an ambient marker into a participant is exposed, remove the
  ambient record and create its encounter member in one undoable command. There
  must be exactly one source record and one eventual entity.
- All authored participants are guaranteed in the first release; every enemy is
  required. Do not expose chance, optional-member or ambient deferred-spawn
  controls in the encounter inspector.
- Support the four current runtime enemies: Grojib, Hashash, Unoco and Derf.
  Encounter Hashash uses its authored terrain placement and existing factory/
  intro/teleport behavior, bypassing the ambient deferred edge-spawn scheduler.
  Reuse explicit placement results that return entity identity or a rejection;
  the current silent `void` spawn path is insufficient for required members.
- Validate the complete roster's placements before creating any actor. Publish
  the group in stable encounter/participant ID order only when all placements
  are accepted. Unforeseen runtime rejection is an invalid-content outcome with
  zero rescue points and diagnostic evidence, never a partial playable group
  or a reduced required-enemy count. Play/Build must catch supported placement
  failures before publication.
- Preserve `noEnemyChunks`: suppress the whole group, including NPCs, in an
  enemy-free opening occurrence. It does not activate or award points; later
  occurrences remain independent. Show this in Play diagnostics. Never suppress
  just the enemies and leave a free rescue behind.
- Unloading terrain must not strand a live participant or its navigator. Keep
  encounter resolution/cleanup aligned with the stream lifecycle; do not retain
  an entire visited level just to preserve NPCs behind the camera.
- Bound live encounters, participants and retained terminal state with explicit
  Core admission limits. Evict safely after streaming has made reactivation
  impossible, while keeping aggregate score counters. Readiness must account
  for simultaneously streamed/retained groups, not just a single record's size.
  Runtime admission failure rejects the whole group deterministically with an
  invalid-content diagnostic; never silently omit a required member.

Keep each encounter's initial participant placement within its owning chunk.
NPC confinement continues after spawning; enemies retain their normal movement
capabilities and may pursue targets outside the chunk even while active. Keep
their encounter identity and required-member status until resolution. Do not
merge encounters because chunks use the same assembly group or encounter name.

### Activation

Capture dormant definitions when a chunk streams in. At the pre-AI activation
phase, test the segment from the preceding activation sample of the player's
center to its current center against the authored closed trigger rectangle.
Touching its boundary counts; the first sample activates when already inside.
This observes movement completed on the preceding tick, catches a dash across a
narrow trigger, and avoids adding a second motion integration in the current
tick. After terrain publication, create the roster before motion preparation,
target selection and AI. Newly spawned actors use normal intro/attack timing.

Trigger coordinates are chunk-local with positive finite dimensions and must
fit inside the chunk horizontally. Expiry/run termination takes priority over
activation. Dormant groups passed without entry abandon for zero points; they
never spawn retroactively. Multiple triggers crossed in one sample activate in
stable occurrence/local-ID order. Pause does not advance activation samples.

### Shared target selection

Introduce one typed target state for AI-controlled combatants. Encounter policy
chooses the permitted candidate set and preference; the selector chooses a valid
entity. Player aiming and command handling remain player-owned.

The first authoring policies are `Player only`, `Prefer encounter NPCs` (the
new-encounter default), and `Nearest opponent`. An enemy inherits its encounter
default unless explicitly overridden. Policy candidates are the actual player
and active NPCs of that enemy's own encounter, never NPCs from another encounter.
`Nearest opponent` chooses the nearest eligible candidate when acquiring a
target. NPCs select hostile members of their own encounter; they hold position
when none can be engaged. Ambient attacks can still hurt them under D7, but do
not transfer objective membership or targeting policy. Ordinary enemies retain
the existing player target when no encounter policy applies.

On enemy victory, remove the encounter's effective target policy and stale NPC
target from each surviving enemy. Its next normal AI decision selects the player
through the same target system. This must not heal, respawn or reset the enemy,
refund resources, bypass a cooldown, or redirect an already committed strike or
projectile. Preserve normal archetype behavior, including terrain traversal and
special abilities; no second post-encounter AI mode is needed.

Selection and retention rules:

- Candidates must be alive, active, targetable and compatible with faction and
  membership rules. Apply archetype perception and current traversal evidence
  for encounter candidates; being outside attack range alone is not rejection.
- Prefer-NPC policy ranks eligible owned NPCs before the player; player-only
  admits only the player. If no NPC is eligible, fall back to normal player
  behavior. If the player is also unavailable, clear the target and uncommitted
  attack requests; committed phases follow the rule below.
- Rank acquisition by policy tier, squared world-space center distance, then
  stable entity ID. Retain a valid target within its tier until it dies, becomes
  ineligible or existing navigation evidence confirms it cannot be engaged.
  A newly eligible higher-priority tier may preempt it. Small distance changes
  alone do not switch an engaged target. Negative reachability evidence is
  invalidated on relevant target/support/terrain changes, not held forever.
- Avoid all-pairs path searches to rank candidates. Reuse bounded candidate
  queries and the selected actor/target's existing navigation evidence.
- No additional RNG consumption or changed spawn/entity ordering for ordinary
  encounter-free runs. Target selection must not perturb existing seeded AI.
- One target identity shared by navigation, engagement, facing and attack
  decisions for the tick. After movement, consumers may read its updated position
  while preserving existing attack timing semantics.
- Explicit treatment of target switches during windup: preserve each ability's
  committed aim/facing unless its definition supports retargeting. Validate a
  stale target and clear obsolete intents without inventing a replacement in a
  downstream attack system.
- Navigation caches keyed by actor/target and terrain version as appropriate;
  the present single-player prediction cache cannot become shared mutable state
  for unrelated targets.

Complete the migration for ground, flying, ranged, melee and teleport behavior
in the same validated milestone. Do not leave a parallel player-only decision
path hidden behind an encounter flag.

### NPC movement, combat and presentation

Give NPC archetypes explicit health, traversal capabilities, attacks, perception
and render metadata. Review the imported art before selecting frame dimensions,
anchors, timings, collider/source bounds and projectile behavior. Suggested roles
are warrior melee, spear huntress and bow huntress; exact attacks and balance
remain authored implementation choices, not assumptions from filenames.

NPC AI uses shared attack commit gates before writing existing committed intents:
alive/active state, target/range, control locks, current ability phase, resources
and cooldown. Reuse or extract the common enemy commit operation; melee and
projectile execution alone does not deduct costs or start cooldowns. An NPC must
not attack once per tick simply because an intent can be emitted. Reuse actor
setup, status, resource, animation and death machinery at their common boundaries.
Do not route NPC decisions through simulated player inputs or put them in
`EnemyId`, whose ordinals already participate in scoring/contracts.

Register NPC body roles, traversal/contact profiles and world contact capsules
with `WorldMotionAuthority` before they enter motion preparation or the damage
broadphase. Current body dispatch rejects unsupported dynamic actors and the hit
cache requires a contact capsule. Extend shared facing accessors so terrain,
capsule/AABB mirroring, melee offsets and projectile origins agree with sprite
facing for all three NPCs. Adding health and a render entry is not sufficient.

Movement bounds constrain the full collision body, not just its center. Enforce
them both in route/goal selection and authoritative motion, including walking,
jumps, swimming where supported, knockback, mobility and teleport. Reuse terrain
contact updates and `WorldMotionAuthority`; arbitrary post-motion position clamps
must not place bodies inside terrain or retain stale support. Bounds are specific
to the constrained actor and must not become invisible global terrain walls.

Derive horizontal limits from the owning streamed chunk's actual world-space
start and end X, and keep terrain authoritative for vertical support. NPCs may
move throughout the chunk; they are not fixed to their spawn position. Do not
infer limits from sprite size, camera visibility, the activation trigger or a
Level Creator section. The editor must not persist a second copy of these bounds.

An unreachable enemy should not make an NPC cross a boundary or teleport through
terrain. Return/hold behavior, spawn support and authored encounter layout must
be validated and playtested against the actual traversal capabilities.
Bounds apply to the NPC body; its detached projectiles retain ordinary range,
collision and lifetime rules. An enemy leaving the chunk remains a required
opponent, but cannot pull the NPC's body across its boundary.

Extend actor iteration in `AnimSystem` and `SnapshotBuilder`, not only render
catalogs. Derive idle, movement, airborne, attack, hit and death presentation from
Core timing; map unsupported art states through reviewed animation fallbacks.
Keep dead NPCs long enough to show their death animation instead of allowing
generic non-enemy health cleanup to remove them immediately.

Expose NPC identity and lifecycle through typed snapshots, plus health/objective
data needed by the HUD. Reuse deterministic animation loading, hit/status effects
and camera transforms. Show a clear allied health indicator and rescue feedback.
Audit `LiveWorldSyncSystem`, the ghost layer, actor visual-cue filters and enum
switches as well as the registry. Ghosts follow current ghost presentation rules
and cannot emit live rescue awards or duplicate live HUD feedback.

Register every NPC/ability/projectile image through runtime UI asset scopes,
render preload, editor catalog previews and immutable Play capture/warmup paths.
Assets for later-streamed chunks must be captured too. Missing required images
produce actionable Play readiness errors, not invisible actors or reliance on
incidental Flutter asset availability. Visual checks cover mirrored anchors,
capsules, attack origins and full death playback for all three packs.

### Combat eligibility and terminal NPC behavior

Use one semantic actor eligibility contract across AI selection, hit/broadphase
queries, trap occupancy and damage/status application. Active NPCs follow normal
faction and trap rules. Dormant groups have no actors. Rescued or terminal-safe
NPCs cannot be targeted, trigger traps, intercept/consume hostile projectiles,
receive queued damage, acquire harmful status or receive combat knockback. A
late damage request must recheck eligibility even if hit detection ran earlier.
Keep their terrain collision and chunk bounds; do not implement safety by setting
the enemy faction, a huge HP value or a timed invulnerability window.

On rescue, stop new attack commits, clear pending intents, cancel held channels
and remove attached melee hitboxes. Clear harmful ongoing effects on survivors
and use bounded idle/settling movement until ordinary cleanup. Already detached
projectiles and already-applied effects on other actors finish under normal
lifetime/faction rules with their original ownership; do not redirect them or
reclassify their damage as player damage. The same safety transition applies to
unassisted survivors below, without marking them rescued or granting points.

### Encounter outcomes and participation

Use a small explicit lifecycle: dormant, active, succeeded, failed, abandoned.
Terminal outcomes are irreversible. Keep per-NPC rescued/dead outcomes where
multiple NPCs can have different results.

If enemies are defeated without the participation required by D3, resolve
`failed(unassisted)` once with zero rescue points. Surviving NPCs stop fighting
and become terminal-safe until cleanup, but do not contribute to rescued count
or show rescue-success feedback. Later player damage cannot reopen the result.

Track player participation from positive applied damage attributed to the player,
including owned projectiles and status effects. Preserve attribution after a
projectile is destroyed or a damage-over-time effect outlives its original hit.
Observe authoritative HP reduction (`previousHp > nextHp`) with stable origin
credit, not a visual damage event or `Faction.player` alone: NPCs share that
faction. NPC damage, blocked attacks and zero-damage hits do not satisfy
participation. The flag belongs to one encounter instance and remains set once
earned; every credited target must be a registered enemy of that active instance.

Carry credit through damage requests, applied-damage evidence, status requests
and DoT channels. Keep participation credit separate from the live source used
for outgoing weaken/procs/reactive effects: merely populating today's nullable
DoT `sourceEntity` would change existing damage arithmetic. For the current
one-channel-per-damage-type merge rules, a stronger replacement or an equal-DPS
accepted duration extension takes the incoming credit; an ignored weaker/shorter
application does not. Removing a projectile or original actor cannot erase the
channel's credit. Test player/NPC applications competing for the same channel
and preserve existing DoT amounts, cadence, RNG and proc behavior.

Record explicit participant fate before ECS removal. Combat death and an
authoritative fatal world/kill-plane transition count as enemy defeat; ordinary
horizontal culling or unexplained disappearance does not. Fatal NPC falls count
as NPC deaths. Unexpected required-member loss resolves
`failed(participantLost)` with no reward. This encounter evidence must not change
the existing defeated-enemy score rule, which currently excludes some culls.

Enemy victory resolves failure once, freezes the encounter result and releases
surviving enemies from active encounter control. Retain immutable origin/result
evidence for diagnostics and bookkeeping without keeping the targeting override
active. A later player kill uses the unchanged defeated-enemy counting rule and
cannot retroactively turn the failed encounter into a rescue. Living released
enemies may chase the player across chunk boundaries under normal terrain and
culling rules; NPC confinement never applies to them.

### Abandonment threshold and cleanup

Use the owning chunk's captured world-space bounds and Core camera-left:

```text
chunkWidth = chunkEndX - chunkStartX
abandonmentX = chunkEndX + chunkWidth
abandon unresolved encounter when cameraLeftX >= abandonmentX
```

This is one full chunk-width after the entire encounter chunk leaves the left
side of the screen. For a chunk from X=1000 to X=1600, abandonment begins when
camera-left reaches X=2200. Use deterministic coordinate comparisons and the
actual owning width; do not substitute screen pixels, render shake, a fixed 600,
or distance from an individual NPC. The threshold is fixed by D4, not another
editor setting. Run end abandons an unresolved encounter regardless of distance.

Streaming reads camera state before this tick's camera update, whereas actor
culling reads the updated position. Check the threshold once before stream
teardown using the committed starting camera sample, then again immediately
after `camera.updateTick`, before hits/outcome awards, using the updated sample.
Both calls are idempotent. Thus crossing the threshold during this tick expires
the encounter this tick, without prematurely unloading support at tick start.

`EnemyCullSystem` currently culls individual bodies against
`cameraLeft - cullBehindMargin`, while `TrackStreamer` culls whole chunks by
their end X. Even with the default one-chunk margin, a participant near the
chunk's left edge can disappear before its encounter reaches the threshold.
Make unresolved encounter participants' horizontal lifetime follow the encounter
threshold. Keep required terrain/support available until terminal resolution,
and resolve abandonment before streaming discards its evidence. A different
generic cull margin must not shorten the rescue window; preserve ordinary
non-encounter culling behavior. Vertical fatal/removal cases remain explicit
outcomes, never successful defeats inferred from missing entities.

At abandonment, freeze zero rescue points and release any surviving enemies to
normal AI/lifetime rules; they may then be culled normally if already too far
behind. Clean up remaining encounter NPCs without reporting them as rescued.
Previously successful or failed encounters do not transition again. Retain only
the bounded state needed for lifecycle and provenance, not the whole visited map.

### Tick order and scoring

Order dependencies to fit `GameCore.stepOneTick`, without broadly reordering
unrelated systems:

1. Check starting-camera abandonment before stream teardown. Retain unresolved
   terrain, publish streamed terrain/instances and activate admitted rosters
   before actor preparation, target selection and AI.
2. Run the existing movement phases. After the camera update, check abandonment
   again before combat. Every early fatal run exit terminates unresolved
   encounters before stats are frozen.
3. Run eligible attacks, damage and status consequences. Capture actual applied
   damage and participant fatal/removal facts before cleanup loses identity.
4. Resolve with the priority table below after all normal damage for the tick
   settles. Observe lethal player HP now, before the death-animation freeze.
5. Emit immutable presentation output and perform normal death/cull cleanup
   through the existing owners, preserving ordinary death/kill accounting.

Current enemy culling precedes enemy death-state processing, and kill reporting
only carries `EnemyId`. Implement the smallest coherent change that distinguishes
defeated, culled, invalid spawn and abandoned participants. Never infer victory
from an empty ECS query. Document the changed ordering and preserve ordinary
death/kill behavior with regression coverage.

For an encounter still unresolved at each decision point, the first applicable
rule wins. A known fatal player outcome therefore prevents a new award, while
an outcome already finalized at an earlier phase is not reclassified:

| Priority | Condition | Result |
| --- | --- | --- |
| 1 | Run terminates or player suffers fatal HP/world loss this tick | Abandon unresolved groups; no new rescue points, even if the last enemy also dies. |
| 2 | Distance threshold reached at either specified camera sample | Abandon before further encounter combat/awards; expiry also prevents dormant activation. |
| 3 | Invalid roster/spawn or unexpected required-member loss | Fail with diagnostic reason, no rescue points; release surviving enemies. |
| 4 | Every NPC is dead after the tick's damage/fatal outcomes | Fail, including when the last enemy and last NPC die together; release surviving enemies. |
| 5 | All required enemies defeated and at least one NPC survives | Succeed if participation is set; otherwise fail unassisted. Freeze survivors and award at most once. |
| 6 | None of the above | Remain dormant or active. |

Previously terminal outcomes never change, including when a later run ends.
Wire one idempotent unresolved-run finalization path into give-up, gap loss,
camera loss, lethal HP/death-freeze entry and any controller disposal path that
ends a run. Presentation-only death ticks cannot activate, fight or award.
Preserve existing normal enemy kill reporting even on a fatal player tick.

Store aggregate rescued count and actual awarded rescue points in Core run
statistics; use the shared score breakdown for the total and a separate rescue
row. Keep zero-rescue runs' existing score contributions unchanged. Widget
rebuilds, repeated events and backend retries cannot award points again. This
work adds score, not a new direct wallet write or reward settlement.

Add a shared Core default plus an optional per-encounter authored override for
points per saved NPC. The proposed initial default is **250 points**: above the
current 100-point ground-enemy and 150-point Unoco kill values, giving rescue a
distinct bonus without replacing kill points. Treat 250 as a starting balance
value to verify in M7, not a user-confirmed numeric requirement. The editor reads
the default from Core rather than maintaining a copied UI constant.

Resolve and capture the effective value for each encounter instance using its
authored override or the run's score tuning. On successful resolution:

```text
encounterRescuePoints = survivingNpcCount * effectivePointsPerNpc
runRescuePoints = sum(points actually awarded by each successful encounter)
```

The total rescued count cannot be multiplied by one default because encounters
may use different values. Use non-negative integer points within a shared Core
supported range; validate multiplication and accumulated-score bounds. Zero is
an explicit valid override, not an alias for missing. Show counts and awarded
points in the score row without inventing one unit value for a mixed-price run.
The validator resolves the same source-backed value and never trusts an editor
preview or a client-supplied reward override.

## 5. Chunk Creator and playtest UX

### Workspace and interaction

Add an **Encounters** domain in the existing Chunk Creator scene selector. Keep
the chunk library, scene and contextual sidebar in the current layout. Reuse
`EditorSectionCard`, `EditorListCard`, `EditorVisualCatalogLayout` and
`EditorVisualCatalogCard`; do not introduce an encounter route or a second shell
toolbar.

The intended authoring journey is:

1. Open a chunk, select Encounters, and expand **Create encounter**. Enter its
   name; the initial objective is Rescue. Show **NPCs stay in this chunk** as
   read-only guidance, with no movement-scope selector or boundary-editing tool.
2. Place its activation trigger using the shared rectangle interaction and
   exact-coordinate fields. Display the allowed movement area separately from
   the trigger; they have different meanings.
3. Add NPCs and enemies from catalog cards using Select/Place/Move conventions.
   NPCs use reviewed idle thumbnails and placement evidence from Core metadata.
   Selecting a catalog entry alone creates no pending change or history entry.
4. Select a participant in the scene or encounter list. Open its inline inspector
   for type, position, facing and supported placement options. Enemy targeting
   displays **Use encounter setting** or an explicit supported override, with
   the effective policy shown in plain language.
5. Select the encounter to edit its default targeting and **Points per saved NPC**
   in the inline inspector. Show the shared default, support a validated numeric
   override and **Use default** reset, and preview the maximum rescue bonus from
   the placed NPC count. Display the actual rescue condition beside it. Show
   only implemented choices; do not expose target weights, scripts or ECS fields.
6. Apply through the existing command/history path, then use shared Save, Build
   and Play. Invalid fields remain visible and actionable.

Highlight selected participants with their encounter and show activation and
movement bounds using distinct labeled overlays. Reuse scene transforms,
snapping, image caches and Ctrl+drag/Ctrl+scroll behavior. Catalogs, forms,
gestures and painters should be bounded siblings of the workspace coordinator;
the already-large coordinator must not become the source of validation rules.

Creating an encounter creates a saveable incomplete draft; require at least one
NPC and one enemy before Build/Play. Catalog selection alone stays read-only;
placement/Apply creates the member. New encounters default to **Prefer encounter
NPCs** and **Use default** points, with both effective values visible.

Deleting an encounter removes its owned participants in one undoable transaction;
show the affected count. Removing or replacing a participant must preserve a
coherent draft and flag any now-incomplete rescue objective. Apply existing
reference-aware confirmation conventions where references actually exist.

### Source, history and validation

Extend the existing Chunk plugin/store path. Persist through canonical JSON,
revision guards, source-drift checks and atomic Save; no page-level file writes.
Encounter mutations, marker conversion, duplication and deletion must update
membership and selections together, with correct Undo/Redo and pending diffs.
Other composition operations must retain encounter data unchanged.

Encounter IDs are unique within a chunk; participant IDs are unique within their
encounter. Select by composite stable identity, not sorted list position. Moving,
renaming and reordering preserve IDs. Duplicating an encounter within the same
chunk creates a new encounter ID; duplicating a participant creates a new member
ID. A whole-chunk copy may retain its local IDs because its chunk occurrence is
a separate namespace. Undo restores the original IDs, records and selection.
Include encounter fields in every reconstruct/copy path, semantic diff, source
fingerprint, generated-data equality and captured-scenario identity.

The per-encounter points override follows the same draft/Apply, revision, Undo,
pending-diff and Save path as other encounter fields. Omit the override in
**Use default** mode; retain an explicitly entered value even if it equals the
current default, so future default tuning does not erase the designer's intent.
Reject explicit null, fractional, negative and out-of-range values. Persist the
override through shared decoding, generated runtime data, captured Play and Core;
switching inspector selection alone must never commit a reward edit.

Use an optional strict encounter collection, following current water/trap
extensions: absent means empty, explicit null is invalid, and empty data can be
omitted to preserve encounter-free source bytes. Put reusable encounter decoding
in `runner_content_pipeline` and consume it from the editor codec and generator.
Extend the current chunk schema in every reader/writer in the same milestone;
nested encounter/member IDs do not require rewriting ambient marker identity.
Each record owns its trigger, default policy, optional points override and typed
NPC/enemy participant placements; each enemy may have a policy override. No
participant references an ambient marker. Reject unknown keys/types rather than
silently dropping behavior. Do not reinterpret old markers or keep fallback
parsers. A genuinely required schema break must have one explicit migration for
all checked-in sources and fixtures before that milestone is complete.

Validate unique IDs, supported types/policies, nonempty required roles, spawn and
trigger geometry, movement containment, valid placement support, numeric ranges,
references and participant limits. Separate structurally invalid data (write
blocker) from structurally valid but incomplete content (saveable with clear
Play/Build readiness failures), following the existing Level readiness contract.
Incomplete content must never be published into a production runtime pool.
Diagnostics identify the encounter/member and relevant field in the existing
inspector; compilation and UI use the same rules. Authoring readiness validates
actual NPC capsules, facing and terrain placement, not only sprite rectangles.

Changing chunk size, duplicating/rekeying a chunk, changing level/group and
deleting members must revalidate encounter ownership and placement. Level section
changes retain the existing scheduling/readiness checks; encounter confinement
continues to derive from each selected chunk instance.
Use the shared compiler for runtime readiness; scene overlays are evidence, not
an alternate gameplay or placement compiler.

### Chunk and Level Play

Chunk Play currently builds a deterministic filtered chunk loop, while Level Play
retains actual assembly. Both modes must instantiate each encounter with its
owning chunk's identity and horizontal bounds. Repeating the same authored chunk
creates an independent encounter every time, including in a single-chunk Play
loop. No captured section context or Level-only fallback is needed.

Keep Level Creator's existing composition and Play workflow. It consumes the same
compiled encounter-bearing chunks without new encounter settings or participant
editing. Automatic levels and assembled levels use the same confinement rule.

Extend immutable scenario capture, image collection, background compilation,
source fingerprinting and readiness checks. Play must use unsaved accepted
edits, stop back into the retained workspace, and restart from the same captured
input. It must continue to create no tickets, submissions or backend rewards.
Optional target/encounter inspection must read Core snapshots through the existing
debug/overlay pattern, not execute an editor-owned AI preview.

For NPC collider/source-bound authoring, extend the existing Entities domain's
catalog parsing and guarded source bindings where needed. Chunk Creator should
consume those definitions, not acquire a separate sprite/collider editor.

## 6. Implementation milestones

This is the single progress checklist for the workstream. Each milestone must
leave a coherent, validated change and its relevant documentation. Commit only
that milestone's changes; do not include unrelated navigation/content work.

- [x] **M0 — Establish limits, fixtures and the baseline.** Implement against
  D1–D7, enemy-victory behavior and the audited rules in sections 2–5. Use 250
  points as the initial default candidate. Record shared source/runtime limits
  for encounters per chunk, members per encounter, live retained actors and
  points per survivor before schema work; derive safe score accumulation from
  supported run duration/spawn bounds and the tightest Dart/web/wire integer
  limit. Validate the limits in normal and AOT construction, not assertions only.
  Author one typed warrior fixture with a concrete trigger and a complete enemy
  roster. Build on the navigation repair and capture ordinary combat/replay
  traces before refactoring. Acceptance: executable baselines and a documented
  capacity/score budget; no unresolved schema-driving or lifecycle decision.
- [x] **M1 — Introduce shared AI targeting.** Add typed target/policy state,
  deterministic selection and lifecycle invalidation; migrate every affected
  enemy decision consumer, including Hashash and flying behavior. Preserve
  committed attack semantics and fix target-dependent cache ownership.
  Acceptance: ordinary player-only combat matches the baseline; fixture NPC
  targets can be selected without adding a second attack/navigation pipeline.
- [x] **M2 — Add Core encounters and NPC lifecycle.** Add immutable definitions,
  occurrence/participant identity, explicit spawn outcomes, activation, terminal
  state, body-safe movement bounds, and one warrior integration fixture. Wire
  terrain/contact roles, shared commit gates, combat eligibility, fatal-removal
  evidence and persistent player/status credit. Adapt shared actor setup/death/
  animation behavior only where required. Resolve outcomes at the specified
  camera/damage/run-exit phases; coordinate terrain and actor retention with D4
  and release victorious enemies to normal AI. Acceptance: deterministic
  rescue/failure/abandonment, unchanged ordinary DoT/kill behavior, no premature
  culling or rescued-NPC trap activation, no NPC escape, no enemy reset and no
  partial group spawn or repeated outcome.
- [x] **M3 — Complete authored compilation and streaming.** Implement shared
  strict decode/materialization, editor source models, generator output and
  scenario validation, including all new data in composition copies. Carry
  owning chunk instance identity and reuse its published bounds. Regenerate
  through the normal tool; implement any required explicit migration in this
  milestone.
  Carry the optional points override through the shared source/runtime path.
  Acceptance: generator and authored Play compile identical encounter facts;
  empty legacy content retains its behavior and invalid required spawns fail
  readiness instead of producing a free rescue.
- [x] **M4 — Deliver all NPC archetypes and rendering.** Review and register all
  three packs, their source/collider bounds, abilities, projectiles, traversal,
  facing and animation timings. Add typed render/HUD output, shared sprite
  loading, actor animation/snapshot dispatch, live/ghost rendering, preload,
  complete captured assets and needed Entities support. Acceptance: all three
  NPCs attack, take damage, die and render correctly in runtime and captured
  Play; no invented timing or collider assumptions remain unverified.
- [x] **M5 — Deliver encounter authoring and Play UX.** Implement the Encounters
  domain, catalog placement, inline inspectors, policy inheritance, overlays,
  points override/default controls, operations, diagnostics and read-only
  chunk-boundary guidance. Exercise the complete create, edit, move, duplicate,
  delete, Undo/Redo, Save/Reload, Build and Play journey.
  Acceptance: existing scene controls, dirty-draft guards, responsive state and
  pending diff behavior remain consistent; no duplicated domain logic or write
  path is introduced.
- [x] **M6 — Integrate rescue score and replay contracts.** Add aggregate rescue
  stats, shared defaults and per-encounter resolved awards, shared score
  calculation, end-screen formatting/feed and result summaries. Update
  validator-produced stats and affected wire consumers;
  validate forged client summaries are ignored. Acceptance: client and worker
  derive the same score, zero-rescue contributions stay unchanged, and terminal
  outcomes cannot award points more than once. Mixed-override encounters total
  correctly and retain normal enemy kill credit after an enemy victory.
- [ ] **M7 — Author playable content and complete release readiness.** Add a
  deliberate representative rescue encounter without overwriting unrelated
  level edits; tune NPC survival and encounter clearance for auto-scroll. Run
  the integrated acceptance matrix, all affected suites and compiled replay
  performance gate. Coordinate new gameplay/score compatibility and publish
  implemented TDD/GDD documentation. Acceptance: all confirmed requirements,
  three NPC types and authoring flows are complete; remaining operational
  deployment work is explicitly recorded rather than marked as delivered.

M0 precedes schema-dependent work. M1 precedes production NPC combat. M3 and M4
must be complete before declaring M5's Play journey delivered. M6 precedes
publishing score-bearing production content. Intermediate fixtures may use typed
test definitions, but the delivered authoring path must use repository sources.

M0 evidence (September 24): immutable Core contracts and constructor guards,
four encounters/chunk, four NPCs/eight enemies per encounter, sixteen live
encounters/192 participants, 0–100,000 points/NPC and checked exact-integer
accumulation. See [implemented contracts](../tdd/npc_encounter_contracts.md).
The pre-change Core suite passed 596 tests; five new contract/baseline tests pass
and the validation probe passes as an AOT executable. The fixed ordinary-combat
trace covers 785 ticks and all three moving enemy types; stationary Derf retains
separate existing coverage. Generator freshness reports pre-existing drift in
two outputs from unrelated Woodcamp edits; no generated files were rewritten
for this milestone. No encounter runtime or editor UI is enabled by M0.

M1 evidence (September 24): one explicit target store/selector and every ground,
flying, cast and Hashash consumer migrated. Entity destruction invalidates roster
and target references before ID reuse; navigation caches include target identity
and profile. Ordinary combat retains the M0 trace. Core analysis is clean, the
full package suite passed 608 tests and Flutter Core passed 366. A final set of
26 focused tests covers the added ground-melee, flying and Hashash target cases
as well as retention, policies, removal, release and committed-cast preservation.

M2 combat foundation (September 24): stable player damage credit now survives
projectile and status lifetimes without changing live-source damage modifiers.
NPC protection gates target selection, trap occupancy, projectiles, queued damage
and harmful statuses; terminal cleanup retains detached effects. Forty focused
Core tests and 31 existing Flutter combat tests pass, including the unchanged
ordinary-combat trace. Encounter orchestration, spawning and movement remain
within the unfinished M2 milestone.

M2 lifecycle controller (September 24): occurrence identity, swept activation,
complete-roster admission, removal evidence, terminal precedence, exact expiry,
enemy release and once-only awards are implemented and covered by sixteen
controller scenarios. Core's 634-test suite and Flutter's 366 Core integration
tests pass; analysis is clean. Coordinator damage/run-exit hooks and enemy cull retention
are wired; real NPC actor spawning, terrain retention and bounded motion remain
before M2 can be checked complete.

M2 motion foundation: the capsule controller now accepts actor-specific full-body
horizontal limits, including supported travel, airborne displacement, steps,
convex support transitions and overlap recovery. Downhill boundary recovery
preserves support by resolving its separation vertically within the same budget.
All 185 terrain collision tests pass, analysis is clean and the ordinary-combat
trace remains unchanged. NPC authority/catalog integration
is still required before these limits apply to real streamed actors.

## 7. Acceptance and regression matrix

M2 completed (September 25): warrior actors now use shared setup, melee commit
gates, terrain navigation/motion, swimming, animation, death and cleanup. Typed
chunk encounters activate after terrain publication with atomic full-roster
preflight. Required Hashash retains authored placement and intro; all four enemy
types are covered. Stream retention and occurrence retirement follow the exact
abandonment contract. Tests include a real player/warrior rescue, repeated chunks,
opening suppression and no partial spawn. The ordinary combat digest is unchanged.
M3 completed: shared strict source decoding, complete-roster placement readiness,
editor source preservation and generated/captured runtime materialization are
implemented. All 81 pipeline tests, 26 generator regressions, 68 Core
encounter/Play checks and 40 editor source/Play checks passed. Generator freshness
was checked against the user's current authored tree; its unrelated generated
changes were excluded from these commits.

M4 completed: both Huntresses share enemy cast execution and use reviewed
physical projectile metadata. All three NPCs publish typed identity, health,
motion and animation snapshots, use shared actor sprite loading, and appear in
live/ghost pools. Live health/safety indicators, complete preload/captured assets,
Build image fingerprints and guarded Entities source edits are implemented.
The visual review covers both facings, idle, attack release, hit and final death
poses against capsule/support guides (`.tmp/npc_render_review.png`, reproducible
with `NPC_RENDER_REVIEW=1` and `test/game/npc_render_test.dart`).
All 71 Core encounter tests, 28 existing cast/projectile/attack tests, five
sprite/live/ghost checks, seven Play host checks, 50 Entities checks and image
capture/warmup checks pass. Core/game analysis is clean; full editor analysis
had one test-only redundant null assertion, removed and rechecked. The Play host
fixture now derives its image bounds from current explicit trap atlas regions.
M5 evidence (September 25): Encounters uses the existing scene/domain controls,
visual catalog/list cards, shared rectangle gestures, revision-guarded composition
commands and inspector Save/Discard/Cancel gates. Actor previews share Core
placement requests, and selection uses stable group/member identities through
duplication, deletion and Undo. Ambient-marker conversion transfers the exact
source record and required participant atomically. Per-member readiness messages,
effective targeting, inherited/explicit reward values and separate activation/
movement bounds are visible in the editor.

The combined focused editor checks cover 82 cases across new authoring/preview
tests, existing terrain/water/trap controls, source/history and captured Play.
The preparation time budget passes in isolation; an initial concurrent run
exceeded five seconds and was rerun without competing suites. Ten Core placement,
streaming and ordinary-combat regression tests pass. Full editor analysis found
only corrected brace lints; scoped rechecks are clean. The opt-in
`NPC_EDITOR_REVIEW=1` authoring test captures the reviewed scene with real catalog
sprites/fonts (`.tmp/npc_editor_review.png`). M6–M7 still own score presentation/
contracts, production content and compatibility/release validation.

M6 evidence (September 25): terminal Core rescue counts/awards flow through the
shared score breakdown, end-screen feed, local result serialization, provisional
summary and authoritative worker stats. Zero-rescue runs retain their existing
rows; zero-point rescues stay visible, mixed awards sum once, and overflow fails
before addition. Forty client scoring/ticket tests, seven Core streaming tests,
69 worker tests, 44 protocol tests and all 212 Functions emulator tests pass.
Functions build and changed-source Dart analysis are clean. Forged client rescue,
score and gold claims are ignored at 30 Hz. Defaults now agree on gameplay
`2026.09.8`/`score-v2`; retired versions reject before replay. Deployment remains
tracked separately in [release operations](rescue_release_operations.md).

M7 content evidence: `field_roadside_rescue` includes all three allies against
Grojib/Hashash with default rewards and clear, connected ground. Seeds 7, 42 and
2026 rescue all three before ordinary auto-scroll catches the player; the 2026
case also passes at 30 Hz. Tests record actual inputs and replay through the
worker, checking every NPC's full horizontal body bounds and authoritative
750-point totals despite forged summaries. All 694 Core tests (including the
ordinary-combat digest and traversal matrix) and 152 worker tests pass in an
isolated checkout. Generated rescue-only changes are staged from the committed
authoring baseline; concurrent user Forest/navigation edits remain separate.
Subsequent app/editor checks completed; their fixture/content failures were
corrected and the affected targets passed. The final 20/13/9 HP tuning passed
127 encounter/traversal cases and all four real rescue replays. Current authored
levels were explicitly requested for generation and deployment and committed
with their matching outputs. See the [release verification](../archive/2026-09-25/verification/game-compat-2026.09.8-production.md)
for the exact release, validation results and remaining smoke/performance limits.

| Area | Required evidence |
| --- | --- |
| Ordinary gameplay | No-encounter traces preserve enemy targets, navigation, attacks, death/kill behavior and existing score contributions across ground, flying and special enemies. |
| Targeting | Player-only, preferred NPC, nearest opponent, override inheritance, deterministic ties, retention, fallback, target death during windup, stale IDs and no-target clearing. Other encounters' NPCs cannot be acquired. Enemy victory restores normal player targeting without resetting health/cooldowns/status/committed attacks. Different attackers hold different targets without cache contamination; unreachable evidence expires when support/target changes. |
| Factions and damage | Player/NPC friendly-fire filtering and ambient hostile melee/projectiles/status/trap damage. Positive HP reduction with persistent projectile/status credit; rejected zero/blocked/NPC damage; mixed-owner DoT replacement/refresh/ignored applications with unchanged ordinary damage amounts. NPC commit gates enforce costs, cooldowns and control locks. |
| Terminal safety | Saved/unassisted-safe NPCs cannot be selected, trigger traps, absorb hostile projectiles or receive direct/queued/DoT damage, harmful status or knockback. Attached attacks stop; detached projectiles keep their original ownership/lifetime. Terrain collision, settling and chunk containment continue. |
| Bounds and terrain | Full-body containment inside the owning chunk under walking, jumps, slopes, steps, unsupported edges, knockback, mobility/teleport and supported water behavior. Crossing a chunk seam is prevented even inside the same Level section; movement inside the chunk remains allowed. No stale contacts, terrain penetration or global invisible wall. |
| Encounter lifecycle | Swept trigger crossing, exact boundary/initially-inside activation, multiple triggers and no preactivation actors. Atomic placement rejection, whole-group opening suppression, Hashash intro, fatal world losses and unexpected removal. Mixed survival, last enemy/last NPC death, unassisted outcome, give-up and player-death freeze follow the priority table. Later enemy defeats cannot reopen any terminal result. |
| Streaming | Adjacent/overlapping encounters, repeated chunk keys in automatic and assembled levels, widths, section lengths and memory limits. Independent state/bounds per occurrence. Test immediately before/at/after D4 using both camera samples and differing generic cull margins; left-edge participants cannot disappear early. Required terrain remains available. Active enemies may leave the chunk without losing membership; released enemies follow normal lifetime rules. |
| Compilation | Strict malformed-input rejection, canonical round trips, IDs stable through sorting/movement, empty-source parity, supported schema behavior, generator/editor equivalence and generated drift checks. |
| Editor | Catalog selection stays revision-neutral; gesture/inline Apply is one command; effective targeting and point defaults/overrides are clear; reward edits/reset support Undo and round-trip Save/Play; Delete/Undo restores membership; unrelated edits preserve encounters; stale-source writes reject; invalid input stays visible; selection survives supported navigation/resize. |
| Play and assets | Unsaved accepted capture, identical confinement in Chunk/Level Play, independent encounters in a single-chunk loop, complete later-streamed NPC/projectile assets, missing-image readiness diagnostics, stable Restart, Stop restoring workspace and no backend side effects. Check facing, mirrored capsules/anchors, attack origin, hit/death timing and HUD readability for every NPC; cover live and ghost actor dispatch. |
| Scores and protocol | Once-only rescue points, inherited default, explicit zero/equal-default overrides, mixed encounter values, invalid/overflow rejection, zero-rescue rows, unchanged ally and released-enemy kill credit, shared UI/worker totals, forged summary/reward rejection, non-default ticket tick rate, duplicate submission/projection behavior and supported version rejection. |
| Performance | Bounded candidate queries and live state; benchmark representative crowded encounters in addition to the existing whole-level compiled replay gate. Preserve current budgets unless a measured change is explicitly accepted. |

Extend meaningful existing tests rather than mirroring new implementation details.
Relevant starting points include:

- `packages/runner_core/test/ecs/terrain_enemy_navigation_system_test.dart`,
  `ground_enemy_terrain_locomotion_test.dart`, `terrain_spawn_placement_test.dart`,
  `packages/runner_core/test/track/section_composition_test.dart` and
  `track_streamer_active_chunks_test.dart`.
- The [seeded level traversal workflow](../../.agent/workflows/test-level-traversal.md)
  and `packages/runner_core/test/navigation/level_enemy_traversal_test.dart`.
  Preserve the existing enemy pursuit matrix; add bounded NPC/encounter cases
  using production motion and continuous actor state. Do not teleport actors,
  widen traversal limits or bypass blocked chunks to make rescue fixtures pass.
- `test/core/enemy_attacks_test.dart`, `enemy_engagement_system_test.dart`,
  `ground_enemy_melee_facing_lock_test.dart`, `invulnerability_and_death_test.dart`,
  `score_system_test.dart`, `determinism_test.dart` and Hashash spawn tests.
- `packages/runner_content_pipeline/test/chunk_runtime_materialization_test.dart`
  and `test/tool/generate_chunk_runtime_data_test.dart`.
- `tools/editor/test/chunk_v2_composition_operation_test.dart`, codec/save/plugin
  tests, `chunk_authoring_workspace_test.dart`, scene/marker tests, authored
  playtest tests and `level_section_composition_test.dart`.
- `test/game/components/sprite_anim/`, `test/playtest/`,
  `test/ui/game_over_score_feed_test.dart`, and validator simulation/worker tests.

Add focused encounter, NPC and targeting suites in the owning packages, plus
one editor journey that proves the complete workflow from authoring to Play.

## 8. Validation commands

Run targeted tests during each milestone; at integration run the following
affected suites. Check generated-content freshness before interpreting traversal
results; regenerate through the normal tool when needed. Commands assume
PowerShell at repository root unless a working
directory is shown. Resolve root workspace dependencies from the root only;
the editor and validator keep their independent lockfiles.

```powershell
dart run tool/generate_chunk_runtime_data.dart --dry-run
dart analyze packages/runner_core
dart analyze packages/runner_content_pipeline
dart analyze packages/run_protocol
dart analyze lib
Push-Location packages/runner_core
dart test
Pop-Location
Push-Location packages/runner_content_pipeline
dart test
Pop-Location
Push-Location packages/run_protocol
dart test
Pop-Location
flutter test test/core test/game test/ui test/playtest test/tool
dart run tool/sync_assets.dart --check

Push-Location tools/editor
dart analyze
flutter test
Pop-Location

Push-Location services/replay_validator
dart analyze
dart test test
dart compile exe bin/server.dart -o ../../.tmp/replay_validator_encounters.exe
& ../../.tmp/replay_validator_encounters.exe benchmark --ticks=36000 --strict
Pop-Location

corepack pnpm --dir functions build
corepack pnpm --dir functions test
```

Run protocol suites when contracts change and Functions suites when compatibility,
board configuration or callable contracts change. Extend/run the existing AOT
protocol probe if public constructor validation changes. Record command results,
visual evidence and any unavailable checks with the implementing milestone.
Writing this plan does not constitute running these implementation checks.

## 9. Compatibility, documentation and completion

Targeting, NPC outcomes and encounter timing affect deterministic gameplay;
rescue points affect scoring. Coordinate gameplay compatibility and a new score
version with the client, `functions/src/runs/compatibility.ts`, board provisioning
and `services/replay_validator/lib/src/validator_worker.dart`. Select actual
version values from the then-current baseline, including navigation work; do
not reuse an already published compatibility value for changed simulation.

Update `RunEndStats`, score consumers in `lib/ui/leaderboard/run_result.dart` and
`lib/ui/hud/gameover/`, and summary serialization in `lib/ui/runner_game_widget.dart`
where applicable. Keep validated rescue statistics sourced from replayed Core.
Change shared `run_protocol` and matching TypeScript contracts only where wire
shapes actually change. Preserve existing ordinals and digest-bound data;
NPC AI does not require new player command frames by itself.

Document how old sessions, queued validations, boards and ghosts are retired or
served by a compatible worker during release. Do not advertise historical support
from a worker that only runs the new Core. Retain settlement idempotency and
generation-pinned artifacts. Deployment is a separate operational action, not
part of this documentation task.

As milestones land, create focused implemented encounter/NPC TDD and GDD docs and
update the existing simulation, animation, content-pipeline, editor UI/Play/Level,
level-composition, score and replay-validator documents where behavior changes.
Update layer AGENTS guidance only for new ownership/working rules, and public
embedding docs only if their API changes. Keep proposed rules in this plan until
implemented; avoid copying the plan into production-contract documentation.

Completion requires the confirmed scope, decision record, milestone checklist,
tests, visual review, generated outputs and implemented docs to agree. Perform
a final reuse review for duplicated targeting, attack execution, placement,
catalog UI, parsing and persistence logic. Archive the completed plan under
`docs/archive/<completion-date>/building/` and update incoming links; retain any
outstanding operational release work in the active index with its actual status.
