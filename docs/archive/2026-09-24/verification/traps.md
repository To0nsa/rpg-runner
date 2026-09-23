# Trap implementation verification

Date: September 24, 2026. Implementation through `13801aa8`.

Spike, Swinging Axe and Poison Darts are implemented across Core, shared source
compilation, Flame rendering, Chunk Creator, captured Play and replay validation.
Client/Functions/validator compatibility is `2026.09.4`. Thunder Bolt remains
equippable. No player ownership migration or replay wire change was introduced.

## Milestones

| Commit | Delivered boundary |
| --- | --- |
| `7567c614` | Accepted-hit statuses and terminal DoT pulses |
| `1badaa08` | Catalog, canonical source and compilation contracts |
| `dfbfcb50` | Shared swept first-contact projectile resolution |
| `21152a06` | Poison, Acid resistance and immutable trap attribution |
| `1f93c2bb` | Fixed-tick cycles, environmental darts and spell allowlists |
| `10389483` | Snapshot rendering and post-world hazard cues |
| `4da3af57` | Editor gestures, Save/Undo and captured assets |
| `13801aa8` | Integration/replay parity and compatibility cutover code |

## Checks

| Check | Result |
| --- | --- |
| Repository `dart analyze` | No issues |
| Editor and replay-validator `dart analyze` | No issues |
| Core package tests, run from its directory | 537 passed |
| Content-pipeline package analysis/tests | No issues; 58 passed |
| Validator complete tests | 140 passed |
| Functions build and emulator tests | Build passed; 212 tests passed |
| Final app ticket, trap rendering, terrain layering and Build snapshot tests | 21 passed |
| Gear authoring regression | 3 passed |
| Generator `--dry-run` | 50 chunks, 3 levels, no blocking issues |
| Generated trap fixture | All three traps, both characters, real worker accepted matching ticket/replay outcomes |
| Validator native compilation | Passed |
| Native `benchmark --ticks=36000 --strict` | Passed; [host report](trap-replay-benchmark.json) |

The editor complete suite was exercised. Its four Play-host image-fixture
failures were corrected by accommodating the 2816-pixel Axe sheet; the affected
Play integration/preparation and trap-authoring tests pass on rerun, including
the unsaved trap capture test. Water, prefab and marker regressions passed.
One baseline test remains failing in the current working tree:
`phase4_authoring_baseline_test.dart` expects only polygon soft-target warnings,
but authored content currently produces six `chunk_connection_unused` warnings.
No blocking content error occurs. The unrelated authored level/chunk/prefab and
generated-content edits were excluded from trap commits. Two existing editor
tests were skipped by their existing test configuration.

## Parity and reuse evidence

The generator fixture copies Core into an isolated temporary package, compiles
each trap from source, and runs the actual validator worker against a matching
ticket and digest-checked replay. Both characters match app run-end tick,
reason, score, gold and enemy counts. Assertions require actual trap activation,
Spike/dart damage and Poison feedback for the dart fixture. No alternate worker
content hook was added.

A separate equivalent Level Play/app fixture compares every tick's trap source,
phase/frame, projectile position, status mask and HP for both characters. Core
tests also cover initial prewarming, pause, trap-attributed lethal damage and
eight simultaneous Spikes counting an enemy death exactly once. Chunk Play
materialization is compared separately because its schedule intentionally differs.

The existing damage/status queue, projectile movement/hit/lifetime path and
damageable-target cache remain shared. Explicit render rectangles/anchors extend
the common sprite loader. Water and traps both use the extracted scene rectangle
gesture; domain validation stays separate. Editor commands retain the existing
composition revision, Undo/Redo, Save and captured-source boundaries.

## Release operations still pending

This is local implementation evidence, not a deployment record. The benchmark
records a dirty Windows workspace, including the current authored content; it is
not clean-artifact or constrained-container release evidence. Deployment should
use a reviewed coherent source/content snapshot and repeat its container smoke
and throughput checks.

No remote ticket issuance, run cancellation, data reset, board provisioning or
service deployment was performed. Follow the
[pre-live cutover](../../../tdd/traps.md#pre-live-compatibility-cutover): stop old
issuance, cancel disposable runs, let in-flight validation/settlement finish,
reset remaining test state and switch the matching artifacts. Fresh tickets and
boards replace historical-run migration and ticket-lifetime retirement waits.
