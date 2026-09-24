# Fixed trap depth verification

Implemented on 2026-09-24. The current contract is in
[traps](../../../tdd/traps.md).

Each trap has an authored integer `zIndex`, defaulting to `-21`, on the same
scale as prefabs. Compilation subtracts the chunk terrain depth; immutable
snapshots carry the result into Flame. Idle, wind-up, attack, cooldown and
waiting-for-clear all use the same priority. The phase-dependent constants and
editor idle/active render passes were removed.

Create and inline-edit controls use the existing placement, revision, pending
input, Undo/Redo and Save paths. The editor interleaves prefabs and traps by
depth using a shared borrowed image cache. Overlapping trap selection follows
front-to-back depth. Separate flying darts retain their projectile priority.

## Checks

| Check | Result |
| --- | --- |
| Core package suite | 548 passed |
| Updated Core trap integration target | 11 passed, including three new depth-only gameplay parity regressions |
| Root Core integration suite | 366 passed |
| Content pipeline suite | 59 passed, including nonzero terrain-depth normalization |
| Renderer tests | 2 passed; every phase checked at Z-index -21, -1 and 3 |
| Generated trap fixture | Passed typed compiled-depth and app/replay-worker checks |
| Editor authoring and captured Play targets | 19 passed |
| Editor depth ordering/picking target | 2 passed |
| Full editor suite | 846 passed, 2 skipped, 1 existing working-tree baseline failure |
| Static analysis | Core, pipeline, changed root render/generator targets and editor clean |

The existing `phase4_authoring_baseline_test.dart` failure still reports six
`chunk_connection_unused` warnings where its assertion expects only
`polygon_vertex_soft_target_exceeded`. No new failures occurred.

Repository generator dry-run validated current authored sources and reported
the existing generated drift in `authored_chunk_patterns.dart` and
`staged_authored_terrain.dart`. Unrelated authored/generated edits were left
untouched and excluded from the feature commits.

Depth-only changes preserve gameplay tick by tick, so compatibility remains
`2026.09.5`. This presentation change requires no backend compatibility change
or run migration. No remote services were deployed.
