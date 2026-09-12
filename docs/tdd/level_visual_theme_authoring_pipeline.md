# Level And Visual Theme Authoring Pipeline

## Status

Implemented on August 14, 2026.

This document defines the editor-side ownership, identity, validation,
transaction, navigation, and generated-runtime publication contracts for Level
Creator and Parallax. It describes current behavior, not a future design.

## Source Ownership

Two authored files participate in the workflow:

| Source | Owner | Data |
| --- | --- | --- |
| `assets/authoring/level/level_defs.json` | `LevelStore` | Level identity, display/runtime metadata, `visualThemeId`, assembly, revision, build inclusion, and status |
| `assets/authoring/level/parallax_defs.json` | `ParallaxStore` | Reusable visual-theme identities, ordered background/foreground layers, and theme revisions |

`LevelDef.visualThemeId` is a reference to
`ParallaxThemeDef.parallaxThemeId`. Parallax themes are visual-only. Terrain
materials continue to own terrain rendering material data; neither the Level
workflow nor a Parallax theme gains terrain or gameplay authority.

Generated Dart is output and is never an authoring input. In particular,
`packages/runner_core/lib/levels/level_registry.dart` is not consulted to admit
the authored Level/Parallax pair or to regenerate the Parallax registry.

Parallax PNGs use `assets/images/parallax/<theme>/<sheet>.png`. Theme and sheet
names are lowercase snake_case, and sequential source layers use zero-padded
`layer_NN.png` names. The visual-theme ID remains independent of a folder name,
so multiple levels can reuse the same authored theme and asset collection.

## Identity Contract

Level IDs and visual-theme IDs use the shared editor grammar:

```text
^[a-z][a-z0-9_]*$
```

Explicit identity input may be trimmed, but persisted identities are not lowercased
or separator-rewritten. New Level and Copy forms can supply only a friendly name:
the domain allocates a unique lowercase snake_case identity with numeric collision
suffixes. New theme identities derive from the target Level identity and avoid
both authored-ID and generated-symbol collisions. Theme validation computes the Dart declaration suffix used by
the root generator and rejects distinct IDs that would emit the same symbol.
The root generator enforces the same grammar and symbol-uniqueness rules before
writing generated output.

An empty theme is valid and is the result of the explicit empty-background mode:

```json
{
  "parallaxThemeId": "crystal_caves",
  "revision": 1,
  "layers": []
}
```

Independent background-copy mode creates a new revision-1 theme with the selected
source theme's layers, sharing referenced PNG assets without changing the source
theme. Subsequent layer authoring remains in the Parallax route.

### Level Schema And Build Inclusion

Level source uses strict schema v2 with a required boolean `includeInBuild` on
each record. Normal editor and generator parsers reject v1 and missing or
coerced inclusion values. The explicit migration commands are:

Schema v2 also permits an optional non-empty `firstChunkKey`. The identity is
Level-scoped and must resolve to an active Chunk in the scheduler pool for
index zero. It is omitted for automatic opening selection.

```bash
dart run tool/migrate_level_build_inclusion.dart --check
dart run tool/migrate_level_build_inclusion.dart --apply
```

Migration validates canonical v1 input, sets every existing record to included,
and preserves identities, ordinals, revisions, status and design values. Valid
v2 input is a no-op. New and copied levels start excluded. Updating inclusion
uses the normal revisioned `update_level` command and Save path; it never clears
groups, assembly, chunk identities or theme references. Inclusion can be saved
before whole-level readiness succeeds.

Persisted Level identities cannot be deleted or have their enum ordinals changed;
new identities append above the highest persisted ordinal. Domain commands and
compound Save validation enforce this baseline contract, including direct
candidate and installed-source verification, so exclusion cannot recycle a slot.

Build inclusion and deprecation are independent. Included deprecated levels
remain available to exact registered lookup, while only included active levels
appear in standard selection. Excluded source remains editable and is eligible
for authored Play when ready.

## Compound Session Document

The active Level plugin document contains:

- the canonical Level candidate and its exact loaded source baseline;
- a typed Parallax candidate and its exact loaded source baseline;
- candidate-derived available theme IDs;
- a candidate-derived level-to-theme map;
- session-only provenance for empty or copied themes created by Level commands;
- load and operation findings.

