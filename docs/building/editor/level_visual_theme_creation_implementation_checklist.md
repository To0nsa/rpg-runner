# Level And Visual Theme Creation Implementation Checklist

Date: August 13, 2026
Status: Implemented August 14, 2026; broad release validation is partially blocked by unrelated concurrent worktree changes

Strategy:

- [Level and visual theme creation strategy](level_visual_theme_creation_strategy.md)

This checklist delivers explicit existing/new theme selection in Level Creator,
one compound in-memory operation, and rollback-safe application of
`level_defs.json` plus `parallax_defs.json`.

## Implementation Closure Summary

- [x] Root generator validates authored theme IDs and generated-symbol
      uniqueness without consulting stale generated Level registry output.
- [x] Level Creator holds one compound Level/Parallax candidate and exposes
      explicit create-new, reuse, assign-existing, and create-and-assign flows.
- [x] One deterministic pending plan and one rollback-safe transaction cover
      the exact one- or two-file source set, including both baseline checks and
      installed-pair revalidation.
- [x] Unresolved references are blocking, empty themes are valid, session-only
      empty-theme pruning is reference-aware, and loaded themes are preserved.
- [x] Level Creator exposes repair UI, namespaced dirty state, two-file diff and
      confirmation, runtime-generation guidance, and narrow-window layout.
- [x] A successful canonical reload enables a typed, guarded Level-to-Parallax
      handoff; stale targets fail before the active session changes.
- [x] User, agent, UI-system, and focused pipeline TDD documentation describe
      the implemented ownership and recovery contracts.
- [ ] Re-run full editor analyze/test and the shell handoff suite after the
      concurrent terrain-material atlas migration restores a compiling shared
      editor tree. On August 14, the unrelated migration removed
      `chunk_v2_composition_workspace.dart` and changed terrain-material APIs
      while the Level/theme files themselves analyzed cleanly.
- [ ] Run the full root analyzer/test/generator matrix and the disposable-
      workspace manual acceptance pass after unrelated authoring changes settle.

Implementation commits:

- `5dc6867d` — generator identity validation and authored-source authority;
- `2ed8ee2a` — compound candidate, validation, planning, and transaction;
- `54487682` — Level Creator UX and guarded Parallax handoff;
- `7b3602b5` — installed-pair and recovery-path transaction hardening.

Focused evidence completed on August 14, 2026:

- `dart analyze` passed for every changed Level/theme/UI/handoff file;
- focused editor suites passed across the workflow, Level UI, Parallax
  plugin/page, stores, and workspace transaction slices;
- the four new root generator identity tests passed individually;
- the combined store/plugin/transaction regression set passed;
- `git diff --check` passed for each implementation commit.

The detailed decomposition below remains as the acceptance ledger. Items not
covered by the closure summary—primarily the broad shared-worktree and manual
release passes—remain open intentionally.

## Working Rules

- [x] Keep level metadata authority in `tools/editor/lib/src/levels/**`.
- [x] Reuse Parallax models, parsing, validation, normalization, and canonical
      serialization from `tools/editor/lib/src/parallax/**`; do not fork them in
      Level code.
- [x] Keep page state limited to uncommitted form input and navigation state.
- [x] Route every accepted source mutation through the active plugin document so
      undo/redo, validation, pending diffs, and export stay coherent.
- [x] Use `WorkspaceWriteTransaction` for the compound repository replacement;
      do not call two independent store saves in sequence.
- [x] Preserve source-drift checks for both baselines immediately before
      replacement.
- [x] Preserve canonical ordering by `levelId`, `enumOrdinal`,
      `parallaxThemeId`, layer group, `zOrder`, and `layerKey` as applicable.
- [x] Do not introduce theme rename/delete, Level-side layer editing, terrain
      ownership, or implicit generator execution.
- [x] Do not edit generated runtime files manually.
- [x] Distinguish **authoring saved** from **runtime generated** throughout UI,
      tests, and handoff documentation.

## Phase 0 — Characterize And Freeze The Contract

### Current behavior tests

- [ ] Add/adjust a Level plugin test proving `create_level` currently falls back
      to `visualThemeId == levelId` when no theme ID is supplied.
- [ ] Add/adjust a Level validation test proving an unresolved authored
      `visualThemeId` is currently warning-only.
- [ ] Add/adjust a Level page test proving the visual-theme dropdown cannot
      create a new theme ID.
- [ ] Add/adjust a Parallax plugin/page test proving **Create Theme** requires an
      active level-to-theme mapping.
