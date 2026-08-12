# Slopes Phase 5 - Streaming, Rendering, And Runtime Integration Checklist

- Status: Normal render handoff integrated; collision authority remains legacy
- Source plan: [plan.md](plan.md)
- Prerequisite: Phase 4 current-schema cutover and its recorded
  [manual usability pass](phase4-manual-usability-pass.md)

## 1) Goal And Boundary

Promote the checked-in staged terrain artifact into the sole streamed terrain
input for normal Core construction. One immutable, versioned runtime bundle
must then feed collision, support/navigation, spawn placement, rendering, and
debug evidence for every active chunk.

Phase 5 now establishes and tests the runtime handoff against reauthored flat
Forest and Field ground polygons. It must not switch
replay compatibility or remove the legacy authority until Phase 6's broader
slope-content and direct-cutover gates are satisfied.

The work must not modify the Prefab Creator or Chunk Creator polygon authoring
workflow except where an already-public Core output needs a read-only consumer.

## 2) Existing Handoff

- `staged_authored_terrain.dart` is generated, deterministic, and intentionally
  unreachable from normal construction at the start of this phase.
- `TrackManager` and `TrackStreamer` currently publish `StaticSolid`,
  `StaticGroundSegment`, and `StaticGroundGap` collections derived from
  `authored_chunk_patterns.dart`.
- The Phase 3 terrain authority can compile edges, build indexes and graphs,
  and publish a complete immutable geometry bundle at a tick boundary. Phase 5
  must reuse that authority; it must not recreate terrain queries in the
  streamer or Flame.
- Staged records retain canonical local loops, exposed edges, triangles,
  source/placement lineage, and the signatures required to reject stale or
  mismatched generated data before publication.

## 2.1 Delivered Foundation

- [x] `StagedTerrainArtifactCatalog` admits only the expected generated format,
      compiler/signature-format versions, SHA-256 digest shape, canonical
      unique chunk keys, and structurally valid local geometry lineage. It
      binds a selected chunk key to an instance index and exact world-origin
      physics tick without importing generated terrain into normal `GameCore`
      construction. The binding rejects missing chunks and foreign or absent
      polygon source identities.
- [x] `StagedTerrainWorldGeometryBuilder` converts admitted local polygon and
      exposed-edge records to canonical world-space `TerrainGeometry`. It
      preserves generated tangents/normals/join context, translates only
      physics-grid X coordinates, and rehydrates every edge identity with its
      selected streamed chunk index. The builder rejects duplicate streamed
      indices and malformed local records; it is not connected to the normal
      `TrackManager` path yet.
- [x] `StagedTerrainRuntimeBundleBuilder` composes that world geometry with
      the Phase 3 edge index, shared surface set, placement query, and Grojib /
      Hashash graph publication before returning a candidate. It takes existing
      graph profiles explicitly and performs no scheduling, gameplay mutation,
      or normal-runtime selection.
- [x] `TrackStreamer.activeChunks` exposes immutable active chunk index,
      world interval, selected pattern name, and optional authored `chunkKey`
      from the existing scheduler. It changes only beside the existing
      spawn/cull geometry rebuild, allowing a future staged binder to consume
      real scheduling choices without reselecting chunks. Legacy missing keys
      remain explicit and cannot imply a fallback staged record.
- [x] `StagedTerrainStreamBindingBuilder` consumes only that active snapshot
      and validates the generated chunk key, physics-grid world interval, and
      exact staged width before returning bindings. It neither selects chunks
      nor substitutes geometry; all invalid legacy/mismatched records fail
      closed ahead of future publication.
- [x] `StagedTerrainRenderSnapshotBuilder` reads world-space polygon vertices
      from the exact `TerrainGeometry` used by collision and accepts only
      generated triangle indices. Missing, out-of-range, or degenerate
      triangles reject the whole render candidate; the new snapshot is not yet
      included in normal `GameStateSnapshot` or consumed by Flame.
- [x] `StagedTerrainStreamCandidateBuilder` joins the real active scheduler
      selection, staged bindings, one world geometry object, the full Phase 3
      runtime bundle, and the render candidate. It proves object identity and
      geometry-version agreement between collision/navigation and render data,
      while remaining entirely unselected by normal `TrackManager` or
      `GameCore` construction.
- [x] A streamed-candidate regression culls an initial `field_flat` selection,
      rebuilds it from the same scheduler seed, and proves identical
      world-edge IDs/order/signature and render source ordering. Later repeated
      selections retain distinct streamed chunk indices.
