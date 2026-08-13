# Level And Visual Theme Creation Strategy

Date: August 13, 2026
Status: Implemented August 14, 2026; final broad-worktree validation remains recorded in the checklist

Related documents:

- [Implementation checklist](level_visual_theme_creation_implementation_checklist.md)
- [Completed Level Creator plan](../archived/editor/levelCreator/plan.md)
- [Chunk Creator plan](chunkCreator/plan.md)
- [Editor UI system](../../tdd/editor_ui_system.md)
- [Implemented pipeline TDD](../../tdd/level_visual_theme_authoring_pipeline.md)

## Decision Summary

Level Creator will support one explicit, coherent operation for assigning a
visual theme:

- **Use existing theme** selects an authored `parallaxThemeId` and assigns it
  as the level's `visualThemeId`.
- **Create new theme** accepts a new stable theme ID, stages an empty revision-1
  parallax theme, and assigns that same ID to the level.

For a new level, **Create new theme** is the default and initially suggests the
new `levelId`. The ID remains editable and stops following `levelId` after the
author changes it manually. An existing theme must be chosen explicitly; an ID
collision in **Create new theme** mode does not silently switch to reuse.

The level and new theme participate in one in-memory command, one undo step,
one pending-change preview, one confirmation, and one rollback-safe repository
transaction. Applying the operation must never expose a committed
`level_defs.json` that references a theme absent from `parallax_defs.json`.

After a successful apply, Level Creator offers **Open in Parallax** for the
created or assigned theme. Parallax remains the place where layers are edited;
Level Creator creates only the empty theme identity needed to make the
cross-file reference valid.

The apply makes the two authoring JSON sources coherent; it does not make the
generated runtime Dart current. After level and layer authoring is complete,
the normal root content generator must publish the updated level registry, UI
metadata, and parallax registry. The editor must show this remaining step
instead of implying that authoring apply alone makes the level playable.

## Problem Statement

The current workflow has a circular dependency:

1. A level requires `visualThemeId`.
2. Level Creator exposes existing parallax theme IDs through a dropdown, so it
   cannot explicitly author a new ID.
3. Creating a level silently defaults `visualThemeId` to `levelId` even when no
   matching parallax theme exists.
4. Parallax can create a theme only after an active level resolves that theme
   ID through the level registry mapping.
5. The author must therefore apply an unauthored theme reference, switch
   routes, create the theme, and apply a second file change.

The missing-theme condition is currently a warning, which makes the sequence
technically possible, but it creates an intentionally inconsistent repository
state between the two applies. The convention is also hidden: neither the
dropdown nor the creation controls explain that the new level's ID became a
future theme ID.

This is a workflow and transaction problem, not merely a missing text field.
Adding an editable field without coordinated validation and export would make
it easier to create invalid cross-file references.

## Goals

- Let a non-developer create a level and its visual theme identity in one
  discoverable workflow.
- Let multiple levels explicitly reuse one existing theme.
- Support creating and assigning a new theme to an existing level, not only at
  initial level creation.
- Keep `LevelDef.visualThemeId` and `ParallaxThemeDef.parallaxThemeId` equal at
  the reference boundary without inventing a third identity.
- Keep level metadata ownership in the Level domain and parallax layer/theme
  serialization ownership in the Parallax domain.
- Preserve canonical ordering, normalized formatting, source-drift checks,
  deterministic validation, explicit apply confirmation, and post-apply
  reload.
- Make the two-file operation one undo unit before export and one rollback-safe
  transaction during export.
- Leave the repository in a cross-file-valid state after every successful
  apply.

## Non-goals

- Do not edit parallax layers from Level Creator.
- Do not make parallax themes own terrain materials, ground geometry, collision,
  traversal, spawn, or streaming data.
- Do not add theme rename or deletion. Both require reference-aware lifecycle
  rules beyond this repair.
- Do not clone a theme automatically when duplicating a level. Duplication
  continues to reuse the source level's theme unless the author explicitly
  creates and assigns another theme.
- Do not create a generic multi-plugin transaction/session framework. This
  change needs one bounded Level-plus-theme workflow.
- Do not run the content generator implicitly from a widget action. Generated
  runtime output remains governed by the explicit repository generator
  workflow, and the editor must report when that publication step remains.
