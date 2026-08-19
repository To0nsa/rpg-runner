# Windows Chunk Playtest Phase 6 Implementation Checklist

Date: August 19, 2026

Status: Complete

Source plan: [Windows Chunk Playtest and Reusable Desktop Input Plan](plan.md)

Phase 5 evidence:
[Phase 5 implementation checklist](phase5-implementation-checklist.md)

This checklist completes the active plan. Phase 6 hardens the delivered
Windows Chunk Creator Play mode, measures its preparation/runtime boundary,
documents fixed controls and limitations, records native Windows acceptance,
and closes the building plan. It does not mount desktop input in the product
game; that remains the plan's separately labeled follow-on.

## Completion gate

Phase 6 is complete only when:

- resize, non-unit device-pixel ratio, fitted-viewport alignment, and mouse
  boundary tests prove aim remains in logical host coordinates
- app deactivation and focus loss neutralize held keyboard/mouse input before
  pause and require explicit resume
- repeated editor Play/Stop/retry/restart cycles retain Edit state and do not
  leak host controllers, focus nodes, images, games, or listeners
- preparation timing is measured on the current Windows environment and the
  accepted-document capture remains outside widget `build`
- the standalone README documents entry, controls, no-reward/replay behavior,
  focus/pause rules, unsupported platforms, and known Phase 6 limitations
- the editor analyzes, its focused and full suites reach their known baseline,
  relevant root/Core/pipeline checks pass, generation is dry-run clean, and a
  Windows release build succeeds
- a native Windows acceptance record covers keyboard rollover, mouse actions,
  app deactivation, resize, DPI, pause/restart/stop, game over, and return to
  the unchanged Edit projection
- the active plan is archived only after all required evidence is recorded

## Scope boundaries

### In scope

- focused additions to existing desktop aim/adapter/host/editor tests
- a deterministic preparation profile with recorded environment/results
- native Windows editor smoke and acceptance instructions/evidence
- `tools/editor/README.md`, relevant TDD status, checklist, and plan closeout
- cleanup discovered directly by the hardening pass

### Out of scope

- product `RunnerGameWidget` desktop composition or `runner.dart` exports
- binding remapping, settings persistence, gamepad/controller input
- Core gameplay, replay, protocol, backend, reward, leaderboard, or ghost
  changes
- authoring source or generated-output writes

## Step 0 — Audit existing hardening evidence

- [x] Confirm keyboard mappings, alternate sources, opposing directions,
      repeat suppression, and host-key exclusion already have focused tests.
- [x] Confirm mouse chords, pointer cancel, focus acquisition/loss, pause, and
      disposal already use the shared cancel path.
- [x] Confirm letterbox, zero-delta, and non-default viewport alignment already
      have deterministic aim coverage.
- [x] Confirm host restart/stop stale callbacks and editor stale preparation
      already have generation tests.
- [x] Keep the unrelated authored terrain-material JSON outside Phase 6 edits
      and commits.

## Step 1 — Add missing automated hardening coverage

- [x] Add explicit logical-coordinate invariance tests across resize and
      non-unit device-pixel ratios.
- [x] Exercise mouse entry/exit at every fitted-viewport boundary after resize
      without disturbing held keyboard movement.
- [x] Exercise app inactive/paused/hidden/detached handling while keyboard and
      mouse inputs are held, proving neutralization and explicit resume.
- [x] Exercise repeated editor Play/Stop and failed Retry/Return cycles with
      stale completions and no post-disposal notifications/exceptions.
- [x] Exercise runtime resize while ready/running/paused and prove restart/stop
      remain deterministic.
- [x] Keep all hardening in existing semantic/adapter/host boundaries; do not
      add editor-aware behavior to gameplay input.

## Step 2 — Measure preparation and runtime behavior

- [x] Add a focused Windows profile/benchmark path for accepted-document
      capture, background preparation, host-ready startup, and repeated cycles.
- [x] Use the canonical repository fixture and fixed scenario defaults.
- [x] Record warmup, sample count, median, p95, maximum, environment, revision,
      and dirty-state caveat without writing authoring/generated files.
- [x] Treat correctness/no-long-frame ownership as the gate; do not add a
      brittle cross-machine millisecond threshold without reference evidence.
- [x] Fix any measured synchronous work that occurs from widget `build` or
      causes a reproducible visible long frame.

## Step 3 — Complete Windows controls and limitation documentation

