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
| 1 | Stream/cull track, obtain the complete staged candidate, publish any queued terrain bundle, place the captured enemy/item batch, and prepare motion | An exact prepared selection may replace synchronous construction; no consumer may observe a partial candidate or mixed terrain/index/surface/graph versions. AI receives validated prior support. |
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

Interactive hosts opt into `GameCore.prepareTerrainAhead()` during loading.
Core projects eight upcoming spawn/cull selection states and builds complete
candidates from admitted bindings in a background Dart isolate. Publication
still uses the actual scheduler selection and live monotonic geometry version;
cache readiness cannot change the publication tick, RNG, commands, or results.
A miss uses the original synchronous builder. Headless validation does not need
to enable preparation. See [terrain preparation](sloped_navigation_and_enemy_terrain.md#background-terrain-preparation)
for matching, capacity, failure, and lifetime rules.

`LevelDefinition.identity`, `GameCore.levelIdentity`, and
`GameStateSnapshot.levelIdentity` carry one typed provenance value.
`RegisteredLevelIdentity` wraps the existing protocol-stable `LevelId`;
`AuthoredLevelIdentity` retains a validated authored string, including identities
that have never been generated. Their equality preserves provenance even when
the strings match. Normal `LevelDefinition(id: LevelId, ...)` remains available;
`LevelDefinition.authored` is the explicit tooling configuration constructor.
Copies retain identity. Normal `GameCore(...)` rejects authored identity before
world initialization; production consumers resolve `requireRegisteredId()` at
registered-only boundaries. This does not change ticket/replay identities or
backend authorization.

Registered identity is separate from compiled content availability. Generated
`LevelRegistry.compiledLevelIds` includes Build-enabled active and deprecated
levels, while `defaultLevelId` is an included active level. An excluded stable
enum remains addressable as metadata; `requireAvailable` and `byId` fail with
`LevelUnavailableException` before absent terrain pools can be constructed.
Normal app selection uses generated selectable metadata and restores stale
local choices to the generated default. Ticket, replay, and ghost IDs are never
substituted. Validator content absence remains an internal/configuration failure
through the worker's existing retry/grace policy rather than a replay rejection.

`GameCore.chunkPlaytest` and `GameCore.levelPlaytest` are explicit tool-only
construction boundaries. They accept validated immutable scenarios, never a
flag on the production constructor or a serialized ticket/replay option.
`StagedTerrainChunkCatalog` admits captured, individually compiled terrain
records with the same structural checks and world bindings as generated terrain.
Scenario construction owns the scheduler/seam checks; Core does not import the
content pipeline or read repository sources.

`ChunkPlaytestScenario` receives the captured level terrain pool plus the selected
pattern/terrain draft. It replaces or adds that stable key, so the first chunk of
a never-generated level needs no generated placeholder. Preparation:

1. freezes pattern and assembly collections and requires matching selected key,
   level, group, active status, and streamed width;
2. re-runs canonical authoring reachability using captured tier/group/status;
3. chooses an incoming transition when available, then follows canonical
   transition-record order until the finite path has a deterministic loop; and
4. validates every reachable seam touching the selected chunk and every loop/path
   seam using Core's exact boundary signatures.

The resulting focused path places the selected chunk near the start. It adds no
flat pad or substitute collision and uses captured content for every key. Opening
enemy suppression is cleared to test authored markers. This focused loop does
not claim to reproduce the actual seeded whole-level sequence.

`LevelPlaytestScenario` preserves real automatic/ordered selection, consecutive
pacing windows, enemy suppression, seed, camera, and ground values. Admission
requires the complete active pattern pool to match its captured terrain by unique
key, level, tier, group, and runtime width. It rejects missing/foreign records,
empty pools, impossible resolved distinct capacity, and every incompatible
reachable seam before Core construction. Inactive terrain cannot enter a playable
pool. Source compilation and fresh semantic signatures remain the content
pipeline's responsibility; typed records do not bypass that preparation boundary.

`LevelPlaytestScenario.sampleChunks(count: 12)` provides a bounded read-only
opening projection from a fresh instance of that same seeded source. Streaming
and projection share the canonical pacing-tier function. Each selected chunk
reports its requested/resolved tier, group, opening enemy suppression and resolved
section run/boundary, including repeated final sections for non-looping assembly.
The projection does not predict individual enemy spawn rolls or mutate the
running simulation. The editor uses returned chunk keys to select source
thumbnails instead of implementing its own scheduler.

Each playtest factory creates a fresh level/source with the same normal scheduler
prewarm, terrain authority, player/loadout setup, tick ordering, and snapshots.
Restart uses the captured seed/character/loadout/tick rate with run ID zero and
no retained simulation/input state. Normal, ghost, and replay-validator callers
continue using the registered `GameCore(...)` path with generated terrain.

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
support, placement, and graph bundle. The snapshot renders direct Chunk
polygons and their separately generated direct material edges; placed Prefab
polygons remain in collision geometry but their sprites own their visuals. The
snapshot may additionally contain staged `none` polygons: their generated
vertices, triangles, and material are rendered, but the world-geometry builder
omits them before every simulation consumer and they cannot own exposed edges.
Track-disabled fixtures use direct
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

`ChunkVisualSpriteRel.zIndex` and `StaticPrefabSpriteSnapshot.zIndex` carry
render-only layers relative to the owning Chunk's terrain plane. The shared
content pipeline subtracts authored `groundBandZIndex` from each Prefab z;
Core streams the result unchanged. Negative layers render behind terrain,
while zero and positive layers render over it. This normalization affects
neither collision nor command/replay/settlement contracts.

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


## Authored terrain selection

Normal Core binds authored chunk pools to compiled terrain with
`ConnectedChunkPatternSource` before prewarming or streaming. Its admitted
continuations, spawn rules, seeded salts and bounded cursor are specified in
[chunk connections](chunk_connections.md). Level Play and replay consume the same
Core rules. This selection change is versioned as game compatibility 2026.09.0.