- [x] A terrain-harness integration test builds a staged floor candidate and
      passes its exact geometry to the existing isolated Core authority. It
      proves player support/movement and render triangles can share the staged
      geometry without selecting it for normal game or replay construction.
- [x] The terrain harness can queue a complete staged candidate and publishes
      its exact runtime bundle and immutable render snapshot together at the
      next preparation boundary. `GameStateSnapshot` carries that read-only
      data only for the harness; normal game and replay construction still
      publish no staged terrain.
- [x] The staged render snapshot also retains the exact canonical exposed
      `TerrainEdge` objects from its collision geometry. Edge IDs preserve
      chunk, placement, and shape lineage for a future Flame debug overlay;
      no render consumer may reconstruct boundaries from polygon fills.
- [x] All seven Forest chunks retain their visuals, 50 repository placements,
      and two enemy markers while adding one canonical `ground_001` polygon at
      the established 224px ground line. Every polygon carries `ground` /
      `grass_dirt` metadata, all scheduler-reachable seams validate, and the
      temporary legacy projection restores the former continuous flat ground.
- [x] `field_flat` replaces the temporary manual floating rectangle with the
      same canonical full-width `ground_001` band, so every currently
      schedulable chunk has continuous baseline support for runtime cutover.
- [x] Normal streaming admits the generated artifact once, binds the existing
      scheduler's exact active selection after every spawn/cull rebuild, and
      atomically replaces one complete staged candidate. `GameStateSnapshot`
      now exposes that candidate's compiler-owned polygons, triangles, and
      diagnostic edges while legacy collision remains active for Phase 6.
      Anonymous custom legacy chunks publish no staged candidate and never
      fall back to unrelated generated geometry.
- [x] Flame maps `grass_dirt` through one render-only material registry and
      caches meshes from Core's exact world-space loops and triangle indices.
      It tiles fill in world phase and draws surface/foreground art only along
      Core's upward-facing exposed edges. Legacy ground, foreground bands, and
      the temporary floor mask yield whenever staged terrain is present.
- [x] World binding removes exact reversed internal faces where adjacent
      chunks share compatible seam coverage. It reconnects the retained top
      and bottom edges across chunk identities with smooth/connected join
      evidence, so collision, navigation, diagnostics, and rendering do not
      retain hidden vertical walls at streamed seams.
- [x] Startup now performs the scheduler's deterministic initial selection and
      builds its complete staged candidate before the player or any other ECS
      entity is spawned. `TrackManager` adopts that exact prewarmed streamer;
      it does not reselect opening chunks or change player/entity ID order.
- [x] Streamed enemy requests and new-chunk item work are captured without ECS
      mutation. Core completes and publishes the matching terrain world first,
      then applies enemies followed by collectibles/restoration items, and only
      then prepares prior support for AI and motion. Marker/item RNG and legacy
      placement outcomes remain unchanged.
- [x] Physics-driven projectiles keep their existing collider AABB and gravity
      phase under terrain authority. A reusable continuous SAT sweep queries
      the published 2D edge index, filters solid and one-way approach sides,
      resolves the earliest contact by time then canonical edge ID, writes the
      existing directional flags, and preserves same-tick
      `ProjectileWorldCollisionSystem` despawn ownership.
- [x] Terrain-authority ground-enemy AI reads the exact published Grojib and
      Hashash graph views through a dedicated ECS adapter. Per-entity terrain
      state invalidates on bundle version, grounded targets retain exact
      support, airborne targets use the terrain capsule predictor, safe
      fallback stays finite, and planned jump timing is forwarded through the
      existing locomotion intent contract. Normal/replay construction still
      selects the legacy navigator.
- [x] `GameCore.stagedTerrainStreamHarness` is an explicit test/tool boundary
      that starts terrain authority from the scheduler's exact prewarmed
      candidate before player placement, then consumes every normal spawn/cull
      candidate through the atomic publication barrier. Two independent
      900-tick `field_flat` runs match geometry versions, polygon/edge order,
      support identity, and grounded survival across multiple rebuilds. The
      same harness covers eight deterministic Forest seeds with terrain-placed
      grounded markers, collectibles, restoration items, and the streamed
      fall-death rule. The normal constructor and replay validator remain
      legacy-owned.
- [x] Paired 1,800-tick command runs over both reauthored Field and Forest
      streams remain deterministic through repeated publication rebuilds,
      preserve render/support identity at every sampled boundary, survive past
      5,000 distance, and stay within the published strict Phase 2 benchmark
      gates. The unchanged legacy replay path remains covered by the complete
      replay-validator suite.

