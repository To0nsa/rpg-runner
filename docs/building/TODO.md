## Core

- Add archetype builders to reduce `createPlayer`/`createEnemy` callsite bloat (spawn helpers/builders per entity type; used by deterministic spawning later).
- Reduce `EcsWorld.destroyEntity` maintenance risk (central registry/list of stores or a component mask approach) so new stores can’t be forgotten.
- Handle player death explicitly (core event/flag + UI flow) instead of despawning the player in `HealthDespawnSystem`.
- Reduce Flame per-frame allocations in `RunnerFlameGame` by reusing buffers in `_syncEnemies/_syncProjectiles/_syncHitboxes` (use `clear()` on cached `Set`/`List` instead of allocating each frame).

Items intentionally deferred (not required to make Milestone 13 correct + deterministic today).

## Navigation (Milestone 13)

- **Graph build perf:** avoid per-takeoff `tempCandidates.sort` in `lib/core/navigation/surface_graph_builder.dart` by returning candidates in a stable order from `SurfaceSpatialIndex` (or sorting buckets once at rebuild time).
- **Drop landing perf:** replace `_findFirstSurfaceBelow` O(S) scans with a cheap “surfaces below x” query (e.g., secondary index keyed by x-buckets with y-sorted candidates).
- **Edge count control:** if edge counts grow with more complex tracks, add bounded pruning (e.g., keep best K edges per `(from,to,kind)` or represent jump reachability as a takeoff range and pick takeoff at runtime).
- **Cost model scalability:** current A* state is “surface-only”. If you ever need accurate run costs on intermediate nodes (arrival x matters), expand the state space (surface + discretized x) or add conservative approximations.
- **Tolerances cleanup:** centralize navigation epsilons/tolerances (builder/locator/template) into a single place (consts or a dedicated tuning struct) to reduce “magic number” drift.

## Determinism / platform targets

- **Web compatibility:** `packSurfaceId()` and `GridIndex2D.cellKey()` rely on 64-bit bit packing (`<< 32`). This is fine for Dart VM/AOT (mobile), but would not be safe on JS/Web without changes.