- Do not weaken validation or source-drift checks to preserve the current
  two-apply workaround.

## Terminology And Identity Contract

`visualThemeId` is the reference stored by a level. `parallaxThemeId` is the
identity stored by the referenced parallax theme. They are two field names for
the two sides of one reference:

```text
LevelDef.visualThemeId ──────────────> ParallaxThemeDef.parallaxThemeId
```

The UI should call the concept **Visual theme** and explain that its parallax
layers are edited in the Parallax route. It must not imply that creating this
theme creates terrain materials or ground visuals.

Theme IDs use the same stable identifier grammar already required by level
theme references: `^[a-z][a-z0-9_]*$`. The rule must be single-sourced for both
editor domains and enforced equivalently by the root generator. Input is
trimmed for field handling but is not lowercased, separator-rewritten, or
otherwise silently coerced into an identity. A theme ID is stable after
creation; rename is outside this scope.

The root generator derives a Dart symbol from each theme ID. Validation must
also reject two distinct theme IDs that map to the same generated symbol (for
example IDs distinguished only by repeated separators). Successful editor
validation must be sufficient to prevent duplicate generated declarations.

Generated Dart is output, never validation authority. The current standalone
Parallax loader consults the existing generated `level_registry.dart` for
referenced theme IDs. That dependency must be removed from the generation path:
cross-file references are validated from the candidate authored
`level_defs.json` plus `parallax_defs.json`, then the registry is regenerated
from that same admitted pair. A stale or missing generated registry must not
block legitimate authoring-source regeneration.

An empty theme is a valid creation result:

```json
{
  "parallaxThemeId": "crystal_caves",
  "revision": 1,
  "layers": []
}
```

This gives the level a valid reference while leaving visual composition to the
Parallax route. The current generator and runtime representation accept empty
background and foreground layer lists; focused tests must freeze that behavior
before the workflow relies on it.

## Target Author Workflow

### Create a level with a new theme

1. Choose **New Level** and enter `levelId`.
2. Leave **Create new theme** selected or choose it explicitly.
3. Accept the suggested theme ID or enter another stable ID.
4. Create the level. The candidate document now contains both the level and the
   empty theme.
5. Review one pending preview containing `level_defs.json` and
   `parallax_defs.json`.
6. Apply once. Both files commit or neither commits.
7. Choose **Open in Parallax** and add layers to the new theme.
8. Run the explicit root content generator after level and layer authoring is
   complete, then run its dry-run check to prove generated output has no drift.

### Create a level that reuses a theme

1. Choose **Use existing theme**.
2. Select an authored theme from the deterministic catalog.
3. Create and apply the level. `parallax_defs.json` remains byte-identical.

### Assign a new theme to an existing level

1. In the selected level's Visual theme control, choose **Create and assign new
   theme**.
2. Enter a unique stable ID.
3. The level mapping and empty theme are staged as one command.
4. Review and apply both files once, then open the level in Parallax.

### Cancel or revise before apply

- Undo of **Create level with new theme** removes both candidate records in one
  step.
- Undo of **Create and assign new theme** restores the previous level mapping
  and removes the session-created theme in one step.
- A session-created empty theme is removed from the candidate when its final
  candidate level reference is removed. This pruning applies only to themes
  created by the current Level workflow; loaded themes are never deleted
  implicitly.
- Route or workspace changes remain protected by the existing unsaved-work
  guard because the compound pending preview reports both files.

## Architecture And Ownership

### Narrow workflow composition

`LevelDomainPlugin` remains the plugin selected by the Level Creator route, but
its authoring document becomes a Level workflow snapshot containing:

- the editable `LevelDefsDocument` candidate and baseline;
- the Parallax-owned theme catalog candidate and source baseline needed for
  theme creation;
- session provenance identifying which empty themes were created by compound
  Level commands;
- cross-file operation issues.

This can be introduced as a small wrapper document or as an equivalent focused
composition. The implementation must not copy Parallax parsing, normalization,
serialization, or validation into Level code.

