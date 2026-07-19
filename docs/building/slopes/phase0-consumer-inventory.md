# Slopes Phase 0 - Consumer Inventory

- Date: July 18, 2026
- Source revision: `d924895cf32f25abd6fdc4f3317fbfbc9936dcc9`
- Status: First production-consumer pass complete; validation and final repeat
  search remain open
- Source checklist:
  [phase0-implementation-checklist.md](phase0-implementation-checklist.md)
- Technical contracts:
  [phase0-technical-contracts.md](phase0-technical-contracts.md)

## 1) Evidence Rules

This document records the current implementation and the intended migration
disposition. It does not claim that the slope implementation already exists.

The inventory was performed with read-only searches and source inspection. The
working tree already contained unrelated user work in Functions, replay
validation, UI, and other documentation. Phase 0 documentation edits are
limited to `docs/building/slopes/**` plus the already-linked chunk-editor plans.
No conclusion in this inventory treats the unrelated dirty files as Phase 0
changes.

The primary search command was:

```text
rg -n --fixed-strings <term> packages/runner_core lib tools/editor \
  packages/run_protocol services/replay_validator test docs
```

The file-list follow-up used:

```text
rg -l <grouped-pattern> packages/runner_core/lib lib/game tools/editor/lib \
  packages/run_protocol/lib services/replay_validator/lib
```

The search must be repeated at the end of Phase 0 and again when the legacy
runtime representation is removed.

## 2) Required-Term Search Ledger

Counts include production, test, and documentation files. The production
consumers are classified in Sections 4-13.

| Search term | Matching files | Primary ownership found |
| --- | ---: | --- |
| `groundTopY` | 50 | Level/chunk schema, streaming, spawn, death/cull, editor |
| `StaticGroundPlane` | 17 | Core collision/index, levels, collision/nav tests |
| `StaticGroundGap` | 14 | Core collision, streaming, navigation, tests |
| `StaticGroundSegment` | 17 | Core collision, streaming, navigation, tests |
| `StaticSolid` | 34 | Core collision/streaming/snapshots, Game debug rendering |
| `StaticWorldGeometry` | 31 | Core geometry/index, TrackManager, navigation, tests |
| `groundSurfaces` | 20 | Core snapshots/determinism, Game ground rendering |
| `staticSolids` | 14 | Core snapshots/determinism, Game debug rendering |
| `ColliderAabbDef` | 49 | Actor/projectile/pickup definitions and combat tests |
| `colliderAabb` | 43 | World contact, combat bounds, spawn, snapshots, culling |
| `grounded` | 64 | Collision, jump, AI, death, animation, snapshots, tests |
| `hitCeiling` | 4 | Collision store/writer and projectile despawn |
| `hitLeft` | 4 | Collision store/writer and projectile despawn |
| `hitRight` | 4 | Collision store/writer and projectile despawn |
| `oneWayTop` | 24 | Authoring/generation, collision, snapshots, tests |
| `WalkSurface` | 15 | Navigation types/extraction/index/path tests |
| `SurfaceGraph` | 29 | Navigation, TrackManager, spawn, enemy AI, tests |
| `SurfaceNavigator` | 17 | Enemy navigation and traversal tests |
| `surfaceTopY` | 5 | Streaming spawn requests and GameCore spawn routing |
| `highestSurfaceAtX` | 6 | Authoring marker modes and runtime spawn resolution |
| `obstacleTop` | 9 | Authoring marker modes, Derf spawn resolution, tests |

`groundSurfaces` and `staticSolids` are snapshot field names. The authoritative
Core geometry fields are currently `groundSegments`, `solids`, and
`groundGaps`.

## 3) Authored Content Baseline

### Prefabs

Source: `assets/authoring/level/prefab_defs.json`, schema version 2.

| Metric | Count |
| --- | ---: |
| Prefabs | 99 |
| Decoration prefabs | 29 |
| Obstacle prefabs | 66 |
| Platform prefabs | 4 |
| Prefabs with zero colliders | 29 |
| Prefabs with one collider | 41 |
| Prefabs with multiple colliders | 29 |
| Authored rectangle colliders | 116 |

The 29 zero-collider prefabs are the 29 decorations. Collision-bearing
obstacles/platforms therefore all have at least one collider in the current
valid source.

The following multi-collider prefabs contain at least one touching or
overlapping pair and require deterministic union analysis during migration:

