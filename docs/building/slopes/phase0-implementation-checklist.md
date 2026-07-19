# Slopes Phase 0 - Contract Freeze And Baseline Inventory Checklist

- Date: July 18, 2026
- Status: In progress
- Source plan: [plan.md](plan.md)
- Consumer inventory:
  [phase0-consumer-inventory.md](phase0-consumer-inventory.md)
- Technical defaults:
  [phase0-technical-contracts.md](phase0-technical-contracts.md)
- Gameplay decisions:
  [phase0-gameplay-decisions.md](phase0-gameplay-decisions.md)

## How To Use This Checklist

- `[x]` means the item is supported by recorded evidence, not merely discussed.
- `[ ]` means the work, decision, evidence, or approval is still outstanding.
- Record decisions in the ledgers in this document and update the referenced
  TDD/GDD in the same change.
- Record command results with date, source revision, and relevant environment.
- An unresolved contract item blocks Phase 0 acceptance even when a prototype
  appears to work.
- Do not begin production polygon authoring or collision-authority cutover from
  this checklist.
- Create the Phase 1 checklist only after the Phase 0 contracts are frozen.

## Phase 0 Goal

Remove architectural and gameplay ambiguity before implementing the new geometry
kernel.

Phase 0 must produce:

- a complete inventory of current flat-ground, rectangle-collision, actor-AABB,
  grounding, surface-navigation, spawn, render, and replay dependencies
- accepted player-facing slope and traversal rules
- frozen polygon, edge, capsule, support, spatial-index, and navigation
  contracts
- an explicit world-contact policy for every current player/enemy/body category
- deterministic numeric, ordering, identity, and quantization rules
- a representative slope scenario and replay-golden specification
- measured baselines and accepted performance/capacity budgets
- an operational compatibility and rollout contract
- a Phase 1 implementation checklist derived from the accepted contracts

## Phase 0 Exit Gate

Every item below must be true:

- [ ] Every affected production consumer has one recorded disposition:
      keep, derive, replace, remove, or explicitly unaffected.
- [ ] Player-facing traversal rules are accepted and documented in the GDD.
- [ ] Authoring polygon and migration contracts are frozen.
- [ ] Runtime terrain-edge, adjacency, seam, and spatial-index contracts are
      frozen.
- [ ] Capsule shape, solver, support-state, and system-ordering contracts are
      frozen.
- [ ] Player, projectile, pickup/trigger, and all current enemy policies are
      frozen.
- [ ] Sloped navigation/pathfinding and per-enemy traversal rules are frozen.
- [ ] Spawn, streaming, death-bound, rendering, and debug contracts are frozen.
- [ ] Determinism, replay compatibility, versioning, rollout, and rollback
      policies are frozen.
- [ ] Golden scenario fixtures and expected invariants are specified.
- [ ] Baseline measurements and Phase 1 performance budgets are recorded.
- [ ] Required TDD/GDD documents reflect the accepted decisions.
- [ ] The Phase 1 checklist exists and contains no unresolved Phase 0 decision.

## Scope Boundaries

### In scope

- documentation and contract decisions
- source/test consumer inventory
- current-behavior characterization tests where evidence is missing
- test-only geometry/replay fixture definitions or harness preparation
- deterministic and performance baseline measurements
- schema/content migration audit
- rollout and compatibility planning

### Out of scope

- production polygon editor controls
- production polygon/edge runtime authority
- production capsule collision cutover
- migrating committed content to the new schema
- removing `StaticSolid`, `StaticGroundSegment`, or current AABB physics
- deploying new compatibility versions or boards
- tuning gameplay by feel without an accepted GDD rule
- implementing Phase 1 geometry-kernel tasks

If a Phase 0 finding requires a production bug fix unrelated to contract
characterization, track and review that fix separately. Do not hide production
behavior changes inside the contract-freeze phase.

## Inherited Architecture Decisions

These decisions are already established by the source plan. Changing one
requires updating and re-accepting the source plan:

- [x] Core remains the sole gameplay/collision/navigation authority.
- [x] Static terrain is authored as simple snapped polygons.
- [x] Runtime static-world collision is performed against compiled terrain
      edges/segments.
- [x] Player and world-colliding actors use upright kinematic capsules.
- [x] Derived AABBs remain available for broad phase, combat overlap, triggers,
      culling, and debug use where appropriate.
- [x] Collision, support lookup, navigation, spawning, and rendering derive from
      one canonical geometry source.
- [x] The final production migration is a direct authority cutover with legacy
      runtime paths removed.
- [x] Static terrain only is in scope; moving/deformable/rotating terrain and
      general rigid-body physics remain out of scope.

## Step 0 - Pre-Flight And Baseline

### Instructions and workspace

- [x] Re-read:
  - [x] repository `AGENTS.md`
  - [x] `packages/runner_core/lib/AGENTS.md`
  - [x] `lib/game/AGENTS.md`
  - [x] `tools/editor/AGENTS.md`
  - [x] `packages/run_protocol/AGENTS.md` if a protocol change is proposed
  - [x] `services/replay_validator/AGENTS.md` before validator changes
  - [x] `docs/rules/code-documentation-policy.md`
- [x] Record the starting Git revision and dirty-worktree summary.
- [x] Confirm unrelated user changes are identified and excluded from Phase 0
      edits/validation conclusions.
- [x] Re-read the source plan and confirm no newer plan supersedes it.

### Current baseline commands

Run the smallest supported commands that establish the current state before
contract or characterization changes:

- [ ] `dart analyze`
- [x] `dart analyze packages/runner_core`
- [x] `flutter test test/core/determinism_test.dart`
- [x] `flutter test test/core/fixed_point_pilot_test.dart`
- [x] `flutter test test/core/platform_collision_test.dart`
- [x] `flutter test test/core/obstacle_collision_test.dart`
- [x] `flutter test test/core/surface_extraction_test.dart`
- [x] `flutter test test/core/surface_graph_builder_test.dart`
- [x] `flutter test test/core/surface_pathfinder_test.dart`
- [x] `flutter test test/core/track_streaming_test.dart`
- [x] `flutter test test/core/track_streamer_spawn_placement_test.dart`
- [x] `flutter test test/core/ground_enemy_obstacle_jump_test.dart`
- [x] `flutter test test/core/ground_enemy_gap_jump_test.dart`
- [x] `flutter test test/core/hashash_teleport_ambush_test.dart`
- [x] `dart run tool/generate_chunk_runtime_data.dart --dry-run`
- [x] `cd tools/editor && dart analyze`
- [ ] `cd tools/editor && flutter test`
- [x] `dart analyze services/replay_validator`
- [x] `cd services/replay_validator && dart test test`

