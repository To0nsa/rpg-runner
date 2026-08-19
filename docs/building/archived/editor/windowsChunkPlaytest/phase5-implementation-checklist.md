# Windows Chunk Playtest Phase 5 Implementation Checklist

Date: August 19, 2026

Status: Complete (August 19, 2026)

Source plan: [Windows Chunk Playtest and Reusable Desktop Input Plan](plan.md)

Phase 4 evidence:
[Phase 4 implementation checklist](phase4-implementation-checklist.md)

This checklist implements Phase 5 only: mount the completed backend-free host
inside the current-schema Windows Chunk Creator, prepare its scenario from the
exact accepted in-memory document, guard editor/host shortcuts, retain the Edit
workspace projection, and prove that Play/Stop performs no repository writes.
It does not adopt desktop input in the product game or complete the manual
Windows hardening pass reserved for Phase 6.

## Completion gate

Phase 5 is complete only when:

- the editor depends on `rpg_runner` only through its tooling `playtest.dart`
  barrel and never imports internal game/UI paths
- one immutable preparation input captures the selected accepted chunk,
  Prefab catalog, tile catalog, level/theme identity, fixed seed, character,
  and loadout without reading or writing temporary authoring files
- the shared content pipeline and `ChunkPlaytestScenario` remain the only
  compilation/admission authorities
- current plugin-owned pending changes are playable, while active operations,
  dialogs, uncommitted page drafts, blocking validation issues, missing owner,
  unsupported platform/source, loading, and exporting block entry
- preparing and Play mode disable route switching, reload, apply, undo, redo,
  owner changes, and every authoring mutation
- the mounted authoring subtree survives Play/Stop with selection, domain,
  viewport, toggles, pending diff, document identity, and history unchanged
- F5/F6/Escape/P/Enter are mode-scoped host commands and never fire from an
  Edit-mode text field or modal dialog
- canceled/stale preparation cannot mount a host, app deactivation cancels
  input and pauses safely, and explicit Stop disposes the runtime before Edit
  returns
- focused tests prove valid/invalid preparation, accepted pending content,
  shortcut guards, lifecycle, restoration, rapid cycles, and no file changes

## Scope boundaries

### In scope

- an editor-side immutable preparation/result adapter under
  `tools/editor/lib/src/playtest/**`
- `rpg_runner` tooling dependency and `package:rpg_runner/playtest.dart` import
- Play availability/status in the normal Chunk-v2 workspace header
- page-local edit/preparing/play/failed state and generation cancellation
- preserved offstage Edit subtree while preparing/playing
- shell delegation for guarded playtest shortcuts, app lifecycle, and route
  lock state
- fixed Phase 5 scenario defaults: seed `4401`, Eloise, default empty loadout
- deterministic diagnostics and focused editor tests

### Out of scope

- product Windows desktop input adoption or `runner.dart` export changes
- binding customization, persistence, remapping UI, or controller/gamepad input
- changing Core, pipeline, protocol, replay, reward, ghost, or backend contracts
- editor writes, temporary source files, generated-output refresh, or automatic
  Apply To Files
- manual Alt+Tab/DPI/resize/performance acceptance and final README controls
  sign-off, which remain Phase 6

## Chosen integration boundary

| Concern | Phase 5 owner |
| --- | --- |
| Accepted authoring snapshot | `EditorSessionController.document` |
| Selected owner/local blockers | mounted `ChunkAuthoringWorkspaceState` |
| Canonical source-string snapshot | editor preparation adapter using existing codecs |
| Runtime compile/materialization | `runner_content_pipeline` |
| Scheduler/seam admission | `ChunkPlaytestScenario` |
| Runtime/render/input lifecycle | `RunnerChunkPlaytestHost` |
| Edit/prepare/play orchestration | `ChunkCreatorPage` |
| Global key/dialog/route guard | `EditorHomePage` through a narrow page contract |
| Repository writes | existing explicit plugin/store Apply flow only |

## Step 0 — Integration audit

- [x] Re-read root, editor, game/UI, and documentation guidance.
- [x] Trace Chunk page/workspace selection, local drafts, active operations,
      dialogs, pending changes, undo/redo, viewport, and panel ownership.
- [x] Confirm current codecs can encode the accepted in-memory Chunk, Prefab,
      and tile DTOs without repository I/O.
- [x] Confirm the shared single-chunk pipeline returns the exact typed pattern
      and staged terrain required by `ChunkPlaytestScenario`.