| Concern | Owner | Invariant |
| --- | --- | --- |
| Level parsing, normalization, and save plan | `LevelStore` | Canonical level ordering and revision rules remain single-sourced. |
| Parallax parsing, normalization, and save plan | `ParallaxStore` | Canonical theme/layer ordering remains single-sourced. |
| Create/use-existing intent and candidate coordination | Level workflow plugin/coordinator | One semantic command updates both candidates. |
| Cross-file reference validation | Focused Level-theme workflow validator | Every candidate `visualThemeId` resolves before export. |
| Pending two-file plan | Focused Level-theme save coordinator | Previewed bytes are the bytes offered to the transaction. |
| Repository replacement | `WorkspaceWriteTransaction` | Both files commit and verify or originals are restored. |
| Layer editing | `ParallaxDomainPlugin` and Parallax page | Level Creator never becomes a layer editor. |
| Undo/redo and unsaved guard | `EditorSessionController` | The compound workflow is still one active plugin document. |

The current `AuthoringDomainPlugin` interface does not need to become
multi-document-aware. From the session's perspective, the Level workflow is
one immutable `AuthoringDocument` with one deterministic scene, validation
result, pending preview, and export path.

### Store seams

The Level and Parallax stores need reusable pure planning and public drift-check
seams suitable for composition. The workflow coordinator may ask each store to:

- load its typed source snapshot, including the exact raw source content used
  by pending diffs as well as its fingerprint;
- build a canonical candidate/save plan;
- validate its own document;
- verify that its captured baseline is still installed;
- provide the exact target path and after-content for a transaction.

Save-plan construction must not reread the current filesystem to obtain its
`beforeContent`. It projects from the immutable loaded baseline; external
changes are drift and are rejected at apply rather than incorporated into a
misleading pending preview.

It must not call each store's current independent `save` method in sequence,
because two successful single-file atomic writes do not form one atomic
cross-file operation.

### Candidate mapping

Parallax validation currently derives `parallaxThemeIdByLevelId` from loaded
level source. In the compound workflow, validation and scene projection must
derive that map from the candidate level list. Otherwise a newly staged level
would still appear unresolved until after export.

The derived map is not a third persisted source. It is recomputed
deterministically from the candidate `LevelDef` list.

## Command Contract

Use explicit semantic commands rather than inferring creation from field
contents. Conceptually the workflow needs:

- `create_level_with_existing_theme(levelId, visualThemeId, ...)`
- `create_level_with_new_theme(levelId, visualThemeId, ...)`
- `assign_existing_theme(levelId, visualThemeId)`
- `create_and_assign_theme(levelId, visualThemeId)`

Exact Dart names may follow existing command conventions, but the creation mode
must remain explicit in the payload/model.

For **new theme** commands, acceptance requires all of the following before the
document changes:

- level ID and theme ID satisfy their stable identifier grammars;
- the level ID is unique for level creation;
- the theme ID does not collide with a loaded or already staged theme;
- the theme ID's generated Dart symbol does not collide with another theme;
- both source documents loaded without blocking parse/schema issues;
- the complete candidate level and theme documents validate;
- the new level reference resolves in the candidate theme catalog.

Rejected commands return the unchanged source candidate plus an actionable,
stable operation issue. They create no undo entry and no pending diff.

Revision behavior remains semantic and exactly-once: a new level and new theme
start at revision 1; assigning a different theme to an existing level increments
that level revision once; reusing a theme never changes the theme revision; and
no unrelated level or theme revision changes.

## Validation Contract

After this workflow ships, an unresolved `visualThemeId` is a blocking Level
workflow error whenever the parallax source is available and parseable. The
warning-only behavior exists to permit the broken two-step pipeline and should
not remain the normal escape hatch.

Validation order is deterministic:

1. load/schema issues from both sources;
2. Level-domain structural issues;
3. Parallax-domain structural issues;
4. cross-file identifier/reference issues;
5. command-specific operation issues.

Required stable findings include:

- invalid new theme ID;
- duplicate/colliding theme ID;
- generated Dart theme-symbol collision;
- missing or unreadable parallax source;
- unresolved level theme reference;
- non-canonical theme ordering;
- source drift on either file;
- transaction or rollback failure.

Empty layer lists remain valid. Unreferenced loaded themes also remain valid
because themes are reusable catalog objects and may be prepared before use.

