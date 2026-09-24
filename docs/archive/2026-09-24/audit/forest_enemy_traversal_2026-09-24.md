# Forest enemy traversal check — September 24, 2026

## Resolution

The repaired implementation passes all nine Forest cases: Grojib, Hashash and
Unoco each complete seeds 7, 42 and 2026, plus all three flat controls. The first
authored sequences contain 64, 62 and 63 chunks respectively. Derf remains
stationary and is excluded.

The original measurements below used arrival within the final chunk's exit
area. A later review reproduced a false pass before an impassable wall at
X=500: the actor stopped at X=441 on a 600-unit fixture. The current reusable
harness requires crossing the actual route boundary and supplies a chase
target on continuation terrain beyond it. Its blocked-finish controls preserve
that reproduction. The archived measurements do not establish this stronger
completion condition; rerun the current matrix for that evidence.

The cause was a combination of navigation and authored clearance:

- Unexpected landings retained an obsolete active jump; they now trigger a
  replan from the actual support.
- Terrain publication invalidated an airborne jump's horizontal commitment;
  the world-coordinate commitment now survives until landing, swimming or
  teleport, while graph indices are still invalidated.
- Graph capsule offsets assumed right-facing art despite left-facing enemy
  sprites. They now match runtime collision in both directions.
- A 64-pixel takeoff grid missed usable approaches. The maximum interval is
  now 16 pixels, with the same complete capsule sweep and jump limits.
- Single-facet width checks stranded bodies on connected rock surfaces.
  Runtime footholds now include directly connected eligible facets, retaining
  the one-third-width rule and strict spawn placement.

Five small content adjustments fit the existing movement capabilities:

| Chunk | Adjustment |
| --- | --- |
| `forest_rocky_grove_normal_004` | Entry platform Y 148 → 164 |
| `forest_training_camp_normal_001` | Last tent X 518 → 502 |
| `forest_training_camp_normal_002` | First dummy X 454 → 438 |
| `forest_training_camp_normal_003` | Hay X 527 → 511 |
| `forest_training_camp_normal_004` | Large tent Y 123 → 139 |

Speed 300, jump impulse 500, gravity 1200, Grojib's 45-degree and Hashash's
60-degree slope limits remain unchanged. Generated runtime content was rebuilt
from current authoring. Client, Functions and validator use gameplay
compatibility `2026.09.6`; no services were deployed.

Validation: 564 Core package tests, 212 Functions tests and 142 replay-validator
tests pass. Core and validator analysis are clean. Generator dry-run validates
50 chunks and reports fresh outputs. The combined Flutter gameplay/content/UI
run hit a five-minute timeout in the generated-trap worker fixture; that test
passed when rerun alone in 2 minutes 42 seconds. The other 414 tests in that
combined Flutter run passed.

The compiled 36,000-tick-per-level replay benchmark passes on this Windows host
(Forest 2.43 s, Field 1.59 s, New Level 3.40 s). Its
[JSON report](../verification/forest_enemy_navigation_benchmark.json) describes
the existing no-enemy benchmark fixture; the dedicated traversal matrix is the
evidence for mobile enemy movement. Container throughput verification remains
release work. These tests cover the selected seeds, not every possible layout.

The original Forest-only harness is now shared by the reusable level matrix.
Reproduce its Forest cases with
`dart test test/navigation/level_enemy_traversal_test.dart --name "forest traversal"`
from `packages/runner_core`. The test reports the chunk, local/world position,
recent movement decisions and graph reachability when an actor fails. See the
[current workflow](../../../../.agent/workflows/test-level-traversal.md) for
adaptations; the measurements and hashes below describe the archived build.

Final generated runtime SHA-256 values:

- `level_registry.dart`: `eade1512811d74b9753d44db415962fa373d3d22d52c38e23943cdb7aeee1d92`
- `authored_chunk_patterns.dart`: `cd62a96afb78c3e1f2749464712a5f1ae1eec8dea2c5ddb570839358de9f2002`
- `staged_authored_terrain.dart`: `59743ed66350b7e75255754beff1687b400434cca43fcc6f61daeab411bd5e70`

## Initial result

The initial runtime forest terrain did **not** support reliable end-to-end
ground-enemy pursuit in the tested layouts. Four of nine Forest cases passed.
The completion assertions remain enabled in
[`level_enemy_traversal_test.dart`](../../../../packages/runner_core/test/navigation/level_enemy_traversal_test.dart)
so future navigation/content changes can be checked against the same requirement.
The initial measurements below preceded the repairs described above.

| Enemy | Seed 7: 64 chunks | Seed 42: 62 chunks | Seed 2026: 63 chunks |
| --- | --- | --- | --- |
| Grojib | Stalled at chunk 13 | Stalled at chunk 15 | Stalled at chunk 16 |
| Hashash | Fell below kill plane at chunk 11 | Completed | Stalled at chunk 32 |
| Unoco Demon | Completed | Completed | Completed |

