# Chunk connections validation — September 15, 2026

Repository implementation is complete. No production deployment was performed.
The current contract and release prerequisites are in
[chunk connections](../../../../tdd/chunk_connections.md).

## Delivered behavior

- Normal, Raised and High use the Level's absolute ground reference. The default
  step is 24 px, with a strict 1–32 px range. Existing geometry never moves when
  the preset changes.
- Exact continuation analysis excludes future dead ends, preserves all authored
  length choices and distinctness, and proves the repeating tail. Core, captured
  Play, generator admission and editor diagnostics share that implementation.
- Connections, joined previews, guides, starter creation and Flow repair reuse
  existing cards, forms, navigation guards and Undo/Save. Neighbor navigation
  restores the original Chunk and viewport.
- Level schema v3 has an explicit migration. Compatibility 2026.09.0 requires
  old tickets to drain on the old worker before switching the release set.

## Checks

- Core: full 421-test suite passed on committed source assets. After regenerating
  the current workspace, seven fixture failures exposed assumptions about old
  Forest composition. Fixtures now use plain ground where their contracts require
  it; all 14 tests in the affected scenario/stream suites passed on current assets.
- Root gameplay: all 359 tests passed against current generated assets.
- Shared pipeline: all 52 tests passed, including water and boundary contracts.
- Generator: all 24 tests passed; Level generation, strict migration, and both
  committed-source and current-workspace generator dry-runs passed. Current
  generation validates 27 chunks, three Levels and three material/theme definitions.
- Editor: full run passed 812 tests with two existing skips. One preparation
  performance test timed out under concurrent load and passed in isolation.
  The remaining prefab baseline assertion reports an extra existing
  `prefab_collision_shape_outside_visual_bounds` warning in uncommitted prefab
  source; the same tests pass against committed assets. No prefab source was
  changed by this implementation.
- New elevation fixtures passed for both characters at 24 and 32 px steps,
  exercising creation, exact seams, Undo/Redo, Save/reload, a repeating hill
  route, High jumps inside the viewport, and equal replayed positions for 1,800
  ticks. Cancellation, stale settings, duplicate identity and unsupported edges
  also passed. The actual neighbor-open/return workspace journey passed.
- Embedded playtest host: all seven lifecycle tests passed after updating the
  fixture opener and waiting for real terrain-preparation isolates. Client
  ticket, submission, leaderboard and ghost tests passed.
- Functions: build and all 208 tests passed. Replay worker: all 130 tests passed.
- Static analysis passed for Core, pipeline, editor, replay worker and the
  changed app/migration/generation code.

## Performance and release boundary

A ten-chunk four-distinct pool produces 482 states and 3,451 edges. On the Windows
host, exact analysis took about 5–8 ms and 200,000 selections about 0.51–0.53 s.
Runtime cursors keep constant history and replay earlier queries deterministically.
The graph has explicit 32,768-state and 262,144-edge admission limits.

The compiled replay worker passed `benchmark --ticks=36000 --strict` for all
three included Levels using current generated content. Field and the plain test
Level reached 190 geometry publications. The fixture bot stopped making forward
progress in Forest, so that benchmark's Forest timing is replay-loop evidence;
it does not establish sustained Forest streaming throughput. The dedicated flat
stream and hill-route fixtures provide that separate traversal evidence. The
one-CPU/512 MiB production container check and compatibility drain remain deployment
prerequisites, not completed production verification.

Feature commits exclude the user's existing chunk/prefab/tile edits. Generated
outputs for those current edits remain alongside them in the working tree.