- `anvil_00`
- `boolder_pile_00`
- `boolder_pile_01`
- `boolder_pile_02`
- `dark_dead_tree_00`
- `dark_dead_tree_03`
- `dark_menhir_00`
- `dark_menhir_01`
- `dark_menhir_02`
- `dark_menhir_03`
- `dark_rock_02`
- `rock_dark_00`
- `rock_dark_moss_00`
- `rock_moss_00`
- `rock_moss_01`
- `rock_moss_02`
- `rock_moss_03`
- `ruin_stone_00`
- `ruin_stone_02`
- `ruin_stone_03`
- `statue_00`
- `wood_pile_00`

This does not make those records invalid. It means rectangle-to-polygon
migration must union their occupied areas or emit an explicit reauthoring
report; converting each rectangle independently would create overlapping
terrain polygons.

### Chunks and levels

| Metric | Count |
| --- | ---: |
| Active level definitions | 2 |
| Authored chunk files | 8 |
| Placed prefabs | 50 |
| Collision-bearing prefab placements | 31 |
| Enemy markers | 2 |
| Ground gaps | 1 |

All current chunks use `groundProfile.kind = flat` with `topY = 224`.

| Chunk | Prefabs | Colliding | Markers | Gaps |
| --- | ---: | ---: | ---: | ---: |
| `field_flat` | 0 | 0 | 0 | 0 |
| `forest_early_00` | 9 | 5 | 0 | 0 |
| `forest_early_01` | 9 | 5 | 0 | 0 |
| `forest_early_02` | 8 | 6 | 0 | 0 |
| `forest_early_03` | 10 | 5 | 0 | 0 |
| `forest_early_flat` | 0 | 0 | 0 | 0 |
| `forest_easy_woodcamp_00` | 7 | 5 | 1 | 0 |
| `forest_normal_woodcamp_00` | 7 | 5 | 1 | 1 |

Current placement-transform coverage:

- uniform scales: `0.4`, `0.7`, `0.8`, `0.9`, `1.0`, `1.2`, `1.3`, `1.4`
- 7 horizontal-flip placements
- no current vertical-flip placement
- 9 snapped and 41 free placements
- no rotation or non-uniform scale field

Migration must preserve uniform scale, both flip fields, free placement,
deterministic placement ordering, stable prefab/chunk keys, revisions, and
anchor-relative coordinates even where current content does not exercise every
combination.

## 4) Editor, Schema, And Generator Consumers

| Consumer | Current responsibility | Final disposition | Phase |
| --- | --- | --- | --- |
| `PrefabColliderDef` | Anchor-relative integer AABB centers/sizes | Replace with shared polygon shape model | 2 |
| `PrefabDef.colliders` | Ordered multi-rectangle source collision | Replace with ordered collision shapes | 2 |
| Prefab store/determinism | Parse, normalize, order, fingerprint, save | Extend for canonical polygon JSON | 2 |
| Prefab validation | Size, bounds, kind, overlap/source checks | Replace geometry rules with polygon validator | 1-2 |
| Prefab form/scene | Add/select/duplicate/delete rectangle colliders | Replace with vertex/shape editing | 2 |
| `GroundProfileDef` | Flat ground top | Replace with chunk terrain shapes | 2 |
| `GroundGapDef` | Missing spans in flat ground | Migrate to missing polygon coverage | 2 |
| `LevelChunkDef` | Prefabs, markers, flat ground/gaps, ordering | Extend schema, then remove flat adapters | 2 and 7 |
| Chunk validation/scene ground | Flat band and gap editing/preview | Replace with terrain polygon editing/preview | 2 |
| `prefab_runtime_adapter.dart` | Editor-to-runtime rectangle contract | Replace with polygon contract adapter | 2 |
| `generate_chunk_runtime_data.dart` | Transform/snap AABBs into `SolidRel` | Compile canonical polygons and exposed edges | 1-2 |
| `authored_chunk_patterns.dart` | Generated `SolidRel`/`GapRel` data | Replace with generated terrain shapes/edges | 2 |

Current generator transform order is placement plus anchor-relative collider
offset, optional X/Y flip, uniform scale, and final grid snapping. Polygon
generation must define the equivalent vertex transform and one deterministic
quantization boundary.

## 5) Core Geometry And Spatial Index Consumers

