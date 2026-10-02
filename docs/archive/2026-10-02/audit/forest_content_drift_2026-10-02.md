# Forest authored-content drift found during NPC guard validation

Observed and resolved: October 2, 2026. Status: closed by user-requested follow-up
at implementation commit `474aae70` on `feature/npc-section-guards`.

## Original observation

The section-guard branch starts from commit `135fa7cc`. Its committed authored
Forest sources include changes not present in `authored_chunk_patterns.dart` and
`staged_authored_terrain.dart`. Normalizing Windows checkout line endings removes
five spurious generator warnings; these two files still have semantic drift.
Regeneration introduces additional rocky-grove chunks and changed placements.
No authoring sources were changed by the guard implementation.

The generator's dry-run passes after temporary regeneration. The current-source
traversal matrix then fails four of 27 enemy cases. All fail on a small-rock
support in `forest_rocky_grove_easy_008`, with a reported reachable plan but no
forward progress for 600 ticks:

| Seed | Enemy | Route failure | Final local X | Tick |
| ---: | --- | --- | ---: | ---: |
| 7 | Grojib | Chunk 19 of 72, 43,200 world pixels | 238.20 | 2907 |
| 7 | Hashash | Chunk 19 of 72, 43,200 world pixels | 245.38 | 2866 |
| 2026 | Grojib | Chunk 22 of 71, 42,600 world pixels | 238.08 | 3462 |
| 2026 | Hashash | Chunk 22 of 71, 42,600 world pixels | 245.50 | 3393 |

A detached worktree at `135fa7cc`, with only those same two regenerated files
copied in, reproduces all four failures with identical poses and tick numbers.
It contains no section-guard code. This establishes a pre-existing content/
movement issue rather than a guard regression. The existing matrix retains
seeds 7 and 2026; do not widen actor capabilities or skip the failing chunks.

Reproduction, after dependency resolution and runtime generation:

```powershell
dart run tool/generate_chunk_runtime_data.dart
Push-Location packages/runner_core
dart test test/navigation/level_enemy_traversal_test.dart --name 'forest traversal seed=(7|2026) (grojib|hashash)' --reporter expanded
Pop-Location
```

The temporary generated refresh was discarded during the initial guard task.
Those historical committed-runtime passes did not establish current authored
Forest traversability.

## User-requested resolution

The user subsequently requested fixing this finding. The follow-up retains the
fresh generated runtime and corrects shared grounded placement: only an
uninterrupted profile-eligible support path can lift a capsule. A shelf beyond
a steep ineligible face stays an obstacle, so the graph selects a takeoff that
the enemy can actually reach. Authored geometry, collider/profile limits, jump
and movement speeds, finish controls and tick budgets were not changed.

All four original failures now pass. The full fresh-content traversal matrix
and controls pass 48 checks, including four exact rock-sequence regressions.
Core tests (741), Flutter Core/generator tests (402), worker tests (174),
analyzers, generator freshness and the clean compiled strict replay benchmark
pass. Forest horizons are 72, 69 and 71 chunks at seeds 7, 42 and 2026; the
exact fixtures cover four chunks continuously from a valid authored opener.

See [follow-up verification](../../../verification/forest-content-drift-repair.md)
for detailed evidence, benchmark limits and exclusions, and the
[completed repair plan](../building/forest_content_drift_repair.md). This closes
the drift and traversal finding. Matching client/Functions/worker deployment
under the pending `2026.10.1` release remains a separate authorized cutover.
No deployment occurred.

See [NPC guard validation](../../../verification/npc-section-guards.md) for the delivered
feature and its separate passing checks.
