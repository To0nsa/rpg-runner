# Level Creator UI/UX Implementation Checklist

Date: September 8, 2026  
Status: Implementation and automated regression verification complete; independent creator acceptance pending

Evidence: [Implementation verification](implementation-verification.md), updated September 9, 2026.

The [creator session guide](creator-acceptance-session.md) is prepared. Its
temporary workspace has been removed. Native Windows Play and larger-pool
profiling have passed; human observations remain unrecorded.

Source: [UI/UX redesign plan](ui-ux-redesign-plan.md), incorporating
[workflow audit findings F1–F6](ui-ux-workflow-audit.md).

This ledger covers the complete create/edit/Play/save workflow for a creator
familiar with chunks, Prefabs, groups, layers, and placement tools. A provisioned
editor and valid workspace are prerequisites; supported tasks require no code,
JSON, or terminal work. Beginner tutorials and a general asset-import redesign
are outside scope. Existing features do not make an unchecked item implemented.

## Phase 0 — Characterize and prove the runtime boundary

- [x] Add meaningful regression cases for level switching with dirty input,
      same-level undo/redo/reload, and saving accepted A while visible B is newer.
- [x] Cover invalid/empty/minus/decimal text in pacing and section lengths,
      including selection away from the invalid field.
- [x] Create disposable fixtures with multiple chunks, groups, difficulty tiers,
      backgrounds, inactive content, and invalid boundaries; retain sparse
      Forest/Field/New Level cases.
- [x] Review the concept at real desktop sizes against the current running
      editor; use the plan's semantics as authority over illustrative controls.
- [x] Prove that a never-generated authored level can materialize its own
      settings, chunk source, terrain catalog, and identity into isolated Core
      through both the visible Chunk Play and Level Play entry points.
- [x] Review typed registered/authoring identity changes and snapshot consumers;
      preserve normal run/replay/protocol authority and provenance.
- [x] Confirm authored background and terrain-material catalog injection plus
      preview/Play asset capture ownership.
- [x] Characterize deprecated-chunk generator eligibility and background versus
      foreground runtime rendering before claiming preview parity.
- [x] Reproduce incomplete-section Save/repair and ordered-copy deadlocks at
      compound command, export, transaction, and installed-candidate admission.
- [x] Characterize Save→Undo, two-level departure, shared-dependency repair,
      source conflict, committed-save/refresh failure, and interrupted starter.
- [x] Prove explicit build inclusion can preserve all identity/enum slots while
      unavailable configs, selection defaults, ghosts, and validation fail
      explicitly rather than resolving an unusable registry entry.

Gate: all prerequisite behavior is demonstrated or has a concrete failing test;
the recommended Play boundary is proven before full integration proceeds.

## Phase 1 — Editing reliability and shared Save

- [x] Introduce explicit Level edit-buffer lifetime and revision reconciliation
      outside widget build; track every visible local field.
- [x] Complete valid edits into semantic session commands without per-keystroke
      revision/undo churn; retain exact invalid input with inline diagnostics.
- [x] Save finalizes visible valid inputs, including the focused field, then
      invokes the existing authoritative export path.
- [x] Introduce shared semantic save outcomes and reactive draft status; migrate
      all existing route adapters together and preserve operation locks.
- [x] Replace ambiguous Apply labels with consistent Save semantics; keep
      technical source diff review available separately.
- [x] Name every affected level/theme in the document-wide Save/Discard summary;
      distinguish Discard all from Discard this edit for an invalid local buffer.
- [x] Dirty/save status combines local and accepted changes; a successful save
      cannot omit visible content or imply a runtime build occurred.
- [x] Ordinary same-session level/section/tab selection finalizes valid local
      input without saving files or prompting for accepted session changes;
      protect invalid buffers from replacement, including Create/Copy settings.
- [x] Pure selection/filter/tab/viewport/seed changes create no source revisions,
      pending diff, or content undo entries.
- [x] Normal domain/workspace replacement, reload, and close resolve departing
      changes with Save/Discard all/Cancel; failed save preserves the workspace.
      Explicit dependency repair uses the bounded return contract below.
