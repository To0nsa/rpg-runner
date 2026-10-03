---
description: Reproduce and diagnose seeded enemy traversal through authored levels
---

# Test Level Traversal

Use this workflow when testing a level, changing chunk geometry/assembly, or
investigating enemy navigation and movement limits. Read root `AGENTS.md` and
`packages/runner_core/AGENTS.md`; read the closest layer's instructions before
fixing production code or authored content.

## Run the checks

From the repository root, check that the generated terrain matches the sources:

```powershell
dart run tool/generate_chunk_runtime_data.dart --dry-run
```

If stale, regenerate with the same command without `--dry-run`, inspect the
source/generated diff, and rerun the check. These tests use generated terrain;
unsaved editor changes and excluded levels are not automatically included.

```powershell
Push-Location packages/runner_core
dart test test/navigation/level_enemy_traversal_test.dart test/navigation/level_enemy_traversal_harness_test.dart --reporter expanded
Pop-Location
```

For a focused reproduction, from `packages/runner_core`:

```powershell
dart test test/navigation/level_enemy_traversal_test.dart --name "forest traversal seed=42 grojib" --reporter expanded
```

Omit `seed=42 grojib` to run all Forest cases. `--name` is a test-name filter,
not an arbitrary seed argument; add a newly discovered seed to the matrix.
Use `--reporter json` and redirect to `.dart_tool/` when machine-readable test
evidence is useful. Do not check transient logs into source control.

## Current coverage

The matrix in
[`level_enemy_traversal_test.dart`](../../packages/runner_core/test/navigation/level_enemy_traversal_test.dart)
declares each compiled level, seeds `7`, `42`, `2026`, and Grojib, Hashash, Unoco.
A coverage assertion fails when a compiled level lacks an explicit scenario.

| Level | Tested route |
| --- | --- |
| Forest | One complete authored assembly, excluding the repeating final section |
| Field | First 32 production-selected chunks |
| `new_level` | First 32 production-selected chunks, including its difficulty ramp |

This is 27 seeded pursuit cases. Three flat controls check the harness, and
negative controls verify blocked finishes, stall, kill-plane, and total-budget
failures. Derf is
stationary and is deliberately rejected by the movement harness; retain its
separate placement/clearance and combat coverage.

## Adapt the test to a level

1. Add the generated `LevelId` to `_scenarios`. Use `chunkCount: null` only for
   a non-looping assembly: the production selector determines its seed-specific
   length. Endless/looping levels require a positive `chunkCount`. Pick enough
   chunks to include relevant difficulty phases and seam transitions; a finite
   prefix is not proof of an endless level's complete coverage.
2. Keep previous reproduction seeds and add seeds that exercise new chunk
   combinations. Three seeds do not enumerate every chunk or legal seam.
   Preserve a problematic exact sequence as a focused regression when needed.
3. Confirm which enemies should traverse the route. The current helper supports
   Grojib, Hashash and Unoco using their real catalog capsules, slope limits,
   level tuning, gravity, water behavior and locomotion. Adding another movement
   family requires wiring its production systems and a flat control first.
4. Check whether the default chase target suits the level. Intermediate targets
   search near each chunk exit, at `width - 32`, using offsets
   `[0, -16, 16, 32, 48, 64, 80, 96]` world units. It chooses the highest legal
   player foothold at the first usable X, requiring a legal foothold for ground
   enemies too. The current vertical search is `[-1024, 1024]` world units.
   Levels with different coordinate ranges, branching paths, submerged exits,
   very narrow chunks, or intentionally inaccessible perches need an explicit
   target/spawn policy in the shared helper and a focused control. A target
   placement failure is a scenario failure to diagnose, not proof of a broken
   navigation graph. The final target is placed in one continuation chunk beyond
   the fixed finish boundary (`tested chunk count * width`). Scheduled routes
   use the next production-selected chunk; exact fixtures must explicitly supply
   `continuationChunkKey`. That extra terrain supplies target support and is not
   part of the tested route length. Final target probes stay beyond the boundary
   with room for the actor's stand-off; they never move the finish backward.
   When the continuation midpoint is unsupported, final-target probes also
   search forward in 16-unit steps up to 256 units, bounded inside that one
   continuation chunk. The tested boundary and actor capabilities stay fixed.
