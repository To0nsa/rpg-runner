# Runner Core Simulation Contract

## Scope

This document describes the implemented contract of
`packages/runner_core`. It is the authoritative deterministic gameplay layer
used by the Flutter/Flame client and the replay-validation worker.

It does not define backend ownership, replay serialization, or rendering
implementation. Those concerns are documented in:

- [replay validator worker](replay_validator_worker.md)
- [ghost run serialization](ghost_run_serialization_deserialization.md)
- [animation data flow and timing](animation_data_flow_and_timing.md)
- [terrain capsule controller](terrain_capsule_controller.md)
- [sloped navigation and enemy terrain foundation](sloped_navigation_and_enemy_terrain.md)
- [polygon terrain authoring foundation](polygon_terrain_authoring_foundation.md)

## Ownership boundaries

| Responsibility | Owner | Must not be moved to Core |
| --- | --- | --- |
| Fixed-tick gameplay, ECS, combat, collision, streaming, snapshots, events | `runner_core` | Flutter/Flame rendering or widget state |
| Input aggregation, tick driving, interpolation, render-only effects | `lib/game/` | Gameplay rule resolution |
| UI state, HUD, menus, backend-client orchestration | `lib/ui/` | Direct ECS mutation |
| Replay/run/board wire payloads | `packages/run_protocol` | Duplicate gameplay implementation |
| Ticket validation and deterministic replay execution | `services/replay_validator` | Alternate gameplay rules |

## Run configuration and command lifecycle

`GameCore` is configured with deterministic run inputs, including seed, tick
rate, level definition, player character, and resolved loadout/tuning. The
same configuration and command stream must yield the same Core results.

Command scheduling is strict:

1. `tick` starts at zero.
2. Before each active simulation step, callers build commands for
   `core.tick + 1`.
3. `GameCore.applyCommands` rejects every stale or future command before it
   resets or mutates player input.
4. `GameCore.stepOneTick` increments the clock and consumes that input.

An empty command list is valid and clears one-tick input edges. Movement,
aim, and press flags are per-tick input; ability-slot hold transitions are
latched until a later transition command changes them. Callers stop submitting
commands once the run is paused or ended.

`GameController` owns client-side scheduling from `TickInputFrame` to commands.
The replay validator and ghost playback map each replay frame to its matching
simulation tick. Neither consumer may reinterpret a command's tick.

## Tick ordering

`GameCore.stepOneTick` ordering is gameplay behavior, not an implementation
detail. The code-level phase list beside that method is the exact execution
order; the contract below records the dependencies that must survive changes.

| Order | Contractual phase | Dependency |
| --- | --- | --- |
| 1 | Stream/cull track, build the complete staged candidate, publish any queued terrain bundle, place the captured enemy/item batch, and prepare motion | No placement or motion consumer may observe a partial candidate or mixed terrain/index/surface/graph versions; AI receives validated prior support. |
| 2 | Decrement timers and refresh control locks, ability phases, and hold/charge state | Input activation must observe current timer, ability, and control state. |
| 3 | Resolve AI, ability activation, jump, movement, mobility, gravity, and collision | Intent is composed before every terrain-owned dynamic actor is integrated exactly once. |
| 4 | Update distance, camera, and terminal fall conditions | Camera-dependent culling, pickups, and run termination use final motion state. |
| 5 | Collect pickups, rebuild broadphase, and move existing projectiles | Hit detection requires current spatial data; newly spawned projectiles do not move until a later tick. |
| 6 | Write enemy intents, execute abilities, then position hitboxes | Self abilities resolve before downstream combat so their effects apply deterministically. |
| 7 | Resolve projectile/hitbox/mobility/world hits, then status and damage | Damage middleware changes queued damage before application; reactive effects follow applied damage. |
| 8 | Apply queued statuses and visual cues, process deaths, regen, animation, and cleanup | Death is resolved before regen/cleanup; animation reflects final gameplay state for the tick. |

Combat spatial lookup has a two-stage deterministic contract. During phase 5,
`DamageableTargetCache` requires every live damageable actor to have faction,
transform, authored collider, and `WorldContactCapsuleStore` state. It resolves
the facing-aware quantized capsule once and derives the spatial-grid AABB from
those exact endpoints and radius. Missing capsule state is an invalid world
composition and fails rather than falling back to a rectangle.

During phase 7, melee/area hitboxes, projectiles, and mobility impacts query
that AABB grid only for candidates. `HitResolver` preserves stable entity-ID
ordering and owner/faction filters, then confirms attack capsule versus target
capsule. Tangency is inclusive; overlap limited to an enclosing AABB corner is
not a hit. This shape change does not move a phase or change hit-once,
piercing, source-attribution, status, or damage-queue ordering.