- [x] Save failure/rejection retains exact input, selection, and pending changes.
- [x] Define operation-aware validation: structural/source errors block Save;
      empty usable pools and insufficient distinct capacity block runtime
      readiness without preventing valid section designs from being saved.
- [x] Apply that contract consistently to compound commands, plugin export,
      coordinator preflight, canonical installed-candidate verification, and
      Play/Build admission; retain schema, identity, reference, range, baseline,
      transaction, and dependency-source integrity checks.
- [x] Offer explicit dependency repair when a structurally unsaveable origin
      cannot use Save-and-continue. Retain one origin's accepted edits, local
      buffers, baselines, and UI context; load the repair target atomically.
- [x] Return from repair through fresh source/dependency loading and compatible
      plugin-owned intent replay, preserving conflicting edits for resolution.
      Start fresh history; never restore stale dependency/persistence snapshots.
- [x] Permit only one suspended repair origin, with no nested repair sessions;
      close/workspace replacement resolves that retained origin as well as the
      current domain. Failed target load leaves the originating workspace intact.
- [x] Undo/redo restores visible same-level fields/flow and correct dirty state;
      text undo remains local when an editable field owns it.
- [x] Preserve ordinary value/section undo across Save through plugin-owned
      semantic reconciliation against refreshed canonical baselines/revisions;
      never restore old persistence metadata or dependency snapshots.
- [x] Fence creation history at the first persisted save of each new identity:
      Undo cannot delete that saved identity or recycle its ordinal. Ordinary
      edits remain undoable; source lifecycle actions remain explicit.
- [x] Normal domain handoff, deliberate reload, workspace change, and reopen
      establish fresh history; return context does not promise cross-domain undo.
- [x] Discard-and-reload clears every local buffer even with unchanged level ID.
- [x] Preserve atomic Level/theme planning, drift detection, rollback, canonical
      reload, and committed-cleanup-required handling.
- [x] Recover source drift with a retained edit/recovery copy, refreshed sources,
      compatible intent reapplication, and explicit choices for conflicting
      values; never blind-overwrite or present endless Retry as a resolution.
- [x] Distinguish files committed/refresh failed from failed Save; retry refresh
      only and preserve recovery state without repeating writes or creation.
- [x] Close/reopen restores saved content and stable selection where available.
      State that forced termination preserves saved sources only; do not imply
      crash-draft recovery or autosave.
- [x] Run editor analyzer, focused lifecycle tests, shell/session regressions,
      and editor suite; update the UI and Level/theme TDD.

## Phase 2 — Workspace and understandable flow

- [x] Replace the permanent creation form and duplicate selector with a compact
      level library, search, New level action, and contextual lifecycle menu.
- [x] Compose shared tokens/cards/catalog/layout/viewport helpers; remove replaced
      Level-local chrome and the legacy long-form workspace in the same milestone.
- [x] Add immutable content/thumbnail projection without changing active plugin
      or introducing another Chunk write path.
- [x] Keep the preview mounted across Contents/Flow/Appearance changes and resize.
- [x] Present chunk groups, active/deprecated content, authored tiers, and empty
      states honestly using current data.
- [x] Add group creation through the Level domain with canonical identity and
      readable labels; define the reference-aware removal and no-silent-rename
      policy using the existing string-group schema.
- [x] Automatic maps to absent assembly; no mandatory synthetic section.
- [x] Ordered sections expose group, exact or Automatic difficulty, count range, within-section repeats, and
      repeat-all/continue-last behavior with friendly explanatory text.
- [x] New section defaults work with the current one-chunk pool; capacity feedback
      uses resolved tier pools to explain readiness while allowing a saveable
      incomplete design with distinctness enabled.
- [x] Add drag ordering and keyboard/button alternatives; one operation equals
      one semantic undo step.
- [x] Guard removal of referenced groups; preserve the Default group.
- [x] Explain and make undoable removal of sections when switching to Automatic.
- [x] Show consecutive difficulty windows, Hard continuation, tier fallback,
      and independent enemy-free opening; hide IDs/ordinals behind Advanced.
- [x] Keep camera/ground references read-only until a separately reviewed edit
      contract exists.
- [x] Provide complete navigable diagnostics; field errors relate to current
      input and suggestions are distinct from blockers.