| Consumer | Current responsibility | Final disposition | Phase |
| --- | --- | --- | --- |
| `StaticGroundPlane` | Optional infinite flat top | Remove after migrated finite terrain exists | 7 |
| `StaticGroundGap` | Holes in the plane | Remove after missing terrain encodes pits | 7 |
| `StaticGroundSegment` | Horizontal collision/navigation ground spans | Replace with compiled terrain edges | 3 |
| `StaticSolid` | AABB platform/obstacle faces | Replace with terrain polygons/edges | 3 |
| `StaticWorldGeometry` | Canonical flat/AABB bundle | Replace with canonical terrain bundle | 3 |
| `StaticWorldGeometryIndex` | Sorted face lists and ground-segment queries | Replace with deterministic edge grid | 3 |
| `CollisionSystem` | Integrate AABB bodies and resolve four face directions | Replace with shape-aware move-and-slide | 4 |
| `CollisionStateStore` | Grounded and four directional booleans | Generalize to support/contact state | 4 |
| `ColliderAabbStore` | World contact and overlap bounds | Keep as derived broad-phase/combat bounds | 4 |
| `BodyStore` | Dynamic/kinematic/gravity/side configuration | Keep; replace side semantics with shape role/filter | 4 |

The existing `GridIndex2D` is reusable for terrain-edge buckets. The current
`StaticWorldGeometryIndex` is not reusable as the final index because it is
organized around AABB face categories.

## 6) Bodies Integrated By Current Collision

`CollisionSystem` iterates every enabled entity with transform, body,
collision state, and AABB collider. Kinematic bodies are skipped.

| Category | Current physics role | Migration risk/disposition |
| --- | --- | --- |
| Éloïse / Éloïse WIP | Dynamic, gravity, ceilings and both walls | Upright capsule world contact |
| `unocoDemon` | Dynamic, no gravity, no side mask; still vertically integrated | Explicit flying capsule/terrain policy required |
| `grojib` | Dynamic, gravity, ignores ceilings, both walls | Upright capsule world contact |
| `hashash` | Dynamic, gravity, ignores ceilings, both walls | Upright capsule plus teleport clearance |
| `derf` | Kinematic, no gravity, no side mask | No integration; capsule used for placement/clearance |
| Ballistic projectiles | Dynamic body with `usePhysics = true` | Separate swept world-shape path; no double integration |
| Non-physics projectiles | Integrated by `ProjectileSystem` | Keep outside actor collision; optional terrain query by policy |
| Pickups/triggers/hitboxes | AABB overlap only, no body integration | Keep derived AABB overlap behavior |

Only `EntityFactory` player/enemy construction and
`spawn_projectile_item.dart` currently add `Body` components. Splitting actor
and projectile collision without an explicit integration owner would integrate
ballistic projectiles twice or not at all.

Current AABB-to-capsule mapping inputs:

| Actor | AABB half X | AABB half Y | Offset X | Offset Y |
| --- | ---: | ---: | ---: | ---: |
| Éloïse | 10.3 | 23.0 | -0.3 | 1.0 |
| Éloïse WIP | 10.3 | 23.0 | -0.3 | 1.0 |
| `unocoDemon` | 8.125 | 8.625 | 0.0 | 2.0 |
| `grojib` | 19.5 | 25.0 | -4.0 | 18.0 |
| `hashash` | 14.0 | 21.5 | -1.0 | 7.0 |
| `derf` | 11.5 | 24.25 | 0.0 | 7.0 |

The safe mechanical mapping is radius = AABB half X and vertical half-segment
= max(0, AABB half Y - radius), preserving the old broad-phase AABB and bottom
position while rounding only the corners.

## 7) Collision/Bounds Consumers

### Authoritative world-contact state

Production readers of `grounded` or directional collision flags:

- `game_core.dart`
- `entity_factory.dart`
- `spawn_service.dart`
- `jump_system.dart`
- `enemy_navigation_system.dart`
- `ground_enemy_locomotion_system.dart`
- `enemy_death_state_system.dart`
- `anim_system.dart`
- `projectile_world_collision_system.dart`
- `snapshot_builder.dart`

Only `CollisionSystem`, initial entity construction, and spawn initialization
currently write `grounded`. The final support store must have one normal tick
writer; spawn initialization is provisional state until the first terrain
solve.

### AABB-derived contact or placement truth

The following production areas read AABB half extents/offsets and must be
classified rather than mechanically replaced:

- collision integration and resolution
- surface lookup and standability
- player/enemy spawn bottom placement
- Hashash teleport placement and melee origin
- enemy cast/melee/flying engagement ranges
- enemy culling and fall bounds
- projectile spawn and world collision
- cast-origin fallback
- snapshots and actor debug overlays