Done when:

- [x] The baseline validation ledger records every result.
- [x] Any pre-existing failure is separated from Phase 0 work and has an owner
      or explicit accepted blocker.
- [x] Current deterministic golden behavior is captured before contracts
      change.

## Step 1 - Complete Consumer Inventory

### 1.1 Search inventory

Run and record searches for at least:

```text
groundTopY
StaticGroundPlane
StaticGroundGap
StaticGroundSegment
StaticSolid
StaticWorldGeometry
groundSurfaces
staticSolids
ColliderAabbDef
colliderAabb
grounded
hitCeiling
hitLeft
hitRight
oneWayTop
WalkSurface
SurfaceGraph
SurfaceNavigator
surfaceTopY
highestSurfaceAtX
obstacleTop
```

- [x] Record exact search commands and revision.
- [x] Record every production match, not only files expected to change.
- [ ] Review test matches to identify current invariants and coverage gaps.
- [ ] Review documentation matches for statements that will become stale.
- [ ] Repeat the inventory after Phase 0 documentation/characterization changes
      and record any new consumers.

### 1.2 Editor, schema, and generator

Review:

- `tools/editor/lib/src/prefabs/**`
- `tools/editor/lib/src/chunks/**`
- `tools/editor/lib/src/app/pages/prefabCreator/**`
- `tools/editor/lib/src/app/pages/chunkCreator/**`
- `assets/authoring/level/prefab_defs.json`
- `assets/authoring/level/chunks/**`
- `tool/generate_chunk_runtime_data.dart`
- `packages/runner_core/lib/track/authored_chunk_patterns.dart`

- [x] Inventory rectangle collider model/store/validation/scene ownership.
- [x] Inventory flat ground/gap model/store/validation/scene ownership.
- [x] Inventory anchor, scale, flip, snap, ordering, revision, and migration
      rules that polygons must preserve.
- [x] Inventory all generated `SolidRel` and `GapRel` assumptions.
- [x] Record current content counts:
  - [x] prefabs with zero, one, and multiple colliders
  - [x] overlapping/touching rectangle collider sets
  - [x] placed colliding prefabs by chunk
  - [x] chunks and gap layouts by level
  - [x] transformed/scale/flip combinations currently used
- [x] Identify content that cannot migrate mechanically under the proposed
      non-overlapping simple-polygon policy.

### 1.3 Core physics and ECS

Review:

- `packages/runner_core/lib/collision/**`
- `packages/runner_core/lib/ecs/stores/collider_aabb_store.dart`
- `packages/runner_core/lib/ecs/stores/body_store.dart`
- `packages/runner_core/lib/ecs/stores/collision_state_store.dart`
- `packages/runner_core/lib/ecs/collider_aabb_utils.dart`
- `packages/runner_core/lib/ecs/queries.dart`
- `packages/runner_core/lib/ecs/entity_factory.dart`
- `packages/runner_core/lib/ecs/systems/collision_system.dart`
- `packages/runner_core/lib/game_core.dart`
- player and enemy catalogs/registries

- [x] Inventory every body currently integrated by `CollisionSystem`.
- [x] Identify which bodies are dynamic, kinematic, gravity-driven, or
      ceiling/wall-ignoring.
- [x] Identify every system reading directional collision flags or `grounded`.
- [x] Identify every system using collider half extents/offsets as world-contact
      truth.
- [x] Identify every facing-dependent collider offset rule.
- [x] Identify every current fixed-point/quantization boundary.
- [x] Record current `GameCore.stepOneTick()` ordering dependencies.
- [x] Record every body that could be integrated twice if actor/projectile
      collision responsibilities split.

### 1.4 Player and abilities

Review both current player definitions:

- `PlayerCharacterId.eloise`
- `PlayerCharacterId.eloiseWip`

- [x] Record current collider dimensions/offsets and proposed capsule mapping for
      each player definition.
- [x] Inventory movement, gravity, jump, coyote, buffer, air-jump, dash/roll,
      mobility impact, knockback, death, animation, and camera dependencies.
- [x] Inventory score/distance calculations that depend on world-horizontal
      velocity or position.
- [x] Inventory cast/projectile origin calculations derived from collider
      bounds.
- [ ] Inventory ground-target ability and target-point placement behavior.
- [x] Inventory renderer aim previews that may need authoritative terrain-hit
      data.
- [x] Record whether achievements/progression consume grounded, distance,
      segment, death-reason, or run-result behavior affected by slopes.

### 1.5 Enemy archetypes

Record current and target policy for every `EnemyId`:

| Enemy | Current baseline | Target world-contact policy | Navigation/placement policy | Status |
| --- | --- | --- | --- | --- |
| `unocoDemon` | Dynamic flying body, no gravity, no side collision | Capsule and explicit flying contact policy | Terrain-clear flight profile pending | Gameplay open |
| `grojib` | Gravity-driven ground navigator, ignores ceilings | Upright capsule and support state | 45-degree maximum, 4-pixel step/snap, constant surface speed | Accepted |
| `hashash` | Gravity-driven ground navigator with teleport/ambush behavior | Upright capsule and support state | Graph plus capsule-safe teleport; 60-degree maximum accepted | Gameplay partial |
| `derf` | Kinematic stationary caster spawned on obstacle tops | Kinematic capsule clearance | Eligible support placement profile pending | Gameplay open |

- [ ] Freeze `unocoDemon` collision, terrain avoidance, culling, and flight-target
      reference policy.
- [x] Freeze `grojib` capsule, support, slope, jump/drop, and death-impact policy.
- [ ] Freeze `hashash` capsule, support, slope, jump/drop, teleport-clearance,
      ambush, spawn-animation, and death-impact policy.
- [ ] Freeze `derf` spawn support, slope eligibility, capsule clearance,
      stationary behavior, and target-point casting policy.
- [x] Inventory enemy engagement/melee/facing calculations using AABB extents or
      flat vertical assumptions.
- [x] Inventory enemy culling/death thresholds derived from `groundTopY`.
- [x] Verify no current or generated enemy ID is absent from the table.

### 1.6 Navigation and pathfinding

Review all files under `packages/runner_core/lib/navigation/**` plus:

