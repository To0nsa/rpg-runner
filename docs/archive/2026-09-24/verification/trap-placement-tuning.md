# Per-placement trap tuning verification

Implemented on 2026-09-24. See the current [technical contract](../../../tdd/traps.md)
and [gameplay rules](../../../gdd/traps.md).

Each placement carries optional integer damage and wind-up overrides. Creation
and inline editing share HP/seconds inputs, strict precision/range checks and
Reset to defaults. The normal pending-edit, revision, Undo/Redo, Save, Build and
captured Play paths own these values. Animation wind-up is retimed in Core;
attack poses, projectile eligibility and Poison/Slow remain synchronized with
the existing gameplay rules. No runtime warning graphics were introduced.

## Completed checks

| Check | Result |
| --- | --- |
| Core full suite | 548 passed |
| Content pipeline full suite, run from its package directory | 59 passed |
| Root generator suite | 25 passed, including compiled tuned traps for all three types and real replay-worker parity |
| Editor trap interaction/input tests | 9 passed |
| Tuned unsaved Chunk/Level Play capture | Passed, including exact placement equality in both patterns |
| Client run-ticket prefetch tests | 16 passed |
| Functions build and Firestore emulator suite | Build passed; 212 tests passed |
| Replay validator suite | 140 passed |
| Validator executable and 36,000-tick strict benchmark | Compiled; every level passed determinism and throughput gates |
| Static analysis | Changed root Dart targets, editor and validator clean |
| Full editor suite (`--concurrency=2`) | 844 passed, 2 skipped, 1 existing working-tree baseline failure |

The full editor failure is
`phase4_authoring_baseline_test.dart: checked-in chunk source loads the current
polygon document`: current authoring data emits six `chunk_connection_unused`
warnings, while the test expects only `polygon_vertex_soft_target_exceeded`.
This is the same baseline failure observed before the tuning change.

The repository generator dry-run validated all 50 chunk sources and the level,
parallax and terrain-material definitions, then reported existing generated
drift in `authored_chunk_patterns.dart` and `staged_authored_terrain.dart`.
Unrelated authored/generated working-tree edits were neither rewritten nor
included in the feature commits.

The client, Functions and validator use compatibility `2026.09.5`. Remote
services were not deployed and remote run/board state was not modified. The
existing pre-live cancellation/reset procedure applies when deploying matching
builds; no historical-run migration was added.