- [x] Identify sampled occurrences by their reusable chunk source; Edit chunk
      affects all occurrences. Group assignment clearly moves a chunk out of
      its former group, with navigable readiness diagnostics for emptied groups.
- [x] Verify small-window layout, text scaling, keyboard/focus/semantics,
      long names, many chunks, and zero-content states.
- [x] Run editor analyzer/tests and update implemented UI documentation.

## Phase 3 — Creation and connected authoring

- [x] Deliver the build-inclusion contract as one coherent schema/generator/
      consumer migration before creation uses its new defaults: explicit
      `includeInBuild` boolean, strict Level schema v1→v2 migration, existing
      values true, newly created/copied levels false, no legacy parser fallback.
- [x] Keep build inclusion independent of active/deprecated status. Exclusion
      preserves IDs, ordinals, chunks, groups, section rules, and editability;
      restoring inclusion rechecks readiness rather than recreating content.
- [x] Validate all authored sources and geometry structurally even when excluded;
      run whole-level readiness checks only for included levels. The combined
      Phase 3/4 release must retain authored Play for excluded ready levels.
- [x] Reconcile active/deprecated chunk eligibility in the authoritative
      generation/materialization path now; a deprecated chunk cannot satisfy an
      included pool or distinct capacity or appear in runtime selection.
- [x] Preserve all generated enum slots and identity metadata with explicit
      compiled availability; exclude unavailable runtime configs and pools.
      Update every registry/snapshot consumer without unsafe `byId` resolution
      or fallback to all known IDs.
- [x] Require at least one included active playable level and a valid included
      selectable default; resolve default changes explicitly. Update app
      selection/start, ghost, and replay-validator unavailable-content handling
      while preserving auth, replay identity, and deterministic validation.
- [x] Validate the migration across editor, generator, Core, game/UI, ghost,
      backend, validator, and affected protocol tests; update their technical
      contracts together before treating the inclusion workflow as delivered.
- [x] Create by friendly name with domain-owned unique identifier allocation;
      remove hidden defaults inherited from unrelated selection.
- [x] Provide explicit standard/copy-settings choice without implicit balance
      changes or automatic ID/ordinal reassignment on rename.
- [x] Add explicit copy/share/empty background choices with thumbnails and shared
      usage; implement copy through the compound Level/Parallax domain command.
- [x] Label duplication Copy level settings; ordinary copying starts Automatic.
      Explicit Copy section design preserves groups/rules without claiming chunk
      cloning, seeds the first referenced group, and lists remaining capacities.
- [x] Add a valid first-chunk preset in the Chunk domain, usable with no existing
      chunk template; dimensions/ground/material/group/tier are intentional.
      A standard Automatic starter is Play-ready; an explicit section-design
      copy retains actionable capacity/reachability requirements after its starter.
- [x] Add typed Level→Chunk and return targets with optional intended group;
      reuse guarded atomic plugin load and revalidate targets against sources.
- [x] Add/assign chunks to a chosen group through the Chunk create/metadata
      form, including saving newly authored groups before handoff.
- [x] Add Save and add starter / Save and return actions where required; each
      save belongs to its domain and failures leave a resumable state.
- [x] Give starter operations a stable target identity and resume remaining steps
      after cancellation, refresh failure, or reopen; retries find an existing
      completed target instead of duplicating chunks.
- [x] Preserve selected level/section/tab/filter on return while refreshing
      dependent content and background data.
- [x] Provide exact background handoffs and safe shared-background copy behavior.
- [x] Verify ordinary second-chunk creation using existing tools: create useful
      geometry, place a Prefab and compatible enemy marker, activate content,
      assign a group, and return with updated runtime eligibility.
- [x] Test first creation, partial-journey cancellation, failed starter creation,
      missing/moved target, invalid material, shared-background changes, and an
      incomplete copied two-group design populated through repair handoffs.
- [x] Run editor analyzer/tests and update editor README and authoring TDD.

Gate: new/copy defaults, exclusion, restoration, generation, and all runtime
consumers use the same inclusion contract. Phases 3 and 4 ship together so
exclusion cannot regress existing Chunk Play while its registry dependency
remains. Phase 5 adds the Build UI.

## Phase 4 — Sample preview and authored Chunk/Level Play