Every `GameCore` construction owns polygon terrain. Normal streamed
construction performs the scheduler prewarm, installs the multi-body capsule
authority from that exact admitted candidate before player placement, and
atomically consumes later spawn/cull candidates. Replay validation inherits the
same path without a serialized authority option. Track-disabled synthetic
fixtures compile one deterministic flat polygon at the level's authored ground
reference. The test/tool-only `GameCore.terrainMotionHarness` factory remains
available only to inject focused polygon geometry.

`GameCore.chunkPlaytest` is a second explicit tool-only construction boundary.
It accepts one already validated, immutable `ChunkPlaytestScenario`; it is not
an optional flag on the production constructor and is not represented in a run
ticket, replay blob, or validator payload. Scenario preparation:

1. requires the draft `ChunkPattern` and staged-terrain record to share one
   admitted generated chunk key, level, assembly group, active status, and
   streamed dimensions;
2. replaces that record in a read-only `StagedTerrainOverlayCatalog`, while all
   other keys still resolve from `stagedAuthoredTerrain`;
3. re-runs the existing authoring scheduler reachability analysis using the
   draft's current tier/group/status metadata;
4. chooses a real incoming transition when available, then follows canonical
   transition-record order until the finite path has a deterministic loop; and
5. checks every reachable seam touching the draft, plus every path/loop seam,
   with Core's exact terrain-boundary signatures before construction.

The resulting path-backed pattern source relocates the selected chunk near the
start for authoring feedback. It is therefore a scheduler-reachable playtest
sequence, not a claim that the same finite sequence is a normal production
schedule. It adds no flat pad or substitute collision. The selected draft
pattern and terrain replace every occurrence of that key; non-selected path
records remain generated products. The opening no-enemy suppression is cleared
because the authored path has been deliberately relocated and its markers are
part of the content under test.

Each `GameCore.chunkPlaytest` call creates a fresh level and path source, then
uses the same scheduler prewarm, terrain authority, player/loadout setup,
systems, tick ordering, and snapshots as a normal Core. Restart is therefore a
new factory call with the same scenario, seed, player, loadout, and tick rate;
neither wall-clock time nor retained Core/input state participates. The tooling
run ID is always zero. Normal, ghost, and replay-validator callers continue to
use `GameCore(...)`, which always admits the checked-in artifact directly.

All construction paths follow the same ordering seam:

1. after world generation, atomically publish any fully built terrain bundle
   and its matching immutable render snapshot;
2. resolve captured enemy markers and procedural items through that published
   placement query, then capture/invalidate prior support against its version
   and audit exactly-once ownership;
3. let AI, jump, ordinary movement, mobility/teleport state, external velocity,
   and gravity compose motion;
4. integrate exactly once;
5. publish final transform/support/resolved motion before distance, death,
   camera, pickup broad phase, animation, and snapshots consume it.

Between preparation and integration, terrain-owned AI/locomotion consumers
read prior support through `WorldSupportView`; they must not read the reset
compatibility flags directly. Grounded enemy tuning resolves to one
signed scalar surface speed before gravity, and the authority converts that
intent into one support-distance solve. Accepted jump launch explicitly clears
prior support so the same tick remains world-space. Animation and ground-impact
death read final support only after integration.

The terrain enemy navigation adapter obtains its graph and placement
query from the same published runtime bundle. Bundle-version changes clear all
per-entity surface/path/active-edge state before AI; airborne player targeting
uses the terrain capsule trajectory predictor. Its output remains the existing
navigation-intent contract, including finite fallback bounds and active jump
timing consumed by the shared ground-enemy locomotion system. Normal Field and
Forest streams select this adapter from their published terrain authority.

Terrain authority rejects unknown enabled dynamic bodies and never falls
back to rectangle collision. Catalog-owned actors use their capsule policies;
physics-driven projectiles use a distinct continuous AABB terrain sweep in the
same motion phase. No replay field, saved state, UI, remote configuration, or
test-level tuning selects a second collision authority. The retained
`Staged*` type/file names identify the generated artifact format and publication
snapshot; they do not represent a selectable runtime mode. See the terrain
controller TDD for the authority and test-harness boundaries.

A harness replacement is built completely before queueing and becomes visible
at the next explicit world-publication/preparation boundary. It cannot be
queued mid-integration,
and motion rejects support from any version other than the published bundle.
Streaming-enabled normal and replay construction admit the generated staged
artifact, bind the scheduler's exact active chunk selection, and replace one
complete collision/navigation/render candidate after each spawn/cull rebuild.
The candidate owns simulation and rendering together. A streaming selection
with no admitted authored `chunkKey` fails construction or publication; it
never substitutes an unrelated generated record. Track-disabled synthetic
terrain has no staged render artifact because it exists only as a Core test
fixture.

