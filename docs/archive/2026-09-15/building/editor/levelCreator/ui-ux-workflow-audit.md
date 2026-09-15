# Level Creator plan: workflow audit

Date: September 8, 2026

Status: Findings F1–F5 implemented with source, domain, runtime, and UI regression
coverage. F6's independent creator session remains pending. Final verification
is recorded in [implementation evidence](implementation-verification.md).
The simulations below preserve the pre-correction audit, not current behavior.

Reviewed:

- [UI/UX plan](ui-ux-redesign-plan.md)
- [Implementation checklist](ui-ux-redesign-checklist.md)
- [Interactive concept](level-creator-ux-wireframe.html)
- Current Level, Chunk, Parallax, session, generator, and playtest source.

## Scope and verdict

The author is familiar with game creation: chunks, Prefabs, layers, groups,
placement tools, and reusable assets. They should not need to modify code or
JSON to use the supported workflows. Beginner tutorials, terminology removal,
a new launcher/installer, and a general asset-import system are not requirements
of this audit.

**Pre-correction verdict:** the design direction fit that author, but four
interactions lacked explicit implementation decisions and two recovery/testing
gaps remained. The revised plan now specifies these decisions and corresponding
acceptance cases. The delivery evidence now records implementation and automated regression coverage; independent human acceptance is still separate.

This was a source-based workflow simulation, with independent reviews of content
authoring, persistence/recovery, and runtime dependencies. It was not a usability
test with a human participant. The concept's in-memory starter and Play animation
cannot validate the real authoring/save/gameplay transitions.

## Applied corrections