This remains one `AuthoringDocument` to the session controller. A compound
content command therefore produces one undo entry, and undo/redo restores both
the Level reference and staged theme together. `set_active_level` is declared
as presentation through `AuthoringSessionSemantics`: selection changes do not
require a content undo entry. Content restoration retains the selected level
when it still exists, keeping the compound Parallax selection coherent.

The workflow supports these semantic cases:

- create a level and a new empty theme;
- create a level that reuses an existing theme;
- create or copy a level with an independent copy of an existing background;
- assign an existing theme to an existing level through the normal inspector;
- create and assign a new empty theme to an existing level.
- copy and assign an existing background under a new identity to an existing level.

Creation mode is explicit. A collision in create-new mode is an error and never
silently changes into reuse. New Level/theme records begin at revision 1.
Changing an existing Level's reference increments only that Level once. Reuse
does not alter a theme revision.

`create_level` accepts `displayName`, optional advanced `levelId`, and explicit
`themeMode` (`create`, `existing`, or `copy`). Independent creation/copy may omit
`visualThemeId`; copy uses `sourceVisualThemeId`. `copy_assign_theme` uses the same
copy fields plus the existing `levelId`. `duplicate_level` retains source
`levelId` and optional target `nextLevelId`; `copySectionDesign` is an explicit
boolean, defaulting false. Normal Copy settings keeps numeric settings and the
chosen background but resets assembly to Automatic and groups to `default`.
Explicit section-design copy retains groups, section IDs/order and rules. Neither
mode copies chunk sources. New uses camera 135, ground 224, Early 3, Easy 0,
Normal 0 and enemy-free opening 3, independent of the currently selected Level.

Session-created themes are pruned when their final candidate Level reference is
removed. Themes loaded from source are never implicitly pruned, even when they
are currently unused.

## History Across Save

Level and Parallax implement `AuthoringHistoryReconciliation`. Canonical Save
reloads retain their value-edit history. Each undo/redo target supplies desired
content only; the plugin reconciles it over the current document's loaded source
fingerprints, persisted baselines, dependency snapshots, and valid selection.
An explicit reload or ordinary route handoff establishes a fresh history.

Restoring the current persisted content also restores its baseline revision, so
undoing unsaved work can become clean. Restoring different content advances from
the current revision and baseline; historical revision numbers are never
reinstated. A Save, Undo, Save sequence therefore writes increasing revisions
without reusing an old fingerprint.

Creation can be undone before its first Save, including its Level-owned staged
theme. The first successful Save seals each persisted identity and Level enum
ordinal: an older history target cannot delete it or recycle its ordinal. Value
edits before and after that creation remain undoable. History pruning walks
each stack in order against its preceding reconciled target, preserving repeated
values such as A, B, A across Save.

Level history restores Level settings and assembly, plus its own pending theme
creation. It retains the current layers of already-loaded themes; layer history
belongs to Parallax. Parallax history retains the current Level catalog and
level-to-theme mapping while restoring theme layers. Both reject history from a
different workspace. These projections pass through the normal validation and
Save paths; restoring content never grants permission to write stale sources.

## Validation

`validateLevelDocument` evaluates the compound candidate and includes complete
Parallax validation. A Level reference that does not resolve in the available
authored theme catalog is a blocking error when the Parallax source exists.

Export is blocked when either source has a load/schema/canonical error, either
domain has a structural error, the cross-file reference is unresolved, or an
operation finding is blocking. Empty layer lists and unreferenced loaded themes
remain valid.

`ValidationIssue.blocks(AuthoringOperation.save)` determines Save admission;
error severity alone does not. Existing errors block Save, Play, and Build by
default, while warnings and information are nonblocking. The
`insufficient_distinct_group_chunks` error blocks Play and, for included levels,
Build. It retains its level owner and visible diagnostic. An author can save an
incomplete ordered design and populate its groups without removing its rules.
The existing no-authored-chunks warning also remains saveable.

Compound theme commands, plugin export, coordinator preflight, and installed
candidate verification use the same Save predicate. Structural/schema/canonical
errors, missing references, invalid source assets, and source-drift guards remain
strict across those gates. Installed candidates are still reparsed and compared
before transaction commit. Aggregate group counts are advisory authoring input;
runtime generation/preparation retains its canonical compiler and scheduler
validation rather than treating successful Save as proof of runtime readiness.
Level-scoped validation findings expose the exact Level ID in `ownerKey` for
diagnostic navigation; source-wide findings retain their source path. Section
findings include stable `elementId` and authored `fieldKey`, so navigation survives
section reordering without parsing a diagnostic message.