- [ ] Add a Parallax validation test proving a revision-1 theme with no layers is
      valid.
- [ ] Add a root generator/runtime characterization test proving an empty theme
      generates valid Dart with empty background/foreground lists and loads
      without asset requests.
- [ ] Characterize that generator `--dry-run` reports generated-output drift
      after authoring inputs change and before the non-dry generator runs.
- [ ] Record these tests as characterization tests before changing behavior.

### Contract decisions

- [ ] Freeze **Create new theme** and **Use existing theme** terminology.
- [ ] Freeze **Create new theme** as the default for a new level.
- [ ] Freeze the suggested-ID rule: follow `levelId` only until the author edits
      the theme ID field manually.
- [ ] Freeze duplication behavior: duplicate levels reuse the source theme by
      default.
- [ ] Freeze the theme ID grammar as `^[a-z][a-z0-9_]*$` and identify its single
      shared editor source plus root-generator parity contract.
- [ ] Freeze the no-silent-coercion rule for theme identity: trim field input,
      but reject instead of lowercasing or rewriting separators.
- [ ] Freeze generated Dart symbol uniqueness as an additional acceptance rule
      for theme IDs.
- [ ] Freeze the unresolved-reference cutover from warning to blocking error
      when Parallax source is available and parseable.
- [ ] Freeze session-created empty-theme pruning when its final candidate level
      reference is removed.
- [ ] Confirm unreferenced themes loaded from source are never pruned implicitly.
- [ ] Confirm the handoff requires a successful apply and never auto-applies.

### Phase 0 gate

- [ ] Current failure mode is reproducible through focused tests.
- [ ] Empty-theme validity and all identity/lifecycle decisions are explicit.
- [ ] No later phase depends on an unspecified cross-domain ownership rule.

## Phase 1 — Shared Identity And Store Seams

### Identifier contract

- [ ] Move or expose the stable theme identifier rule from a shared editor
      domain location usable by Level and Parallax validation.
- [ ] Update Level validation to use the shared rule without changing accepted
      existing IDs.
- [ ] Add Parallax validation for non-empty IDs that do not match the shared
      rule.
- [ ] Add tests for leading digits, uppercase, whitespace, separators, valid
      underscores, duplicate IDs, and deterministic issue ordering.
- [ ] Update `tool/parallax_theme_generation.dart` to enforce the equivalent
      theme ID grammar before rendering Dart.
- [ ] Remove the generated `level_registry.dart` from Parallax authoring
      validation authority; make the root generation path validate references
      from candidate authored Level and Parallax results.
- [ ] Keep any standalone Parallax loader reference check explicitly supplied
      with authored mapping data, or omit the cross-reference check and leave it
      to the composing generator. Do not default to generated Dart input.
- [ ] Detect distinct theme IDs that derive the same generated Dart symbol and
      report a stable blocking issue before output rendering.
- [ ] Add root generator tests for repeated/trailing separators, generated-name
      collisions, deterministic issue ordering, and valid existing IDs.
- [ ] Test that stale, missing, or contradictory generated
      `level_registry.dart` content cannot block regeneration from a valid
      authored Level/Parallax pair.
- [ ] Test that a missing theme in the candidate authored pair still blocks
      generation even when the stale generated registry appears valid.
- [ ] Add an editor/root parity fixture so a theme ID accepted by the editor is
      not rejected by generation and cannot produce a duplicate declaration.

### Parallax store composition seams

- [ ] Expose a typed Parallax load snapshot suitable for embedding in the Level
      workflow without UI/plugin coupling.
- [ ] Keep `ParallaxSourceBaseline` with the exact loaded source path and
      fingerprint plus exact raw source content.
- [ ] Ensure canonical source rendering is a pure operation over candidate
      themes.
- [ ] Expose a deterministic save plan without performing writes.
- [ ] Expose a final baseline verification seam for use in a transaction's
      `beforeReplace` callback.
- [ ] Expose installed-source parse/validation needed by transaction
      `verifyReplacements` without mutating plugin preference state.
- [ ] Retain the normal Parallax plugin export path and make it use the same
      store primitives.

### Level store composition seams

- [ ] Ensure the Level save plan is a pure deterministic projection of the
      loaded baseline and candidate levels.
- [ ] Retain exact raw Level source content in its baseline for diff planning.
- [ ] Prove neither save-plan builder rereads current filesystem bytes for
      `beforeContent`; drift is detected separately at apply.