- `EnemyNavigationSystem`
- `GroundEnemyLocomotionSystem`
- `GroundEnemyChaseOffsetStore`
- `SurfaceNavStateStore`
- `SpawnService`

- [x] Inventory horizontal `yTop` assumptions.
- [x] Inventory AABB footprint/standability assumptions.
- [x] Inventory surface extraction, merge, stable-ID, and shared-index rules.
- [x] Inventory walk, jump, and drop edge construction.
- [x] Inventory jump obstruction and clearance logic.
- [x] Inventory current/target surface lookup.
- [x] Inventory same-surface chase shortcuts.
- [x] Inventory trajectory prediction and landing selection.
- [x] Inventory path invalidation and graph-version behavior during streaming.
- [x] Inventory per-enemy jump templates and graph compatibility assertions.

### 1.7 Streaming, spawning, pickups, and death bounds

Review:

- `packages/runner_core/lib/track/**`
- `packages/runner_core/lib/track_manager.dart`
- `packages/runner_core/lib/spawn_service.dart`
- collectible/restoration systems
- teleport/ambush system
- player/enemy spawn construction
- fall/gap death and culling logic

- [x] Inventory base and streamed geometry merge/rebuild ownership.
- [x] Inventory chunk-local and world-space identity/order rules.
- [x] Inventory ground/highest-surface/obstacle-top placement.
- [x] Inventory deferred Hashash edge spawning.
- [x] Inventory player, enemy, collectible, and restoration placement clearance.
- [x] Inventory current pit/gap and kill/cull threshold behavior.
- [x] Identify all places that require a terrain query rather than a global
      `groundTopY`.

### 1.8 Projectiles, combat, pickups, and triggers

- [x] Inventory physics-driven projectile movement and terrain-despawn behavior.
- [x] Inventory non-physics projectile terrain behavior.
- [x] Inventory projectile/hitbox/target capsule-versus-AABB combat overlap
      helpers.
- [x] Inventory mobility-impact collision and whether it consumes world-contact
      or combat bounds.
- [x] Inventory collectible/restoration overlap and broad-phase ownership.
- [x] Inventory temporary hitboxes, sensors, and trigger-only bodies.
- [x] Assign final world-contact and derived-bound policy to each category.

### 1.9 Flame rendering and debug

Review:

- `lib/game/components/ground_surface.dart`
- `lib/game/components/ground_surface_layout.dart`
- `lib/game/components/ground_band_parallax_foreground.dart`
- `lib/game/components/temporary_floor_mask.dart`
- `lib/game/components/aim_ray.dart`
- `lib/game/runner_flame/live_world_sync_system.dart`
- `lib/game/runner_flame_game.dart`
- render/debug flags and AABB overlays

- [x] Inventory horizontal band rendering assumptions.
- [x] Inventory parallax bottom alignment and foreground clipping.
- [x] Inventory static-solid and actor-hitbox debug snapshots.
- [x] Inventory pixel snapping, texture phase, viewport clipping, and render
      interpolation assumptions.
- [x] Inventory aim-preview terrain dependencies.
- [x] Confirm no Flame component currently acts as collision/navigation
      authority.

### 1.10 Replay, protocol, backend, and ghosts

Review:

- `packages/run_protocol/lib/run_ticket.dart`
- replay blob and board-key contracts
- live replay recorder tests
- replay-validator Core construction and compatibility checks
- Functions board provisioning and run-session issuance
- ghost publication/playback compatibility

- [x] Inventory where `gameCompatVersion`, `rulesetVersion`, `scoreVersion`, and
      `ghostVersion` are authored and validated.
- [x] Inventory outstanding-session/ticket expiry and validator queue behavior.
- [x] Inventory how validator deployments obtain generated level content.
- [x] Inventory historical ghost behavior when physics changes.
- [x] Confirm whether any protocol field must change; default expectation is
      that physics/content compatibility changes without adding geometry to the
      replay blob.

Done when:

- [x] The inventory summary ledger has no unreviewed layer.
- [x] Every production match has a final disposition and owning phase.
- [x] Every current enemy/body category is represented.
- [x] Every identified coverage gap has a characterization-test task or an
      accepted rationale.

## Step 2 - Freeze Player-Facing Traversal Rules

Update `docs/gdd/01_controls.md` with accepted behavior and units.

### Slope and speed

- [x] Freeze player maximum walkable slope.
- [ ] Freeze default and per-enemy maximum walkable slopes.
- [x] Choose angle representation in authoring/tuning/runtime comparisons.
- [x] Decide world-horizontal X speed versus constant surface-arc speed.
- [x] Record consequences for distance, score, camera, and animation speed.
- [ ] Freeze enemy travel cost with the per-enemy traversal profiles.
- [x] Decide whether uphill/downhill traversal modifies acceleration, stamina,
      or movement speed.

### Support and transitions

- [x] Freeze contact skin width.
- [x] Freeze support-probe direction, length, and ordinary eligibility.
- [x] Freeze downward ground-snap distance and ordinary velocity limits.
- [x] Freeze support/snap clearing after jump, teleport, upward knockback, or
      body disable.
- [x] Freeze dash/roll-specific snap eligibility with the mobility decision.
- [x] Freeze flat-to-slope, slope-to-flat, convex-peak, and concave-valley
      behavior.
- [x] Decide whether slope changes may intentionally launch an actor.
- [x] Decide whether automatic player step-up is included.
- [x] Freeze maximum player step height and ordinary-locomotion eligibility.
- [x] Freeze ledge departure and coyote-time semantics.

### Jump, mobility, and one-way surfaces

- [x] Freeze jump direction; accepted baseline is world-up.
- [x] Freeze grounded dash/roll direction while supported.
- [x] Freeze grounded dash/roll speed while supported.
- [x] Freeze grounded dash/roll step/snap eligibility.
- [x] Freeze wall/ceiling response during mobility.
- [x] Freeze one-way sloped-platform collision side and crossing test.
- [x] Confirm drop-through-one-way input remains out of scope unless explicitly
      added.
- [x] Freeze behavior when a capsule lands on a one-way endpoint.

### Player feedback and run rules

- [ ] Freeze grounded/air animation signal behavior on slopes.
- [ ] Decide whether actor art stays upright; recommended baseline is yes.
- [ ] Freeze ground-target ability placement and aim-preview behavior.
- [ ] Freeze pit/fall-death authority independent of one global ground height.
- [ ] Freeze enemy culling below terrain/world bounds.
- [ ] Confirm whether achievements, score, distance, rewards, or leaderboard
      rules change.