| Finding | Decision now recorded in the plan | Delivery and verification |
| --- | --- | --- |
| F1 — Repair admission and copies | [Save admission and dependency repair](ui-ux-redesign-plan.md#save-admission-and-dependency-repair): save structurally valid incomplete rules; all authoritative gates agree; one retained repair origin. [Creation](ui-ux-redesign-plan.md#create-a-level-and-its-first-content): ordinary copies start Automatic; explicit section copies retain rules and seed a referenced group. | Checklist Phases 1/3, F1 acceptance in Phase 6 |
| F2 — Both Play entry points | [Runtime construction](ui-ux-redesign-plan.md#runtime-construction-and-identity): migrate both preparations/scenarios to authored identity and snapshots, preserving labeled focused-Chunk versus seeded-Level semantics. | Phases 0/4, F2 acceptance in Phase 6 |
| F3 — Save scope and history | [Save](ui-ux-redesign-plan.md#one-trustworthy-save) names all affected levels/themes. [History](ui-ux-redesign-plan.md#undo-and-history-boundaries) retains ordinary Undo after Save against fresh baselines, seals persisted creation identities, and defines handoff/reopen boundaries. | Phase 1, F3 acceptance in Phase 6 |
| F4 — Unfinished build inclusion | [Inclusion lifecycle](ui-ux-redesign-plan.md#unfinished-levels-and-build-inclusion): explicit `includeInBuild`, coherent schema/generator/consumer migration, stable IDs, strict source checks, and controlled compiled unavailability. | Phase 0 proof; Phase 3 migration and Phase 4 Play ship together; Build UI in Phase 5; F4 acceptance in Phase 6 |
| F5 — Recovery | [Recovery and reopening](ui-ux-redesign-plan.md#recovery-and-reopening): conflict-aware reapply, refresh-only retry after committed writes, identity-aware starter continuation, safe saved selection restoration, and saved-source-only crash recovery. | Phases 1/3/5, F5 acceptance in Phase 6 |
| F6 — Real authoring acceptance | [Verification](ui-ux-redesign-plan.md#9-verification-and-definition-of-done): create a second useful chunk, geometry/Prefab/enemy placement, activation, group reassignment, repeated-source edits, and all F1–F5 transitions with a game content creator. | Phases 2/3/4 behavior, F6 acceptance in Phase 6 |

Verified implementation is marked in the [checklist](ui-ux-redesign-checklist.md).
The concept remains a layout illustration; automated source/UI/runtime evidence
is recorded separately and is not represented as a human usability test.

## Simulated content-creation workflow before correction

| Task | Result against the plan |
| --- | --- |
| Create a level, choose a background, add its first flat chunk | The intended sequence is defined. Domain-owned saves and handoffs are acceptable if the contextual actions perform them coherently. |
| Edit terrain, place objects/enemies, add another chunk | Existing tools support these tasks. No beginner redesign is needed, but acceptance must exercise actual creation and inclusion in the level rather than supplying completed chunks. |
| Press Play inside the new chunk's editor | Gap: the plan solves authored whole-Level Play but does not explicitly remove generated-data dependencies from the existing Chunk Play preparation. |
| Organize groups and ordered sections | The main controls are defined. Gap: incomplete sections may block Save, which is required before navigating to add the missing content. |
| Copy an ordered level's settings | Gap: sections are copied without chunks; capacity checks may prevent saving, and a Default-group starter may never be selected by the copied sequence. |
| Edit two levels, save, then undo a change | Gap: the visible scope of Save/Discard and history after Save or a domain handoff are not fully specified. |
| Put aside an unfinished level and build another completed level | Gap: repository-wide Build rejects incomplete included content, but the compatible set-aside/restore policy is unspecified. |
| Recover after source drift or interrupted save/handoff | Input retention is specified. The actions that resolve the failure without repeated writes or loss are incomplete. |
| Close and reopen saved content | Should be an explicit acceptance task, including resuming a saved level whose starter was not completed. |

The first starter path involves two editor transitions and two domain saves
before whole-Level Play. That is not inherently a usability failure for a game
creator. The important requirement is that Save-and-continue/return actions
preserve context and have predictable scope. Transition counts here are derived
from the proposal; they are not measured click counts or timings.

## F1 — P1: Validation can deadlock the content-repair handoff

The reviewed plan required successful Save or explicit Discard before opening
another domain. Existing Level export rejects every
validation error, including insufficient distinct-group capacity and errors in
the loaded Parallax document.

Simulation:

1. Request three distinct chunks from a group that currently has two.
2. Follow the issue's Add chunk action.
3. The handoff requires Save.
4. Save fails because the third chunk is missing.
5. Discard loses the intended change.

Copying an ordered level with distinct sections but no chunks produces this same
cycle before first content can be added. Even with repeats allowed, a copied
Ruins/Woods-only sequence does not select the prescribed Default-group starter.

**Required decision:** define Save, Play, Build, and repair admission separately
at the authoritative domain/store boundaries. The plan mentions structural versus
runtime readiness but does not specify which existing export errors change
classification or how all save gates stay consistent.

| Condition | Intended operation rule to specify |
| --- | --- |
| Invalid field syntax, duplicate identity, unsafe source, stale baseline | Block unsafe writes; preserve the edit and provide a correction/recovery action |
| Structurally valid but incomplete section content | Provide an explicitly supported way to persist the design and populate its dependencies; Play/Build stay blocked until their requirements pass |
| Truly unsaveable dependency repair | Retain the initiating edit in a bounded repair context instead of requiring its loss to open the dependency editor |
| Copy ordinary settings | State whether Automatic is the default; do not silently copy a nonfunctional sequence |
| Explicitly copy a section design | Preserve requested rules and provide content in groups those rules actually select |

This requires coordinated validation contracts, not bypassing checks in a button
handler or weakening source integrity.

**Acceptance:** copy or author an incomplete two-group distinct sequence, follow
the correction into Chunk Creator, populate the missing content, return, and
Play without discarding or dismantling the intended rules. Also repair a broken
shared dependency while retaining the initiating edit.

Evidence:
[Level export](../../../../../../tools/editor/lib/src/levels/level_domain_plugin.dart)
lines 121–128;
[validation](../../../../../../tools/editor/lib/src/levels/level_validation.dart)
lines 5–10 and 473–486;
[compound admission](../../../../../../tools/editor/lib/src/levels/level_theme_save_coordinator.dart);
[copy behavior](../../../../../../tools/editor/lib/src/levels/level_domain_plugin.dart)
lines 408–430.

## F2 — P1: Both Play entry points need the authored-data migration

The plan proposes a new Level scenario and a generalized host. However, the
creation workflow sends the author into Chunk Creator, which already has its own
visible Play action.

Current Chunk preparation rejects levels absent from generated `LevelId`, reads
`LevelRegistry.byId`, and builds its scenario on generated terrain and patterns.
A new host alone does not remove those dependencies. A never-generated Level
could therefore work from Level Creator but fail when tested from Chunk Creator.

**Required decision:** migrate Chunk preparation and scenario dependencies to
the same authored identity/content inputs, preserving the intended difference
between focused Chunk Play and actual Level Play. Alternatively, define an
explicit authored-data-backed return-and-play-level action for unsupported
Chunk cases. A generated-registry error must not be the expected next step.

**Acceptance:** create a never-generated level, open its starter, and press the
visible Play action without generation or restart. Repeat with a newly authored
material/theme and changed level settings. Both launchers must state their test
scope and return to the correct editing context.

Historical evidence: the pre-implementation `chunk_playtest_preparation.dart`
lines 221–269 and Chunk scenario lines 172–208 contained those generated-data
dependencies. The deleted preparation has been replaced by
[shared authored preparation](../../../../../../tools/editor/lib/src/playtest/authored_playtest_preparation.dart);
the [current Chunk scenario](../../../../../../packages/runner_core/lib/playtest/chunk_playtest_scenario.dart)
now uses authored content. See the
[revised runtime contract](ui-ux-redesign-plan.md#runtime-construction-and-identity)
and [implementation evidence](implementation-verification.md) for delivered behavior.

## F3 — P1: Save/Discard scope and history boundaries are ambiguous

The plan deliberately retains accepted unsaved edits while switching levels.
Actual persistence serializes every level in the active Level document and
combines all changed Level/theme records.

Simulation: rename Forest, select Field, change its pacing, then choose Edit
background. Does Discard affect Field, the current form, or both Levels? Under
the current architecture, it resolves the whole departing session. Optional
technical diff review is not enough to establish that scope.

The plan also calls section removal and switching to Automatic undoable.
Existing successful Save reloads the document and clears history. Save → notice
a mistake → Undo, and Save → edit chunk → return → Undo, have no explicit outcome.

**Required decision:**

- Keep one session-wide Save, but expose a friendly affected-content summary.
  Departure prompts list the affected names and distinguish all-session
  Save/Discard from discarding one invalid local edit.
- Preserve ordinary edit undo across Save with a new persisted baseline, or
  explicitly establish another history contract. Retaining old full-document
  snapshots with stale baselines/revisions is not a safe solution.
- Define history at domain handoff, deliberate reload, and reopen. Do not imply
  cross-domain undo unless it is implemented.

**Acceptance:** change two levels, resolve a handoff with Save and with Discard,
and verify that affected names match actual writes/loss. Exercise Save → Undo →
Save without stale-baseline or revision corruption, and verify the declared
handoff/return history behavior.

Evidence:
[Level store](../../../../../../tools/editor/lib/src/levels/level_store.dart) line 125;
[compound plan](../../../../../../tools/editor/lib/src/levels/level_theme_save_coordinator.dart)
lines 100–108;
[session export/history](../../../../../../tools/editor/lib/src/session/editor_session_controller.dart)
lines 144–216 and 319–360;
[revised history contract](ui-ux-redesign-plan.md#undo-and-history-boundaries).

## F4 — P1: Unfinished work has no complete build-inclusion lifecycle

The reviewed plan intentionally saved empty levels, then rejected active/selectable
levels without usable content during repository-wide Build. It offered Add a
chunk, but did not define how to put an experiment
aside and build another finished level.

The existing deprecate command is not a complete answer: generator assembly
validation considers every level. A copied incomplete sequence can remain a
blocker after deprecation.

**Required decision:** define incomplete-work/build-inclusion/set-aside/restore
behavior compatible with stable identities and source validation. Existing
status fields may be sufficient only if their precise generator/runtime
semantics are aligned; a label change alone is not enough. Structural corruption
must not be hidden by exclusion.

**Acceptance:** put aside an incomplete experimental copy, build finished
content, restore the experiment, and resume it without losing its identity or
intended section rules.

Evidence:
[generator assembly validation](../../../../../../tool/generate_chunk_runtime_data.dart)
lines 709–744;
[existing lifecycle](../../../../../../tools/editor/lib/src/levels/level_domain_plugin.dart);
[revised inclusion contract](ui-ux-redesign-plan.md#unfinished-levels-and-build-inclusion).

## F5 — P2: Failure recovery needs actionable outcomes

Retaining input after failure is necessary, but does not specify recovery from
repeated source-drift failure, files committed followed by refresh failure, or
an interrupted starter handoff. Retry cannot repair a changed baseline alone.

**Required decisions:**

| Situation | Observable behavior to define |
| --- | --- |
| External source conflict | Review affected content, then deliberately reload or reapply compatible edits; preserve unresolved edits rather than blind overwrite or endless retry |
| Files committed but refresh failed | Report that source files were saved, retry refresh, and avoid repeating creation/writes blindly |
| Starter creation/handoff interrupted | Reopening the saved level offers the remaining step; retry is identity-aware and does not create duplicate chunks |
| Normal close/reopen | Restore saved content and the intended editing context |
| Crash/forced termination | State whether only saved sources survive; crash-draft recovery is not implicitly required or promised |

A provisioned editor with a valid workspace is a reasonable prerequisite here.
A new installer or beginner launch tutorial is not needed.

**Acceptance:** recover from external drift, committed-save/refresh failure, and
an interrupted starter operation without losing intended edits or duplicating
content. Close and reopen the saved level, then Play again.

Evidence:
[session](../../../../../../tools/editor/lib/src/session/editor_session_controller.dart);
[revised recovery contract](ui-ux-redesign-plan.md#recovery-and-reopening).

## F6 — P2: Acceptance must exercise real content and shared-source effects

The section exercise uses supplied valid chunks. That is useful for scheduler
testing but bypasses creation, inclusion/status, geometry edits, and group
assignment. Existing ordinary Chunk creation starts empty and deprecated; the
special starter does not establish that the rest of the content workflow has
been tested.

Also exercise the normal effects of reusable content: editing a sampled chunk
edits its source and therefore every occurrence; assigning a chunk to one group
moves it out of its old group; full Level Play can suppress an enemy during its
opening while focused Chunk Play uses different test semantics. Experienced
creators understand these concepts, but selection labels, action scope, and
diagnostics must identify the actual operation.

**Required acceptance additions:**

- Create the second useful chunk using supplied assets, include it in runs,
  place an object/enemy, assign groups, and test the result.
- Move the last chunk out of a referenced group and follow the correction path.
- Edit a repeated source and verify the affected occurrences match the selected
  source, not an accidental preview-instance edit.
- Explain observed differences between focused Chunk Play and actual Level Play.
- Exercise F1–F5 recovery/history/copy/build cases, including Save → Undo and
  close → reopen, with a content creator who did not implement the editor.

Do not require terminology coaching tests or beginner tutorials. Success means
a complete, predictable content workflow without code/JSON intervention. The
implemented workflow must exercise its real handoffs and state transitions;
the prototype's coverage disclaimer correctly limits it to a layout concept.

Evidence:
[creation](../../../../../../tools/editor/lib/src/app/pages/chunkCreator/v2/chunk_owner_panels.dart)
lines 127–149;
[metadata/group assignment](../../../../../../tools/editor/lib/src/app/pages/chunkCreator/v2/chunk_v2_owner_form.dart);
[revised acceptance](ui-ux-redesign-plan.md#9-verification-and-definition-of-done);
[concept coverage note](level-creator-ux-wireframe.html).

## What does not need expanding

The plan already gives substantive attention to immutable snapshots, real Core
scheduling, material/background injection, cancellation during Build, retained
editing state during Play, responsive layout, and technical source ownership.
Those are not uncovered gaps merely because implementation remains to be done.

Keep the familiar game-creation vocabulary and existing detailed content tools.
F1–F6 now have explicit planning resolutions above. Implement and verify them
through the checklist without expanding this into a beginner-oriented redesign
of the entire editor.