Derf is a stationary caster and is intentionally outside this traversal test.
Three flat-terrain control cases, one per mobile enemy, also complete across
multiple chunk seams.

## Reproduction and failure locations

From the repository root:

```powershell
Push-Location packages/runner_core
dart test test/navigation/level_enemy_traversal_test.dart --name "forest traversal" --reporter expanded
Pop-Location
```

To focus on one case, replace the name filter with
`--plain-name "forest traversal seed=7 grojib"`. The initial suite exited
unsuccessfully because the traversal requirement was not met; the repaired
build passed. The test does not treat a known stall as a passing outcome.

Chunk numbers below are one-based. Positions are body-center world units,
with local X measured from the chunk's start.

| Enemy / seed | Chunk key | World X / Y | Local X | Tick | Observed outcome |
| --- | --- | --- | --- | --- | --- |
| Grojib / 7 | `forest_rocky_grove_easy_003` | 7214.97 / 141.96 | 14.97 | 2107 | Stalls on `pixel_fantasy_caves_rock_02`, collision edge 1 |
| Grojib / 42 | `forest_training_camp_easy_004` | 8403.35 / 180.47 | 3.35 | 2517 | Stalls on `ground_001`, edge 0 |
| Grojib / 2026 | `forest_training_camp_easy_001` | 9411.96 / 180.94 | 411.96 | 2790 | Stalls on `ground_001`, edge 0, sub-edge 4 |
| Hashash / 7 | `forest_early_forest_003` | 6322.57 / 639.14 | 322.57 | 1354 | Loses support and falls below the level kill plane |
| Hashash / 2026 | `forest_ruin_easy_003` | 19014.99 / 181.33 | 414.99 | 4884 | Stalls on `ancient_forest_ruin_wall_01`, collision edge 3 |

All four stalls still report a navigation plan. This establishes a failure to
execute continuous pursuit; it does not establish whether the root cause is
graph construction, traversal execution, or authored geometry. Each case stops
at its first failure, so later obstructions in that layout remain unexamined for
that enemy.

## Test boundary

- Uses `ConnectedChunkPatternSource.forLevel` and the generated production
  polygon artifact, with the current forest registry and seeds 7, 42, and 2026.
- Starts at the normal player-start X (300). Forest repeats its final section
  indefinitely, so “end” means the exit area of the last chunk in the first
  complete authored assembly, before the repeating tail.
- Preserves the enemy's transform and velocity through terrain publications.
  A bounded window retains one chunk behind and two ahead, with real stitched
  seams. This is an isolated system integration test, not a camera-driven
  `GameCore` playthrough or a test of asynchronous terrain preparation.
- Runs the production navigation, engagement, ground/flying locomotion,
  water immersion, gravity, and terrain authority systems at 60 Hz, using
  level-derived tuning and catalog contact profiles.
- Moves only a stationary, clearance-checked player target between chunk exit
  areas. The target uses legal support near local X 568; nearby exit samples
  are checked when narrow rock geometry prevents placement at that coordinate.
  A target advances when the enemy comes within 128 units, allowing Unoco's
  intentional hover stand-off. Ground enemies must finish grounded or swimming.
  Ground-enemy waypoints also require clearance for that enemy's capsule, so a
  player-only perch cannot masquerade as a failure to traverse the level.
- Detects a stall after 600 ticks without at least four units of new forward
  progress, a fall below the configured kill plane, or an overall budget of
  30 simulated seconds per chunk.
- Omits combat, damage, culling, authored spawn markers, spawn animations, and
  Hashash teleporting to isolate terrain traversal. It does not claim that
  every possible seed, spawn position, pursuit direction, or combat situation
  is covered.

## Initial content freshness

The authoring generator's `--dry-run` validated 50 chunks and three levels, but
reported stale `authored_chunk_patterns.dart` and `staged_authored_terrain.dart`.
Existing authored and generated worktree edits were left untouched. These
findings apply to the runtime artifacts tested, not ungenerated editor changes.
After the next content generation, rerun the test before carrying results forward.

SHA-256 of the tested runtime inputs:

| File under `packages/runner_core/lib/` | SHA-256 |
| --- | --- |
| `levels/level_registry.dart` | `eade1512811d74b9753d44db415962fa373d3d22d52c38e23943cdb7aeee1d92` |
| `track/authored_chunk_patterns.dart` | `cf943c9c45904506931c3781f4bc6904f2b060f24f10d6a83f3b50609c6b074c` |
| `track/staged_authored_terrain.dart` | `d70e1eed79b688381932f5e14598fc385218da4c807924c484f6ed6634a9f6cf` |

`dart analyze packages/runner_core` reports no issues. The full Core package
suite reports **558 passing tests and only the five forest failures above**.
The targeted navigation, ground/flying locomotion, and swimming checks plus the
new cases also reported 43 passing tests and those same five failures. The user
then authorized the completed navigation/content repair.