Done when:

- [ ] Every item has one accepted rule and tuning owner.
- [ ] GDD language is player-facing and does not expose implementation guesses.
- [ ] No collision-kernel decision depends on an unresolved feel question.

## Step 3 - Freeze Polygon Authoring And Migration Contracts

### Source model

- [x] Freeze simple-polygon definition and coordinate system.
- [x] Freeze stable `shapeId` format and lifecycle.
- [x] Freeze vertex representation, grid/snap units, ordering, and canonical
      winding.
- [x] Freeze collision modes and their semantics:
  - [x] solid terrain/obstacle
  - [x] one-way platform
- [x] Decide whether semantic kind and collision mode are separate fields.
- [x] Decide whether gameplay/render material keys are included now or deferred.
- [x] Confirm holes, spline runtime collision, arbitrary rotation, non-uniform
      scale, and polygon boolean editing remain out of scope.

### Validation

- [x] Freeze rules for duplicate/collinear/zero-length vertices.
- [x] Freeze minimum edge length and polygon area.
- [x] Freeze self-intersection detection.
- [x] Freeze polygon overlap policy; baseline is blocking except exact shared
      boundaries.
- [x] Freeze prefab-source and chunk-bounds rules.
- [x] Freeze one-way winding/orientation and exposed-edge classification.
- [x] Freeze maximum polygons/vertices/edges per prefab and chunk.
- [x] Freeze deterministic diagnostics and validation ordering.

### Migration

- [x] Freeze rectangle-to-four-vertex-polygon mapping.
- [x] Freeze flat-ground-plus-gaps to terrain-polygons mapping.
- [x] Freeze revision/schema-version behavior for migrated prefabs/chunks.
- [x] Freeze current overlap/touch migration policy.
- [ ] Produce a content migration report with:
  - [ ] automatic migrations
  - [ ] blocking reauthor cases
  - [ ] expected generated-data churn
- [x] Freeze removal criteria for rectangle/flat-gap schema adapters.

### Editor and generator boundary

- [x] Confirm prefab and chunk domains reuse one polygon model/validation
      implementation where ownership permits.
- [x] Freeze editor undo/redo, vertex selection, scene controls, and export
      ownership at a contract level.
- [x] Freeze generator responsibility for transforms, normalization, adjacency,
      internal-edge removal, and stable ordering.
- [x] Freeze whether generated Dart retains polygons, precompiled edges, or
      both, and which representation each runtime consumer receives.

Done when:

- [ ] A schema example and migration example exist in the terrain TDD.
- [ ] Current content has a complete migration disposition.
- [x] Editor and generator ownership cannot diverge into parallel shape models.

## Step 4 - Freeze Runtime Terrain Geometry And Spatial Index

### Runtime types and identity

- [x] Freeze responsibilities of polygon, edge, edge ID, geometry bundle, and
      spatial-index types.
- [x] Freeze coordinate units and world/chunk-local conversion points.
- [x] Freeze stable runtime edge identity lineage:
  - [x] chunk index/key
  - [x] placed prefab identity/index where applicable
  - [x] local polygon ID/index
  - [x] local edge index
- [x] Freeze ordering and equality rules across generation, streaming, culling,
      and rebuild.
- [x] Freeze edge fields:
  - [x] endpoints
  - [x] outward normal or normal derivation input
  - [x] collision/one-way/walkable flags
  - [x] previous/next adjacency
  - [x] source identity
  - [x] query bounds

### Adjacency and seams

- [x] Freeze exact shared/internal-edge removal.
- [x] Freeze connected-edge/ghost-vertex representation.
- [x] Freeze smooth versus exposed vertex classification.
- [x] Freeze chunk seam matching, intentional ledge, and gap rules.
- [x] Freeze behavior as neighboring chunks spawn and cull.
- [x] Freeze navigation-chain continuity and renderer texture continuity across
      seams.

### Spatial index

- [x] Select the existing grid primitive to reuse or document why it cannot be
      reused.
- [x] Freeze cell size ownership/tuning.
- [x] Freeze edge insertion on exact cell boundaries.
- [x] Freeze query inclusivity and swept-AABB expansion.
- [x] Freeze candidate deduplication and stable sort.
- [x] Freeze reusable buffer ownership.
- [x] Freeze rebuild timing and graph/index versioning.

### Snapshots

- [x] Freeze immutable terrain polygon/edge snapshot ownership.
- [x] Freeze fields needed by fill rendering, debug edges/normals, one-way
      visualization, and source diagnostics.
- [x] Confirm snapshots are never read back as gameplay collision authority.
- [x] Freeze removal/migration of `StaticSolidSnapshot` and
      `GroundSurfaceSnapshot`.

Done when:

- [ ] The terrain TDD contains concrete type responsibilities and identity
      examples.
- [x] Seam behavior is unambiguous for continuous ground, ledges, and pits.
- [x] All consumers can query one canonical geometry without reconstructing
      flat bounds.

## Step 5 - Freeze Capsule, Solver, And Numeric Contracts

### Capsule and body roles

- [x] Freeze upright capsule parameterization:
  - [x] center/facing-dependent offset
  - [x] radius
  - [x] vertical half-segment length
  - [x] derived broad-phase AABB
- [x] Freeze validation for invalid/wide/short actor bounds.
- [x] Freeze current AABB-to-capsule migration and per-character/enemy override
      policy.
- [x] Freeze authoritative world-contact store versus derived broad-phase/combat
      store ownership.
- [x] Freeze shape policy for physics projectiles and other non-actor bodies.

### Geometry kernel

- [x] Select and document moving-capsule-versus-segment time-of-impact
      algorithm.
- [x] Freeze point/segment, closest-point, endpoint, penetration, and support
      operations.
- [x] Freeze degenerate input behavior.
- [x] Freeze whether normals are generated offline, derived at load, or derived
      per query.
- [x] Freeze squared-distance versus normalized calculations.

### Move-and-slide

- [x] Freeze requested-displacement construction.
- [x] Freeze swept candidate query.
- [x] Freeze earliest-contact selection and equal-time tie-break.
- [x] Freeze skin application.
- [x] Freeze velocity/displacement projection along contact tangent.
- [x] Freeze maximum contact iterations.
- [x] Freeze simultaneous floor/wall/ceiling resolution.
- [x] Freeze bounded initial-penetration recovery and failure behavior.
- [x] Freeze walkable-ground classification from normal/slope profile.
- [ ] Freeze support probing and snap after movement.
- [x] Freeze one-way prior-side/crossing/velocity tests.
- [x] Freeze behavior for capsule endpoint contact at sharp vertices.