Dependency-repair preflight requires a complete editable current source document.
Strict Chunk/Prefab documents qualify after decoding; Parallax/material documents
must have their source baseline and no blocking load findings. Migration-only,
missing and partially decoded sources leave the origin intact. Computed value,
image and runtime findings remain repairable and do not prevent opening a readable
dependency for correction.

Semantic recovery recreates a never-persisted Level-owned theme with its retained
immutable layer snapshot. It does not recopy a shared theme's newly changed layers
or replace a current saved theme. If another writer allocated that pending theme
identity, recovery requires an explicit saved-version choice and cannot overwrite
it. The normal compound creation command validates the retained snapshot against
the new identity and all current source/asset gates.

The Parallax handoff loader reloads authored sources and verifies all of the
following before changing the active plugin session:

- the requested Level still exists;
- it still resolves to the requested theme ID;
- that theme still exists;
- the resulting Parallax document has no blocking validation errors.

## Deterministic Planning

Both stores retain the exact raw source content and fingerprint captured during
load. Save planning renders canonical candidate output from immutable state and
uses the captured bytes as diff `beforeContent`; it does not reread current
filesystem bytes.

The Level/theme coordinator combines both plans and namespaces dirty identities:

```text
level:<levelId>
parallaxTheme:<parallaxThemeId>
```

Writes and identities are sorted deterministically. Reuse normally produces
only the Level write. New-theme creation produces both Level and Parallax
writes. The unified diffs shown in Level Creator are built from the exact
planned bytes later offered to the transaction.

Immediately before apply, the coordinator rebuilds the plan and requires exact
equality with the confirmed plan.

## Repository Transaction

All changed files are submitted to one `WorkspaceWriteTransaction`.

1. Complete outputs are staged as sibling temporary files.
2. `beforeReplace` verifies both captured source baselines, including the
   unchanged Parallax baseline in a one-file reuse apply.
3. Existing targets move to sibling backups.
4. Staged files replace their targets and are byte-verified.
5. While backups still exist, both installed sources are reparsed with their
   owning store codecs, checked for canonical bytes, compared with the admitted
   candidate, and run through compound validation again.
6. Any failure rolls both sources back through the transaction.
7. Verified output commits remove transaction artifacts and the session reloads
   from installed source.

A transaction exception exposes `outputsCommitted`, rollback failures, and
exact remaining recovery paths. If output verification succeeded but backup
cleanup failed, the Level plugin returns an applied typed result with validated
transaction-sibling recovery paths. The editor reloads the committed sources,
reports cleanup-required state, and disables another apply. It never describes
that state as a rollback.

The editor does not offer automatic recovery deletion. Operators must inspect
and remove only the reported transaction artifacts before applying again.

## Level Creator UX

New Level creation defaults to **Create new theme**. The new theme ID follows
the Level ID until the author edits the theme field manually. **Use existing
theme** requires an explicit selection from the deterministic authored catalog.

The existing-Level inspector labels the field **Visual theme (Parallax)**,
allows normal reassignment, and offers **Create and assign new theme**. An
unresolved loaded reference is rendered as a blocking repair state with actions
to create the missing theme or select an existing one; it is not inserted as a
fake dropdown option.

Apply is disabled for blocking validation, pending-plan failure, active export,
or committed-output cleanup state. Confirmation names every affected source.
Pending preview renders every planned file diff, and Level dirty markers consume
the namespaced identity.

## Guarded Parallax Handoff

Immediately before confirmed apply, Level Creator captures a typed transient
`ParallaxLevelTarget` containing the active `levelId` and `parallaxThemeId`.
The **Open in Parallax** action appears only after:

- export reports `applied`;
- the controller completes its canonical reload;
- the reloaded Level still resolves the exact target;
- no pending changes or local drafts remain;
- no cleanup-required state exists.

The shell uses its atomic `loadWorkspaceForPlugin` path and the
Parallax-plugin-owned targeted loader. Failure leaves the Level session active.
The handoff never applies, discards, or bypasses the unsaved-work guard.

## Generated Runtime Publication

Schema-v2 assembly segments accept optional `difficulty` with one of `early`,
`easy`, `normal`, or `hard`. Omission selects global progression and existing tier
fallback; explicit null or any other value is invalid. Canonical output omits
Automatic difficulty. This additive setting round-trips through commands, Save,
copy, history and generated `LevelAssemblySegment` definitions.