Combat hit detection, dynamic broad phase, pickups, restoration items, and
temporary hitboxes should continue using AABBs. Terrain contact, support,
spawn clearance, and navigation feasibility must use the capsule/terrain
kernel.

Facing-dependent collision offset is centralized through
`colliderEffectiveOffsetX`; the final capsule center must preserve that rule or
explicitly remove it for actors whose collision should not mirror.

## 8) Player And Ability Consumers

| Area | Current dependency | Final disposition |
| --- | --- | --- |
| Movement | Writes world-horizontal velocity | Compose requested displacement, then slide |
| Gravity | Writes vertical velocity before collision | Keep ordering; solver consumes result |
| Jump | Reads `grounded`, coyote, buffer | Read generalized support; clear snap eligibility |
| Mobility/dash/roll | Writes X/Y velocity and suppresses gravity | Preserve authored direction; resolve through terrain |
| Knockback/stun | Modifies velocity/control | Resolve through same capsule path |
| Animation | Reads grounded and velocity thresholds | Read support validity; art stays render-owned |
| Camera | Reads final player transform | Continue after collision |
| Distance/score | Accumulates positive world-X velocity | Preserve unless gameplay decision changes it |
| Cast/melee origins | Uses collider extents or explicit offsets | Keep explicit offsets; derived AABB remains fallback |
| Aim preview | Render-only direction ray | Terrain hit/ground placement must come from Core query |
| Death | Uses player bottom versus global ground kill threshold | Replace with level kill plane |

Achievements/progression do not directly own terrain collision. They consume
run results, distance, score, kills, and death reasons, so compatibility tests
must prove those semantics stay intentional.

`TargetingModel.groundTarget` exists in the ability contract and HUD targeting
classification, but no current player ability uses it and player activation
does not currently commit `TargetPointHitDelivery`. The only authored
target-point delivery is Derf's predicted-player-center fire explosion.
Current projectile/melee `AimRay` components draw a fixed-length render-only
direction and do not query terrain. A future ground-target preview therefore
needs a Core-authored resolved target/validity result; Flame must not invent
slope or line-of-sight rules.

## 9) Enemy And Navigation Consumers

### Enemy policy inventory

| Enemy | Current baseline | Required migration |
| --- | --- | --- |
| `unocoDemon` | Flying dynamic body; hover references ground top | Capsule clearance and explicit terrain/flight reference |
| `grojib` | Ground navigator, per-enemy jump graph, ignores ceilings | Capsule support, sloped walk edges, jump/drop clearance |
| `hashash` | Ground navigator plus deferred spawn and ambush teleport | Same as Grojib plus teleport destination clearance |
| `derf` | Kinematic caster on obstacle tops | Eligible support, capsule clearance, stationary placement |

`groundNavigatingEnemyIds` contains exactly `grojib` and `hashash`. All four
`EnemyId` values are represented above.

### Existing navigation assets to generalize

- `SurfaceExtractor`: extracts horizontal tops and merges coplanar spans.
- `WalkSurface`: stores `[xMin, xMax]` and one `yTop`.
- `SurfaceSpatialIndex`: indexes thin horizontal slabs through `GridIndex2D`.
- `SurfaceGraphBuilder`: produces deterministic jump/drop edges, per-enemy.
- `SurfacePathfinder`: deterministic A* with stable surface-ID tie-breaks.
- `SurfaceNavigator`: locates current/target surfaces and executes graph edges.
- `TrajectoryPredictor`: predicts landings on horizontal surfaces.
- `Standability`: uses AABB width and support fractions.
- `TrackManager`: rebuilds per-enemy graphs and asserts shared surface
  identity/order.

Keep the graph, A*, navigator state, per-enemy graph variants, graph versions,
and stable tie-break structure. Replace horizontal surface geometry,
standability, trajectory intersection, and jump obstruction with canonical
terrain-segment/capsule queries.

## 10) Streaming, Spawn, Item, And Death Consumers

`TrackStreamer` owns deterministic chunk selection, chunk index/start X,
spawn-roll order, active-chunk ordering, and flatten/cull order. `TrackManager`
is the single current geometry mutation point and rebuilds collision index,
render snapshots, surface graphs, and placement graph references together.
That ownership should remain.

Current terrain-dependent placement:

- initial player spawn on level `groundTopY`
- ground/highest-surface/obstacle-top enemy markers
- deferred Hashash spawn at the visible-right chunk edge
- Derf obstacle-top placement through marker mode
- collectible/restoration highest-surface placement
- AABB rejection against static solids
- Hashash ambush teleport relative to predicted player position, without a
  terrain-clearance query