### Numeric determinism

- [x] Freeze geometry epsilon, contact epsilon, tie epsilon, and skin units.
- [x] Freeze fixed-point pilot relationship to the final solver.
- [x] Freeze authoritative position/velocity/contact quantization points.
- [x] Freeze division/square-root/normalization policy.
- [x] Freeze candidate iteration and map/set ordering rules.
- [x] Freeze failure behavior when solver iteration limits are reached.

Done when:

- [x] An implementer can build the pure kernel without making a gameplay or
      numeric-policy choice.
- [x] Live and validator builds have one deterministic algorithm.
- [x] Hot-path allocation and iteration bounds are explicit.

## Step 6 - Freeze Support State, Player Integration, And System Order

### Support/contact state

- [x] Freeze grounded definition.
- [x] Freeze support edge/surface ID, point, normal, tangent, and validity/tick
      fields.
- [x] Freeze generalized wall/ceiling state and compatibility with current
      directional flags.
- [x] Freeze support clearing/persistence across jump, mobility, teleport,
      disable, death, and kinematic movement.
- [x] Freeze which systems may write versus read support.

### GameCore ordering

- [x] Freeze track streaming/stitching before terrain queries.
- [x] Freeze whether enemy navigation reads prior-tick or current-tick support.
- [x] Freeze jump clearing support before snap eligibility.
- [x] Freeze movement/mobility/gravity composition into one displacement.
- [x] Freeze actor capsule resolution order.
- [x] Freeze projectile movement/world-contact order.
- [x] Freeze death/culling/camera/distance/animation consumers after final
      authoritative transforms/support.
- [x] Freeze broad-phase rebuild and hit-detection ordering.
- [x] Prove no body integrates twice.
- [x] Record required `GameCore.stepOneTick()` documentation changes.

### Player integration disposition

- [x] Freeze both player capsule definitions or the shared derivation rule.
- [ ] Freeze movement acceleration/deceleration on support.
- [x] Freeze jump/coyote/buffer/air-jump integration.
- [x] Freeze dash/roll/mobility/knockback integration.
- [x] Freeze ceiling-ignore and side-mask replacement semantics.
- [x] Freeze animation, camera, score, distance, death, and origin-offset
      integration.
- [x] Freeze ground-target/aim-preview query boundary between Core and Game.

Done when:

- [x] Support has one writer/ordering contract.
- [x] Every current collision flag consumer has a final data source.
- [x] Player and projectile motion cannot be integrated twice or from stale
      support.

## Step 7 - Freeze Enemy Navigation And Pathfinding

### Shared surface geometry

- [x] Freeze walkable edge-chain/surface representation.
- [x] Freeze `yAt(x)`, tangent, normal, length, and endpoint semantics.
- [x] Freeze X-monotonic requirement or alternative lookup policy.
- [x] Freeze geometric surface identity shared across enemy profiles.
- [x] Freeze per-enemy walkability filtering without changing shared
      surface/index ordering.
- [x] Freeze chain merging/splitting across vertices and seams.

### Standability and lookup

- [x] Replace AABB full-footprint assumptions with a frozen capsule support
      policy.
- [x] Freeze narrow-surface and endpoint eligibility.
- [x] Freeze current/target surface lookup tolerances and tie-breaks.
- [x] Freeze player target lookup near ledges.
- [x] Freeze spawn eligibility versus navigation eligibility.

### Graph construction

- [ ] Freeze ordinary walk-edge generation and cost.
- [ ] Freeze slope arc-length versus horizontal/time-based traversal cost.
- [x] Freeze jump takeoff/landing samples using source/destination `yAt(x)`.
- [x] Freeze capsule clearance for jump paths.
- [x] Freeze landing slope eligibility.
- [x] Freeze drop-edge ledge departure and first-valid-landing selection.
- [x] Freeze one-way surface graph participation.
- [x] Freeze deterministic edge ordering/deduplication.
- [x] Freeze graph-version invalidation after streamed geometry changes.

### Runtime locomotion and AI

- [x] Freeze same-chain direct pursuit.
- [x] Freeze takeoff approach and in-flight commit direction.
- [x] Freeze landing completion.
- [x] Freeze chase-offset behavior on slopes.
- [ ] Freeze slope-following velocity for `grojib` and `hashash`.
- [x] Freeze stuck/invalid-plan fallback without hidden teleport authority.
- [x] Freeze player/enemy vertical-separation and engagement calculations.
- [x] Freeze trajectory prediction onto sloped surfaces.
- [ ] Freeze `unocoDemon`, `hashash`, and `derf` special placement/targeting
      rules from the enemy-policy table.

Done when:

- [ ] Every current enemy has an accepted policy.
- [ ] Collision and navigation use the same walkable-slope classification.
- [x] Shared surface identity remains compatible with per-enemy graphs.
- [x] Jump/drop feasibility is defined in terms of the final capsule kernel.

## Step 8 - Freeze Streaming, Spawn, Death, Rendering, And Debug Contracts

### Streaming and generated content

- [x] Freeze `ChunkPattern` replacement fields and generated-data ownership.
- [x] Freeze chunk build transform and stable identity propagation.
- [x] Freeze active-geometry flatten/stitch/cull order.
- [x] Freeze collision-index, snapshot, and per-enemy graph rebuild order.
- [x] Freeze behavior when one side of a seam is culled.
- [x] Confirm RNG selection and spawn-roll order remain unchanged or require
      explicit ruleset versioning.

### Spawn and placement

- [x] Freeze highest eligible terrain point query.
- [x] Freeze exact surface Y/normal/tangent evaluation.
- [x] Freeze full-capsule clearance query.
- [x] Freeze stable tie-break for vertically overlapping surfaces.
- [ ] Freeze slope/narrow-surface eligibility per actor/item.
- [x] Freeze initial player spawn.
- [x] Freeze enemy marker placement modes.
- [x] Freeze deferred Hashash edge spawn.
- [x] Freeze Derf obstacle-top placement.
- [x] Freeze collectible/restoration placement.
- [x] Freeze teleport destination validation.

### Death and culling

- [x] Select absolute, camera-relative, level-authored, or combined kill-bound
      policy.
