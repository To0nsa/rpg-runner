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
| `assets/authoring/level/level_defs.json` | `LevelStore` | Level identity, display/runtime metadata, `visualThemeId`, assembly, revision, and status |
| `assets/authoring/level/parallax_defs.json` | `ParallaxStore` | Reusable visual-theme identities, ordered background/foreground layers, and theme revisions |

`LevelDef.visualThemeId` is a reference to
`ParallaxThemeDef.parallaxThemeId`. Parallax themes are visual-only. Terrain
materials continue to own terrain rendering material data; neither the Level
workflow nor a Parallax theme gains terrain or gameplay authority.

Generated Dart is output and is never an authoring input. In particular,
`packages/runner_core/lib/levels/level_registry.dart` is not consulted to admit
the authored Level/Parallax pair or to regenerate the Parallax registry.

## Identity Contract

Level IDs and visual-theme IDs use the shared editor grammar:

```text
^[a-z][a-z0-9_]*$
```

Form input may be trimmed, but identities are not lowercased or separator-
rewritten. Theme validation also computes the Dart declaration suffix used by
the root generator and rejects distinct IDs that would emit the same symbol.
The root generator enforces the same grammar and symbol-uniqueness rules before
writing generated output.

An empty theme is valid and is the canonical result of Level-side creation:

```json
{
  "parallaxThemeId": "crystal_caves",
  "revision": 1,
  "layers": []
}
```

Layer authoring remains in the Parallax route.

## Compound Session Document

The active Level plugin document contains:

- the canonical Level candidate and its exact loaded source baseline;
- a typed Parallax candidate and its exact loaded source baseline;
- candidate-derived available theme IDs;
- a candidate-derived level-to-theme map;
- session-only provenance for empty themes created by Level commands;
- load and operation findings.

This remains one `AuthoringDocument` to the session controller. A compound
command therefore produces one undo entry, and undo/redo restores both the
Level reference and staged theme together.

The workflow supports four semantic cases:

- create a level and a new empty theme;
- create a level that reuses an existing theme;
- assign an existing theme to an existing level through the normal inspector;
- create and assign a new empty theme to an existing level.

Creation mode is explicit. A collision in create-new mode is an error and never
silently changes into reuse. New Level/theme records begin at revision 1.
Changing an existing Level's reference increments only that Level once. Reuse
does not alter a theme revision.

Session-created themes are pruned when their final candidate Level reference is
removed. Themes loaded from source are never implicitly pruned, even when they
are currently unused.

## Validation

`validateLevelDocument` evaluates the compound candidate and includes complete
Parallax validation. A Level reference that does not resolve in the available
authored theme catalog is a blocking error when the Parallax source exists.

Export is blocked when either source has a load/schema/canonical error, either
domain has a structural error, the cross-file reference is unresolved, or an
operation finding is blocking. Empty layer lists and unreferenced loaded themes
remain valid.

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

The compound apply updates authored JSON only. Runtime output is published
explicitly after Level and Parallax authoring is complete:

```bash
dart run tool/generate_chunk_runtime_data.dart
dart run tool/generate_chunk_runtime_data.dart --dry-run
```

Level Creator distinguishes **authoring sources saved** from runtime
generation and shows both commands after apply. A dry-run before publication is
expected to report generated drift; the post-generation dry-run must be clean.

## Test Coverage

Focused coverage lives in:

- `tools/editor/test/level_visual_theme_workflow_test.dart`;
- `tools/editor/test/level_creator_page_test.dart`;
- `tools/editor/test/level_domain_plugin_test.dart`;
- `tools/editor/test/level_domain_plugin_integration_test.dart`;
- `tools/editor/test/parallax_domain_plugin_test.dart`;
- `tools/editor/test/workspace_write_transaction_test.dart`;
- `test/tool/generate_chunk_runtime_data_test.dart`.

These tests cover explicit creation/reuse, candidate mapping, revision and
pruning behavior, namespaced plans, one- and two-file applies, baseline drift,
rollback, committed cleanup state, target loading, first-layer creation,
widget repair/undo/narrow layout, and generator identity authority.