- [x] Confirm the shell already owns route-current, dialog, editable-text,
      global shortcut, and app-lifecycle coordination seams.
- [x] Keep the unrelated authored terrain-material JSON outside every Phase 5
      commit.

## Step 1 — Add the editor preparation adapter

- [x] Add an immutable sendable preparation input containing canonical source
      paths/text and the selected level/theme/default scenario choices.
- [x] Snapshot from the accepted `ChunkV2Document`, never its repository
      baseline contents, so accepted unapplied commands are included.
- [x] Resolve the selected chunk and level deterministically and fail with
      stable editor-facing codes when either is missing or unsupported.
- [x] Encode through `ChunkV2FileCodec`, `PrefabV3FileCodec`, and
      `PrefabTileFileCodec`; do not duplicate their canonicalization.
- [x] Compile through `compilePolygonTerrainRuntimeChunkSource`; retain its
      canonical issue ordering and source context.
- [x] Construct `ChunkPlaytestScenario` with `LevelRegistry`, fixed seed 4401,
      Eloise, and the empty default loadout; map thrown scenario failures into
      stable preparation diagnostics.
- [x] Run the pure preparation work outside the UI isolate on Windows and make
      the runner injectable for deterministic widget tests.
- [x] Return no partial scenario when any blocking issue exists.

## Step 2 — Expose narrow workspace readiness

- [x] Expose only the selected chunk key and whether an active operation or
      uncommitted local field/polygon draft blocks snapshotting.
- [x] Do not treat accepted session pending changes as a local-draft blocker.
- [x] Add a Play button to the current-schema header with a concise disabled
      reason for platform/source, owner, loading/exporting, local operation, or
      validation blockers.
- [x] Keep migration-required/missing source fail closed with no Play surface.
- [x] Route button and F5 entry through the same readiness evaluation.

## Step 3 — Implement the page-local Play/Edit state machine

- [x] Add explicit edit, preparing, playing, and preparation-failed states with
      a monotonic generation token.
- [x] Capture the exact accepted document identity, selected owner, workspace
      path, and immutable preparation input before asynchronous work begins.
- [x] Cancel stale preparation on Stop, disposal, controller/document/context
      replacement, or a newer request; stale results must be ignored.
- [x] Keep the same `ChunkAuthoringWorkspace` subtree mounted offstage and
      non-interactive during preparing/playing so local UI state survives.
- [x] Mount `RunnerChunkPlaytestHost` with a fresh public controller and
      `RunnerWorkspaceAssetBundle` for the captured workspace.
- [x] Surface preparation diagnostics in editor language with Retry and Return
      to Edit; leave host loading/runtime diagnostics with the host.
- [x] Dispose each host controller only after its host unmounts and make rapid
      Play/Stop/retry cycles idempotent.
- [x] Return to the captured Edit projection without reloading, applying,
      incrementing revision, or changing undo/redo/pending state.

## Step 4 — Guard shell actions and host shortcuts

- [x] Add a narrow page contract for playtest-active shell locking, shortcut
      dispatch, and app-lifecycle notification.
- [x] Disable route selection, reload, apply, undo, and redo while preparing or
      playing; retain only page-owned cancel/stop/runtime actions.
- [x] Dispatch unmodified physical/logical F5, F6, Escape, P, and Enter only on
      `KeyDownEvent`; repeats and modified chords must not duplicate commands.
- [x] In Edit: F5 requests Play only when readiness passes.
- [x] In Play: F5/Escape stop, F6 restarts the same scenario, P toggles
      pause/resume, and Enter starts only from ready.
- [x] Refuse host shortcuts whenever a modal route or focused `EditableText`
      owns Edit-mode input.
- [x] Forward app inactive/paused/detached/hidden to focus release so running
      input is canceled before the host pauses; do not auto-resume.
- [x] Ensure gameplay actions remain local to the Phase 3 adapter and never
      become shell shortcuts.

## Step 5 — Prove snapshot fidelity, restoration, and write safety

- [x] Unit-test preparation from the canonical repository fixture.
- [x] Mutate one accepted in-memory chunk without applying and prove the
      resulting scenario pattern/terrain reflects that snapshot.
- [x] Test missing owner/level, invalid pipeline content, inactive/unreachable
      chunk, and deterministic issue ordering/failure codes.
- [x] Widget-test Play button and F5 readiness for pending accepted changes,
      local drafts/gestures, blocking validation, and unsupported source.