- [ ] Expose final Level baseline verification for compound transactions.
- [ ] Expose installed-source parse/validation for compound post-write checks.
- [ ] Route every Level Creator export through the compound coordinator. Reuse
      may yield only one Level write artifact, but it still verifies both loaded
      baselines and the cross-file reference before replacement.
- [ ] Keep any lower-level `LevelStore.save` primitive only for bounded callers
      that do not bypass the Level Creator coordinator; remove or narrow it if
      it becomes a shadow export path.

### Focused tests

- [ ] Extend `tools/editor/test/level_store_test.dart` for pure planning and
      baseline verification.
- [ ] Extend `tools/editor/test/parallax_store_test.dart` for pure planning,
      identifier validation, and baseline verification.
- [ ] Prove planning performs no filesystem writes.
- [ ] Prove identical inputs produce byte-identical canonical outputs and
      deterministically ordered findings.

### Phase 1 gate

- [ ] Both stores can participate in one external transaction without exposing
      duplicate parsing/serialization logic.
- [ ] Existing single-domain Level and Parallax behavior remains green.

## Phase 2 — Compound Level Workflow Document

### Immutable state

- [ ] Add a focused Level workflow `AuthoringDocument` composition containing:
  - [ ] candidate and baseline Level document;
  - [ ] candidate and baseline Parallax theme catalog;
  - [ ] session-created theme IDs/provenance;
  - [ ] deterministic cross-file operation issues.
- [ ] Keep candidate collections immutable and canonically ordered.
- [ ] Derive `availableParallaxVisualThemeIds` from the candidate theme catalog,
      not a stale load-only string list.
- [ ] Derive `parallaxThemeIdByLevelId` from candidate levels for validation and
      scene projection.
- [ ] Keep active level selection and other view-only context out of persisted
      output.

### Semantic commands

- [ ] Add explicit command coverage for creating a level with a new theme.
- [ ] Add explicit command coverage for creating a level with an existing theme.
- [ ] Add explicit command coverage for assigning an existing theme to an
      existing level.
- [ ] Add explicit command coverage for creating and assigning a theme to an
      existing level.
- [ ] Ensure duplicate-level continues to reuse the source theme.
- [ ] Remove the hidden missing-payload fallback that treats `levelId` as an
      already-authored theme.
- [ ] Reject invalid IDs, level collisions, theme collisions, missing source,
      and structurally invalid candidates before changing the document.
- [ ] Reject a new ID that collides at the generated Dart symbol level even when
      the raw IDs differ.
- [ ] Return the original document instance for every rejected/no-op command so
      session history stays clean.
- [ ] Add stable operation issue codes and actionable messages.

### Session-created theme lifecycle

- [ ] Create new themes at revision 1 with an empty immutable layer list.
- [ ] Keep a new level at revision 1 and increment an existing level exactly
      once when its theme assignment changes.
- [ ] Reusing a theme must not change that theme's revision or any unrelated
      level/theme revision.
- [ ] Mark provenance in session state only; do not serialize provenance.
- [ ] Remove a session-created empty theme when no candidate level references it.
- [ ] Preserve a session-created theme while at least one candidate level uses
      it.
- [ ] Never prune a loaded theme, even if currently unreferenced.
- [ ] Make one undo reverse both sides of each compound command.
- [ ] Make redo restore the exact canonical compound candidate.

### Validation

- [ ] Validate load/schema issues from both documents before cross-file issues.
- [ ] Reuse complete Level validation on candidate levels.
- [ ] Reuse complete Parallax validation on candidate themes.
- [ ] Add deterministic cross-file resolution validation.
- [ ] Promote an unresolved `visualThemeId` to a blocking error after the new
      workflow is available.
- [ ] Keep empty themes valid and loaded unreferenced themes allowed.
- [ ] Ensure a malformed/unavailable Parallax source blocks new-theme creation
      and compound export without hiding Level load diagnostics.

### Pure workflow tests

- [ ] Add `tools/editor/test/level_visual_theme_workflow_test.dart` or equivalent.
- [ ] Test new level plus suggested new theme.
- [ ] Test new level plus custom new theme ID.
- [ ] Test new level reusing an existing theme with no Parallax candidate diff.
- [ ] Test existing-level create-and-assign.
- [ ] Test multiple levels sharing one loaded or staged theme.
- [ ] Test new-theme ID collision does not silently become reuse.
- [ ] Test invalid command identity/no-op behavior.
- [ ] Test candidate mapping updates before export.
- [ ] Test pruning, undo, redo, canonical ordering, and stable revisions.