- [x] Freeze pit/fall run-end behavior.
- [x] Freeze enemy below-world culling.
- [x] Freeze ground-impact death on sloped support.
- [x] Freeze behavior below high/low terrain without using local terrain Y as
      the sole world bound.

### Rendering and debug

- [x] Freeze terrain-fill snapshot/render contract.
- [x] Freeze triangulation ownership if required for rendering.
- [x] Freeze world-anchored texture coordinates and pixel snapping.
- [x] Freeze seam crack/texture-phase behavior.
- [x] Freeze foreground/parallax mask behavior.
- [x] Freeze temporary floor mask behavior.
- [x] Freeze render interpolation behavior while slope-supported.
- [x] Freeze debug overlays for source polygons, compiled edges, normals,
      one-way direction, seams, capsules, derived AABBs, support, and nav graph.
- [x] Confirm debug/render consumers cannot classify gameplay geometry
      independently.

Done when:

- [ ] Streaming, spawning, death, rendering, and navigation consume compatible
      geometry semantics.
- [ ] A continuous chunk seam has no physical, graph, or visible discontinuity.
- [ ] Every current placement mode has a sloped-terrain definition.

## Step 9 - Freeze Determinism, Replay, Compatibility, And Rollout

### Replay and compatibility

- [x] Freeze the new `gameCompatVersion`.
- [x] Freeze Competitive/Weekly `rulesetVersion`.
- [x] Decide and record whether `scoreVersion` changes.
- [x] Decide and record whether `ghostVersion` changes.
- [x] Confirm replay/command encoding remains unchanged or document the required
      protocol migration.
- [x] Freeze exact generated-content revision deployed with the compatible
      client and validator.
- [x] Freeze validator rejection behavior for incompatible tickets.
- [x] Freeze historical replay/ghost audit behavior.

### Deployment order

- [x] Freeze how old run issuance is stopped.
- [x] Record run-ticket/session expiry windows relevant to draining.
- [x] Freeze how uploaded/pending/validating old sessions drain before validator
      cutover.
- [x] Freeze new board provisioning order.
- [x] Freeze client, Functions/config, generated content, and validator deploy
      order.
- [x] Freeze rollback trigger and compatible component set.
- [x] Confirm no long-lived dual physics authority is required.

### Deterministic evidence

- [x] Define canonical geometry signature.
- [x] Define collision/support state included in deterministic signatures.
- [x] Define navigation graph/path signature.
- [x] Define representative full-run signature.
- [x] Define live recorder versus validator comparison.
- [x] Freeze epsilon/tolerance policy for tests versus exact canonical state.

Done when:

- [x] No incompatible ticket can be replayed under the wrong physics/content.
- [x] Deployment and rollback preserve one compatible component set.
- [ ] Golden evidence detects player, enemy, support, graph, score, and end-state
      drift.

## Step 10 - Specify Golden Scenarios And Performance Budgets

### 10.1 First playable slope scenario

Define a deterministic Core fixture containing:

- [ ] flat terrain
- [ ] allowed ascent in both travel directions
- [ ] allowed descent in both travel directions
- [ ] flat-to-slope and slope-to-flat transitions
- [ ] convex peak
- [ ] concave valley
- [ ] continuous cross-chunk seam
- [ ] intentional ledge and pit
- [ ] slope exactly at the player limit
- [ ] slope just above the player limit
- [ ] solid steep wall
- [ ] ceiling/sloped underside
- [ ] one-way sloped platform
- [ ] narrow/non-standable peak
- [ ] overlapping vertical surface candidates where tie-break matters

Record snapped coordinates only after the authoring coordinate contract is
frozen.

### 10.2 Player scenario matrix

- [ ] idle/support persistence
- [ ] start/stop/reverse
- [ ] normal and maximum run speed
- [ ] jump/coyote/buffer/air jump
- [ ] uphill/downhill dash or roll
- [ ] knockback into floor/wall/ceiling
- [ ] land on slope at multiple velocities
- [ ] leave ledge and fall into pit
- [ ] one-way pass-through and landing
- [ ] ground-target ability/aim preview
- [ ] deterministic score/distance/end reason
- [ ] both player definitions

### 10.3 Enemy scenario matrix

- [ ] `grojib` pursuit across walkable slopes, seam, jump, and drop
- [ ] `hashash` pursuit plus valid/invalid teleport destinations
- [ ] `unocoDemon` flight/terrain/culling behavior
- [ ] `derf` placement and target-point casting from eligible support
- [ ] target moving across chains and becoming airborne
- [ ] graph rebuild while enemies hold paths
- [ ] death/ground-impact behavior on slopes

### 10.4 Determinism fixtures

- [ ] geometry compiler/edge signature fixture
- [ ] capsule contact-order fixture
- [ ] navigation graph signature fixture
- [ ] command-stream replay fixture
- [ ] repeated fresh-Core comparison
- [ ] client recorder versus validator comparison
- [ ] stream/cull/rebuild identity comparison

### 10.5 Performance and capacity ledger

Measure current baseline where an equivalent exists and freeze Phase 1 targets:

| Metric | Baseline | Phase 1/target budget | Fixture/environment | Status |
| --- | --- | --- | --- | --- |
| Polygons per prefab | Pending | Pending | Pending | Open |
| Vertices/edges per chunk | Pending | Pending | Pending | Open |
| Active streamed edges | Pending | Pending | Pending | Open |
| Static-index rebuild | Pending | Pending | Pending | Open |
| Player query candidates/tick | Pending | Pending | Pending | Open |
| Enemy query candidates/tick | Pending | Pending | Pending | Open |
| Actor solver time/tick | Pending | Pending | Pending | Open |
| Per-enemy graph build | Pending | Pending | Pending | Open |
| All-graphs rebuild | Pending | Pending | Pending | Open |
| Steady-state allocations | Pending | Pending | Pending | Open |
| Validator replay duration | Pending | Pending | Pending | Open |
| Editor polygon interaction | Pending | Pending | Pending | Open |

- [ ] Define reference hardware/runtime for client measurements.
- [ ] Define validator environment for replay measurements.
- [ ] Define representative edge/enemy/chunk counts.
- [ ] Define failure/action when authoring capacity exceeds a budget.
- [ ] Record measurement scripts or commands so results are reproducible.

Done when:

- [ ] Golden scenarios cover all contract boundaries.
- [ ] Every performance metric has a reproducible fixture and accepted budget.
- [ ] Phase 1 tests can be written without inventing expected behavior.