- [x] Capture a coherent immutable Level/dependency/asset snapshot from accepted
      authoring content; never mix stale generated settings with current edits.
- [x] Invalidate late preparation on input/source generation changes, reload,
      navigation, retry, stop, or disposal.
- [x] Compile/materialize through the shared pipeline; use Core reachability
      for tier/group/distinct/seam readiness and surface its limits accurately.
- [x] Admit the full pool only after matching-level, unique-key, active-status,
      and runtime-width checks; add wrong-level and mismatched-width fixtures.
- [x] Consume the canonical Phase 3 chunk-eligibility predicate and verify
      generation/Play parity; deprecated chunks never satisfy active capacity.
- [x] Build a bounded sampled preview using the real seed/selection rules and
      shared chunk/material visuals; preview seed/length do not dirty source.
- [x] Implement the validated full Level scenario and explicit authoring identity
      boundary proved in Phase 0; migrate affected Core/snapshot consumers fully.
- [x] Migrate existing Chunk preparation/scenario to the same authored identity,
      settings, compilation, material/background, and asset capture boundaries;
      remove generated-registry dependencies from both preview launchers.
- [x] Preserve actual early/easy/normal windows, enemy suppression, automatic or
      ordered selection, final-section continuation, camera, and ground settings.
- [x] Label focused Chunk Play as the selected chunk loop with authored markers
      and no level enemy-free opening; Level Play uses the real seeded sequence
      and opening suppression. Explain observed scope differences in context;
      focused Play still requires canonical reachability and safe-loop admission.
- [x] Inject captured background definitions/assets into the real render bridge;
      expose unsupported foreground layers instead of falsely previewing support.
- [x] Inject captured validated terrain-material catalogs into Flame/StagedTerrain
      rather than resolving preview material IDs from generated registries;
      cover never-generated material IDs and edited source regions in parity tests.
- [x] Generalize existing playtest host/input/lifecycle for Chunk and Level
      scenarios without duplicating the scheduler or product app shell.
- [x] Add Play/F5 with current valid unsaved input admission and clear blockers;
      never save/build merely to start Play.
- [x] Support Enter/P/F6/F5/Escape, focus-loss pause, aim bounds, loading/failure/
      game-over recovery, and frozen scenario restart as specified.
- [x] Stop restores mounted editing state, selection, viewport, seed, history,
      and pending changes. External edits require a new preparation.
- [x] Assert no tickets, rewards, replay artifacts, backend requests, or source
      writes on Prepare/Play/Restart/Stop.
- [x] Test a never-generated level and changed existing level, authored theme,
      newly authored material, multiple seeds/tiers/groups, distinct capacity
      failures, and source drift through both visible Play entry points without
      generation or restart. Excluded-but-ready authored levels can Play.
- [x] Run editor, pipeline, Core, game/UI, playtest and affected contract tests;
      update Core/snapshot and full-level playtest TDD plus tool entrypoint docs.

Gate: both authored Play entry points work without generation. Level Play runs
the actual sequence; a static sample or single-chunk loop does not satisfy it.

## Phase 5 — Build without a terminal

- [x] Expose a structured root-generator report distinguishing invalid inputs,
      ordinary generated drift, changed artifacts, and transaction outcomes.
- [x] Add one guarded workspace Build game content job using the existing
      generator/artifact transaction, fixed argv and canonical repository cwd.
- [x] Resolve local/session saves before Build; handle source generation changes,
      cancellation, SDK absence, file locks, and cleanup/rollback errors.
- [x] Lock editor writes/reload/workspace replacement during Build and recheck
      external source fingerprints before commit. Admit cancellation before
      replacement; once commit begins finish commit/rollback safely, with a
      transaction-boundary cancellation regression test.
- [x] Show repository-wide scope and navigable issues for other affected levels.
- [x] Surface the Phase 3 inclusion contract: included levels must meet readiness;
      offer Open/Add chunk or Exclude from build for unfinished content, plus
      Restore to build. Explain that exclusion is independent of deprecation.
- [x] Report structural errors in excluded content as errors, preserve the valid
      included default, and surface the no-included-playable-level condition.
- [x] Verify an incomplete excluded copy does not block building finished content;
      restoring it retains identity/rules and reports remaining readiness work.