### Phase 2 gate

- [ ] One immutable active-plugin document represents the complete Level/theme
      candidate.
- [ ] All compound edits participate correctly in session validation, history,
      and scene projection without repository mutation.

## Phase 3 — Pending Plan And Rollback-Safe Export

### Compound save plan

- [ ] Add a focused coordinator that composes the Level and Parallax store plans.
- [ ] Produce only the Level file write when an existing theme is reused.
- [ ] Produce both file writes when a new theme is staged.
- [ ] Namespace changed item IDs as `level:<id>` and
      `parallaxTheme:<id>` (or an equally explicit frozen format).
- [ ] Sort changed item IDs and file diffs deterministically.
- [ ] Generate each unified diff from exact planned before/after content.
- [ ] Retain the immutable confirmed plan or rebuild and equality-check it
      immediately before export.
- [ ] Reject a plan mismatch before any target replacement.

### Transaction

- [ ] Convert changed plan entries to `WorkspaceWriteArtifact` values.
- [ ] Use one `WorkspaceWriteTransaction` for every changed target.
- [ ] In `beforeReplace`, verify both loaded baselines even when only one file is
      expected to change; external changes can invalidate cross-file
      validation.
- [ ] In `verifyReplacements`, reparse the installed Level and Parallax files.
- [ ] Rebuild the installed level-to-theme map and rerun structural plus
      cross-file validation while rollback is available.
- [ ] Reject installed bytes that do not match the planned canonical output.
- [ ] Surface whether rollback completed when a transaction fails.
- [ ] Handle `outputsCommitted == true` separately: verify/reload installed
      outputs, report committed-with-cleanup-required, expose exact leftover
      paths, and block another apply until recovery is resolved.
- [ ] Return committed-with-cleanup-required as a typed applied export result so
      `EditorSessionController` performs its normal canonical reload; do not
      encode recovery state only in human-readable artifacts.
- [ ] Preserve cleanup paths as structured, workspace-validated sibling paths.
- [ ] If retry cleanup is offered, revalidate installed target bytes and exact
      workspace containment before deleting only those known temp/backup files.
- [ ] Never report `outputsCommitted == true` as a rollback or unchanged source.
- [ ] Ensure temp and backup files are removed after success and complete
      rollback.
- [ ] Reload both workflow snapshots from disk after successful export.

### Transaction failure tests

- [ ] Add `tools/editor/test/level_visual_theme_transaction_test.dart` or
      equivalent.
- [ ] Test clean one-file reuse apply.
- [ ] Test clean two-file creation apply.
- [ ] Test Level source drift before replacement.
- [ ] Test Parallax source drift before replacement.
- [ ] Inject failure while staging each target.
- [ ] Inject failure while replacing each target.
- [ ] Inject byte-verification failure.
- [ ] Inject installed Level parse/validation failure.
- [ ] Inject installed Parallax parse/validation failure.
- [ ] Inject installed cross-file resolution failure.
- [ ] Inject backup-cleanup failure after verified commit and assert the new
      outputs remain installed, are reloaded, and receive the distinct recovery
      status.
- [ ] Assert both originals are byte-identical after every rolled-back failure.
- [ ] Assert no transaction temp/backup artifacts remain after recoverable
      failures.
- [ ] Assert a clean no-op performs no writes.

### Plugin integration

- [ ] Update `tools/editor/test/level_domain_plugin_test.dart` for compound
      command, validation, and pending-plan behavior.
- [ ] Update `tools/editor/test/level_domain_plugin_integration_test.dart` for
      real workspace apply/reload behavior.
- [ ] Keep existing Parallax plugin tests green against the refactored store
      seams.
- [ ] Verify export is blocked whenever either domain or cross-file validation
      contains an error.

### Phase 3 gate

- [ ] A successful apply commits the complete valid pair.
- [ ] Every simulated failure commits neither file or reports an explicit
      incomplete rollback requiring human recovery.
- [ ] The post-apply session exactly reflects installed canonical bytes.

## Phase 4 — Level Creator User Experience

### New-level form

- [ ] Replace the single level-ID-only creation row with an accessible creation
      form/dialog appropriate to current editor layout.
- [ ] Add **Create new theme** and **Use existing theme** controls.
- [ ] Default new levels to **Create new theme**.
- [ ] Suggest the exact accepted `levelId` as the new theme ID while the field is
      untouched; do not lowercase or rewrite identity text silently.