- [x] Add a Chunk Play Mode section to `tools/editor/README.md`.
- [x] Document Play button/F5 entry, Enter start, P pause/resume, F6 restart,
      F5/Escape stop, keyboard/mouse gameplay bindings, and focus acquisition.
- [x] Document app deactivation pause with explicit resume and the
      `PLAYTEST - NO REWARDS/REPLAY` boundary.
- [x] Document valid accepted pending changes, local draft/validation blockers,
      Windows-only support, fixed seed/character/loadout, and no remapping or
      gamepad support.
- [x] Update gameplay-input and editor-host TDD status/evidence.
- [x] Confirm root README/public embedding docs remain unchanged because the
      product host still does not mount desktop input.

## Step 4 — Native Windows acceptance

- [x] Build the release editor executable from `tools/editor`.
- [x] Run a native Windows-engine integration/smoke pass at normal and scaled
      logical view sizes.
- [x] Confirm keyboard rollover and left/right mouse actions reach the real
      host while gameplay focus is owned.
- [x] Confirm app deactivation/Alt+Tab equivalent cancels held input and pauses
      without automatic resume.
- [x] Confirm resize, high-DPI logical coordinates, letterbox boundaries, and
      non-default alignment preserve mouse aim.
- [x] Confirm pause/resume, restart, stop, game over, and return to Edit.
- [x] Record tester/environment/revision, exact automated versus manual
      evidence, failures, and final decision in a Phase 6 acceptance record.

## Step 5 — Final validation and closeout

- [x] Run `dart format` on changed Dart files.
- [x] Run root `dart analyze lib test` and relevant input/host tests.
- [x] Analyze and test `packages/runner_core` and
      `packages/runner_content_pipeline` relevant slices.
- [x] Run `cd tools/editor && dart analyze` and focused Phase 6 tests.
- [x] Run `cd tools/editor && flutter test`, recording only verified unrelated
      working-tree exceptions.
- [x] Run `dart run tool/generate_chunk_runtime_data.dart --dry-run`.
- [x] Run `cd tools/editor && flutter build windows`.
- [x] Run `git diff --check`, package-boundary, forbidden-import, backend, and
      repository-write searches.
- [x] Update this checklist and the source plan with factual evidence.
- [x] Move the completed plan/checklists into `docs/building/archived/` and
      update active links.
- [x] Commit hardening, documentation, acceptance evidence, and archive
      closeout as coherent validated milestones.

## Evidence record

### Validation

| Date | Command/test | Result | Notes |
| --- | --- | --- | --- |
| August 19, 2026 | Hardening and focused lifecycle tests | Pass | 68 focused root input/host tests and 12 focused editor preparation/integration/shortcut tests passed. |
| August 19, 2026 | Preparation/runtime profile | Pass | 2 warmups, 12 foreground samples, and 4 background samples; capture median/p95 5.021/6.934 ms, synchronous preparation 10.057/13.735 ms, background preparation 9.761/14.546 ms. |
| August 19, 2026 | Full validation | Accepted with one unrelated working-tree exception | Full root suite passed 802 tests; Core/pipeline analysis and tests, editor analysis/focused tests, and generator dry-run passed. Full editor suite completed 526 passing tests plus the known terrain-material line-ending exception. |
| August 19, 2026 | Windows build/acceptance | Pass | Release build succeeded; native profile Windows-engine test passed at revision `c3d93f9b` and persisted source-hash, input, resize/DPI, lifecycle, restart, and Edit-restoration evidence. |

### Delivered contracts

- `94cb6d3d` added resize/DPI, boundary, app-lifecycle, repeated-cycle,
  disposal, and preparation-profile coverage without changing runtime code.
- `0b90c171` added the native Windows-engine acceptance target and report
  driver over the real repository-backed Chunk Creator.
- The Phase 6 acceptance record explicitly distinguishes native automation,
  deterministic supporting tests, and the absence of a human visual pass.
- `tools/editor/README.md` and the input/host TDDs now document the implemented
  controls, focus rules, isolation, limitations, and evidence.
- The root product README and public embedding API remain unchanged because
  `RunnerGameWidget` still does not mount desktop input.

## Closeout

- [x] Every Phase 6 checkbox is complete or explicitly accepted with evidence.
- [x] Mark the source plan complete and archive the dedicated plan folder.
- [x] Do not implement the product-game desktop follow-on as part of Phase 6.

Phase 6 completion means the Windows editor playtest plan is closed with
hardening, measured evidence, documented controls, and a native Windows
acceptance record. Product desktop adoption remains a separate future change.