- [x] Verify exact post-build drift and invalidate freshness after relevant
      local or external changes; support Not checked rather than inventing success.
- [x] Keep authoring saved, Play readiness, and generated-content states separate.
- [x] Explain application build/restart and production release dependencies;
      active/generated content never receives an unsupported Live/Published claim.
- [x] Test all outcomes against disposable repository fixtures and run editor plus
      generator analysis/tests. Update README and add-new-level workflow.

## Phase 6 — Author acceptance and closure

- [ ] Have a game creator who did not implement the editor create a level, add a
      starter, Play from Chunk Creator, return, and Play the level in a provisioned
      workspace without code/JSON/terminal intervention. Retain familiar creation
      terminology; no beginner-tutorial requirement. (F2, F6)
- [ ] Create a second useful chunk from supplied assets, edit geometry, place a
      Prefab and compatible enemy, include it in runs, and assign its group;
      compare focused Chunk Play with actual Level Play's enemy opening. (F2, F6)
- [ ] Create two groups and configure a sequence using those newly created chunks;
      identify repetition, resolved difficulty, and source/occurrence scope.
      Edit a repeated source and verify every affected occurrence. (F6)
- [ ] Save an incomplete two-group distinct design, use Add chunk to meet its
      capacities, return, and Play without discarding rules. Repeat after explicit
      section-design copying; ordinary settings copying starts Automatic. (F1)
- [ ] Move the last chunk out of a referenced group and repair the resulting
      readiness issue through its next action. Exercise empty-pool/distinct/seam
      diagnostics and shared-dependency repair with retained origin edits. (F1, F6)
- [ ] Change two levels, then resolve a handoff with Save and Discard all; affected
      names match actual writes/loss. Verify Cancel and Discard this edit protect
      unrelated accepted changes. (F3)
- [ ] Exercise section/value Save→Undo→Save and redo against fresh revisions and
      baselines; creation→first Save→Undo never deletes a persisted identity or
      recycles its ordinal. Verify normal handoff/reload/reopen history boundaries
      and repair return's fresh history. (F3)
- [ ] Exercise a failed repair-target load, no nested suspension, conflicting
      return edits, and closing with a retained repair origin; intended content
      remains recoverable through the declared resolution actions. (F1, F3, F5)
- [ ] Edit/copy a shared background and correctly identify affected levels.
- [ ] Exclude an incomplete experiment, build finished content, restore the
      experiment, and resume its original identity/groups/rules. Confirm excluded
      structural corruption remains a blocker and unavailable levels cannot be
      selected or silently substituted in game/ghost/validator paths. (F4)
- [ ] Recover external drift through compatible reapplication and conflicting
      field choices without losing the retained edit copy; simulate files saved
      followed by refresh failure and verify refresh-only retry. (F5)
- [ ] Interrupt starter creation before and after source commit, reopen the saved
      level, resume the remaining step, and verify no duplicate chunk. Save,
      close, reopen with expected selection, and Play again; verify the declared
      saved-only recovery after forced termination. (F5)
- [ ] Build content and distinguish Saved, Ready to play, Included in build,
      and Built; confirm default/last-included-level errors are actionable. (F4)
- [x] Validate 1440×900, 1280×800, 1024×768, 800×600, text scaling, keyboard,
      focus, color-independent state, and preview state retention.
- [x] Measure native Play readiness and preparation/session cancellation for
      1, 25, and 100 chunks; record fixture and measurement limitations.
- [ ] Record human time-to-first-Play, confusion points, and perceived preview/
      cancel responsiveness on the reference Windows machine with larger fixtures.
- [ ] Exercise real handoffs and recovery states in the implemented workflow;
      an illustrative concept's mock Play/starter interactions do not establish
      acceptance. Record human-test observations separately from source review.
- [x] Run required final editor/pipeline/Core/game/UI/playtest/generator checks;
      add backend/validator/protocol checks if an implementation touched them.
- [x] Update TDD/README/AGENTS/workflow documentation for delivered behavior;
      update GDD only for actual gameplay changes.
- [x] Remove replaced paths and check shared behavior/redundancy before closure.
- [ ] Archive completed plan/checklist, update their active links, and preserve
      the concept as historical design material.