Explicit difficulty fixes the eligible pool for the whole section occurrence.
`AssembledChunkPatternSource` uses the existing seed/run permutation to select
distinct chunks without replacement, or indexed selection when repeats are
allowed. Source list ordering and stable hash tie-breaks remain deterministic.
The Core seam scheduler, shared pipeline, Chunk seam checks and whole-Level
playtest preparation carry the same optional tier. Exact pools do not fall back;
capacity is checked against the section's maximum count. Fully explicit schedules
do not require enumeration of unused global difficulty windows. Sample requested
tiers report the section override, matching runtime selection.

Existing sources without section difficulty keep their selection behavior. No
run-ticket or replay payload changes are required: client and replay validator
consume the same generated Core level definitions and deterministic scheduler.

The compound apply updates authored JSON only. Runtime output is published
explicitly after Level and Parallax authoring is complete:

```bash
dart run tool/generate_chunk_runtime_data.dart
dart run tool/generate_chunk_runtime_data.dart --dry-run
```

Build parses every Level, theme, Prefab, tile and chunk source and validates
references, identities, assets and individual geometry, including excluded
content. Exclusion never hides corruption. The shared pipeline then proves
scheduler reachability and seams for included levels, using only active chunks.
`isRuntimeEligibleChunkStatus` is the common active-chunk admission predicate for
generation, authored Play and editor section-capacity counts. Deprecated chunks
remain structurally checked and do not satisfy runtime capacity.

The pipeline returns all structurally compiled chunks for complete reference and
asset validation, and a separate validated batch containing only runtime-eligible
chunks. Only that batch becomes generated terrain; generated pattern pools use
the same eligibility. Included levels must have active playable content, and at
least one included active level must pass admission before the artifact
transaction can replace any generated output.

The generated enum and display/theme metadata retain every authored identity in
stable ordinal order. `LevelRegistry.compiledLevelIds` records availability;
`defaultLevelId` selects an included active record. Lookup of an excluded ID
throws `LevelUnavailableException` before constructing a definition or accessing
absent pools. UI selection output contains only included active identities;
deprecation and exclusion never rewrite ticket, replay or ghost identities.

Level Creator distinguishes **authoring sources saved** from runtime
generation and shows both commands after apply. A dry-run before publication is
expected to report generated drift; the post-generation dry-run must be clean.

## Test Coverage

Focused coverage lives in:

- `tools/editor/test/level_visual_theme_workflow_test.dart`;
- `tools/editor/test/level_save_admission_test.dart`;
- `tools/editor/test/level_parallax_history_test.dart`;
- `tools/editor/test/level_creator_page_test.dart`;
- `tools/editor/test/level_domain_plugin_test.dart`;
- `tools/editor/test/level_domain_plugin_integration_test.dart`;
- `tools/editor/test/parallax_domain_plugin_test.dart`;
- `tools/editor/test/workspace_write_transaction_test.dart`;
- `test/tool/generate_chunk_runtime_data_test.dart`;
- `tools/editor/test/level_creation_workflow_test.dart`;
- `tools/editor/test/authoring_intent_reconciliation_test.dart`;
- `tools/editor/test/dependency_repair_admission_test.dart`;
- `test/tool/level_build_inclusion_migration_test.dart`;
- `packages/runner_content_pipeline/test/polygon_terrain_repository_generation_test.dart`.

These tests cover explicit creation/reuse, candidate mapping, revision and
pruning behavior, namespaced plans, one- and two-file applies, baseline drift,
rollback, committed cleanup state, target loading, first-layer creation,
widget repair/undo/narrow layout, and generator identity authority.
Save-admission regressions also cover incomplete copied sequences, compound
theme creation on an incomplete design, direct coordinator admission and installed
verification, strict structural rejection, and unchanged source-drift protection.
History regressions cover Save/Undo/Save revisions, clean unsaved Undo, first-save
identity fences, compound creation redo, repeated-value stacks, preserved current
dependency snapshots and theme layers, selection, and workspace boundaries.
Inclusion regressions cover strict migration, excluded Field/default selection,
stable enum slots, runnable generated lookup failures, included deprecated
lookup, set-aside/resume with unchanged rules, no-playable-level publication
rejection, and excluded-source/deprecated-chunk validation.