5. Keep arrival and time budgets meaningful. Defaults are 128 world units of
   intermediate waypoint tolerance, 600 ticks without 4 units of new forward progress, and
   1,800 ticks per chunk, at 60 Hz. Unoco intentionally stops short of its
   target. Custom probes can pass `arrivalDistance`, `stallTicks`, and
   `ticksPerChunk` to the harness. Explain changes against real actor tuning;
   never expand tolerances or skip failing chunks merely to pass a regression.
   `arrivalDistance` cannot satisfy completion: the actor's body center must
   cross the fixed route boundary. Keep both clear-finish and blocked-finish
   controls when adapting this policy.

The reusable helper is
[`test_support/level_enemy_traversal.dart`](../../packages/runner_core/test/test_support/level_enemy_traversal.dart).
Use the existing test runner; no new production API or shell script is needed.
For an isolated sequence, add a normal Dart test that creates:

```dart
final route = LevelTraversalRoute.chunks(
  level: LevelRegistry.byId(LevelId.field),
  seed: 42,
  chunkKeys: ['field_default_normal_001', 'field_default_normal_001', 'field_default_normal_001'],
  continuationChunkKey: 'field_default_normal_001',
);
final harness = EnemyTraversalHarness(route, EnemyId.grojib);
expect(harness.traverse(), isNull);
```

`chunks` preserves exact order but bypasses production selection and connection
validation. `scheduled` uses the real selector. Both can accept an already
validated `StagedTerrainCatalog` and a `LevelDefinition` for focused authored
fixtures. Keep repository loading/compilation out of Core production code.

## Diagnose a failure before choosing a fix

The failure includes level, seed, enemy, exact chunk sequence, local/world
coordinates, tick, support, movement limits, target, graph reachability and a
bounded movement trace. Separate three possibilities:

- **Chunk composition/geometry:** invalid seam, gap, ceiling, narrow support or
  obstruction exceeds the actor's capsule, jump, slope or clearance limits.
  Compare the failing chunk alone and joined to its actual neighbors.
- **Navigation:** a physically legal route exists but graph edges, target
  selection, replanning, or active-jump state do not describe it correctly.
  Graph reachability is evidence, not proof that the actor can execute a path.
- **Movement capability/execution:** a planned transition exceeds actual
  acceleration, jump, flight, slope or swimming capability, or locomotion does
  not follow it. Change capabilities only as an intentional gameplay decision,
  with graph planning and execution kept consistent.

Fix the owning source/system, retain a failing-seed regression, and rerun the
focused case followed by the matrix and Core checks. Gameplay/content changes
also require the checks in
[`change-core-authored-content.md`](change-core-authored-content.md) or
[`change-core-simulation-contract.md`](change-core-simulation-contract.md),
including replay compatibility where applicable. Test-only refactors do not
change gameplay compatibility.

## What a pass means

The same enemy continuously visits every tested chunk and crosses the actual
boundary after the last one, across streamed terrain updates, without falling
below the configured kill plane, stalling or exhausting its tick budget.
Ground enemies must finish grounded or swimming at or beyond that boundary.
Only the stationary chase target is repositioned; enemy teleporting, death,
despawning and camera culling cannot hide a failure.

The harness starts at the level's player-start X and ground reference and uses
an Éloïse-shaped target. It does not run the complete `GameCore` loop, authored
enemy spawn markers, combat, traps/damage, Hashash ambush teleport, player input,
camera survival pressure, rendering or performance gates. Pair it with the
owning integration tests and editor Level Play for those concerns. Report the
tested levels, seeds, enemies, route horizons and these limits with results;
do not claim every possible route is traversable from a small seed sample.