- [ ] Stop automatic synchronization after manual theme-ID editing.
- [ ] Include creation mode, new-theme ID, existing-theme selection, and any
      create/assign dialog draft in `hasLocalDraftChanges` so shell guards
      cannot discard them silently.
- [ ] Add a deterministic existing-theme selector in reuse mode.
- [ ] Show inline invalid-ID, collision, missing-source, and empty-catalog states.
- [ ] Explain that the new empty theme's layers are edited in Parallax after
      apply.
- [ ] Keep plugin validation authoritative after submission.
- [ ] Reset local creation drafts only after the command is accepted.

### Existing-level inspector

- [ ] Rename/reword the visual-theme field so it does not imply Parallax owns
      ground or terrain materials.
- [ ] Keep explicit existing-theme reassignment.
- [ ] Add **Create and assign new theme** with an editable stable ID.
- [ ] Replace the normal fake `(<id> missing)` dropdown path with a blocking
      repair state.
- [ ] In repair state, offer **Create missing theme** and **Select existing
      theme** actions.
- [ ] Preserve other inspector drafts when a theme command is rejected.

### Pending state and confirmation

- [ ] Update level-row dirty checks for namespaced changed item IDs.
- [ ] Show staged theme identity and new/existing mode in the pending summary.
- [ ] Make Apply confirmation state whether one or two files will change.
- [ ] Name `level_defs.json` and `parallax_defs.json` when both are pending.
- [ ] Keep Apply disabled for blocking validation or pending-plan failures.
- [ ] Ensure route, workspace, reload, and app-close guards see compound pending
      changes through the existing session boundary.
- [ ] Ensure undo/redo updates both visible theme choices and pending file diffs.
- [ ] After authoring apply, show that runtime generation remains required and
      provide the exact non-dry command followed by the dry-run verification
      command.

### Widget tests

- [ ] Extend `tools/editor/test/level_creator_page_test.dart` for creation-mode
      controls and defaults.
- [ ] Test suggested ID tracking and manual-edit detachment.
- [ ] Test new-theme creation, existing-theme reuse, and collision feedback.
- [ ] Test existing-level create-and-assign and unresolved-reference repair.
- [ ] Test one-step undo/redo visibility.
- [ ] Test one-file versus two-file confirmation content.
- [ ] Test narrow-window layout, keyboard traversal, labels, and disabled states.
- [ ] Update `tools/editor/test/home_route_plugin_switch_test.dart` for compound
      unsaved-work guarding.

### Phase 4 gate

- [ ] A non-developer can understand and complete both create-new and reuse
      workflows without knowing the hidden field-name convention.
- [ ] No UI path can apply a newly created unresolved level reference.

## Phase 5 — Guarded Parallax Handoff

### Navigation

- [ ] Add an **Open in Parallax** action after a successful Level/theme apply.
- [ ] Pass target `levelId` as transient navigation intent through the editor
      shell, not persisted authoring data.
- [ ] Capture a typed page-local level/theme target immediately before confirmed
      export; never parse IDs from human-readable export artifacts.
- [ ] Activate the handoff only after `ExportResult.applied`, canonical reload,
      an empty pending plan, and exact target resolution in the reloaded Level
      scene.
- [ ] Clear the target after later edits, reload/export failure, workspace
      change, or route disposal.
- [ ] Add a Parallax-plugin-owned targeted loader that loads and validates the
      requested level selection before returning the document.
- [ ] Use that loader through the existing atomic guarded cross-plugin load
      path, keeping Parallax document construction out of the shell.
- [ ] Preserve the current Level session if target loading fails.
- [ ] Disable the handoff while Level/theme changes are pending or export is in
      progress.
- [ ] Do not auto-apply, auto-discard, or bypass the unsaved-work guard.

### Handoff tests

- [ ] Test successful Level-to-Parallax transition after compound apply.
- [ ] Test the intended level and theme are active on arrival.
- [ ] Test stale/missing typed target rejection leaves the Level session intact.
- [ ] Test the new empty theme can accept its first layer through the normal
      Parallax command path.
- [ ] Test failed target load leaves the current session usable.
- [ ] Test pending local/page drafts block or confirm navigation consistently.
- [ ] Test a reused theme reports all level usages after handoff.

### Phase 5 gate

- [ ] The author can move directly from valid level/theme creation to layer
      authoring without manual file edits or ambiguous selection.

## Phase 6 — Cleanup And Documentation

### Code cleanup