Current fall/cull behavior:

- player pit death: player AABB bottom exceeds
  `level.groundTopY + gapKillOffsetY`
- enemy below-world cull: enemy AABB bottom exceeds
  `groundTopY + enemyCullBelowGroundOffsetY`
- behind-camera cull: enemy max X is behind the configured camera margin
- ground-impact enemy death: waits for `grounded` or a deterministic timeout

All global-ground Y uses above require a level/world-bound or a terrain query.
Behind-camera culling remains independent of slopes.

## 11) Projectile, Combat, Pickup, And Trigger Consumers

| Category | Current geometry | Final geometry policy |
| --- | --- | --- |
| Actor world contact | AABB versus static AABB faces | Capsule versus terrain edges |
| Ballistic projectile world contact | AABB through `CollisionSystem` | Swept projectile shape versus terrain edges |
| Non-physics projectile movement | Projectile-system integration | Preserve; add terrain query only when authored |
| Actor combat hurt bounds | AABB | Derived AABB, preserving current balance |
| Melee/projectile hit bounds | AABB | Keep AABB |
| Dynamic broad phase | AABB grid | Keep AABB |
| Mobility impact | AABB combat overlap plus actor motion | Keep overlap AABB; terrain motion uses capsule |
| Collectibles/restoration | AABB overlap | Keep AABB |
| Temporary hitboxes/sensors | AABB | Keep AABB |

World contact and combat overlap must remain separate concepts even when both
are derived from the same actor capsule.

## 12) Flame Rendering And Debug Consumers

Current flat/AABB assumptions:

- `GroundSurface` and `GroundSurfaceLayout` render horizontal texture bands
  from `GroundSurfaceSnapshot`.
- `GroundBandParallaxForeground` clips parallax foreground to those bands.
- `TemporaryFloorMask` chooses one maximum flat surface Y.
- `LiveWorldSyncSystem` renders `StaticSolidSnapshot` as debug rectangles.
- actor debug bounds are rectangle components.
- static prefab sprites already render independently from collision.
- interpolation and pixel snapping consume final Core transforms.

The Game layer is not collision or navigation authority. It reads immutable
Core snapshots and never feeds its rendering classification back into Core.
That boundary is already correct and must be preserved.

## 13) Replay, Backend, Validator, And Ghost Consumers

Current compatibility values:

- client/default board `gameCompatVersion`: `2026.03.0`
- default `rulesetVersion`: `rules-v1`
- default `scoreVersion`: `score-v1`
- default `ghostVersion`: `ghost-v1`
- replay blob version: 1
- command encoding version: 1
- run-session expiry: 24 hours
- validation lease: 10 minutes by default

The replay blob records commands, seed, level, character, loadout, tick rate,
and board binding. It does not include static geometry, and no geometry field
is required for slopes.

The validator constructs `GameCore` from its deployed generated level content.
Therefore the deployed Core/generated-content build must be bound to an
accepted compatibility version. A new validator must not replay an old ticket
with new slope physics, and an old validator must not accept the new version.

## 14) Inventory Summary

| Area | Keep | Derive | Replace | Remove | Open |
| --- | ---: | ---: | ---: | ---: | ---: |
| Editor/schema/generator | 5 | 1 | 7 | 0 | 0 |
| Core geometry/index | 1 | 0 | 5 | 0 | 0 |
| ECS bodies/collision/support | 2 | 1 | 2 | 0 | 0 |
| Player/abilities | 7 | 2 | 2 | 0 | 0 |
| Enemies | 4 | 2 | 4 | 0 | 4 gameplay profiles |
| Navigation/pathfinding | 5 | 1 | 4 | 0 | 1 gameplay cost rule |
| Streaming/spawning/items | 5 | 2 | 5 | 0 | 1 gameplay eligibility rule |
| Projectiles/combat/triggers | 6 | 2 | 2 | 0 | 0 |
| Rendering/debug | 3 | 1 | 4 | 1 temporary mask | 0 |
| Replay/protocol/backend/ghost | 5 | 0 | 3 | 0 | exact release version |
| Tests/docs | 8 | 0 | 0 | 0 | golden/performance evidence |

Counts in this summary classify responsibilities, not files. The detailed
tables above are the evidence source.

## 15) Remaining Inventory Work

- complete the remaining baseline commands
- record current performance measurements
- inspect and classify every test/doc match during Phase 1 checklist creation
- repeat all required-term searches at the end of Phase 0
- verify no new enemy/body/placement category appeared during Phase 0
