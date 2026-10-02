# Forest content drift and traversal repair verification

Verified: October 2, 2026. Branch: `feature/npc-section-guards`.
Implementation: `474aae70`, following NPC guard validation at `f92da996`.
All source edits were made in the isolated feature worktree. No deployment,
merge or production mutation was performed.

## Resolution

The inherited generator drift and all four current-source Forest failures are
resolved. The runtime was regenerated from the existing authored sources;
`authored_chunk_patterns.dart` and `staged_authored_terrain.dart` contain the
semantic refresh. Other generator-owned outputs have no semantic change.
Authored geometry and content sources were not edited.

A grounded placement previously lifted a capsule above any eligible shelf in
the same canonical support chain, even across a steep, ineligible intervening
face. Graph takeoffs could therefore be clear but unsupported and unreachable
by ordinary grounded motion. The placement query now requires an uninterrupted
profile-eligible neighbor path before a shelf can lift the chosen support pose.
Shelves beyond an ineligible face remain clearance blockers. Legal takeoffs are
then selected before the obstacle, and both enemies execute their existing jumps.

Catalog colliders, slope limits, locomotion and jump speeds, support-width rules,
arrival tolerances, finish controls and simulation budgets are unchanged.
A focused placement regression rejects the unsupported lift while existing
connected-facet tests retain legal peak/valley lifting. Four exact rock routes
retain continuous enemy state and cross their actual final boundary.

## Passing checks

| Check | Result |
| --- | --- |
| `dart analyze packages/runner_core` | No issues |
| `dart test --reporter expanded` in Core | 741 passed |
| Traversal matrix and harness targets | 48 passed: 27 scheduled cases, four exact routes, 17 controls/coverage checks |
| `dart analyze lib test` | No issues |
| `flutter test test/core test/tool/level_definition_generation_test.dart test/tool/generate_chunk_runtime_data_test.dart --reporter expanded` | 402 passed |
| `dart analyze` in replay validator | No issues |
| `dart test test --reporter expanded` in replay validator | 174 passed |
| Runtime generator dry-run | Fresh outputs; no blocking issues |
| `dart compile exe bin/server.dart` | Succeeded |
| Compiled `benchmark --ticks=36000 --strict` | All nine gates passed at clean `474aae70` |

The original four failing seed/enemy cases were reproduced after regeneration
before the placement edit, then all four passed with the fix. The full Core
suite passed before the final exact-route assertions were strengthened; the
separate 48-check matrix then passed those final assertions and all controls.

Functions and editor code were unchanged in this repair. Their earlier NPC
guard checks remain historical evidence in [the guard report](npc-section-guards.md).
Client, Functions and worker agreed on the then-pending `2026.10.1` gameplay
version. This placement correction and generated refresh affect replay outcomes
and were included in the subsequent [coordinated cutover](game-compat-2026.10.1-production.md);
scoring, rules and replay encoding are unchanged.

## Tested horizons and exclusions

Each scheduled route tests Grojib, Hashash and Unoco at seeds 7, 42 and 2026.
Forest stops before the final section repeats; Field and new_level explicitly
cover 32 chunks.

| Level/seed | Tested chunks | Required exit X |
| --- | ---: | ---: |
| Forest / 7 | 72 | 43,200 |
| Forest / 42 | 69 | 41,400 |
| Forest / 2026 | 71 | 42,600 |
| Field / each seed | 32 | 19,200 |
| new_level / each seed | 32 | 19,200 |

The exact fixtures start at `forest_early_first_chunk_001`, traverse either
`forest_rocky_grove_easy_004` or `forest_rocky_grove_easy_007`, then
`forest_rocky_grove_easy_008` and `forest_rocky_grove_easy_009`.
Grojib and Hashash each continuously cross the four-chunk
2,400-pixel exit. The real flat opener supplies a valid initial spawn; no enemy
is repositioned during traversal. `forest_rocky_grove_normal_001` supplies the
chase target beyond the finish and does not extend the tested horizon.

Scheduled routes likewise publish one real continuation chunk beyond their
finish. Arrival tolerance cannot shorten the route. Clear/blocked finish,
stall, kill-plane and budget controls pass. Derf is stationary and excluded
from pursuit; placement tests cover it. These routes isolate enemy movement
from combat, damage, camera culling, spawn-marker placement and Hashash teleport.
They do not establish full NPC Forest traversal or complete playable-run behavior.

## Compiled benchmark scope

[The raw benchmark JSON](forest-content-drift-repair-benchmark.json) records
`dirty: false`, revision `474aae70`, Windows 11 build 26200 and Dart 3.13.1.
The no-enemy fixture replays 36,000 ticks per level at 60 Hz and verifies
deterministic outcomes. Measured times were Forest 0.825056 seconds, Field
1.057530 seconds and new_level 1.179058 seconds.

The Forest player path advances about 332 pixels and remains at geometry
version 1, so this benchmark does not prove Forest traversal. Field and
new_level advance about 113,873 pixels at geometry version 190. Enemy route
completion is established by the separate matrix above. This local benchmark
does not measure crowded guard combat and does not replace the exact release
image's one-CPU/512-MiB container gate or signed-in gameplay smoke.

The [resolved finding](../archive/2026-10-02/audit/forest_content_drift_2026-10-02.md)
and [completed plan](../archive/2026-10-02/building/forest_content_drift_repair.md)
retain the reproduction and implementation history.
