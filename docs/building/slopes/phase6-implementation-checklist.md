# Slopes Phase 6 - Content Migration And Direct Authority Cutover Checklist

- Status: In progress
- Source plan: [plan.md](plan.md)
- Prerequisite: accepted
  [Phase 5 runtime integration](phase5-implementation-checklist.md)

## 1) Goal And Boundary

Make the admitted polygon artifact and its edge/capsule runtime bundle the sole
static-terrain authority for normal and replay `GameCore` construction, then
delete the temporary rectangle projection and every obsolete runtime adapter.
The cutover is direct: no production option, remote flag, replay field, or
fallback may select the legacy authority.

Field and Forest are the complete current level set. Their eight schedulable
Chunks already own current-schema full-width `ground` / `grass_dirt` polygons
and pass generator reachability, seam, streaming, placement, renderer,
determinism, and performance gates. Further slope design is content polish,
not a reason to retain a second collision authority.

Backend compatibility rollout, board versioning, session draining, deployment,
and production monitoring remain Phase 7 work.

## 2) Direct Cutover Order

1. Change normal `GameCore` construction to prewarm the scheduler's exact
   staged candidate before ECS placement and install
   `TerrainMultiBodyWorldMotionAuthority` from that candidate. Replay
   validation must inherit the same path through the normal constructor.
2. Replace harness-only assertions with normal-construction Field/Forest,
   deterministic replay, player/enemy/projectile, spawn/cull, pickup, fall
   death, renderer, and long-run coverage. Remove the staged stream factory
   once no test needs a separate authority selector.
3. Remove legacy collision/navigation reads from `TrackManager`, movement
   systems, snapshots, debug output, and placement adapters in dependency
   order. Keep scheduler RNG, Chunk identity/order, enemy/item request order,
   and content tuning unchanged.
4. Stop rendering and generating the compatibility rectangle terrain. Split
   any still-required scheduler metadata from
   `authored_chunk_patterns.dart`, stop emitting its `StaticSolid`, horizontal
   ground, and gap records, then delete
   `polygon_terrain_legacy_projection.dart` and its projection tests.
5. Delete `LegacyWorldMotionAuthority`, legacy static-world collision systems,
   obsolete `StaticSolid`/ground/gap contracts, temporary adapters, stale
   snapshots, and harness-only selection seams after repository-wide import and
   construction audits show no consumers.
6. Regenerate committed outputs, freeze new deterministic references, and
   update TDD, GDD, README, and applicable `AGENTS.md` guidance to describe
   polygon terrain as implemented production behavior.

Each removal lands only after its replacement tests pass. The sequence may use
small commits, but the completed phase must not retain a runtime dual path.

## 3) Content And Runtime Acceptance

- [ ] all eight current Chunks compile from current source with exact semantic
      signatures, reachable seams, and zero generated drift
- [ ] normal Field and Forest construction uses the staged terrain authority
      before initial player/entity placement
- [ ] replay validation constructs the identical terrain authority and matches
      deterministic live Core outcomes
- [ ] player, Grojib, Hashash, Unoco, Derf, ballistic projectile, marker,
      collectible, restoration, cull/re-add, and fall-death policies pass on
      normal construction
- [ ] Flame renders only Core-published polygon terrain with stable material
      phase and no visible/physical streamed seams
- [ ] scheduler selection, RNG consumption, entity ID/order, and authored
      placement outcomes remain deterministic
- [ ] representative Field and Forest runs pass accepted controller,
      full-harness, allocation, and replay-validation budgets

## 4) Legacy Deletion Acceptance

- [ ] no normal or replay construction can instantiate legacy rectangle
      terrain authority
- [ ] no production system reads legacy `StaticSolid`, horizontal-ground, or
      ground-gap collision as gameplay authority
- [ ] the generator emits no projected legacy terrain records
- [ ] `polygon_terrain_legacy_projection.dart`, its temporary tests, and stale
      migration-only runtime bridges are deleted
- [ ] the test/tool-only terrain authority selectors are deleted after normal
      construction owns their coverage
- [ ] repository import/construction audits find one polygon terrain authority
      and no fallback or runtime toggle
- [ ] documentation describes the final ownership and the remaining Phase 7
      compatibility rollout accurately

## 5) Validation

Run focused tests after each dependency step, then the full cutover matrix:

```powershell
dart analyze
flutter test

Push-Location packages\runner_core
dart analyze
dart test
Pop-Location

Push-Location services\replay_validator
dart analyze
dart test test
Pop-Location

Push-Location tools\editor
dart analyze
flutter test --concurrency=1 --fail-fast
Pop-Location

dart run tool\generate_chunk_runtime_data.dart --dry-run
dart run tool\benchmark_slopes_phase2.dart --strict `
  --warmup=1000 --iterations=5000 --harness-iterations=5000

corepack pnpm --dir functions build
corepack pnpm --dir functions test
```

Record exact test counts, deterministic references, benchmark percentiles,
generated membership, and any compatibility/version disposition before Phase 7.