## Step 11 - Documentation And Phase 1 Handoff

### Required docs

- [ ] Create `docs/tdd/static_terrain_geometry_and_capsule_collision.md`.
- [ ] Update `docs/gdd/01_controls.md`.
- [ ] Update `docs/gdd/combat/combat_system_design.md`.
- [ ] Update the source plan with frozen decisions and Phase 0 status.
- [ ] Update editor/chunk documentation links if authoring ownership changes.
- [ ] Update replay-validator compatibility documentation.
- [ ] Update relevant AGENTS files only if working rules/boundaries actually
      change.
- [ ] Ensure proposed/incomplete behavior remains in `docs/building/**`, not
      described as implemented in TDD/GDD.

### Decision and evidence closure

- [ ] Complete the decision ledger.
- [ ] Complete the inventory summary ledger.
- [ ] Complete the baseline validation ledger.
- [ ] Complete the performance/capacity ledger.
- [ ] Record all deferred items with owner/trigger.
- [ ] Record all blockers and resolve them before acceptance.

### Phase 1 checklist

- [ ] Create `docs/building/slopes/phase1-implementation-checklist.md` only after
      the above contracts are accepted.
- [ ] Derive Phase 1 tasks from the frozen geometry/numeric contracts.
- [ ] Keep Phase 1 limited to the pure geometry kernel and static edge index
      described by the source plan.
- [ ] Include exact tests, file targets, performance gates, and removal criteria.
- [ ] Do not create Phase 2+ detailed checklists until the preceding phase
      resolves its implementation findings.

Done when:

- [ ] Phase 1 contains no open product, ownership, numeric, or compatibility
      choice.
- [ ] Documentation clearly separates current behavior, accepted target
      contracts, and future implementation.

## Step 12 - Phase 0 Validation

Run validation appropriate to actual Phase 0 changes.

### Documentation-only minimum

- [ ] All local Markdown links in this folder resolve.
- [ ] `git diff --check`
- [ ] No proposed behavior is incorrectly described as implemented.
- [ ] Source plan and checklist statuses/links agree.

### Characterization fixture or source-test changes

When Phase 0 adds or changes test fixtures/harness code:

- [ ] `dart analyze`
- [ ] focused Core tests changed by the fixture work
- [ ] `flutter test test/core/determinism_test.dart`
- [ ] `flutter test test/core/fixed_point_pilot_test.dart`
- [ ] replay recorder/validator comparison tests if changed
- [ ] generator dry-run if authored/generated fixtures changed
- [ ] editor analysis/tests if editor fixture or validation code changed

### Final baseline recheck

- [ ] Re-run the accepted baseline command set from Step 0.
- [ ] Record all results in the validation ledger.
- [ ] Confirm failures are not hidden by changed expectations or loosened
      tolerances.

Done when:

- [ ] All required validation passes or has an explicitly accepted external
      blocker.
- [ ] No determinism, auth, replay, revision, or source-drift invariant is
      weakened.

## Decision Ledger

Use stable IDs in reviews and downstream checklists.

| ID | Decision | Status | Authoritative doc/section | Evidence/approval |
| --- | --- | --- | --- | --- |
| `SLP-P0-001` | Player maximum slope | Accepted | Gameplay decisions, Decision 1; technical defaults §18 | User selected 60 degrees inclusive on July 19, 2026 |
| `SLP-P0-002` | Per-enemy slope profiles | Gameplay in progress | Gameplay decisions, Decision 10+ | Grojib profile and Hashash 60-degree limit accepted July 19, 2026; Hashash small-transition tolerance is next |
| `SLP-P0-003` | Horizontal versus surface-arc speed | Accepted | Gameplay decisions, Decision 2; technical defaults §18 | User selected the continuous signed-slope X-speed curve on July 19, 2026 |
| `SLP-P0-004` | Ground snap/skin/step policy | Accepted | Technical defaults §§9-10 and §18; gameplay decisions | Player ordinary and grounded-mobility step/snap accepted at 4 world pixels on July 19, 2026 |
| `SLP-P0-005` | Sharp vertex and seam behavior | Accepted | Technical defaults §§6, 9, and 10; gameplay decisions | User accepted no artificial launch impulse on July 19, 2026 |
| `SLP-P0-006` | One-way sloped platform behavior | Accepted | Technical defaults §§3, 6, 9, and 18; gameplay decisions | User preserved pass-from-below behavior without drop-through on July 19, 2026 |
| `SLP-P0-007` | Polygon schema and overlap policy | Accepted technical default | Technical defaults §§3-4 | Safe-default authority granted July 18, 2026 |
| `SLP-P0-008` | Edge identity/adjacency/compiler contract | Accepted technical default | Technical defaults §§5-7 | Safe-default authority granted July 18, 2026 |
| `SLP-P0-009` | Capsule representation and body roles | Accepted technical default | Technical defaults §8 | Safe-default authority granted July 18, 2026 |
| `SLP-P0-010` | Sweep/solver/numeric policy | Accepted technical default | Technical defaults §9 | Safe-default authority granted July 18, 2026 |
| `SLP-P0-011` | Support state and system ordering | Accepted technical default | Technical defaults §§10-11 | Safe-default authority granted July 18, 2026 |
| `SLP-P0-012` | Sloped surface graph/path costs | Technical accepted; gameplay pending | Technical defaults §12; gameplay decisions | Graph/clearance contract accepted; speed/cost semantics remain open |
| `SLP-P0-013` | Current enemy policies | Gameplay pending | Consumer inventory §9; gameplay decisions | Mechanical migration mapped; traversal profiles remain open |
| `SLP-P0-014` | Spawn/teleport/clearance policy | Technical accepted; gameplay pending | Technical defaults §13; gameplay decisions | Clearance/fallback accepted; steep/narrow eligibility remains open |
| `SLP-P0-015` | Kill bound and enemy culling policy | Accepted technical default | Technical defaults §13 | Safe-default authority granted July 18, 2026 |
| `SLP-P0-016` | Terrain render/snapshot contract | Accepted technical default | Technical defaults §14 | Safe-default authority granted July 18, 2026 |
| `SLP-P0-017` | Replay/version/rollout contract | Accepted technical default | Technical defaults §§15-16 | Reserved compatibility set; issuance remains prohibited |
| `SLP-P0-018` | Golden fixtures and performance budgets | In progress | Technical defaults §§16-17; checklist Step 10 | Initial budgets accepted provisionally; fixtures/measurements pending |
| `SLP-P0-019` | Player jump/dash/roll slope behavior | Accepted | Gameplay decisions, Decisions 6-9; technical defaults §§10 and 18 | World-up jump plus support-tangent, constant-surface-distance, 4-pixel-helper grounded mobility accepted July 19, 2026 |