Startup resolves the scheduler's initial selection before spawning the player
or any other ECS entity. `TrackManager` adopts that exact prewarmed streamer;
it never selects the opening chunks again. At startup and on later stream
changes, marker requests are captured in authored order, the matching complete
terrain candidate is built/published, then enemies are applied before
collectibles/restoration items as before. Marker rolls remain keyed by seed,
chunk, marker index, and salt. Collectible/restoration count draws, candidate
draws, salts, snapping, spacing, and attempt limits are unchanged. The terrain
authority validates each already-created candidate through a mutation-free
placement request that consumes no RNG. Terrain rejection consumes the existing
marker request or item attempt and never draws a replacement.
Therefore an invalid placement cannot shift any later marker roll or candidate
sequence.

Player death may enter a death-animation freeze: only animation advances until
the terminal `RunEndedEvent` is emitted. Any terminal end freezes normal
simulation and sets the run paused.

## Outputs and consumers

Core exposes immutable snapshots through `GameCore.buildSnapshot` and transient
events through `GameCore.drainEvents`.

- Snapshots are renderer/UI-friendly projections of ECS state; consumers treat
  them as read-only.
- Events are transient feedback and lifecycle records. Render/UI consumers may
  produce effects from them but must not resolve gameplay outcomes.
- `RunEndedEvent` is the terminal gameplay result used by client flow and
  replay validation.

Streaming-enabled normal and replay construction expose the selected staged
candidate's `StagedTerrainRenderSnapshot` and use its matching collision,
support, placement, and graph bundle. The snapshot may additionally contain
staged `none` polygons: their generated vertices, triangles, and material are
rendered, but the world-geometry builder omits them before every simulation
consumer and they cannot own exposed edges. Track-disabled fixtures use direct
polygon geometry and therefore leave the staged render artifact null. The
isolated terrain harness may queue a fully constructed staged candidate;
its exact collision/navigation bundle and render snapshot become visible
together only at the next preparation boundary. This read-only snapshot output
does not alter commands, replay serialization, or simulation outcomes.

`GameStateSnapshot` has one terrain-render contract: the staged polygon
snapshot paired with its runtime bundle. The former `staticSolids` and
`groundSurfaces` fields and all Flame fallback consumers are deleted.
`TrackManager` retains only scheduler selection, authored prefab visual
sprites, and deferred item batches. It has no collision geometry, spatial
index, horizontal surface graph, or legacy terrain snapshots.

The former `LegacyWorldMotionAuthority`, rectangle `CollisionSystem`,
`StaticWorldGeometry`/index, and horizontal navigation stack are deleted.
Actor systems that need placement or clearance receive the terrain authority
explicitly; construction cannot fall back when it is omitted.

Any snapshot/event shape or semantic change requires consumer updates in the
same change. If replay acceptance, score, or terminal outcome changes, the
validator must replay and assert the new behavior rather than infer it from UI.

## Determinism invariants

- Simulation time is fixed ticks. No wall-clock time or frame delta is gameplay
  authority.
- Random decisions use the existing deterministic RNG facilities seeded by the
  run; unseeded randomness is forbidden.
- Ordering-sensitive iteration and conflict resolution use stable store/entity
  order or an explicit stable tie-break.
- Tick conversion, numerical scaling, and content-derived values must remain
  deterministic for the same run configuration.
- Gameplay-authoritative Core never depends on Flutter, Flame, widgets, or
  backend I/O.

When changing any invariant, add a deterministic regression test and update
this document plus the relevant replay/consumer documentation.

## Authored content and generated outputs

Playable levels are authored under `assets/authoring/level/**`. The root
generator validates the source and produces runtime data for Core, Game, and
UI. Generated Core files include:

- `packages/runner_core/lib/levels/level_id.dart`
- `packages/runner_core/lib/levels/level_registry.dart`
- `packages/runner_core/lib/track/authored_chunk_patterns.dart`

Do not edit generated files by hand. Changes to chunk geometry, prefabs,
markers, level sequencing, or themes can alter deterministic simulation and
must be tested as gameplay changes.

## Required validation by change type

| Change | Minimum validation |
| --- | --- |
| Pure Core rule/system | `dart analyze packages/runner_core`; package tests; focused `test/core` coverage |
| Command/tick/order/determinism | Above, plus scheduling, determinism, and fixed-point tests; replay-validator tests if outcomes can change |
| Snapshot/event contract | Above, plus affected Game/UI consumer tests |
| Authored level/chunk/prefab/theme | Generator `--dry-run`, generator tests, focused Core tests, and affected Game/UI/editor checks |

The exact workflow checklists live in `.agent/workflows/`. Use the narrowest
relevant checks first, then broaden through each affected boundary.