- [ ] Remove the hidden `visualThemeId = levelId` fallback from normal creation.
- [ ] Remove warning-driven UI branches made obsolete by the repair workflow.
- [ ] Remove duplicate theme ID normalization/validation helpers.
- [ ] Check for duplicated save-plan, drift, diff, and transaction logic.
- [ ] Keep the workflow coordinator focused; do not broaden the plugin contract
      for unrelated domains.
- [ ] Review touched public APIs and reasoning hotspots against
      `docs/rules/code-documentation-policy.md`.

### Documentation

- [ ] Update `tools/editor/README.md` with the visible create-new/reuse workflow
      and Parallax handoff, plus the explicit runtime generation step.
- [ ] Update `tools/editor/AGENTS.md` if Level/Parallax workflow ownership or
      transactional rules changed materially.
- [ ] Update `docs/tdd/editor_ui_system.md` with cross-domain pending/apply and
      navigation behavior.
- [ ] Update or add a focused TDD for the compound document, cross-file
      validation, source-drift, transaction, committed-cleanup-failure, and
      rollback invariants.
- [ ] Update generator contract documentation for theme ID and generated-symbol
      validation parity.
- [ ] Update the active Chunk Creator plan only if its level/parallax preview
      dependencies or milestone links change.
- [ ] Keep player-facing GDD unchanged unless implementation changes actual
      runtime visual behavior.
- [ ] Move this strategy and checklist to an appropriate archived location only
      after all accepted scope is complete or explicitly closed.

### Phase 6 gate

- [ ] No stale documentation describes the warning-only two-apply workaround as
      the intended workflow.
- [ ] No shadowed Level or Parallax persistence path remains.

## Phase 7 — Validation And Release Evidence

### Focused checks

- [ ] `cd tools/editor && dart analyze`
- [ ] `cd tools/editor && flutter test test/level_store_test.dart`
- [ ] `cd tools/editor && flutter test test/level_domain_plugin_test.dart`
- [ ] `cd tools/editor && flutter test test/level_domain_plugin_integration_test.dart`
- [ ] `cd tools/editor && flutter test test/level_creator_page_test.dart`
- [ ] `cd tools/editor && flutter test test/parallax_store_test.dart`
- [ ] `cd tools/editor && flutter test test/parallax_domain_plugin_test.dart`
- [ ] `cd tools/editor && flutter test test/parallax_editor_page_test.dart`
- [ ] `cd tools/editor && flutter test test/editor_session_controller_test.dart`
- [ ] `cd tools/editor && flutter test test/home_route_plugin_switch_test.dart`
- [ ] Run every new focused workflow and transaction test added by this plan.

### Full checks

- [ ] `cd tools/editor && flutter test`
- [ ] `dart analyze`
- [ ] `flutter test test/tool/generate_chunk_runtime_data_test.dart`
- [ ] Run any new focused root parallax-generation tests.
- [ ] `dart run tool/generate_chunk_runtime_data.dart` when acceptance fixtures
      intentionally change checked-in authoring content.
- [ ] `dart run tool/generate_chunk_runtime_data.dart --dry-run` after generated
      outputs have been refreshed.
- [ ] Run relevant root level-registry/theme-resolution tests.
- [ ] `git diff --check`

### Manual acceptance

- [ ] In a disposable workspace, create a level with the suggested new theme ID,
      inspect both diffs, apply once, and open it in Parallax.
- [ ] Add and apply the first Parallax layer, confirm a pre-generation dry-run
      reports expected drift, run the non-dry generator, then confirm the next
      dry-run is clean.
- [ ] Create another level that reuses the theme and confirm Parallax bytes stay
      unchanged.
- [ ] Create and assign a new theme to an existing level and confirm one-step
      undo before apply.
- [ ] Trigger invalid ID, collision, and missing-source states and confirm each
      message gives a clear recovery action.
- [ ] Cause external drift in each source before apply and confirm neither file
      is replaced.
- [ ] Exercise route/workspace/app-close guards with compound changes pending.
- [ ] Verify narrow-window controls remain reachable and readable.

### Release gate

- [ ] All focused and full automated checks pass.
- [ ] Manual acceptance demonstrates no invalid intermediate repository state.
- [ ] Reuse changes only Level source; creation changes the exact intended pair.
- [ ] Rollback/failure evidence is recorded for both source targets.
- [ ] Committed-output cleanup failure is distinguished from rollback in tests
      and operator messaging.
- [ ] Generated runtime artifacts are refreshed explicitly and finish
      drift-free.
- [ ] Documentation matches the implemented workflow and ownership boundaries.
- [ ] This checklist status is updated with dated completion evidence.
