# Windows Chunk Playtest Phase 2 Implementation Checklist

Date: August 19, 2026

Status: Complete (August 19, 2026)

Source plan: [Windows Chunk Playtest and Reusable Desktop Input Plan](plan.md)

Phase 1 evidence:
[Phase 1 implementation checklist](phase1-implementation-checklist.md)

This checklist implements Phase 2 only: create a deterministic, immutable Core
scenario for a selected draft chunk, admit that draft through a one-record
terrain overlay, and run it through an explicit `GameCore.chunkPlaytest`
construction path. It does not add Flutter, Flame, editor UI, or desktop input.

## Completion gate

Phase 2 is complete only when:

- the selected draft `ChunkPattern` and `StagedTerrainChunkData` replace the
  same admitted generated chunk key and no other terrain lookup changes
- an inactive, missing, wrong-level, malformed, width-incompatible, or
  scheduler-unreachable selected chunk fails before Core construction
- the scenario path uses only canonical scheduler-reachable transitions,
  includes a real compatible entry into the selected chunk where one exists,
  and has a deterministic loop for continued streaming beyond it
- every path seam involving the draft passes Core's exact boundary comparison;
  no synthetic ground or collision pad is introduced
- the scenario owns explicit seed, tick rate, visual theme, player, and loadout
  inputs and can build a fresh runtime source for deterministic restart
- `GameCore.chunkPlaytest` is an explicit tool/test factory; the normal
  constructor, replay inputs, run protocol, and generated artifact remain
  unchanged
- identical scenario and command streams produce identical snapshots while a
  changed draft record is visible in the headless terrain/render snapshot

## Scope boundaries

### In scope

- a Core-only immutable chunk-playtest scenario and deterministic path record
- canonical path selection from the existing terrain authoring scheduler result
- exact path-seam validation using existing Core boundary signatures
- a read-only staged-terrain catalog interface and one-record overlay
- a path-backed `ChunkPatternSource` used only by the playtest scenario
- `GameCore.chunkPlaytest` and headless restart/determinism tests
- production-constructor parity characterization and Core/TDD documentation

### Out of scope

- editor snapshot compilation or scenario-preparation UI
- semantic gameplay actions, keyboard, mouse, focus, or touch migration
- Flame/game host construction and workspace-backed image loading
- Play/Edit state, shortcuts, route guards, or editor persistence behavior
- backend, Firebase, replay recording, run tickets, rewards, or protocol fields
- authoring JSON, generated Dart, terrain materials, or unrelated render work

## Chosen Core boundary

| Concern | Phase 2 owner |
| --- | --- |
| Draft source compilation | `runner_content_pipeline` (already delivered) |
| Active/reachable scheduler analysis | existing Core authoring scheduler |
| Canonical finite-prefix plus loop path | new Core playtest scenario builder |
| Draft terrain replacement | validated staged-terrain overlay catalog |
| Draft pattern replacement | playtest-only path pattern source |
| Simulation, collision, spawn, snapshots | unchanged `GameCore` systems |
| Restart | host later calls `GameCore.chunkPlaytest` again with same scenario |

The scenario derives its scheduler metadata from the admitted artifact plus the
selected draft record. Non-selected path patterns and terrain records remain
the generated runtime products. The fixed path ignores runtime tier requests
only after it has been proven as an ordered chain of scheduler-reachable seams;
this isolates the target near the start without claiming that it is a normal
production run sequence.

## Step 0 — Baseline and construction audit

- [x] Re-read Core package and simulation-contract guidance.
- [x] Trace normal scheduler prewarm, `TrackManager`, staged candidate binding,
      player placement, and snapshot publication.
- [x] Confirm replay validator, ghost playback, and app runs call only the
      normal `GameCore` constructor.
- [x] Confirm Phase 1 exposes typed draft `ChunkPattern` and
      `StagedTerrainChunkData` without creating a Core reverse dependency.
- [x] Record the unrelated existing full-Core test exception and keep it out of
      Phase 2 implementation scope.

## Step 1 — Generalize staged-terrain lookup safely

- [x] Introduce a narrow read-only catalog interface used by binding/candidate
      builders.
- [x] Keep `StagedTerrainArtifactCatalog` as the normal generated-artifact
      implementation with unchanged validation and lookup behavior.
- [x] Add a validated overlay that requires the selected key in the admitted
      base catalog and substitutes exactly one structurally valid draft record.
- [x] Reject replacement key, level, dimensions, and format incompatibilities
      before stream binding.
- [x] Test base fallback, repeated selected-key binding, invalid replacement,
      and no mutation of the base catalog.

## Step 2 — Add immutable playtest scenario and path

- [x] Add an immutable scenario containing level, visual theme, seed, tick
      rate, draft pattern/terrain, player, loadout, and canonical path.
- [x] Require the draft pattern/staged keys and assembly metadata to agree.
- [x] Require active status, matching level, finite positive chunk dimensions,
      and an admitted generated record for the same stable key.
- [x] Derive scheduler metadata from the admitted artifact, replacing only the
      selected record's current status/tier/group facts.
- [x] Surface existing scheduler diagnostics if reachability enumeration fails.
- [x] Select the earliest real incoming transition when available, then follow
      canonical outgoing transition order until a deterministic loop exists.
- [x] Preserve the transition canonical records as inspectable path evidence.
- [x] Fail if the selected chunk is not scheduler-reachable or the path cannot
      continue beyond it.

## Step 3 — Validate exact draft seams

