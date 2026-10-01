# Forest authored-content drift found during NPC guard validation

Observed: October 2, 2026. Status: unresolved, outside the NPC section-guard change.

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

The generated refresh was discarded from the NPC branch. Its committed runtime
matrix passes, but that result does not establish current authored Forest
traversability. Diagnose chunk composition, graph planning and motion execution
before accepting a separate content refresh. A release built after regeneration
must resolve this issue or explicitly address its scope; no fix or deployment
is authorized by this audit.

See [NPC guard validation](../verification/npc-section-guards.md) for the delivered
feature and its separate passing checks.