## 3) Implementation Order

1. Define and test a strict runtime artifact admission boundary. It accepts
   only the generated format/compiler/signatures and complete scheduler seam
   evidence already validated by the generator.
2. Bind selected streamed chunk instances to staged chunk records using stable
   chunk key, runtime chunk index, and world-X origin. Reject missing,
   duplicate, mismatched-level, or stale-revision bindings before geometry
   publication.
3. Build chunk-local staged edges into one deterministic world-space terrain
   publication unit. Preserve source lineage, edge identity, collision mode,
   endpoint join context, and canonical ordering across spawn, cull, and
   rebuild.
4. Replace the legacy streamer geometry only after the new publication unit
   drives the existing Phase 3 controller/index/support/graph consumers in the
   same tick-boundary swap. No consumer may observe a mixture of old and new
   geometry versions.
5. Route player, enemy, marker, collectible, and restoration placement through
   the published terrain queries. Keep authored selection/RNG order and every
   existing failure policy stable.
6. Expose immutable terrain render snapshots from Core. Flame renders polygon
   fill, foreground masks, and debug edges from those snapshots only; it does
   not triangulate, stitch, or determine collision.
7. Add representative reauthored flat, slope, platform, obstacle, seam, and
   gap fixtures. Run full-game integration, deterministic replay parity, and
   performance checks before requesting Phase 6 authority cutover.

## 4) Parallel-Work Guardrails

- Keep the manual usability route and editor implementation stable while
  runtime integration proceeds. Content reauthoring must pass the same strict
  current-source, seam, and generator-drift gates before commit.
- Do not import the staged artifact from normal `GameCore`, Flutter, or replay
  validator construction until the admission, binding, and atomic-publication
  tests have passed.
- Preserve `authored_chunk_patterns.dart` and the exact legacy projection as
  the active production authority until Phase 6 explicitly removes them.
- Treat the reauthored flat Forest bands as cutover-enabling content, not as
  final slope-level design or evidence that every runtime placement policy is
  already accepted.
- Keep replay protocol/version, backend ticket/board changes, and production
  deployment work in Phase 7.

## 5) Acceptance Evidence

- [ ] generated staged terrain is admitted only when format, compiler,
      signature, source membership, and reachable-seam evidence all match
- [x] streamed chunk spawn/cull/re-add produces the same world-space edge IDs,
      ordering, and bundle signature for identical selected chunks
- [x] one atomic publication updates collision, support/navigation, placement,
      render snapshots, and debug evidence together at a tick boundary
- [x] source edge lineage survives world binding and is available in diagnostic
      and debug outputs without per-tick allocation
- [x] every scheduler-reachable neighboring pair is physically stitched or
      intentionally exposed without a collision, navigation, or render seam
- [x] Flame uses Core-owned triangles/edges and does not duplicate geometry,
      material-phase, or collision authority
- [x] initial player, enemy, marker, collectible, restoration, cull, and
      fall-death policies have explicit terrain-backed coverage (startup and
      publication ordering are covered; normal authority selection remains)
- [x] representative full runs match deterministic Core/replay outcomes and
      remain inside the accepted runtime budgets
- [ ] legacy runtime authority remains available until Phase 6's direct
      cutover, then has an explicit deletion/migration plan rather than a
      runtime toggle

## 6) Validation

Run the smallest slice for each change, expanding at the published-boundary
and renderer steps:

```powershell
dart analyze packages/runner_core
Push-Location packages/runner_core
dart test
Pop-Location

flutter test test/core
flutter test test/game
dart run tool/generate_chunk_runtime_data.dart --dry-run
dart run tool/benchmark_slopes_phase2.dart --strict `
  --warmup=1000 --iterations=5000 --harness-iterations=5000

Push-Location services/replay_validator
dart analyze
dart test test
Pop-Location
```

Also retain focused fresh-process signature, chunk spawn/cull/rebuild,
seam-stitching, placement, renderer parity, and performance evidence for each
published runtime boundary.

The 2026-08-12 full validation pass completed with 369 `runner_core` tests,
433 root Core tests, 17 game-renderer tests, 84 replay-validator tests, clean
root/package/service analysis, and a drift-free 8-chunk/2-level/2-theme
generation check. The strict benchmark passed every controller, candidate,
full-harness, overhead, and allocation gate; its observed full-harness p99 was
112 microseconds for flat terrain and 58 microseconds for slope terrain, with
zero post-warmup buffer growth.
