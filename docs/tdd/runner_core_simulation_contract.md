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

World-motion ownership is selected once when `GameCore` is constructed. Normal
streamed construction performs the scheduler prewarm, installs the multi-body
capsule authority from that exact admitted candidate before player placement,
and atomically consumes later spawn/cull candidates. Replay validation inherits
the same path without a serialized authority option. The test/tool-only
`GameCore.terrainMotionHarness` factory remains available for focused synthetic
geometry, while track-disabled legacy fixtures are temporary Phase 6 cleanup
targets rather than a production selection mode.

Both owners follow the same ordering seam; the terrain-only publication step is
a no-op for legacy ownership:

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
legacy compatibility flags directly. Grounded enemy tuning resolves to one
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
same motion phase. No replay field, saved state, UI, or remote configuration
selects terrain versus legacy behavior. See the terrain controller TDD for the
staged boundary and remaining legacy-deletion requirements.

A harness replacement is built completely before queueing and becomes visible
at the next explicit world-publication/preparation boundary. It cannot be
queued mid-integration,
and motion rejects support from any version other than the published bundle.
Streaming-enabled normal and replay construction admit the generated staged
artifact, bind the scheduler's exact active chunk selection, and replace one
complete collision/navigation/render candidate after each spawn/cull rebuild.
The candidate owns simulation and rendering together. A synthetic custom
selection with no authored `chunkKey` publishes no staged snapshot and remains
on the temporary track-disabled/custom-fixture cleanup path; it never
substitutes an unrelated generated record.

Startup resolves the scheduler's initial selection before spawning the player
or any other ECS entity. `TrackManager` adopts that exact prewarmed streamer;
it never selects the opening chunks again. At startup and on later stream
changes, marker requests are captured in authored order, the matching complete
terrain candidate is built/published, then enemies are applied before
collectibles/restoration items as before. Marker rolls remain keyed by seed,
chunk, marker index, and salt. Collectible/restoration count draws, candidate
draws, salts, snapping, spacing, and attempt limits are unchanged. The selected
world-motion authority validates each already-created candidate through a
mutation-free placement request that consumes no RNG. Legacy authority commits
the historical rectangle candidate exactly; terrain rejection consumes the
existing marker request or item attempt and never draws a replacement.
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
support, placement, and graph bundle. Track-disabled fixtures and a custom
source with an anonymous active chunk leave it null. The isolated terrain
harness may queue a fully constructed staged candidate;
its exact collision/navigation bundle and render snapshot become visible
together only at the next preparation boundary. This read-only snapshot output
does not alter commands, replay serialization, or simulation outcomes.

`GameStateSnapshot` has one terrain-render contract: the staged polygon
snapshot paired with its runtime bundle. The former `staticSolids` and
`groundSurfaces` fields and all Flame fallback consumers are deleted.
`TrackManager` retains scheduler selection and authored prefab visual sprites;
its internal legacy read models remain temporarily available only to
track-disabled synthetic tests during the dependency-ordered Phase 6 cleanup.

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