- [x] Test preparing cancel/stale completion, failed retry, ready Enter,
      pause/resume, focus/app deactivation, restart, game-over, and Stop.
- [x] Test F-keys/Escape/P/Enter do not fire from Edit text fields or dialogs.
- [x] Test route/reload/apply/undo/redo are unavailable while locked.
- [x] Record and compare selected owner, domain/selection, pan/zoom/toggles,
      document identity, revision, pending diff, and undo/redo across Stop.
- [x] Hash the relevant authoring and generated files before/after Play/Stop
      and prove no files or replay/backend artifacts are created.
- [x] Test repeated and rapid Play/Stop cycles dispose every injected host
      controller and ignore late callbacks.

## Step 6 — Documentation, validation, and commits

- [x] Update TDD documentation with implemented editor preparation, readiness,
      state, shortcut, cancellation, and restoration ownership.
- [x] Update this source plan and checklist with factual Phase 5 status only.
- [x] Confirm no GDD or public product embedding update is needed.
- [x] Defer final end-user README/manual Windows instructions to Phase 6 unless
      Phase 5 changes the established controls contract.
- [x] Run `dart format` on changed Dart files.
- [x] Run `cd tools/editor && dart analyze` and focused Phase 5 tests.
- [x] Run `cd tools/editor && flutter test`.
- [x] Run relevant root playtest-host, input, Core scenario, and pipeline tests.
- [x] Run `dart run tool/generate_chunk_runtime_data.dart --dry-run`.
- [x] Run `cd tools/editor && flutter build windows` when automated gates pass.
- [x] Run `git diff --check`, import-boundary, and repository-write searches.
- [x] Commit planning, preparation, UI/shell integration, tests, and factual
      closeout as coherent validated milestones.

## Evidence record

### Validation

| Date | Command/test | Result | Notes |
| --- | --- | --- | --- |
| August 19, 2026 | `flutter test test/chunk_playtest_preparation_test.dart test/chunk_playtest_editor_integration_test.dart test/editor_home_playtest_shortcut_test.dart` plus existing Chunk/Home regression files | Pass, 41 tests | Exact accepted snapshot, stale cancel, retry, lifecycle, restoration, shell guards, and file hashes passed. |
| August 19, 2026 | Root host/input, Core scenario, and content-pipeline focused tests | Pass, 79 tests | 41 Flutter host/input tests, 7 Core scenario tests, and 31 pipeline tests passed. |
| August 19, 2026 | `cd tools/editor && dart analyze` | Pass | No issues. |
| August 19, 2026 | `cd tools/editor && flutter test` | 523 pass, 1 unrelated working-tree exception | `terrain_materials_page_test.dart` sees the pre-existing uncommitted/noncanonical `terrain_material_defs.json`; the file was kept outside Phase 5 edits and commits. |
| August 19, 2026 | `dart run tool/generate_chunk_runtime_data.dart --dry-run` | Pass | 9 chunks, 3 levels, 3 parallax themes, and 1 terrain material validated with no blocking issues. |
| August 19, 2026 | `cd tools/editor && flutter build windows` | Pass | Built `build/windows/x64/runner/Release/runner_editor.exe`. |
| August 19, 2026 | `git diff --check` and import/backend searches | Pass | No Phase 5 whitespace issue, no editor import outside `package:rpg_runner/playtest.dart`, and no product backend/replay composition. |

### Delivered contracts

- `16f10252` added immutable accepted-document capture, background preparation,
  the shared compiler/scenario boundary, fixed defaults, and stable failures.
- `b485b0bd` added workspace readiness, persistent Play presentation, the
  Edit/preparing/playing/failed route state machine, stale-result cancellation,
  preserved Edit subtree, Home shell locking, guarded shortcuts/lifecycle, and
  focused integration tests.
- The implementation imports the root package only through its tooling barrel,
  writes no source/generated/runtime artifact during Play, and leaves product
  desktop adoption for the later follow-on.

## Closeout

- [x] Every Phase 5 checkbox is complete or explicitly accepted with evidence.
- [x] Update status to `Complete` with date and commit references.
- [x] Do not begin Phase 6 hardening until exact pending-document play,
      restoration, shortcut, cancellation, and no-write gates are green.

Phase 5 completion means the Windows Chunk Creator can prepare, run, and stop
the selected accepted chunk snapshot without losing Edit state or writing
repository data. It does not yet complete the manual Windows acceptance pass or
enable keyboard/mouse in the product game.