## Pending Changes, History, And Export

### Pending preview

The Level workflow pending summary includes both store plans. Changed item IDs
must be namespaced so equal level/theme strings cannot collide, for example:

- `level:crystal_caves`
- `parallaxTheme:crystal_caves`

Level row dirty-state code must consume the namespaced form explicitly.

The preview must show:

- only `level_defs.json` when an existing theme is reused;
- both `level_defs.json` and `parallax_defs.json` when a theme is created;
- exact canonical after-content from the same save plan later offered to the
  transaction.

### Apply transaction

The compound apply path must:

1. rebuild both save plans from the current immutable candidate;
2. reject if the rebuilt plan differs from the previewed/confirmed plan;
3. stage every changed file through `WorkspaceWriteTransaction`;
4. verify both captured source baselines in `beforeReplace` immediately before
   any target moves;
5. install and byte-verify both outputs;
6. reparse and validate the installed level/theme pair in
   `verifyReplacements` while rollback is still possible;
7. roll back both originals on any drift, write, parse, or validation failure;
8. reload the Level workflow from installed bytes after success.

The apply confirmation states whether one or two files will change and names
both source paths. It must not present a successful Level apply if the theme
write or post-write verification failed.

`WorkspaceWriteTransactionException.outputsCommitted` requires a distinct
recovery state. If replacement and verification succeeded but backup cleanup
failed, the new outputs are already authoritative and must not be described as
rolled back. The editor reloads and verifies the installed pair, blocks another
apply until the cleanup state is resolved, and reports the exact leftover paths.
The plugin returns a typed applied-but-cleanup-required result so the existing
controller still performs its canonical post-apply reload; UI must not infer
this state from artifact prose. Recovery may retry deletion only for the exact
structured sibling temp/backup paths reported by the transaction, after
re-verifying installed target bytes and workspace containment. If
`outputsCommitted` is false, the result reports whether rollback was complete
and never claims that the candidate was applied.

## Generated Runtime Publication

The authoring transaction intentionally owns only:

- `assets/authoring/level/level_defs.json`
- `assets/authoring/level/parallax_defs.json`

The root generator subsequently owns the derived level enum/registry, UI level
metadata, parallax Dart registry, and other generated artifacts in its existing
artifact plan. Therefore:

- **Open in Parallax** can work immediately after authoring apply because the
  editor resolves levels from authored `level_defs.json` first;
- gameplay/runtime must not be claimed current until the non-dry generator run
  completes;
- `--dry-run` is a verification step and is expected to report drift before
  generation when a level or theme was newly authored;
- the post-apply UI/docs must show the exact publication command and distinguish
  **authoring saved** from **runtime generated**;
- generator validation must enforce the same reference and generated-symbol
  rules as the editor so invalid source cannot reach Dart output;
- generator validation must not read the previously generated level registry
  as an input authority; reference validation uses the candidate authored
  Level and Parallax results already loaded by the root generator.

## UI Contract

### New-level controls

Replace the hidden `visualThemeId = levelId` fallback with visible controls:

- segmented/radio choice: **Create new theme** / **Use existing theme**;
- editable **New theme ID** in create mode;
- searchable or standard deterministic theme selector in reuse mode;
- inline uniqueness, format, and source-availability diagnostics;
- helper text explaining that layers are added in Parallax after apply.

The create button is disabled only for locally knowable input errors. Plugin
validation remains authoritative after the command.

### Existing-level inspector

Keep the existing-theme selector and add **Create and assign new theme**. Do
not place a fake missing item in the normal selector as the primary creation
mechanism. A loaded unresolved reference should instead show a blocking repair
state with actions to create the missing theme or select an existing one.

The label should not say that the parallax theme owns ground. Terrain material
authoring remains separate.

### Handoff to Parallax

After successful apply, expose **Open in Parallax**. The shell performs a
guarded plugin transition using a Parallax-plugin-owned targeted loader that
validates and selects the requested level before the session swap becomes
visible. This uses the existing atomic cross-plugin load seam and avoids
teaching the shell how to construct a Parallax document.