Phase 0 cannot close with any decision row marked `Open`, `Pending`,
`Awaiting`, or `In progress`.

## Inventory Summary Ledger

| Area | Matches/items reviewed | Keep | Derive | Replace | Remove | Unresolved | Evidence |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Editor/schema/generator | 13 | 5 | 1 | 7 | 0 | 0 | Consumer inventory §§3-4 |
| Core geometry/index | 6 | 1 | 0 | 5 | 0 | 0 | Consumer inventory §5 |
| ECS bodies/collision/support | 5 | 2 | 1 | 2 | 0 | 0 | Consumer inventory §§6-7 |
| Player/abilities | 11 | 7 | 2 | 2 | 0 | 0 | Consumer inventory §8 |
| Enemies | 10 | 4 | 2 | 4 | 0 | 4 | Consumer inventory §9; gameplay profiles pending |
| Navigation/pathfinding | 10 | 5 | 1 | 4 | 0 | 1 | Consumer inventory §9; gameplay cost rule pending |
| Streaming/spawning/items | 12 | 5 | 2 | 5 | 0 | 1 | Consumer inventory §10; eligibility rule pending |
| Projectiles/combat/triggers | 10 | 6 | 2 | 2 | 0 | 0 | Consumer inventory §11 |
| Rendering/debug | 9 | 3 | 1 | 4 | 1 | 0 | Consumer inventory §12 |
| Replay/protocol/backend/ghost | 8 | 5 | 0 | 3 | 0 | 0 | Consumer inventory §13; technical defaults §15 |
| Tests/docs | 8 | 8 | 0 | 0 | 0 | 2 | Consumer inventory §14; golden/performance evidence pending |

Required evidence for each reviewed consumer:

- current responsibility
- final disposition
- replacement owner/type where applicable
- delivery phase
- characterization/regression test
- documentation impact

## Baseline Validation Ledger

| Date/revision | Command | Environment | Result | Evidence/notes |
| --- | --- | --- | --- | --- |
| 2026-07-18 / `d924895` | Seven focused Core tests: determinism, fixed-point pilot, platform, obstacle, surface extraction, graph builder, pathfinder | Windows local checkout; pre-existing dirty tree | Pass, 31 tests | Current deterministic/collision/navigation characterization |
| 2026-07-18 / `d924895` | Five focused Core tests: streaming, spawn placement, obstacle jump, gap jump, Hashash ambush | Windows local checkout; pre-existing dirty tree | Pass, 10 tests | Streaming/enemy/spawn characterization |
| 2026-07-18 / `d924895` | `dart run tool/generate_chunk_runtime_data.dart --dry-run` | Windows local checkout | Pass | 8 chunks, 2 levels, and 2 parallax themes validated |
| 2026-07-18 / `d924895` | `dart analyze packages/runner_core` | Windows local checkout | Pass | No issues |
| 2026-07-18 / `d924895` | `cd tools/editor && dart analyze` | Windows local checkout | Pass on isolated rerun | First parallel attempt exceeded the 60-second capture window; rerun had no issues |
| 2026-07-18 / `d924895` | `dart analyze services/replay_validator` | Windows local checkout with unrelated validator changes | Pass | No issues; result describes the user's current dirty validator slice |
| 2026-07-18 / `d924895` | `cd services/replay_validator && dart test test` | Windows local checkout with unrelated validator changes | Pass, 40 tests | Initial root-package invocation was invalid and failed package resolution; corrected package-local command passed |
| 2026-07-18 / `d924895` | `dart analyze` | Windows local checkout; pre-existing dirty tree | Inconclusive: timed out after about 64 seconds | No diagnostic was captured; rerun before Phase 0 acceptance |
| 2026-07-18 / `d924895` | Focused editor prefab/chunk suite (8 named test targets) | Windows local checkout | Inconclusive: timed out after about 64 seconds | No output captured; full editor suite remains open |

The focused editor invocation covered `prefab_store_test.dart`,
`prefab_validation_test.dart`, `prefab_runtime_adapter_test.dart`,
`chunk_store_test.dart`, `chunk_validation_test.dart`,
`chunk_domain_plugin_test.dart`, `chunk_domain_plugin_integration_test.dart`,
and `chunk_creator_page_test.dart`.

## Blockers And Deferred Items

| Item | Reason | Owner | Resolution/trigger | Blocks Phase 0? |
| --- | --- | --- | --- | --- |
| Broad root analysis did not finish in the capture window | Result is unknown, not a product failure | Slopes Phase 0 | Rerun with a longer local/CI window before acceptance | Yes, acceptance only |
| Focused editor suite did not finish in the capture window | Result is unknown, not a product failure | Slopes Phase 0 | Run the full editor suite before acceptance | Yes, acceptance only |

## Final Phase 0 Acceptance

### Inventory

- [ ] Search inventory is complete and repeatable.
- [ ] Every production consumer has a disposition and owning phase.
- [ ] Both player definitions and all four current enemies are covered.
- [ ] Projectiles, pickups, triggers, abilities, rendering, and replay are
      covered.

### Contracts

- [ ] GDD traversal rules are accepted.
- [ ] Polygon/schema/migration contract is accepted.
- [ ] Edge/adjacency/seam/spatial-index contract is accepted.
- [ ] Capsule/solver/numeric/support/system-order contract is accepted.
- [ ] Navigation/enemy/spawn/death/render contract is accepted.
- [ ] Replay/version/rollout contract is accepted.

### Evidence

- [ ] Golden fixture specification is complete.
- [ ] Determinism signatures are defined.
- [ ] Performance baselines and budgets are recorded.
- [ ] Baseline/final validation results are recorded.
- [ ] Decision and inventory ledgers contain no open/unresolved rows.
- [ ] Blocker table contains no Phase 0 blocker.

### Handoff

- [ ] Required TDD/GDD documentation is current.
- [ ] Source plan marks Phase 0 accepted with evidence.
- [ ] Phase 1 implementation checklist exists and follows frozen contracts.
- [ ] Phase 2+ detailed checklists remain intentionally deferred.

Only after every final acceptance item is checked may Phase 0 be marked complete
and Phase 1 implementation begin.