- [x] Rehydrate each path record through the overlay catalog at local origin.
- [x] Build left/right Core boundary signatures for every prefix and loop edge.
- [x] Reject incompatible coverage/continuation with the established
      `staged_reachable_seam_mismatch` diagnostic shape.
- [x] Prove a deliberately malformed draft boundary cannot enter Core.
- [x] Prove no synthetic terrain record or collision pad is added.

## Step 4 — Add the explicit Core factory

- [x] Add `GameCore.chunkPlaytest` with scenario-only construction inputs.
- [x] Route it through the same scheduler prewarm, terrain authority, spawn,
      system, tick, and snapshot initialization used by normal Core.
- [x] Pass the overlay catalog only through the private shared constructor;
      expose no optional preview flag on normal construction.
- [x] Force tooling run identity behavior without adding replay/run-ticket
      configuration.
- [x] Ensure every factory call creates fresh path-source/Core runtime state.

## Step 5 — Determinism and parity tests

- [x] Headlessly construct a scenario whose draft terrain/render facts are
      visible at the selected streamed occurrence.
- [x] Run identical tick-stamped commands through two fresh factory calls and
      compare snapshots, terrain identities, events, and terminal state.
- [x] Rebuild from the same scenario after advancing one Core and prove the
      restart begins from the original tick-zero snapshot.
- [x] Prove selected occurrences use draft pattern markers/visuals and draft
      terrain while neighboring records use generated content.
- [x] Characterize the normal constructor before/after with an identical seed,
      level, player, loadout, command stream, and snapshot output.
- [x] Prove normal construction still rejects terrain-harness mutation and has
      no access to the playtest overlay.

## Step 6 — Documentation and boundary review

- [x] Update the Core simulation TDD with the implemented playtest-only
      construction, overlay, path, restart, and replay-isolation invariants.
- [x] Update this source plan with factual Phase 2 delivery status only.
- [x] Confirm no GDD update is needed because player-facing game behavior did
      not change.
- [x] Confirm no public embed API, run protocol, backend, validator, generated
      content, or authoring source changed.

## Step 7 — Verification and milestone commit

- [x] Run `dart format` on changed Dart files.
- [x] Run `dart analyze packages/runner_core`.
- [x] Run focused scenario, overlay, staged binding, scheduler, determinism,
      and production stream tests.
- [x] Run the complete `runner_core` suite and record any pre-existing external
      failure separately.
- [x] Run focused root Core determinism/streaming tests.
- [x] Run `dart run tool/generate_chunk_runtime_data.dart --dry-run` and prove
      generated outputs remain clean.
- [x] Run `git diff --check`.
- [x] Confirm all unrelated terrain-render/editor changes remain outside the
      Phase 2 commit.
- [x] Commit the independently validated Phase 2 milestone.

## Evidence record

### Validation

| Date | Command/test | Result | Notes |
| --- | --- | --- | --- |
| August 19, 2026 | `dart analyze packages/runner_core` | Pass | No issues. |
| August 19, 2026 | Focused Phase 2 Core suites | Pass (27 tests) | Scenario, overlay, binding, scheduler, production streaming, and deterministic contracts. |
| August 19, 2026 | `dart test` in `packages/runner_core` | External baseline exception | 379 tests passed; the pre-existing malformed-record expectation in `staged_terrain_world_geometry_test.dart` remains the only failure. |
| August 19, 2026 | Focused root Core suites | Pass (10 tests) | Determinism, streaming, level selection, and command scheduling. |
| August 19, 2026 | `dart analyze lib` | Pass | Existing Flutter/Flame consumers compile against the additive Core API. |
| August 19, 2026 | Replay validator analysis and replay simulation | Pass (2 tests) | Validator continues to construct normal Core; no playtest payload or replay option exists. |
| August 19, 2026 | Content-pipeline analysis | Pass | Core retains no reverse dependency. |
| August 19, 2026 | Generator `--dry-run` | Pass | 9 chunks, 3 levels, 3 parallax themes, and 1 terrain material validate with no generated drift. |
| August 19, 2026 | `git diff --check` | Pass | No whitespace errors. |

### Delivered contracts

- `StagedTerrainCatalog` is the read-only stream-binding boundary;
  `StagedTerrainArtifactCatalog` remains the production implementation.
- `StagedTerrainOverlayCatalog` replaces one structurally valid admitted key
  and delegates every other lookup to the generated base catalog.
- `ChunkPlaytestScenario` snapshots draft pattern collections, validates the
  draft and every reachable seam touching it, and exposes canonical path
  evidence with a deterministic loop.
- `GameCore.chunkPlaytest` forces tooling run ID zero and otherwise shares the
  normal prewarm, terrain, spawn, system, tick, and snapshot pipeline.
- Rebuilding the same scenario is the restart contract; no Core state, input
  state, or wall-clock seed survives between factory calls.

Planning commit: `72d8543d` (`docs(editor): plan phase two chunk playtest
core`). Implementation commit: `77af803f` (`feat(core): add deterministic
chunk playtest scenarios`).

## Closeout

- [x] Every Phase 2 checkbox is complete or explicitly accepted with evidence.
- [x] Update status to `Complete` with date and commit reference.
- [x] Do not begin Phase 3 input work until the headless scenario, restart, and
      normal-constructor parity gates are green.

Phase 2 completion means Core can deterministically run one validated draft
chunk through the production simulation boundary. It does not yet provide the
shared semantic dispatcher, keyboard/mouse adapter, Flame playtest host, or
Chunk Creator Play/Edit UI.