The Level page captures a typed, page-local handoff target from the candidate
scene immediately before confirmed export. It activates that target only when
export reports applied, the controller finishes its canonical reload, no
pending changes remain, and the reloaded level still resolves the same theme.
This transient state deliberately survives the controller's post-export
document replacement but is cleared by later edits, reload failure, workspace
change, or route disposal. It is never reconstructed by parsing a human-readable
export summary. This is navigation context only; it does not add another
repository mutation.

The handoff is unavailable while compound changes remain unapplied. It must not
silently apply or discard work.

## Alternatives Considered

### Create standalone themes in Parallax first

This would avoid multi-file writes and is a useful possible future capability,
but by itself it only reverses the required order: authors must know to create
the theme before the level. It does not provide the requested level-first
workflow or one coherent create-and-assign action.

### Write the empty theme immediately, then create the level

This bypasses pending-diff review, undo, explicit confirmation, and compound
rollback. It also leaves an orphan theme if level creation is cancelled. It is
not compatible with current editor write-safety rules.

### Generalize the session to edit every plugin simultaneously

That would solve a broader problem than this workflow requires and would
expand history, validation, routing, and export semantics across all domains.
The focused composite Level workflow keeps the change bounded while using the
existing plugin/session contract.

## Delivery Phases

### Phase 0 — Characterization and contract freeze

Capture the current circular workflow in focused tests, freeze terminology and
UI behavior, and confirm empty themes remain valid.

Gate: tests demonstrate the current fallback, warning-only unresolved
reference, and active-level-only Parallax creation behavior.

### Phase 1 — Compound document and pure planning

Load both typed source snapshots into the Level workflow, derive candidate
level-to-theme mapping, add explicit compound commands, and produce
deterministic one- or two-file pending plans. Bring editor and root-generator
theme identity/symbol validation into parity.

Gate: pure tests prove create, reuse, collision, undo identity, pruning, stable
ordering, generator-safe identity, and exact pending bytes without filesystem
mutation.

### Phase 2 — Rollback-safe two-file export

Compose store outputs through `WorkspaceWriteTransaction`, add dual-baseline
drift checks and installed-pair verification, and surface rollback evidence.

Gate: injected failures at every replacement/verification boundary either
commit the complete valid pair or restore both original files exactly.

### Phase 3 — Level Creator UX

Add explicit creation modes, repair state, validation messages, compound apply
confirmation, and namespaced dirty indicators.

Gate: widget tests cover new level/new theme, reuse, collision, existing-level
assignment, undo, and discard guards.

### Phase 4 — Parallax handoff and route coherence

Add guarded **Open in Parallax** navigation with a plugin-owned targeted load
after a successful apply. Show that runtime generation is still required.

Gate: the target route loads the committed theme, selects the intended level,
and can add a layer without manual registry/file edits.

### Phase 5 — Hardening and documentation closure

Run the explicit generator followed by its dry-run, run full editor validation,
remove the hidden fallback and obsolete warning-driven path, update current
editor/TDD documentation, and archive these planning documents only after all
accepted scope is complete.

Gate: the complete non-developer workflow leaves no invalid intermediate
source state and all relevant suites pass.

## Acceptance Criteria

- A user can create a level plus a unique empty visual theme with one Level
  Creator command and one Apply action.
- The pending preview and confirmation name both files before a compound write.
- A successful apply installs a level whose `visualThemeId` resolves to an
  authored `parallaxThemeId` immediately.
- A failure or drift in either file leaves both original files byte-identical.
- A post-commit cleanup failure is reported as committed-with-cleanup-required,
  reloads the installed pair, and is never mislabeled as rollback.
- Reusing an existing theme changes no parallax source bytes.
- Multiple levels can reuse one theme without duplicating it.
- An existing level can create and assign a new theme atomically.
- Undo before export reverses the level and session-created theme together.
- Route/workspace/app-close guards recognize both pending files.
- Parallax can open the committed theme directly and remains the sole UI for
  layer authoring.
- The editor distinguishes saved authoring source from generated runtime state
  and gives the exact explicit generation/verification sequence.
- Theme creation does not create or mutate terrain material or gameplay data.
- Theme IDs cannot create colliding generated Dart declarations.
- Canonical output, analyzer, editor/root tests, an explicit generator run, and
  the subsequent generator dry-run are clean.
